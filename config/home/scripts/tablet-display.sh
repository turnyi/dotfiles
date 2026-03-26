#!/bin/bash

TARGET_OUT=$(hyprctl monitors | awk '/^Monitor (HEADLESS|Virtual)-/{print $2}' | tail -n1)

if [ -z "$TARGET_OUT" ]; then
  echo "Creating new monitor..."
  hyprctl output create headless

  for i in {1..10}; do
    TARGET_OUT=$(hyprctl monitors | awk '/^Monitor (HEADLESS|Virtual)-/{print $2}' | tail -n1)
    [ -n "$TARGET_OUT" ] && break
    sleep 0.2
  done
fi

if [ -z "$TARGET_OUT" ]; then
  echo "Error: Could not create monitor."
  exit 1
fi

MAIN_MON=$(hyprctl monitors | awk '/^Monitor /{print $2}' | grep -Ev '^(HEADLESS|Virtual)-' | head -n1)

if [ -z "$MAIN_MON" ]; then
  echo "Error: Could not detect a main (physical) monitor."
  exit 1
fi

echo "Tablet monitor: $TARGET_OUT"

hyprctl keyword monitor "$TARGET_OUT,1920x1080@60,auto-center-down,1"

sleep 1

# Get the current workspace on the tablet monitor and move it to main monitor
CURRENT_WS=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$TARGET_OUT\") | .activeWorkspace.id")
if [ -n "$CURRENT_WS" ] && [ "$CURRENT_WS" != "9" ]; then
  echo "Moving workspace $CURRENT_WS from tablet to main monitor..."
  hyprctl dispatch moveworkspacetomonitor "$CURRENT_WS" "$MAIN_MON"
  sleep 1
fi

# Switch to workspace 9
echo "Switching to workspace 9..."
hyprctl dispatch workspace 9
sleep 1

# Move workspace 9 to tablet if it's not there already
CURRENT_MON=$(hyprctl activeworkspace -j | jq -r '.monitor')
if [ "$CURRENT_MON" != "$TARGET_OUT" ]; then
  echo "Moving workspace 9 to tablet monitor..."
  hyprctl dispatch moveworkspacetomonitor 9 "$TARGET_OUT"
  sleep 1
  hyprctl dispatch workspace 9
  sleep 1
fi

echo "Workspace 9 is now on tablet monitor $TARGET_OUT"
echo "Plugin will automatically set dwindle layout for workspace 9"

echo "VNC active on port 5901. The tablet monitor will be removed when wayvnc closes (Ctrl+C)..."
wayvnc --output "$TARGET_OUT" 0.0.0.0 5901

echo "Cleaning up..."
hyprctl dispatch moveworkspacetomonitor 9 "$MAIN_MON"
hyprctl output remove "$TARGET_OUT"
echo "Monitor $TARGET_OUT removed. All clean!"
