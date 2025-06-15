#!/bin/bash

BATTERY=$(upower -e | grep 'BAT')
INFO=$(upower -i "$BATTERY")

STATE=$(echo "$INFO" | awk -F': ' '/state/ {print tolower($2)}' | xargs)
PERCENT=$(echo "$INFO" | awk -F': ' '/percentage/ {print $2}' | tr -d '%' | xargs)

TIME_TO_FULL_RAW=$(echo "$INFO" | awk -F': ' '/time to full/ {print $2}' | xargs)
TIME_TO_EMPTY_RAW=$(echo "$INFO" | awk -F': ' '/time to empty/ {print $2}' | xargs)

parse_time_to_hm() {
  local time_str="$1"
  if [[ $time_str =~ ([0-9]+\.[0-9]+)\ hours ]]; then
    local hours_dec="${BASH_REMATCH[1]}"
    local hours=${hours_dec%.*}
    local minutes=$(awk -v dec="$hours_dec" 'BEGIN { printf "%02d", (dec-int(dec))*60 }')
    echo "${hours}:${minutes}"
  elif [[ $time_str =~ ([0-9]+)\ hours ]]; then
    echo "${BASH_REMATCH[1]}:00"
  elif [[ $time_str =~ ([0-9]+)\ minutes ]]; then
    echo "0:${BASH_REMATCH[1]}"
  else
    echo "$time_str"
  fi
}

TIME_TO_FULL=$(parse_time_to_hm "$TIME_TO_FULL_RAW")
TIME_TO_EMPTY=$(parse_time_to_hm "$TIME_TO_EMPTY_RAW")

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

[[ "$STATE" == "charging" ]] && ICON=""
[[ "$STATE" == "fully-charged" ]] && ICON=""

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

if [[ "$STATE" == "charging" && -n "$TIME_TO_FULL" ]]; then
  TEXT="$PERCENT% ($TIME_TO_FULL)"
elif [[ "$STATE" == "discharging" && -n "$TIME_TO_EMPTY" ]]; then
  TEXT="$PERCENT% ($TIME_TO_EMPTY)"
fi

echo "<span color=\"$COLOR\">$TEXT&#8239;$ICON </span>"
