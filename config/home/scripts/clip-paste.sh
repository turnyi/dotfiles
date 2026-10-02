#!/usr/bin/env bash
set -euo pipefail

PANE="${1:-}"
DEST="${CLIP_PASTE_DEST:-$HOME/.shots}"
BUFFER="clip-paste"
X_DISPLAY=":86"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# An ssh login has no compositor in its environment (or a stale one inherited by
# the tmux server), so find the local session's socket.
if [ ! -S "$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-}" ]; then
  unset WAYLAND_DISPLAY
  for socket in "$XDG_RUNTIME_DIR"/wayland-*; do
    if [ -S "$socket" ]; then
      export WAYLAND_DISPLAY="${socket##*/}"
      break
    fi
  done
fi

# With nobody signed in to the desktop, clipcascade.sh keeps the synced
# clipboard on a headless X display instead.
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  clip_types() { wl-paste -l; }
  clip_image() { wl-paste -t image/png; }
  clip_text() { wl-paste -n; }
else
  xclip_out() { xclip -display "$X_DISPLAY" -selection clipboard -o "$@"; }
  clip_types() { xclip_out -t TARGETS; }
  clip_image() { xclip_out -t image/png; }
  clip_text() { xclip_out -t UTF8_STRING; }
fi

fail() {
  if [ -n "$PANE" ]; then
    tmux display-message "clip-paste: $1"
    exit 0
  fi
  echo "clip-paste: $1" >&2
  exit 1
}

types="$(clip_types 2>/dev/null)" || fail "clipboard is empty"

if grep -qx "image/png" <<<"$types"; then
  mkdir -p "$DEST"
  file="$DEST/clip-$(date +%Y%m%d-%H%M%S).png"
  clip_image >"$file"
  if [ -n "$PANE" ]; then
    tmux send-keys -t "$PANE" -l "$file "
  else
    echo "$file"
  fi
elif ! grep -qE "^(UTF8_STRING|text/plain)" <<<"$types"; then
  fail "clipboard is empty"
elif [ -n "$PANE" ]; then
  clip_text | tmux load-buffer -b "$BUFFER" -
  tmux paste-buffer -p -d -b "$BUFFER" -t "$PANE"
else
  clip_text
fi
