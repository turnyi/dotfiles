#!/usr/bin/env bash
set -euo pipefail
PATH="/opt/homebrew/bin:$PATH"  # aerospace exec-and-forget doesn't inherit brew's PATH

host="${SHOT2SERVER_HOST:-server}"
dest="${SHOT2SERVER_DEST:-.shots}"
name="shot-$(date +%Y%m%d-%H%M%S).png"
tmp="$(mktemp -t shot2server.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

grab_clipboard() {
  if command -v pngpaste >/dev/null; then pngpaste "$tmp"
  elif [ -n "${WAYLAND_DISPLAY:-}" ]; then wl-paste -t image/png > "$tmp"
  else xclip -selection clipboard -t image/png -o > "$tmp"
  fi
}

copy_text() {
  if command -v pbcopy >/dev/null; then pbcopy
  elif [ -n "${WAYLAND_DISPLAY:-}" ]; then wl-copy
  else xclip -selection clipboard
  fi
}

notify() {
  if command -v notify-send >/dev/null; then notify-send "shot2server" "$1"
  elif command -v osascript >/dev/null; then osascript -e "display notification \"$1\" with title \"shot2server\""
  fi
}

if [ -t 0 ]; then grab_clipboard; else cat > "$tmp"; fi
[ -s "$tmp" ] || grab_clipboard  # launchers pass /dev/null as stdin; fall back to clipboard
[ -s "$tmp" ] || { notify "no image in clipboard"; exit 1; }

remote_path=$(ssh -o ControlMaster=auto -o ControlPath="$HOME/.ssh/cm-%C" -o ControlPersist=10m \
  "$host" "mkdir -p '$dest' && cat > '$dest/$name' && cd '$dest' && echo \"\$PWD/$name\"" < "$tmp")

printf '%s' "$remote_path" | copy_text
notify "$remote_path"
