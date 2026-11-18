#!/usr/bin/env bash
WS="$1"
DELAY="${2:-0}"

[ "$DELAY" != "0" ] && sleep "$DELAY"

# Icon slots per workspace. Keep in sync with MAX_APPS in items/spaces.lua.
MAX_APPS=6

FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null | tr -d '[:space:]')
WINDOWS=$(aerospace list-windows --workspace "$WS" --format '%{app-bundle-id}' 2>/dev/null)

# Which monitor this workspace is pinned to (see [workspace-to-monitor-force-
# assignment] in ~/.aerospace.toml). One call returns the whole mapping.
MONITOR=$(aerospace list-workspaces --monitor all --format '%{workspace}|%{monitor-id}' 2>/dev/null \
          | awk -F'|' -v w="$WS" '$1==w {print $2; exit}')

# One icon per app, in window order. SketchyBar draws the app's own icon from
# its bundle ID ("app.<bundle id>"), so every installed app, Chrome web apps
# included, gets its real icon without a mapping table.
APPS=()
while IFS= read -r BUNDLE; do
  BUNDLE=$(echo "$BUNDLE" | xargs)
  [ -n "$BUNDLE" ] || continue
  [[ " ${APPS[*]} " == *" $BUNDLE "* ]] && continue
  APPS+=("$BUNDLE")
done <<< "$WINDOWS"

FOCUSED=false
[ "$WS" = "$FOCUSED_WS" ] && FOCUSED=true

# Catppuccin Macchiato. Each workspace is a pill styled like the widgets on
# the right (BG1 fill, BG2 rim, see colors.lua); the focused one swaps its rim
# for the accent and takes a faint wash of it.
#
# The number is tinted by which monitor the workspace lives on, so a glance
# tells you which screen alt-N will jump to. The icons are the apps' own, so
# they keep their colours on and off the chip.
#
# Empty workspaces are hidden outright rather than dimmed. The exception is an
# empty workspace you are focused on: it has to stay visible or the bar would
# show no current workspace at all.
BG1=0x14181926
BG2=0x33494d64

case "$MONITOR" in
  1) ACCENT=0xffb7bdf8 ;;  # lavender  -> built-in
  2) ACCENT=0xff8bd5ca ;;  # teal      -> secondary
  3) ACCENT=0xfff5bde6 ;;  # pink      -> third, if one ever appears
  *) ACCENT=0xffb7bdf8 ;;
esac
FOCUS_FILL="0x1a${ACCENT:4}"
FOCUS_RIM="0x80${ACCENT:4}"

ARGS=()
COUNT=${#APPS[@]}
for ((k = 1; k <= MAX_APPS; k++)); do
  if [ "$k" -le "$COUNT" ]; then
    PAD=1
    [ "$k" -eq "$COUNT" ] && PAD=8
    ARGS+=(--set "space.$WS.app.$k" drawing=on \
      background.image="app.${APPS[$((k - 1))]}" padding_right=$PAD)
  else
    ARGS+=(--set "space.$WS.app.$k" drawing=off)
  fi
done

# With no icons the number closes the chip itself.
NUM_PAD=4
[ "$COUNT" -eq 0 ] && NUM_PAD=10

if $FOCUSED; then
  sketchybar --set "space.$WS" drawing=on icon.color=$ACCENT icon.padding_right=$NUM_PAD \
    --set "space.$WS.chip" background.color=$FOCUS_FILL background.border_color=$FOCUS_RIM \
    --set "space.$WS.gap" drawing=on \
    "${ARGS[@]}"
elif [ "$COUNT" -gt 0 ]; then
  sketchybar --set "space.$WS" drawing=on icon.color=$ACCENT icon.padding_right=$NUM_PAD \
    --set "space.$WS.chip" background.color=$BG1 background.border_color=$BG2 \
    --set "space.$WS.gap" drawing=on \
    "${ARGS[@]}"
else
  sketchybar --set "space.$WS" drawing=off \
    --set "space.$WS.gap" drawing=off \
    "${ARGS[@]}"
fi
