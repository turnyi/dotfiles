#!/usr/bin/env bash
set -euo pipefail

OUTPUT=TAB

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$sock" ]; then
      export WAYLAND_DISPLAY="${sock##*/}"
      break
    fi
  done
fi

output_exists() {
  hyprctl monitors -j | jq -e --arg o "$OUTPUT" 'any(.[]; .name == $o)' >/dev/null
}

output_add() {
  output_exists || hyprctl output create headless "$OUTPUT" >/dev/null
}

output_remove() {
  ! output_exists || hyprctl output remove "$OUTPUT" >/dev/null
}

running() {
  pgrep -x sunshine >/dev/null
}

stop_sunshine() {
  pkill -x sunshine || return 0
  while running; do sleep 0.2; done
}

start() {
  stop_sunshine
  setsid -f sunshine >/dev/null 2>&1
  notify-send "Tablet screen" "server on — open Desktop in Moonlight"
}

stop() {
  stop_sunshine
  output_remove
  notify-send "Tablet screen" "server off"
}

case "${1:-toggle}" in
  start) start ;;
  stop) stop ;;
  toggle) if running; then stop; else start; fi ;;
  output-add) output_add ;;
  output-remove) output_remove ;;
  *) echo "Usage: $0 [start|stop|toggle|output-add|output-remove]" >&2; exit 1 ;;
esac
