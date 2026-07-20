#!/usr/bin/env bash
# waybar ⇄ port-forwards module — the Linux counterpart of the sketchybar
# widgets/port_forwards.lua item. Same state, same pf-ctl.sh backend; only the
# presentation differs.
#
# Where sketchybar draws a clickable popup with one row per slot, waybar has no
# interactive popup — so the tooltip renders the same grouped slot list read-only
# and a click opens the real picker (`pf-menu.sh --float`), which is the same
# menu tmux binds to C-t.
#
# Emits waybar JSON: {"text","tooltip","class"}.
set -uo pipefail

PF="$HOME/scripts/pf-ctl.sh"

# Glyphs by codepoint so the raw PUA bytes never live in this file — same reason
# the sketchybar item uses utf8.char().
TUNNEL=$''  # exchange / tunnel
DOT_ON=$''  # filled circle
DOT_OFF=$'' # hollow circle

if [ ! -x "$PF" ]; then
  jq -cn --arg t "$TUNNEL" \
    '{text: $t, tooltip: "pf-ctl.sh not installed in ~/scripts", class: "idle"}'
  exit 0
fi

# pf-ctl list rows are: name|group|label|detail|status
listing=$("$PF" list 2>/dev/null)

running=0
total=0
tooltip=""
group_seen=""

while IFS='|' read -r name group label detail status; do
  [ -n "$name" ] || continue
  total=$((total + 1))

  # Group header each time the project changes (list is already grouped).
  if [ "$group" != "$group_seen" ]; then
    [ -n "$group_seen" ] && tooltip+=$'\n'
    tooltip+="<b>${group}</b>"$'\n'
    group_seen="$group"
  fi

  if [ "$status" = "on" ]; then
    running=$((running + 1))
    tooltip+="  ${DOT_ON} ${label}   ${detail}"$'\n'
  else
    tooltip+="  ${DOT_OFF} ${label}   ${detail}"$'\n'
  fi
done <<<"$listing"

if [ "$total" -eq 0 ]; then
  tooltip="no port-forward slots configured"
else
  tooltip+=$'\n'"click: open the ⇄ picker  ·  tmux: C-t"
fi

# Mirror the sketchybar item: bare glyph when idle, glyph + count when live.
if [ "$running" -gt 0 ]; then
  text="${TUNNEL} ${running}"
  class="active"
else
  text="$TUNNEL"
  class="idle"
fi

jq -cn --arg text "$text" --arg tooltip "${tooltip%$'\n'}" --arg class "$class" \
  '{text: $text, tooltip: $tooltip, class: $class}'
