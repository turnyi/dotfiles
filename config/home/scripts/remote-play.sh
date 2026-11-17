#!/usr/bin/env bash
set -euo pipefail

# Streams a headless REMOTE output to Moonlight over Tailscale, for playing
# away from home. tablet-screen.sh serves the tablet over USB instead; both
# run Sunshine, so starting one stops the other.

OUTPUT=REMOTE
APPS="$HOME/.config/sunshine/remote-apps.json"

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

# Bound to the Tailscale address only, so the stream and pairing ports are
# never reachable from the LAN or the internet.
serve() {
  local ip
  ip=$(tailscale ip -4)
  [ -n "$ip" ] || { echo "tailscale has no IPv4 address" >&2; exit 1; }
  pkill -x sunshine || true
  while pgrep -x sunshine >/dev/null; do sleep 0.2; done
  # The startup encoder probe needs an output to capture, and with no monitor
  # plugged in there is none until a stream's prep-cmd would add it.
  output_add
  # The web UI rejects form posts from origins it doesn't recognise, and the
  # Tailscale address isn't one of its defaults.
  local suffix origins
  suffix=$(tailscale status --json | jq -r '.MagicDNSSuffix')
  origins="https://$ip:47990,https://$(hostname).$suffix:47990"
  exec sunshine "bind_address=$ip" "output_name=$OUTPUT" "file_apps=$APPS" \
    "csrf_allowed_origins=$origins"
}

case "${1:-}" in
  serve) serve ;;
  output-add) output_add ;;
  output-remove) output_remove ;;
  *) echo "Usage: $0 [serve|output-add|output-remove]" >&2; exit 1 ;;
esac
