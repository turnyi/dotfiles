#!/usr/bin/env bash

# Simple Gmail checker using curl and IMAP
# You need to set up an App Password in your Google Account

EMAIL="${GMAIL_EMAIL:-your-email@gmail.com}"
PASSWORD_FILE="$HOME/.config/eww/.gmail-password"

if [ ! -f "$PASSWORD_FILE" ]; then
  echo '[{"from":"Setup Required","subject":"Create app password: echo \"your-app-password\" > ~/.config/eww/.gmail-password","time":"--","unread":true}]'
  exit 0
fi

PASSWORD=$(cat "$PASSWORD_FILE")

# Use curl to check Gmail via IMAP
response=$(curl -s --url "imaps://imap.gmail.com:993/INBOX" \
  --user "$EMAIL:$PASSWORD" \
  --request "SEARCH UNSEEN" 2>&1)

# Parse unread count
if echo "$response" | grep -q "SEARCH"; then
  # For now, just show count
  count=$(echo "$response" | grep -o "SEARCH.*" | wc -w)
  echo "[{\"from\":\"Gmail\",\"subject\":\"You have $count unread emails\",\"time\":\"now\",\"unread\":true}]"
else
  echo '[{"from":"Error","subject":"Check credentials in ~/.config/eww/.gmail-password","time":"--","unread":true}]'
fi
