#!/usr/bin/env bash
# waybar 🔔 notifications module — the Linux counterpart of the sketchybar
# widgets/notifications.lua item.
#
# macOS reads the count out of the protected `usernoted` database (see
# notif-count.sh, which needs Full Disk Access). Linux has a real API for this:
# swaync's own event stream. `swaync-client --subscribe-waybar` emits a JSON line
# on every add/close, so this module is event-driven rather than polled — declare
# it in waybar with NO "interval" and it stays open, streaming.
#
# The sketchybar item swaps the bell for the notifying app's glyph; swaync's
# waybar feed doesn't carry the app id, so here the bell stays and DND gets its
# own struck-through glyph instead.
#
# Emits waybar JSON: {"text","tooltip","class"}.
set -uo pipefail

BELL=$''      # nerdfont bell
BELL_OFF=$''  # bell-slash, shown while DND is on

if ! command -v swaync-client >/dev/null 2>&1; then
  jq -cn --arg t "$BELL" \
    '{text: $t, tooltip: "swaync is not installed", class: "idle"}'
  exit 0
fi

# Reshape swaync's feed. Its lines look like:
#   {"text":"3","alt":"notification","tooltip":"3 Notifications","class":"notification"}
# `alt` is prefixed with "dnd-" whenever do-not-disturb is on.
reshape() {
  jq -c --unbuffered --arg bell "$BELL" --arg bell_off "$BELL_OFF" '
    (.text | tonumber? // 0)          as $count |
    ((.alt // "") | startswith("dnd")) as $dnd |
    (if $dnd then $bell_off else $bell end) as $glyph |
    {
      text: (if $count > 0 then "\($glyph) \($count)" else $glyph end),
      tooltip: (
        (if $count == 0 then "No notifications"
         elif $count == 1 then "1 notification"
         else "\($count) notifications" end)
        + (if $dnd then "  ·  do not disturb" else "" end)
        + "\n\nclick: open the panel  ·  right-click: toggle DND"
      ),
      class: (if $dnd then "dnd" elif $count > 0 then "active" else "idle" end)
    }
  '
}

# --subscribe-waybar emits the current state on connect and then one line per
# event, so it populates the module on its own — no seed needed. It exits if the
# daemon isn't up yet (e.g. waybar won the startup race), so on exit fall back to
# a dim bell and retry rather than leaving the module permanently blank.
while true; do
  swaync-client --subscribe-waybar 2>/dev/null | reshape
  jq -cn --arg t "$BELL" '{text: $t, tooltip: "swaync is not running", class: "idle"}'
  sleep 2
done
