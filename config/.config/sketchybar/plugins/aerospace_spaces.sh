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

# Always visible — focused=bright, occupied=normal, empty=dim
if $FOCUSED; then
  sketchybar --set "space.$WS" \
    drawing=on \
    label="$ICONS" \
    icon.color=0xffe2e2e3 \
    label.color=0xffe2e2e3 \
    background.color=0xff414550 \
    background.border_color=0xff7f8490
elif [ -n "$WINDOWS" ]; then
  sketchybar --set "space.$WS" \
    drawing=on \
    label="$ICONS" \
    icon.color=0xff7f8490 \
    label.color=0xff7f8490 \
    background.color=0xff363944 \
    background.border_color=0xff414550
else
  sketchybar --set "space.$WS" \
    drawing=on \
    label="" \
    icon.color=0x557f8490 \
    background.color=0x22363944 \
    background.border_color=0x22414550
fi
