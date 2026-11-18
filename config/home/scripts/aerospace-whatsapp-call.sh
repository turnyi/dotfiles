#!/usr/bin/env bash
# WhatsApp call popup that floats and follows you across AeroSpace workspaces,
# like Hyprland's "pin". AeroSpace has no sticky windows, so this script fakes
# it: the call window is remembered when it opens and moved to every workspace
# you switch to.
#
# The WhatsApp Web PWA reports empty window titles to AeroSpace, so the call
# window can't be matched by title. It is told apart from the main window by
# being a second WhatsApp window, or one AeroSpace already floated.
#
# Usage: aerospace-whatsapp-call.sh --detected   (on-window-detected)
#        aerospace-whatsapp-call.sh --follow     (exec-on-workspace-change)

set -euo pipefail

readonly APP_ID="com.google.Chrome.app.hnpfjngllnobngcgfapefoaidbinmjnm"
readonly HOME_WORKSPACE="8"
readonly STATE_FILE="${TMPDIR:-/tmp}/aerospace-sticky-windows"

whatsapp_windows() {
  aerospace list-windows --all --app-bundle-id "$APP_ID" --format "%{window-id}|%{window-layout}|%{workspace}"
}

on_detected() {
  local window_id="${AEROSPACE_WINDOW_ID:-}"
  [ -z "$window_id" ] && exit 0

  local others layout
  others=$(whatsapp_windows | grep -c -v "^${window_id}|" || true)
  layout=$(whatsapp_windows | grep "^${window_id}|" | cut -d "|" -f 2)

  if [ "$others" -gt 0 ] || [ "$layout" = "floating" ]; then
    aerospace layout --window-id "$window_id" floating 2>/dev/null || true
    echo "$window_id" >>"$STATE_FILE"
  else
    aerospace move-node-to-workspace --window-id "$window_id" --focus-follows-window "$HOME_WORKSPACE"
  fi
}

on_follow() {
  local focused="${AEROSPACE_FOCUSED_WORKSPACE:-}"
  [ -z "$focused" ] && focused=$(aerospace list-workspaces --focused)
  [ -f "$STATE_FILE" ] || exit 0

  local live alive=""
  live=$(aerospace list-windows --all --format "%{window-id}|%{workspace}")

  local window_id workspace
  while read -r window_id; do
    [ -z "$window_id" ] && continue
    workspace=$(echo "$live" | grep "^${window_id}|" | cut -d "|" -f 2 || true)
    [ -z "$workspace" ] && continue # call ended, window closed
    alive+="${window_id}"$'\n'
    if [ "$workspace" != "$focused" ]; then
      aerospace move-node-to-workspace --window-id "$window_id" "$focused" || true
    fi
  done <"$STATE_FILE"

  printf "%s" "$alive" | sort -u >"$STATE_FILE"
}

case "${1:-}" in
  --detected) on_detected ;;
  --follow) on_follow ;;
  *)
    echo "usage: $0 --detected|--follow" >&2
    exit 1
    ;;
esac
