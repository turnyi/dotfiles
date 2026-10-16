#!/usr/bin/env bash
WS="$1"
DELAY="${2:-0}"

[ "$DELAY" != "0" ] && sleep "$DELAY"

icon_for_app() {
  case "$1" in
    "kitty")          echo ":kitty:" ;;
    "Google Chrome")  echo ":google_chrome:" ;;
    "Slack")          echo ":slack:" ;;
    "Discord")        echo ":discord:" ;;
    "Spotify")        echo ":spotify:" ;;
    "WhatsApp"*|"‎WhatsApp"*) echo ":whats_app:" ;;
    "WhatsApp Web")   echo ":whats_app:" ;;
    "Obsidian")       echo ":obsidian:" ;;
    "Notes")          echo ":notes:" ;;
    "OBS Studio")     echo ":obs:" ;;
    "Finder")         echo ":finder:" ;;
    "Claude")         echo ":claude:" ;;
    *)                echo ":default:" ;;
  esac
}

FOCUSED_WS=$(aerospace list-workspaces --focused 2>/dev/null | tr -d '[:space:]')
WINDOWS=$(aerospace list-windows --workspace "$WS" 2>/dev/null)

# Which monitor this workspace is pinned to (see [workspace-to-monitor-force-
# assignment] in ~/.aerospace.toml). One call returns the whole mapping.
MONITOR=$(aerospace list-workspaces --monitor all --format '%{workspace}|%{monitor-id}' 2>/dev/null \
          | awk -F'|' -v w="$WS" '$1==w {print $2; exit}')

ICONS=""
SEEN=""
while IFS= read -r line; do
  APP=$(echo "$line" | cut -d'|' -f2 | xargs)
  if [ -n "$APP" ] && [[ "$SEEN" != *"|$APP|"* ]]; then
    SEEN="$SEEN|$APP|"
    ICONS="${ICONS}$(icon_for_app "$APP")"
  fi
done <<< "$WINDOWS"

FOCUSED=false
[ "$WS" = "$FOCUSED_WS" ] && FOCUSED=true

# Catppuccin Macchiato. The workspaces share one frosted pill, so only the
# focused one draws a chip; the rest sit on the shared glass.
#
# The number is tinted by which monitor the workspace lives on, so a glance
# tells you which screen alt-N will jump to. App glyphs stay neutral — tinting
# them would recolour the app logos themselves.
#
# Empty workspaces are hidden outright rather than dimmed. The exception is an
# empty workspace you are focused on: it has to stay visible or the bar would
# show no current workspace at all.
CRUST=0xff181926
TEXT=0xffcad3f5

case "$MONITOR" in
  1) ACCENT=0xffb7bdf8 ;;  # lavender  -> built-in
  2) ACCENT=0xff8bd5ca ;;  # teal      -> secondary
  3) ACCENT=0xfff5bde6 ;;  # pink      -> third, if one ever appears
  *) ACCENT=0xffb7bdf8 ;;
esac
CLEAR=0x00000000

if $FOCUSED; then
  sketchybar --set "space.$WS" \
    drawing=on \
    label="$ICONS" \
    icon.color=$CRUST \
    label.color=$CRUST \
    background.color=$ACCENT \
    background.border_color=$CLEAR
elif [ -n "$WINDOWS" ]; then
  sketchybar --set "space.$WS" \
    drawing=on \
    label="$ICONS" \
    icon.color=$ACCENT \
    label.color=$TEXT \
    background.color=$CLEAR \
    background.border_color=$CLEAR
else
  sketchybar --set "space.$WS" drawing=off
fi
