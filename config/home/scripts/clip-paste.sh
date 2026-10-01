#!/usr/bin/env bash
set -euo pipefail

PANE="${1:-}"
DEST="${CLIP_PASTE_DEST:-$HOME/.shots}"
BUFFER="clip-paste"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# An ssh login has no compositor in its environment, so find the local session's socket.
if [ -z "${WAYLAND_DISPLAY:-}" ]; then
  for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$socket" ]; then
      export WAYLAND_DISPLAY="${socket##*/}"
      break
    fi
  done
fi

fail() {
  if [ -n "$PANE" ]; then
    tmux display-message "clip-paste: $1"
    exit 0
  fi
  echo "clip-paste: $1" >&2
  exit 1
}

types="$(wl-paste -l 2>/dev/null)" || fail "clipboard is empty"

if grep -qx "image/png" <<<"$types"; then
  mkdir -p "$DEST"
  file="$DEST/clip-$(date +%Y%m%d-%H%M%S).png"
  wl-paste -t image/png >"$file"
  if [ -n "$PANE" ]; then
    tmux send-keys -t "$PANE" -l "$file "
  else
    echo "$file"
  fi
elif [ -n "$PANE" ]; then
  wl-paste -n | tmux load-buffer -b "$BUFFER" -
  tmux paste-buffer -p -d -b "$BUFFER" -t "$PANE"
else
  wl-paste -n
fi
