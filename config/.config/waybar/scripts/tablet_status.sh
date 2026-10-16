#!/bin/bash
# Charge of the Android tablet used as a second screen, for waybar.
#
# The reading comes from ~/scripts/tablet-battery.sh, the same script the
# sketchybar widget on the Mac uses, so both bars agree on what "attached"
# means: adb can see it, over USB or over wifi. It prints nothing when no
# tablet answers, and "hide-empty-text" in config.jsonc turns that into a
# hidden module — so whichever machine is holding the tablet is the one that
# shows it.
#
# Output is Pango markup rather than JSON to match battery_status.sh beside it.

READER="$HOME/scripts/tablet-battery.sh"
[[ -x "$READER" ]] || exit 0

LINE=$("$READER" 2>/dev/null)
[[ -n "$LINE" ]] || exit 0

IFS='|' read -r PERCENT STATE _LINK _NAME <<<"$LINE"
[[ "$PERCENT" =~ ^[0-9]+$ ]] || exit 0

# glyph `tablet-android`; the plain tablet glyph is a bare rectangle that reads
# as another battery next to the laptop's.
ICON="󰓷"
# charging / full / not_charging all mean a cable is doing the work.
case "$STATE" in
  charging | full | not_charging) ICON="󰓷󰐥" ;;
esac

# Same thresholds and colours as battery_status.sh, so the two charges on this
# bar are read off one scale.
if ((PERCENT < 15)); then
  COLOR="#FF5555"
elif ((PERCENT < 40)); then
  COLOR="#F1C40F"
elif ((PERCENT < 75)); then
  COLOR="#8AC926"
else
  COLOR="#00CCFF"
fi

echo "<span color=\"$COLOR\">$PERCENT%&#8239;$ICON </span>"
