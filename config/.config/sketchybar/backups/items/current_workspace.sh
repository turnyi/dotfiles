#!/usr/bin/env sh
CURRENT_WS=$(aerospace list-workspaces --current) # Get current workspace
sketchybar --set current_workspace label="$CURRENT_WS"
