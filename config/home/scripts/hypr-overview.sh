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
    trap 'rm -f "$STATE"' ERR
    push_data
    # eww 0.5 addresses monitors by model, not connector; the index is the
    # fallback for outputs without one (the tablet's virtual display).
    screen=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | if .model != "" then .model else (.id | tostring) end')
    "${EWW[@]}" open overview --screen "$screen"
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
