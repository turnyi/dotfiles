#!/bin/bash

BATTERY=$(upower -e | grep 'BAT')
INFO=$(upower -i "$BATTERY")

STATE=$(echo "$INFO" | awk -F': ' '/state/ {print tolower($2)}' | xargs)
PERCENT=$(echo "$INFO" | awk -F': ' '/percentage/ {print $2}' | tr -d '%' | xargs)
TIME=$(echo "$INFO" | awk -F': ' '/time to full/ {print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
TIME="${TIME// minutes/min}"

ICON=""
if ((PERCENT < 15)); then
  ICON=""
elif ((PERCENT < 40)); then
  ICON=""
elif ((PERCENT < 60)); then
  ICON=""
elif ((PERCENT < 80)); then
  ICON=""
fi

# Override if charging or full
[[ "$STATE" == "charging" ]] && ICON=""
[[ "$STATE" == "fully-charged" ]] && ICON=""

# Set color
if ((PERCENT < 15)); then
  COLOR="#FF5555"
elif ((PERCENT < 40)); then
  COLOR="#F1C40F"
elif ((PERCENT < 75)); then
  COLOR="#8AC926"
else
  COLOR="#00CCFF"
fi

TEXT="$PERCENT%"
if [[ "$STATE" == "charging" && -n "$TIME" ]]; then
  TEXT="$PERCENT% ($TIME)"
fi

echo "<span color=\"$COLOR\">$TEXT&#8239;$ICON </span>"
