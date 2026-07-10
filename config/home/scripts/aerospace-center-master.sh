#!/usr/bin/env bash
# Center-master layout: put the focused window in the middle column of the
# focused workspace and widen it, with the other windows tiled at the sides.
# Only acts on external (big) displays; the built-in screen is left alone.
#
# Usage: aerospace-center-master.sh [--auto]
#   --auto  called from on-window-detected: give AeroSpace a moment to tile
#           the new window before arranging.

set -u

[ "${1:-}" = "--auto" ] && sleep 0.5

monitor=$(aerospace list-monitors --focused --format '%{monitor-name}')
case "$monitor" in
  *Built-in*) exit 0 ;;
esac

ws=$(aerospace list-workspaces --focused)
main=$(aerospace list-windows --focused --format '%{window-id}')
[ -z "$main" ] && exit 0

count=$(aerospace list-windows --workspace "$ws" --format '%{window-id}' | sed '/^$/d' | wc -l | tr -d ' ')

aerospace flatten-workspace-tree --workspace "$ws"
aerospace layout --workspace "$ws" --root h_tiles 2>/dev/null

if [ "$count" -lt 3 ]; then
  aerospace balance-sizes --workspace "$ws"
  exit 0
fi

# Push the main window to the leftmost column, then step it into the middle.
i=1
while [ "$i" -lt "$count" ]; do
  aerospace move --window-id "$main" --boundaries workspace --boundaries-action stop left >/dev/null 2>&1
  i=$((i + 1))
done
mid=$(( (count - 1) / 2 ))
i=0
while [ "$i" -lt "$mid" ]; do
  aerospace move --window-id "$main" --boundaries workspace --boundaries-action stop right >/dev/null 2>&1
  i=$((i + 1))
done

aerospace balance-sizes --workspace "$ws"
aerospace resize --window-id "$main" width +600
