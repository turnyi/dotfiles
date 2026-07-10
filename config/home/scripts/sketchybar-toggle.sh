#!/usr/bin/env bash
# Toggle sketchybar visibility. Also collapses/restores the top gap AeroSpace
# reserves for the bar, so windows reclaim the space while it is hidden.

set -u

# Resolve the symlink: BSD `sed -i` would otherwise replace it with a copy.
config=$(readlink -f "$HOME/.aerospace.toml")

if sketchybar --query bar | grep -q '"hidden": *"on"'; then
  sketchybar --bar hidden=off
  sed -i '' "s|^\( *\)outer\.top .*|\1outer.top        = [{ monitor.'built-in' = 5 }, 37]|" "$config"
else
  sketchybar --bar hidden=on
  sed -i '' "s|^\( *\)outer\.top .*|\1outer.top        = 5|" "$config"
fi

aerospace reload-config --no-gui
