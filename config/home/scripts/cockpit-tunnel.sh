#!/usr/bin/env bash
# Forward Cockpit, the Claude fleet board, from the machine running it to this one over SSH,
# so it is usable at http://localhost:<port> from anywhere Tailscale reaches.
#
# Run this on the machine WHERE YOUR BROWSER IS, not on the machine running Cockpit.
# Cockpit binds 127.0.0.1 and rejects foreign Host and Origin headers, so a tunnel that keeps
# localhost as the origin is the supported way to reach it remotely.
#
# Usage:
#   cockpit-tunnel.sh                     # port 4821, host from $COCKPIT_TUNNEL_HOST or ~/.cockpit-tunnel-host
#   cockpit-tunnel.sh 4822                # another Cockpit port (a dev server)
#   cockpit-tunnel.sh 4821 4822           # several ports at once
#   cockpit-tunnel.sh --dev               # dev pair: server 4822 and Vite 5173
#   cockpit-tunnel.sh --host turny        # explicit host (also saved as the default)
#   cockpit-tunnel.sh --open              # open the first forwarded port in the browser
#
# Stop with Ctrl-C.
set -euo pipefail

HOST_FILE="$HOME/.cockpit-tunnel-host"
HOST="${COCKPIT_TUNNEL_HOST:-}"
PORTS=()
OPEN=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      [[ $# -ge 2 ]] || {
        echo "ERROR: --host needs a value" >&2
        exit 1
      }
      HOST="$2"
      echo "$HOST" > "$HOST_FILE"
      shift 2
      ;;
    --dev)
      PORTS+=(5173 4822)
      shift
      ;;
    --open)
      OPEN=1
      shift
      ;;
    -h | --help)
      sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      IFS=',' read -ra TOKENS <<< "$1"
      for TOKEN in "${TOKENS[@]}"; do
        [[ -n "$TOKEN" ]] || continue
        [[ "$TOKEN" =~ ^[0-9]+$ ]] || {
          echo "ERROR: unexpected port '$TOKEN' (use numbers like 4821 or 4821,4822)" >&2
          exit 1
        }
        PORTS+=("$TOKEN")
      done
      shift
      ;;
  esac
done

if [[ -z "$HOST" && -f "$HOST_FILE" ]]; then
  HOST="$(cat "$HOST_FILE")"
fi
HOST="${HOST:-turny}"

[[ ${#PORTS[@]} -gt 0 ]] || PORTS=(4821)

DEDUPED=()
for PORT in "${PORTS[@]}"; do
  [[ " ${DEDUPED[*]:-} " == *" $PORT "* ]] && continue
  DEDUPED+=("$PORT")
done
PORTS=("${DEDUPED[@]}")

FORWARDS=()
for PORT in "${PORTS[@]}"; do
  FORWARDS+=(-L "${PORT}:127.0.0.1:${PORT}")
  echo "Cockpit → http://127.0.0.1:$PORT"
done

if [[ -n "${COCKPIT_TUNNEL_PRINT_ONLY:-}" ]]; then
  echo "ssh ${FORWARDS[*]} $HOST"
  exit 0
fi

if [[ -n "$OPEN" ]]; then
  URL="http://127.0.0.1:${PORTS[0]}/"
  (
    sleep 2
    if command -v open >/dev/null 2>&1 && [[ "$(uname)" == Darwin ]]; then
      open "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$URL" >/dev/null 2>&1
    fi
  ) &
fi

echo "Tunnelling to $HOST — Ctrl-C to stop."
exec ssh -N \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes \
  "${FORWARDS[@]}" \
  "$HOST"
