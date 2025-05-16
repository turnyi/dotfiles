#!/usr/bin/env bash

master_layout_min_width=5120

monitor_info=$(hyprctl monitors -j)
active_width=$(echo "$monitor_info" | jq -r '.[] | select(.focused == true) | .width')

if [ "$active_width" -ge $master_layout_min_width ]; then
  hyprctl keyword general:layout master
  echo "Set layout to MASTER (width = $active_width)"
else
  hyprctl keyword general:layout dwindle
  echo "Set layout to DWINDLE (width = $active_width)"
fi
