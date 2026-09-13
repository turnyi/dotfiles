#!/usr/bin/env bash
set -euo pipefail

OUTPUT=TAB

if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for sock in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$sock" ]; then
      export WAYLAND_DISPLAY="${sock##*/}"
      break
    fi
  done
fi

output_exists() {
  hyprctl monitors -j | jq -e --arg o "$OUTPUT" 'any(.[]; .name == $o)' >/dev/null
}

output_add() {
  output_exists || hyprctl output create headless "$OUTPUT" >/dev/null
}

output_remove() {
  ! output_exists || hyprctl output remove "$OUTPUT" >/dev/null
}

running() {
  pgrep -x sunshine >/dev/null
}

tablet_on_usb() {
  command -v adb >/dev/null && [ "$(timeout 5 adb get-state 2>/dev/null)" = device ]
}

usb_ip() {
  local dev
  for dev in /sys/class/net/*; do
    [[ "$(readlink "$dev/device/driver" 2>/dev/null)" == */rndis_host ]] || continue
    ip -4 -o addr show dev "${dev##*/}" | awk '{split($4, a, "/"); print a[1]; exit}'
    return
  done
}

# `svc usb setFunctions` exits 255 on Samsung even when the switch succeeds,
# so success is judged by the host interface getting an address instead.
usb_up() {
  timeout 5 adb shell svc usb setFunctions rndis >/dev/null 2>&1 || true
  local ip
  for _ in $(seq 1 50); do
    ip=$(usb_ip)
    [ -n "$ip" ] && { echo "$ip"; return 0; }
    sleep 0.2
  done
  return 1
}

usb_down() {
  [ -n "$(usb_ip)" ] && tablet_on_usb || return 0
  timeout 5 adb shell svc usb setFunctions >/dev/null 2>&1 || true
}

stop_sunshine() {
  pkill -x sunshine || return 0
  while running; do sleep 0.2; done
}

start() {
  local ip="" via="network"
  if tablet_on_usb; then
    if ip=$(usb_up); then
      via="USB"
    else
      notify-send -u critical "Tablet screen" "USB tethering did not come up — falling back to network"
    fi
  fi
  stop_sunshine
  setsid -f sunshine >/dev/null 2>&1
  if [ "$via" = USB ]; then
    notify-send "Tablet screen" "server on over USB — open Desktop in Moonlight (host $ip)"
  else
    notify-send "Tablet screen" "server on over network — open Desktop in Moonlight"
  fi
}

stop() {
  stop_sunshine
  output_remove
  usb_down
  notify-send "Tablet screen" "server off"
}

case "${1:-toggle}" in
  start) start ;;
  stop) stop ;;
  toggle) if running; then stop; else start; fi ;;
  output-add) output_add ;;
  output-remove) output_remove ;;
  *) echo "Usage: $0 [start|stop|toggle|output-add|output-remove]" >&2; exit 1 ;;
esac
