#!/usr/bin/env bash
set -euo pipefail

# Pokey stand-in for Hyprland: toggles a big cursor for presentations.

NORMAL_SIZE=24
BIG_SIZE=64
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/presenter-cursor"

theme() {
  gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'" || echo "default"
}

start() {
  hyprctl setcursor "$(theme)" "$BIG_SIZE" >/dev/null
  touch "$STATE_FILE"
  notify-send "Presenter cursor" "on"
}

stop() {
  hyprctl setcursor "$(theme)" "$NORMAL_SIZE" >/dev/null
  rm -f "$STATE_FILE"
  notify-send "Presenter cursor" "off"
}

case "${1:-toggle}" in
  on) start ;;
  off) stop ;;
  toggle) if [ -f "$STATE_FILE" ]; then stop; else start; fi ;;
  status) [ -f "$STATE_FILE" ] && echo on || echo off ;;
  *) echo "Usage: $0 [on|off|toggle|status]" >&2; exit 1 ;;
esac
