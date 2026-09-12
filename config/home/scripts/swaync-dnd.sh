#!/usr/bin/env bash
set -euo pipefail

# Announce before switching on, after switching off: a banner sent while Do Not
# Disturb is active never reaches the screen.
if [ "$(swaync-client --get-dnd)" = "true" ]; then
  swaync-client --dnd-off >/dev/null
  notify-send "Do Not Disturb" "off — notifications are back"
else
  notify-send "Do Not Disturb" "on — notifications are silenced"
  sleep 0.4
  swaync-client --dnd-on >/dev/null
fi
