#!/usr/bin/env bash
# notif-open — toggle macOS Notification Center by clicking the menu-bar clock,
# which is owned by the ControlCenter process. Needs Accessibility permission for
# whatever runs it (sketchybar). Best-effort: silently no-ops if it can't.
osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events"
  tell process "ControlCenter"
    try
      click (first menu bar item of menu bar 1 whose description is "Clock")
    on error
      -- Fallback for locales/versions where the clock isn't labelled "Clock".
      try
        click (last menu bar item of menu bar 1)
      end try
    end try
  end tell
end tell
APPLESCRIPT
exit 0
