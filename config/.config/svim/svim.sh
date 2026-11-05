#!/usr/bin/env bash
set -uo pipefail

export PATH="/opt/homebrew/bin:$PATH"

KARABINER_CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
IDLE_BORDER="0xffe1e3e4"

case "${MODE:-}" in
  N) border="0xffa6da95" ;;
  V) border="0xfff5a97f" ;;
  C) border="0xffeed49f" ;;
  *) border="$IDLE_BORDER" ;;
esac

insert=0
[[ "${MODE:-}" == "I" ]] && insert=1

"$KARABINER_CLI" --set-variables "{\"svim_insert\":$insert}" &
borders active_color="$border" &
sketchybar --trigger svim_mode MODE="${MODE:-}" &
wait
