#!/usr/bin/env bash
set -euo pipefail

OUTPUT=TAB

exists() {
  hyprctl monitors -j | jq -e --arg o "$OUTPUT" 'any(.[]; .name == $o)' >/dev/null
}

# Sunshine's wlr capture picks the output by its position in the wl_output
# list, which follows Hyprland's monitor ids — not by name.
capture_index() {
  hyprctl monitors -j | jq --arg o "$OUTPUT" 'sort_by(.id) | map(.name) | index($o)'
}

on() {
  exists || hyprctl output create headless "$OUTPUT" >/dev/null
  pkill -x sunshine || true
  setsid -f sunshine output_name="$(capture_index)" >/dev/null 2>&1
  notify-send "Tablet screen" "on — connect with Moonlight"
}

off() {
  pkill -x sunshine || true
  ! exists || hyprctl output remove "$OUTPUT" >/dev/null
  notify-send "Tablet screen" "off"
}

case "${1:-toggle}" in
  on) on ;;
  off) off ;;
  toggle) if exists; then off; else on; fi ;;
  *) echo "Usage: $0 [on|off|toggle]" >&2; exit 1 ;;
esac
