#!/usr/bin/env bash

# Joaquin Meerhoff Calendar script for eww
# Displays events with owner name instead of time

CALENDAR_EMAIL="joaquin.meerhoff@opti-task.com"
OWNER_NAME="J. Meerhoff"

# Check if gcalcli is installed
if ! command -v gcalcli &>/dev/null; then
  echo "[]"
  exit 0
fi

# Get events with details
events=$(gcalcli --calendar "$CALENDAR_EMAIL" agenda --nostarted --details=calendar --tsv --military 2>/dev/null | tail -n +2 | head -8)

if [ -z "$events" ]; then
  echo "[]"
  exit 0
fi

# Define color for this calendar
calendar_color="#7aa2f7"

# Parse events into JSON format
json_events="["
first=true
last_date=""

while IFS=$'\t' read -r start_date start_time end_date end_time title calendar; do
  # Skip empty lines
  [ -z "$start_date" ] && continue

  # Determine if this is a new day
  is_new_day="false"
  if [ "$start_date" != "$last_date" ]; then
    is_new_day="true"
    last_date="$start_date"
  fi

  # Format date nicely
  date_display=$(date -d "$start_date" "+%A, %B %d" 2>/dev/null || echo "$start_date")

  # Calculate duration
  if [ -n "$start_time" ] && [ -n "$end_time" ] && [[ "$start_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    start_hour=${start_time:0:2}
    start_min=${start_time:3:2}
    end_hour=${end_time:0:2}
    end_min=${end_time:3:2}

    # Remove leading zeros to avoid octal interpretation
    start_hour=${start_hour#0}
    start_min=${start_min#0}
    end_hour=${end_hour#0}
    end_min=${end_min#0}

    # Handle empty strings after removing zeros
    start_hour=${start_hour:-0}
    start_min=${start_min:-0}
    end_hour=${end_hour:-0}
    end_min=${end_min:-0}

    start_minutes=$((start_hour * 60 + start_min))
    end_minutes=$((end_hour * 60 + end_min))
    duration_minutes=$((end_minutes - start_minutes))

    if [ $duration_minutes -lt 60 ]; then
      duration="${duration_minutes}m"
    else
      hours=$((duration_minutes / 60))
      minutes=$((duration_minutes % 60))
      if [ $minutes -eq 0 ]; then
        duration="${hours}h"
      else
        duration="${hours}h ${minutes}m"
      fi
    fi

    time_display="$start_time"
  else
    duration="All day"
    time_display="All day"
  fi

  # Escape quotes in title
  title=$(echo "$title" | sed 's/"/\\"/g')

  # Add comma if not first event
  if [ "$first" = false ]; then
    json_events+=","
  fi
  first=false

  # Build JSON object
  json_events+="{\"time\":\"$time_display\",\"duration\":\"$duration\",\"title\":\"$title\",\"date\":\"$date_display\",\"color\":\"$calendar_color\",\"new_day\":$is_new_day}"

done <<<"$events"

json_events+="]"

echo "$json_events"
