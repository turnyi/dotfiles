#!/usr/bin/env bash

master_layout_min_width=5120

monitor_info=$(hyprctl monitors -j)

if [ -n "$1" ]; then
  target_workspace="$1"
  target_monitor=$(echo "$monitor_info" | jq -r ".[] | select(.activeWorkspace.id == $target_workspace)")
  
  if [ -z "$target_monitor" ]; then
    echo "Workspace $target_workspace not found on any monitor"
    exit 1
  fi
  
  active_width=$(echo "$target_monitor" | jq -r '.width')
  monitor_name=$(echo "$target_monitor" | jq -r '.name')
  active_workspace="$target_workspace"
else
  active_monitor=$(echo "$monitor_info" | jq -r '.[] | select(.focused == true)')
  active_width=$(echo "$active_monitor" | jq -r '.width')
  active_workspace=$(echo "$active_monitor" | jq -r '.activeWorkspace.id')
  monitor_name=$(echo "$active_monitor" | jq -r '.name')
fi

echo "Monitor: $monitor_name, Workspace: $active_workspace, Width: $active_width"

# Determine which layout to use based on monitor width
if [ "$active_width" -ge $master_layout_min_width ]; then
  TARGET_LAYOUT="master"
  echo "Setting MASTER layout for workspace $active_workspace (width = $active_width)"
else
  TARGET_LAYOUT="dwindle"
  echo "Setting DWINDLE layout for workspace $active_workspace (width = $active_width)"
fi

# Dynamically set workspace rule for current workspace
hyprctl keyword "workspace $active_workspace, layoutopt:wslayout-layout:$TARGET_LAYOUT"

# Reload workspace to apply the layout
TEMP_WS=$(hyprctl workspaces -j | jq -r "[.[] | .id] | map(select(. != $active_workspace)) | .[0]")
if [ -n "$TEMP_WS" ]; then
  hyprctl dispatch workspace "$TEMP_WS"
  sleep 0.1
  hyprctl dispatch workspace "$active_workspace"
  echo "Layout applied: $TARGET_LAYOUT for workspace $active_workspace"
else
  echo "Warning: Could not switch workspace to apply layout"
fi
