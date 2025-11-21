#!/usr/bin/env bash

# Script to add a calendar by searching for a person in Google Calendar
# Uses the Google Calendar API via gcalcli

set -euo pipefail

CALENDAR_EMAIL="${1:-}"

if [ -z "$CALENDAR_EMAIL" ]; then
  echo "Usage: $0 <calendar-email>"
  echo "Example: $0 joaquin.meerhoff@opti-task.com"
  exit 1
fi

echo "Searching for calendar: $CALENDAR_EMAIL"
echo ""

# Try to fetch events from that calendar to test access
echo "Testing access to calendar..."
result=$(gcalcli --calendar "$CALENDAR_EMAIL" agenda --nostarted 2>&1 || true)

if echo "$result" | grep -q "No Events Found\|When\|What"; then
  echo "✓ Calendar is accessible!"
  echo ""
  echo "The calendar '$CALENDAR_EMAIL' is already available to gcalcli."
  echo ""
  echo "Current calendars:"
  gcalcli list
else
  echo "❌ Calendar not accessible yet."
  echo ""
  echo "To add this calendar:"
  echo "1. Go to: https://calendar.google.com"
  echo "2. In the left sidebar, find 'Other calendars'"
  echo "3. Click the '+' button"
  echo "4. Select 'Subscribe to calendar'"
  echo "5. Enter: $CALENDAR_EMAIL"
  echo "6. Press Enter"
  echo ""
  echo "Or ask the owner ($CALENDAR_EMAIL) to share their calendar with you."
fi
