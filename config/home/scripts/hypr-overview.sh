#!/usr/bin/env bash
set -euo pipefail

EWW=(eww -c "$HOME/.config/eww-overview")
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-overview.open"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/hypr-overview.lock"
OPEN_TIMEOUT_S=3

push_data() {
  "${EWW[@]}" update overview="$("$HOME/scripts/hypr-overview.py")"
}

# A close that reaches the eww 0.5 daemon while an open is still in flight is a
# no-op, and the window then maps untracked so no later close can remove it.
take_lock() {
  exec 9>"$LOCK"
  flock 9
}

# Any eww client that finds no daemon forks one under its own argv, which then
# masquerades as a hung `eww open` and competes for the socket.
ensure_daemon() {
  "${EWW[@]}" ping >/dev/null 2>&1 && return 0
  setsid -f "${EWW[@]}" daemon >/dev/null 2>&1 9>&-
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
      "${EWW[@]}" close overview >/dev/null 2>&1 || true
      exit 1
    fi
    ;;
  hide)
    take_lock
    [ -e "$STATE" ] || exit 0
    rm -f "$STATE"
    "${EWW[@]}" close overview >/dev/null 2>&1 || true
    ;;
  refresh)
    [ -e "$STATE" ] && push_data
    ;;
  *)
    echo "usage: hypr-overview.sh show|hide|refresh" >&2
    exit 2
    ;;
esac
