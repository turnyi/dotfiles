#!/usr/bin/env bash
# claude-fork-pane.sh — clone the conversation running here into a new tmux
# pane. `claude --resume <id> --fork-session` copies the transcript under a
# fresh session id, so both sides continue independently from shared history.
#
#   claude-fork-pane.sh [vertical|horizontal|window] [initial prompt...]
#
# vertical (default) splits side by side, horizontal stacks top/bottom, and
# window opens a new tmux window — matching the vsplit/hsplit vocabulary the
# rest of the claude-* scripts use.
set -eu

PROJECTS="$HOME/.claude/projects"

encode_dir() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g'; }

die() { printf '%s\n' "$1" >&2; exit 1; }

layout=vertical
case "${1:-}" in
  vertical | vsplit | v | -h) layout=vertical; shift ;;
  horizontal | hsplit | h | -v) layout=horizontal; shift ;;
  window | w | tab) layout=window; shift ;;
esac

[ -n "${TMUX:-}" ] || die 'not inside tmux — run this from a claude session in a tmux pane'

session="${CLAUDE_CODE_SESSION_ID:-}"
if [ -z "$session" ]; then
  # Not launched from inside Claude: fall back to the newest transcript for
  # this directory, which is the conversation Claude is appending to right now.
  f=$(ls -t "$PROJECTS/$(encode_dir "$PWD")"/*.jsonl 2>/dev/null | head -1) || true
  [ -n "${f:-}" ] || die "no claude conversation found for $PWD"
  session="${f##*/}"; session="${session%.jsonl}"
fi

claude_bin="$(command -v claude || echo claude)"
cmd="$claude_bin --resume $session --fork-session --dangerously-skip-permissions"
[ "$#" -gt 0 ] && cmd="$cmd $(printf '%q' "$*")"

case "$layout" in
  vertical)   tmux split-window -h -c "$PWD" "$cmd" ;;
  horizontal) tmux split-window -v -c "$PWD" "$cmd" ;;
  window)     tmux new-window -c "$PWD" -n "fork:${PWD##*/}" "$cmd" ;;
esac

printf 'forked %s into a new %s\n' "$session" "$layout"
