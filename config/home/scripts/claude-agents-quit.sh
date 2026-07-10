#!/usr/bin/env bash
# Quit the tiled mission-control workspace: send every pinned agent home, then
# close the agents window.
#   claude-agents-quit.sh --now <stage>   quit immediately (e.g. :q)
#   claude-agents-quit.sh --tap <stage>   quit only on a second tap within ~0.7s
#                                         (esc esc; a lone tap is recorded and the
#                                         list's own +abort reopens it via --loop)
set -u
S="$(cd "$(dirname "$0")" && pwd)"

teardown() {
  local stage="$1"
  "$S/claude-agents-dock.sh" --untile-all "$stage" 2>/dev/null
  local win; win="$(tmux display -p -t "$stage" '#{window_id}' 2>/dev/null)"
  [ -n "$win" ] && tmux kill-window -t "$win" 2>/dev/null
}

mode="${1:-}"; stage="${2:-}"
[ -n "$stage" ] || exit 0

case "$mode" in
  --now)
    teardown "$stage" ;;
  --tap)
    MARK="${TMPDIR:-/tmp}/claude-agents-quit.$stage"
    now="$(date +%s%N)"
    last="$(cat "$MARK" 2>/dev/null || echo 0)"
    if [ "$((now - last))" -lt 700000000 ]; then
      : >"$MARK"
      teardown "$stage"
    else
      printf '%s' "$now" >"$MARK"
    fi ;;
esac
