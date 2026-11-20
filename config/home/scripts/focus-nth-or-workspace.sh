#!/bin/bash
# Alt+digit on macOS: within a second of an Alt+letter app bind, pick that app's
# Nth window (Alt+S then Alt+2 → second Slack window); otherwise switch to
# workspace N as before. focus-or-lunch.sh arms the chord by writing its query
# here, and every pick re-arms it, so Alt+S, 2, 3 keeps hopping between windows.
# Hyprland does the same with a timer in hyprland.lua.

N="$1"
CHORD="${TMPDIR:-/tmp}/focus-or-lunch.chord"
CHORD_SECONDS=1

if [ -f "$CHORD" ] && (( $(date +%s) - $(stat -f %m "$CHORD") <= CHORD_SECONDS )); then
    IFS=$'\t' read -r QUERY TITLE_FILTER < "$CHORD"
    exec bash ~/scripts/focus-or-lunch.sh "$QUERY" "$TITLE_FILTER" "$N"
fi

exec aerospace workspace "$N"
