#!/usr/bin/env bash

# Requires gcalcli (yay -S gcalcli). Accounts are added by google-auth.sh.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=google-accounts.sh
source "$script_dir/google-accounts.sh"

if ! command -v gcalcli &> /dev/null; then
  echo "[]"
  exit 0
fi

all_events=""
while read -r account; do
  [ -n "$account" ] || continue
  google_account_has_calendar "$account" || continue
  account_dir=$(google_account_dir "$account")

  # Without a token gcalcli prints its auth prompt to stdout and blocks on
  # stdin; </dev/null keeps the widget from hanging forever.
  events=$(XDG_DATA_HOME="$account_dir" gcalcli \
    agenda --nostarted --details=calendar --tsv --military \
    < /dev/null 2>/dev/null | grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2}")

  [ -n "$events" ] && all_events+="${events}"$'\n'
done <<< "$(google_accounts_list)"

# Merging accounts yields one chronological block per account; the new_day
# header logic below assumes a single ordered stream.
all_events=$(printf "%s" "$all_events" | sort -t$'\t' -k1,1 -k2,2)

if [ -z "$all_events" ]; then
  echo "[]"
  exit 0
fi

declare -A calendar_colors=(
  ["martin.radovitzky@opti-task.com"]="#7aa2f7"
  ["Facultad Martin"]="#bb9af7"
  ["Transferido desde ignacio.azaretto@opti-task.com"]="#73daca"
  ["Transferido desde renato.calabrese@opti-task.com"]="#e0af68"
  ["Días feriados en Uruguay"]="#f7768e"
)

default_color="#9aa5ce"

json_events="["
first=true
last_date=""
event_count=0
max_events=8

while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Tab is an IFS whitespace character, so `IFS=$'\t' read` collapses the empty
  # time columns of all-day events and shifts every later field.
  mapfile -t fields < <(printf "%s" "$line" | tr "\t" "\n")
  start_date="${fields[0]}"
  start_time="${fields[1]}"
  end_time="${fields[3]}"
  title="${fields[4]}"
  calendar="${fields[5]}"

  [ -z "$start_date" ] && continue

  if [[ "$calendar" == "joaquin.meerhoff@opti-task.com" ]] || [[ "$calendar" == "joaquin.rodriguez@opti-task.com" ]]; then
    continue
  fi

  if [ $event_count -ge $max_events ]; then
    break
  fi

  is_new_day="false"
  if [ "$start_date" != "$last_date" ]; then
    is_new_day="true"
    last_date="$start_date"
  fi

  date_display=$(date -d "$start_date" "+%A, %B %d" 2>/dev/null || echo "$start_date")

  if [ -n "$start_time" ] && [ -n "$end_time" ] && [[ "$start_time" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
    start_hour=${start_time:0:2}
    start_min=${start_time:3:2}
    end_hour=${end_time:0:2}
    end_min=${end_time:3:2}

    # Strip leading zeros so arithmetic does not read "08" as octal.
    start_hour=${start_hour#0}
    start_min=${start_min#0}
    end_hour=${end_hour#0}
    end_min=${end_min#0}

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

  color="$default_color"
  if [ -n "$calendar" ]; then
    color="${calendar_colors[$calendar]:-$default_color}"
  fi

  title=$(echo "$title" | sed 's/"/\\"/g')

  if [ "$first" = false ]; then
    json_events+=","
  fi
  first=false

  json_events+="{\"time\":\"$time_display\",\"duration\":\"$duration\",\"title\":\"$title\",\"date\":\"$date_display\",\"color\":\"$color\",\"new_day\":$is_new_day}"

  ((event_count++))

done <<< "$all_events"

json_events+="]"

echo "$json_events"
