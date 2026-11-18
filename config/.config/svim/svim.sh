#!/usr/bin/env bash
set -uo pipefail

export PATH="/opt/homebrew/bin:$PATH"

KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
# Same colors as config/.config/hypr/lua/vimmode.lua and hyprland.lua
IDLE_BORDER="gradient(top_left=0xdd4c5bff,bottom_right=0xdd3cc8cc)"

case "${MODE:-}" in
  N) border="0xee9ed072" ;;
  V) border="0xeef39660" ;;
  C) border="0xeee7c664" ;;
  *) border="$IDLE_BORDER" ;;
esac

# svim_vim: NORMAL/VISUAL, Karabiner skips the Escape delay
# svim_normal: NORMAL, Karabiner maps Ctrl+h/j/k/l to F6 / Shift+F6
vim=0
normal=0
case "${MODE:-}" in
  N) vim=1 normal=1 ;;
  V) vim=1 ;;
esac

"$KARABINER_CLI" --set-variables "{\"svim_vim\":$vim,\"svim_normal\":$normal}" &
borders active_color="$border" &
sketchybar --trigger svim_mode MODE="${MODE:-}" &
wait
