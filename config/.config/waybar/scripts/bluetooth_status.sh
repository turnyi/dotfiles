#!/bin/bash

# Get list of connected Bluetooth devices
CONNECTED=$(bluetoothctl info | awk '/Device/ {name=$2; next} /Name/ {print name, $2}' | paste -sd ", " -)

# Fallback if no devices
if [ -z "$CONNECTED" ]; then
  TOOLTIP="No devices connected"
else
  TOOLTIP="Connected: $CONNECTED"
fi

# Output JSON for Waybar
echo "{\"text\": \"\", \"tooltip\": \"$TOOLTIP\"}"
