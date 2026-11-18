#!/usr/bin/env bash
# Keep the Mac's ClipCascade client logged in.
#
# The server holds sessions in memory, so every time its container restarts
# every client's cookie dies. The Linux client survives that because
# clipcascade.sh supervises it (see session_is_valid there); the Mac app has no
# such supervision, and it cannot recover on its own:
#
#   - it only runs its login flow once, at startup
#   - afterwards it just retries the websocket with the dead cookie
#   - the server answers that handshake with a 302 to /login, the websocket
#     library tries to follow it, and dies on "scheme https is invalid"
#   - it then repeats that every 10s forever, silently
#
# So the fix is the same one the Linux side already uses: notice the session is
# gone and restart the client, which makes it log in again.
#
# A network outage (Tailscale reconnecting, sleep/wake) breaks it differently:
# the client reopens the websocket while the link is still flaky, logs
# "Websocket connected", and never gets its STOMP CONNECT through. The session
# cookie stays valid, so the check above passes, yet nothing syncs until the
# client restarts. So once the server is reachable again after an outage, the
# client is restarted regardless.
set -euo pipefail

APP="/Applications/ClipCascade.app"
DATA="$HOME/Library/Application Support/ClipCascade/DATA"
LOG="$HOME/Library/Application Support/ClipCascade/watchdog.log"
# Restarting takes ~15s to settle; without this a slow start looks like a dead
# session on the next tick and the watchdog restarts it forever.
RESTART_STAMP="${TMPDIR:-/tmp}/clipcascade-watchdog.stamp"
RESTART_COOLDOWN=120
# Present while the server is unreachable; its removal on recovery restarts the client.
OUTAGE_STAMP="${TMPDIR:-/tmp}/clipcascade-watchdog.outage"
CURL_TIMEOUT=8

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >>"$LOG"
}

# Reads one top-level string field out of the client's DATA file.
data_field() {
  python3 -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
key = sys.argv[2]
if key == 'jsessionid':
    print((d.get('cookie') or {}).get('JSESSIONID', ''))
else:
    print(d.get(key) or '')
" "$DATA" "$1" 2>/dev/null || true
}

restarted_recently() {
  local now stamp
  [ -f "$RESTART_STAMP" ] || return 1
  now="$(date +%s)"
  stamp="$(stat -f %m "$RESTART_STAMP" 2>/dev/null || echo 0)"
  [ $((now - stamp)) -lt "$RESTART_COOLDOWN" ]
}

restart_client() {
  : >"$RESTART_STAMP"
  pkill -f "$APP" 2>/dev/null || true
  sleep 3
  open "$APP"
  log "$1 -> restarted ClipCascade"
}

[ -d "$APP" ] || exit 0

if restarted_recently; then
  exit 0
fi

if ! pgrep -f "$APP" >/dev/null 2>&1; then
  restart_client "not running"
  exit 0
fi

server_url="$(data_field server_url)"
session="$(data_field jsessionid)"
# No cookie yet means the client is still logging in — leave it alone.
[ -n "$server_url" ] && [ -n "$session" ] || exit 0

# curl already prints 000 when it cannot connect; `|| true` keeps it from
# being doubled up.
status="$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" \
  -H "Cookie: JSESSIONID=$session" "$server_url/max-size" 2>/dev/null || true)"

case "$status" in
  200)
    if [ -f "$OUTAGE_STAMP" ]; then
      rm -f "$OUTAGE_STAMP"
      restart_client "server reachable again after outage"
    fi
    ;;
  302 | 401 | 403)
    # Authenticated endpoint is bouncing us to the login page: the session is
    # gone. This is the state the client can never dig itself out of.
    restart_client "session dead (HTTP $status)"
    ;;
  *)
    # 000 / 502 / 503: the server itself is down or still booting. Restarting
    # the client would not help — there is nothing to log in to yet.
    [ -f "$OUTAGE_STAMP" ] || log "server unreachable (HTTP ${status:-000}) - waiting"
    : >"$OUTAGE_STAMP"
    ;;
esac
