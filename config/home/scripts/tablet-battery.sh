#!/usr/bin/env bash
# Battery of an Android tablet attached to this machine as a second screen, for
# the sketchybar battery widget on macOS and the waybar one on Linux.
#
# Prints "level|status|link|name" while a tablet is reachable and nothing at all
# when it is not — the empty output is what makes both bars hide their widget.
# adb is the only transport that reports the tablet's battery, so "attached"
# here means "adb can see it", whether that is over USB or over wifi. Each
# machine therefore only shows the tablet while it is the one holding it.
set -euo pipefail

# Status bars run with a bare PATH, so adb has to be located by hand.
ADB_CANDIDATES=(
  "${TABLET_ADB_BIN:-}"
  "/opt/homebrew/bin/adb"
  "/usr/local/bin/adb"
  "/usr/bin/adb"
  "$HOME/Library/Android/sdk/platform-tools/adb"
)
TIMEOUT_CANDIDATES=(
  "/opt/homebrew/bin/timeout"
  "/opt/homebrew/bin/gtimeout"
  "/usr/local/bin/timeout"
  "/usr/bin/timeout"
)
# A tablet on wifi only answers once `adb connect` has run, and the address is
# the one thing that cannot be discovered, so it is read from here. No file
# means USB only, which costs nothing.
ADDRESS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar/tablet-adb-address"
# Reconnecting is the one slow path (it waits on an absent host), so it is tried
# on a timer rather than on every poll.
CONNECT_STAMP="${TMPDIR:-/tmp}/sketchybar-tablet-adb.stamp"
CONNECT_RETRY_SECONDS=30
ADB_TIMEOUT=4

find_binary() {
  local candidate
  for candidate in "$@"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  return 1
}

ADB="$(find_binary "${ADB_CANDIDATES[@]}")" || exit 0
TIMEOUT="$(find_binary "${TIMEOUT_CANDIDATES[@]}")" || TIMEOUT=""

run_adb() {
  if [ -n "$TIMEOUT" ]; then
    "$TIMEOUT" "$ADB_TIMEOUT" "$ADB" "$@"
  else
    "$ADB" "$@"
  fi
}

# Serials of devices that finished handshaking. Anything "offline" or
# "unauthorized" is deliberately skipped: querying it only hangs.
authorized_serials() {
  run_adb devices 2>/dev/null | awk '$2 == "device" { print $1 }'
}

# GNU stat on Linux, BSD stat on macOS — the flags are mutually exclusive.
file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}

connect_attempted_recently() {
  local now stamp
  [ -f "$CONNECT_STAMP" ] || return 1
  now="$(date +%s)"
  stamp="$(file_mtime "$CONNECT_STAMP")"
  [ $((now - stamp)) -lt "$CONNECT_RETRY_SECONDS" ]
}

try_wireless_connect() {
  local address
  [ -s "$ADDRESS_FILE" ] || return 0
  if connect_attempted_recently; then
    return 0
  fi
  : >"$CONNECT_STAMP"
  address="$(tr -d "[:space:]" <"$ADDRESS_FILE" | head -n 1)"
  [ -n "$address" ] || return 0
  run_adb connect "$address" >/dev/null 2>&1 || true
}

# One round trip for identity and charge together: adb pays a fixed cost per
# invocation, and this runs on every poll.
probe_device() {
  run_adb -s "$1" shell \
    "getprop ro.build.characteristics; settings get global device_name; dumpsys battery" 2>/dev/null
}

# Turns a probe into the widget's line, or exits non-zero when the device is not
# a tablet (a phone left charging on the same desk must not take the slot).
format_device() {
  awk -v link="$1" '
    NR == 1 { characteristics = $0 }
    NR == 2 { name = $0 }
    $1 == "level:" { level = $2 }
    $1 == "status:" { status = $2 }
    END {
      if (index(characteristics, "tablet") == 0) exit 1
      if (level == "") exit 1

      word["2"] = "charging"
      word["3"] = "discharging"
      word["4"] = "not_charging"
      word["5"] = "full"
      state = (status in word) ? word[status] : "unknown"

      if (name == "" || name == "null") name = "Tablet"
      printf "%s|%s|%s|%s\n", level, state, link, name
    }
  '
}

main() {
  local serials serial link line
  serials="$(authorized_serials || true)"
  if [ -z "$serials" ]; then
    try_wireless_connect
    serials="$(authorized_serials || true)"
  fi
  [ -n "$serials" ] || return 0

  while IFS= read -r serial; do
    [ -n "$serial" ] || continue
    # A wireless serial is an "address:port"; a USB one is a hardware id.
    case "$serial" in
      *:*) link="wifi" ;;
      *) link="usb" ;;
    esac
    if line="$(probe_device "$serial" | format_device "$link")" && [ -n "$line" ]; then
      printf "%s\n" "$line"
      return 0
    fi
  done <<<"$serials"
  return 0
}

main "$@"
