#!/usr/bin/env bash
# waybar 🔔 notifications module — the Linux counterpart of the sketchybar
# widgets/notifications.lua item.
#
# macOS reads the count out of the protected `usernoted` database (see
# notif-count.sh, which needs Full Disk Access). swaync just answers, so this
# polls `swaync-client -c` on waybar's interval like every other module here.
#
# swaync does offer an event stream (`--subscribe-waybar`) which would update the
# badge instantly, but waybar never signals exec'd modules when it exits, so a
# streaming module survives its own bar and leaks a subscription per restart.
# Nothing detects the dead parent reliably enough to be worth it for a counter —
# so: no persistent process, no cleanup to get wrong.
#
# The sketchybar item swaps the bell for the notifying app's glyph; swaync's
# count API doesn't carry an app id, so here the bell stays and DND gets its own
# struck-through glyph instead.
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

# Both calls fail if the daemon is down (waybar can win the startup race); the
# module degrades to a dim bell and recovers on the next tick.
if ! count=$(swaync-client -c 2>/dev/null) || [ -z "$count" ]; then
  jq -cn --arg t "$BELL" \
    '{text: $t, tooltip: "swaync is not running", class: "idle"}'
  exit 0
fi
dnd=$(swaync-client -D 2>/dev/null) || dnd=false

jq -cn --argjson count "${count:-0}" --arg dnd "$dnd" \
       --arg bell "$BELL" --arg bell_off "$BELL_OFF" '
  ($dnd == "true") as $is_dnd |
  (if $is_dnd then $bell_off else $bell end) as $glyph |
  {
    text: (if $count > 0 then "\($glyph) \($count)" else $glyph end),
    tooltip: (
      (if $count == 0 then "No notifications"
       elif $count == 1 then "1 notification"
       else "\($count) notifications" end)
      + (if $is_dnd then "  ·  do not disturb" else "" end)
      + "\n\nclick: open the panel  ·  right-click: toggle DND"
    ),
    class: (if $is_dnd then "dnd" elif $count > 0 then "active" else "idle" end)
  }
'
