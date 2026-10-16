#!/usr/bin/env bash
# Print the next timed calendar event, for the sketchybar calendar item.
#
# Output (one line, empty if there is nothing to show):
#   <minutes_until>|<HH:MM>|<title>
# minutes_until is negative while an event is already under way.
#
# All-day events are excluded on purpose: "when an event is to start" has no
# meaning for them, and a day full of subscribed holidays would otherwise
# permanently hide the date.

set -uo pipefail

WINDOW_MIN="${SKETCHYBAR_EVENT_WINDOW_MIN:-720}"  # look ahead 12h
GRACE_MIN="${SKETCHYBAR_EVENT_GRACE_MIN:-60}"     # keep showing 1h into an event
SEP='|~|'

# Parse one icalBuddy line into "<mins>|<HH:MM>|<title>". Split out from the
# query so it can be exercised without a calendar (see --selftest).
parse_line() {
  local line="$1" now_epoch="$2"
  [ -n "$line" ] || return 1

  # Title may itself contain the separator, so take the datetime from the tail.
  local title="${line%"$SEP"*}"
  local when="${line##*"$SEP"}"

  # icalBuddy renders a timed event's datetime as e.g.
  #   2025-10-02 at 10:30 - 11:30   (or just "10:30 - 11:30" when it is today)
  local date time
  date=$(printf '%s' "$when" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)
  time=$(printf '%s' "$when" | grep -oE '[0-9]{2}:[0-9]{2}' | head -1)
  [ -n "$time" ] || return 1
  [ -n "$date" ] || date=$(date -j -f '%s' "$now_epoch" '+%Y-%m-%d')

  local start_epoch
  start_epoch=$(date -j -f '%Y-%m-%d %H:%M' "$date $time" '+%s' 2>/dev/null) || return 1

  local mins=$(( (start_epoch - now_epoch) / 60 ))
  (( mins > WINDOW_MIN )) && return 1
  (( mins < -GRACE_MIN )) && return 1

  # Trim trailing whitespace the property separator leaves behind.
  title="${title%"${title##*[![:space:]]}"}"
  printf '%s|%s|%s\n' "$mins" "$time" "$title"
}

if [ "${1:-}" = "--selftest" ]; then
  # Fixed clock so the expected values never drift: 2025-10-02 09:00 local.
  now=$(date -j -f '%Y-%m-%d %H:%M' '2025-10-02 09:00' '+%s')
  fail=0
  check() {
    local got; got=$(parse_line "$2" "$now") || got='<none>'
    if [ "$got" = "$3" ]; then printf 'ok   %s\n' "$1"
    else printf 'FAIL %s\n  got:      %s\n  expected: %s\n' "$1" "$got" "$3"; fail=1; fi
  }
  check "timed event later today"   "Standup${SEP}2025-10-02 at 10:30 - 11:00" "90|10:30|Standup"
  check "time-only (today) form"    "Standup${SEP}10:30 - 11:00"               "90|10:30|Standup"
  check "in progress, within grace" "Retro${SEP}2025-10-02 at 08:30 - 09:30"   "-30|08:30|Retro"
  check "separator inside title"    "1${SEP}1 sync${SEP}2025-10-02 at 10:00"   "60|10:00|1${SEP}1 sync"
  check "beyond the look-ahead"     "Far${SEP}2025-10-03 at 12:00"             "<none>"
  check "ended long ago"            "Old${SEP}2025-10-02 at 06:00"             "<none>"
  check "all-day (no time at all)"  "Columbus Day${SEP}2025-10-13"             "<none>"
  check "empty input"               ""                                         "<none>"
  exit $fail
fi

command -v icalBuddy >/dev/null 2>&1 || exit 0

raw=$(icalBuddy -nc -nrd -ea -b '' -ps "$SEP" -iep 'datetime,title' \
        -po 'title,datetime' -df '%Y-%m-%d' -tf '%H:%M' \
        eventsToday+1 2>/dev/null | head -20)

now_epoch=$(date '+%s')
while IFS= read -r line; do
  [ -n "$line" ] || continue
  if out=$(parse_line "$line" "$now_epoch"); then
    printf '%s\n' "$out"
    exit 0
  fi
done <<< "$raw"

exit 0
