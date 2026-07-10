#!/usr/bin/env bash

master_layout_min_width=5120

monitor_info=$(hyprctl monitors -j)

active_monitor=$(echo "$monitor_info" | jq -r '.[] | select(.focused == true)')
active_width=$(echo "$active_monitor" | jq -r '.width')
monitor_name=$(echo "$active_monitor" | jq -r '.name')

echo "Monitor: $monitor_name, Width: $active_width"

# Determine which layout to use based on monitor width
if [ "$active_width" -ge $master_layout_min_width ]; then
  TARGET_LAYOUT="master"
  echo "Setting MASTER layout (width = $active_width)"
else
  TARGET_LAYOUT="dwindle"
  echo "Setting DWINDLE layout (width = $active_width)"
fi

hyprctl keyword general:layout "$TARGET_LAYOUT"
echo "Layout set to: $TARGET_LAYOUT"
