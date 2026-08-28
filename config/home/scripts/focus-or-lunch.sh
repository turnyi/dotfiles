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
    # A lua hyprland.conf makes `dispatch` a lua expression and rejects the
    # legacy "focuswindow address:..." form outright (exit 7), so try that shape
    # first and fall back for a session still running the old .conf parser.
    # Either way focuswindow follows the window to its workspace and monitor.
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$WINDOW_ID\" })" >/dev/null 2>&1 \
      || hyprctl dispatch focuswindow "address:$WINDOW_ID" >/dev/null 2>&1
    exit 0
fi

# grep returns matches in readdir order, which is not stable: with two entries
# for one app (e.g. a Chrome PWA and a leftover firefoxpwa one) consecutive runs
# disagree on which comes first. Sort, then prefer an exact "Name=" hit over a
# substring one, so the same launcher wins every time.
mapfile -t MATCHES < <(grep -ril --include="*.desktop" "Name=$QUERY" \
    ~/.local/share/applications /usr/share/applications 2>/dev/null | sort)
if [ ${#MATCHES[@]} -eq 0 ]; then
    echo "No .desktop file found for '$QUERY'"
    exit 1
fi
DESKTOP_PATH="${MATCHES[0]}"
for m in "${MATCHES[@]}"; do
    if grep -qix "Name=$QUERY" "$m"; then
        DESKTOP_PATH="$m"
        break
    fi
done
DESKTOP_NAME=$(basename "$DESKTOP_PATH" .desktop)
# Detach: the hyprland bind runs this via a throwaway `sh -c`, and a launcher
# left as its child dies with it before the window ever maps.
setsid -f gtk-launch "$DESKTOP_NAME" >/dev/null 2>&1
