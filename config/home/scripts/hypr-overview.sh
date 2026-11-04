#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.config/eww-overview"
# Without --no-daemonize, a client that misses the daemon forks a second one
# under its own argv; that one steals the socket path and inherits fd 9.
EWW=(eww -c "$CONFIG" --no-daemonize)
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-overview.open"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-overview.lock"
OPEN_TIMEOUT_S=3
LOCK_TIMEOUT_S=5

push_data() {
  "${EWW[@]}" update overview="$("$HOME/scripts/hypr-overview.py")"
}

# A close that reaches the eww 0.5 daemon while an open is still in flight is a
# no-op, and the window then maps untracked so no later close can remove it.
take_lock() {
  exec 9>"$LOCK"
  flock -w "$LOCK_TIMEOUT_S" 9
}

overview_daemon_pids() {
  local pid
  for pid in $(pgrep -x eww); do
    tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -qF -- "-c $CONFIG " && echo "$pid"
  done
  return 0
}

# A daemon whose socket path was unlinked keeps its windows mapped but can no
# longer be reached, so killing it is the only way to remove them.
reset_daemon() {
  local pids
  pids=$(overview_daemon_pids)
  [ -n "$pids" ] || return 0
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
  for _ in $(seq 20); do
    [ -z "$(overview_daemon_pids)" ] && return 0
    sleep 0.1
  done
  # shellcheck disable=SC2086
  kill -9 $pids 2>/dev/null || true
}

ensure_daemon() {
  "${EWW[@]}" ping >/dev/null 2>&1 && return 0
  reset_daemon
  setsid -f eww -c "$CONFIG" daemon >/dev/null 2>&1 9>&-
  for _ in $(seq 50); do
    "${EWW[@]}" ping >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

case "${1:-}" in
  show)
    take_lock
    [ -e "$STATE" ] && exit 0
    ensure_daemon
    touch "$STATE"
    trap 'rm -f "$STATE"' ERR
    push_data
    # eww 0.5 addresses monitors by model, not connector; the list position is
    # the fallback for outputs without one (the tablet's virtual display), since
    # Hyprland ids keep gaps from disconnected outputs and eww's indices do not.
    screen=$(hyprctl -j monitors | jq -r 'to_entries[] | select(.value.focused) | if .value.model != "" then .value.model else (.key | tostring) end')
    if ! timeout "$OPEN_TIMEOUT_S" "${EWW[@]}" open overview --screen "$screen"; then
      rm -f "$STATE"
      "${EWW[@]}" close overview >/dev/null 2>&1 || reset_daemon
      exit 1
    fi
    ;;
  hide)
    take_lock || {
      rm -f "$STATE"
      reset_daemon
      exit 1
    }
    [ -e "$STATE" ] || exit 0
    rm -f "$STATE"
    "${EWW[@]}" close overview >/dev/null 2>&1 || reset_daemon
    ;;
  refresh)
    [ -e "$STATE" ] && push_data
    ;;
  *)
    echo "usage: hypr-overview.sh show|hide|refresh" >&2
    exit 2
    ;;
esac
