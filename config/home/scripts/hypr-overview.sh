#!/usr/bin/env bash
set -euo pipefail

EWW=(eww -c "$HOME/.config/eww-overview")
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-overview.open"

push_data() {
  "${EWW[@]}" update overview="$("$HOME/scripts/hypr-overview.py")"
}

case "${1:-}" in
  show)
    [ -e "$STATE" ] && exit 0
    touch "$STATE"
    push_data
    monitor=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
    "${EWW[@]}" open overview --screen "$monitor"
    [ -e "$STATE" ] || "${EWW[@]}" close overview >/dev/null 2>&1 || true
    ;;
  hide)
    [ -e "$STATE" ] || exit 0
    rm -f "$STATE"
    "${EWW[@]}" close overview >/dev/null 2>&1 || true
    ;;
  refresh)
    [ -e "$STATE" ] && push_data
    ;;
  *)
    echo "usage: hypr-overview.sh show|hide|refresh" >&2
    exit 2
    ;;
esac
