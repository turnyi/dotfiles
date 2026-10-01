#!/usr/bin/env bash
# Open slk in its own kitty window, deliberately outside tmux.
#
# slk draws inline images with kitty's graphics protocol, which tmux cannot
# track: tmux knows where the TEXT rows are but not where the images are, so a
# redraw slides a row sideways, clips an image at the pane edge, or leaves a
# previous image's pixels behind. slk's own docs call pixel pass-through inside
# tmux unreliable and fall back to blocky half-blocks because of it.
#
# Running slk as the window's program sidesteps all of that — no tmux, no
# shell, just slk talking straight to kitty. Transparency, blur, avatars and
# the theme all still apply; they are kitty- and config-level, not tmux-level.
set -euo pipefail

KITTY="/Applications/kitty.app/Contents/MacOS/kitty"
# Prefer the rounded-border build when it is present (see slk-build-rounded.sh).
SLK="$HOME/.local/bin/slk-rounded"

[ -x "$KITTY" ] || {
  echo "slk-window: kitty not found at $KITTY" >&2
  exit 1
}
[ -x "$SLK" ] || SLK="$(command -v slk)" || {
  echo "slk-window: slk is not installed" >&2
  exit 1
}

# --single-instance reuses the running kitty, so this is a new OS window rather
# than a second kitty process.
exec "$KITTY" --single-instance --title slk "$SLK"
