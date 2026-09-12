#!/usr/bin/env bash
set -euo pipefail

WHO=caffeine

inhibitor_pid() {
  pgrep -f "^systemd-inhibit --who=$WHO " || true
}

start() {
  [ -n "$(inhibitor_pid)" ] && return 0
  setsid -f systemd-inhibit --who="$WHO" --what=idle:sleep --why="Caffeine on" sleep infinity >/dev/null 2>&1
  notify-send "Caffeine" "on — no lock, no sleep"
}

stop() {
  pid="$(inhibitor_pid)"
  [ -n "$pid" ] && kill -- "-$pid"
  notify-send "Caffeine" "off"
}

case "${1:-toggle}" in
  on) start ;;
  off) stop ;;
  toggle) if [ -n "$(inhibitor_pid)" ]; then stop; else start; fi ;;
  status) [ -n "$(inhibitor_pid)" ] && echo on || echo off ;;
  *) echo "Usage: $0 [on|off|toggle|status]" >&2; exit 1 ;;
esac
