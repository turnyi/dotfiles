#!/usr/bin/env bash
# Quit mission control on a double-Esc. The list binds esc to call us with --tap;
# two taps within ~0.7s send every docked agent home and close the agents window.
# A single tap just records the time (fzf's own abort reopens the list via --loop).
#   claude-agents-quit.sh --tap <stage>
set -u
S="$(cd "$(dirname "$0")" && pwd)"

[ "${1:-}" = --tap ] || exit 0
stage="${2:-}"; [ -n "$stage" ] || exit 0
MARK="${TMPDIR:-/tmp}/claude-agents-quit.$stage"

now="$(date +%s%N)"
last="$(cat "$MARK" 2>/dev/null || echo 0)"
if [ "$((now - last))" -lt 700000000 ]; then
  : >"$MARK"
  "$S/claude-agents-dock.sh" --untile-all "$stage" 2>/dev/null
  win="$(tmux display -p -t "$stage" '#{window_id}' 2>/dev/null)"
  [ -n "$win" ] && tmux kill-window -t "$win" 2>/dev/null
else
  printf '%s' "$now" >"$MARK"
fi
