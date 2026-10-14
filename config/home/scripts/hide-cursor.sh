#!/usr/bin/env bash
# Builds (when the source changed) and runs the idle-cursor hider.
# Started by ~/Library/LaunchAgents/com.turny.hide-cursor.plist.
set -euo pipefail

SRC="$HOME/.config/hide-cursor/hide-cursor.swift"
BIN="$HOME/.cache/hide-cursor/hide-cursor"
TIMEOUT="${1:-3}"

if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
  mkdir -p "$(dirname "$BIN")"
  swiftc -O "$SRC" -o "$BIN"
fi

exec "$BIN" "$TIMEOUT"
