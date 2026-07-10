#!/bin/bash
# focus-or-launch: focus an existing window or launch the app
# Mac: uses AeroSpace list-windows + aerospace focus for proper workspace switching
# Linux: uses hyprctl + gtk-launch

QUERY="$1"
TITLE_FILTER="$2"  # optional: filter by window title substring (e.g. Chrome profile name)
if [ -z "$QUERY" ]; then
  echo "Usage: $0 app_name [title_filter]"
  exit 1
fi

LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ -n "$TITLE_FILTER" ]; then
        WIN=$(aerospace list-windows --all 2>/dev/null \
            | grep -i "$LOWER" \
            | grep -i "$TITLE_FILTER" \
            | awk '{print $1}' \
            | head -1)
    else
        WIN=$(aerospace list-windows --all 2>/dev/null \
            | grep -i "$LOWER" \
            | awk '{print $1}' \
            | head -1)
    fi
    if [ -n "$WIN" ]; then
        aerospace focus --window-id "$WIN"
    else
        open -a "$QUERY"
    fi
    exit 0
fi

# Linux (Hyprland)
WINDOW_ID=$(hyprctl clients -j | jq -r --arg q "$LOWER" \
  '.[] | select((.initialTitle // "" | ascii_downcase | contains($q)) or (.class // "" | ascii_downcase | contains($q))) | .address' \
  | head -n 1)

if [ -n "$WINDOW_ID" ]; then
    hyprctl dispatch focuswindow address:$WINDOW_ID
    exit 0
fi

DESKTOP_PATH=$(grep -ril --include="*.desktop" "Name=$QUERY" \
    ~/.local/share/applications /usr/share/applications 2>/dev/null)
if [ -z "$DESKTOP_PATH" ]; then
    echo "No .desktop file found for '$QUERY'"
    exit 1
fi
DESKTOP_NAME=$(basename "$DESKTOP_PATH" .desktop)
gtk-launch "$DESKTOP_NAME"
