#!/usr/bin/env bash
set -euo pipefail

OUTPUT=TAB
BASE_CONF="$HOME/.config/sunshine/sunshine.conf"
RUN_CONF="${XDG_RUNTIME_DIR:-/tmp}/sunshine-tablet.conf"

exists() {
  hyprctl monitors -j | jq -e --arg o "$OUTPUT" 'any(.[]; .name == $o)' >/dev/null
}

# Sunshine's wlr capture picks the output by its position in the wl_output
# list, which follows Hyprland's monitor ids — not by name.
capture_index() {
  hyprctl monitors -j | jq --arg o "$OUTPUT" 'sort_by(.id) | map(.name) | index($o)'
}

stop_sunshine() {
  pkill -x sunshine || return 0
  while pgrep -x sunshine >/dev/null; do sleep 0.2; done
}

# An output_name=N CLI argument only held for Sunshine's startup encoder probe;
# real Moonlight sessions still captured monitor 0, so N goes in a config file.
on() {
  exists || hyprctl output create headless "$OUTPUT" >/dev/null
  stop_sunshine
  { cat "$BASE_CONF"; echo "output_name = $(capture_index)"; } >"$RUN_CONF"
  setsid -f sunshine "$RUN_CONF" >/dev/null 2>&1
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
