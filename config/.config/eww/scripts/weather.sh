#!/usr/bin/env bash

# Weather script for eww
# Uses wttr.in API

# Set your location (city name or coordinates)
LOCATION="Montevideo"

# Fetch weather data
weather_data=$(curl -s "https://wttr.in/${LOCATION}?format=j1" 2>/dev/null)

if [ -z "$weather_data" ]; then
  echo '{"temp":"--","condition":"Unknown","icon":"","description":""}'
  exit 0
fi

# Parse JSON
temp=$(echo "$weather_data" | jq -r '.current_condition[0].temp_C')
condition=$(echo "$weather_data" | jq -r '.current_condition[0].weatherDesc[0].value')
feels_like=$(echo "$weather_data" | jq -r '.current_condition[0].FeelsLikeC')

# Map weather condition to icon (using different Nerd Font icons)
case "$condition" in
  *"Clear"*|*"Sunny"*)
    icon="☀"
    ;;
  *"Partly cloudy"*)
    icon="⛅"
    ;;
  *"Cloudy"*|*"Overcast"*)
    icon="☁"
    ;;
  *"rain"*|*"Rain"*)
    icon="🌧"
    ;;
  *"snow"*|*"Snow"*)
    icon="❄"
    ;;
  *"thunder"*|*"Thunder"*)
    icon="⛈"
    ;;
  *"fog"*|*"Fog"*|*"Mist"*)
    icon="🌫"
    ;;
  *)
    icon="🌤"
    ;;
esac

# Create description
description="It's a ${condition,,}"

# Get current hour
current_hour=$(date +%-H)

# Get hourly forecast (next 5 hours: +1h, +2h, +3h, +4h, +5h)
hourly_json="["
first=true

for offset in 1 2 3 4 5; do
  target_hour=$(( (current_hour + offset) % 24 ))
  
  # API uses format: 0, 300, 600, 900, 1200, 1500, 1800, 2100
  # Round to nearest 3-hour block
  rounded_hour=$(( (target_hour / 3) * 3 ))
  if [ $rounded_hour -eq 0 ]; then
    target_hour_api="0"
  else
    target_hour_api="${rounded_hour}00"
  fi
  
  # Find the matching hour in the API data
  day_offset=0
  if [ $((current_hour + offset)) -ge 24 ]; then
    day_offset=1
  fi
  
  hour_temp=$(echo "$weather_data" | jq -r ".weather[$day_offset].hourly[] | select(.time == \"$target_hour_api\") | .tempC" | head -1)
  hour_condition=$(echo "$weather_data" | jq -r ".weather[$day_offset].hourly[] | select(.time == \"$target_hour_api\") | .weatherDesc[0].value" | head -1)
  
  # If data not found, use placeholder
  if [ -z "$hour_temp" ] || [ "$hour_temp" = "null" ]; then
    hour_temp="--"
    hour_condition="Unknown"
  fi
  
  hour_time=$(printf "%02d:00" $target_hour)
  
  # Map hourly weather to icon
  case "$hour_condition" in
    *"Clear"*|*"Sunny"*)
      hour_icon="☀"
      ;;
    *"Partly cloudy"*)
      hour_icon="⛅"
      ;;
    *"Cloudy"*|*"Overcast"*)
      hour_icon="☁"
      ;;
    *"rain"*|*"Rain"*)
      hour_icon="🌧"
      ;;
    *"snow"*|*"Snow"*)
      hour_icon="❄"
      ;;
    *)
      hour_icon="🌤"
      ;;
  esac
  
  if [ "$first" = false ]; then
    hourly_json+=","
  fi
  first=false
  
  hourly_json+="{\"time\":\"$hour_time\",\"temp\":\"${hour_temp}°\",\"icon\":\"${hour_icon}\"}"
done

hourly_json+="]"

# Output JSON
cat << EOF
{
  "temp": "${temp}",
  "condition": "${condition}",
  "icon": "${icon}",
  "description": "${description}",
  "feels_like": "${feels_like}",
  "location": "${LOCATION}",
  "hourly": ${hourly_json}
}
EOF
