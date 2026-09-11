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

exists() {
  hyprctl monitors -j | jq -e --arg o "$OUTPUT" 'any(.[]; .name == $o)' >/dev/null
}

stop_sunshine() {
  pkill -x sunshine || return 0
  while pgrep -x sunshine >/dev/null; do sleep 0.2; done
}

on() {
  exists || hyprctl output create headless "$OUTPUT" >/dev/null
  stop_sunshine
  setsid -f sunshine >/dev/null 2>&1
  notify-send "Tablet screen" "on — connect with Moonlight"
}

off() {
  stop_sunshine
  ! exists || hyprctl output remove "$OUTPUT" >/dev/null
  notify-send "Tablet screen" "off"
}

case "${1:-toggle}" in
  on) on ;;
  off) off ;;
  toggle) if exists; then off; else on; fi ;;
  *) echo "Usage: $0 [on|off|toggle]" >&2; exit 1 ;;
esac
