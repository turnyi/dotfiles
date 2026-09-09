#!/usr/bin/env bash
# claude-fork-pane.sh — clone the conversation running here into a new tmux
# pane. `claude --resume <id> --fork-session` copies the transcript under a
# fresh session id, so both sides continue independently from shared history.
#
#   claude-fork-pane.sh [right|left|bottom|top|window] [initial prompt...]
set -eu

PROJECTS="$HOME/.claude/projects"

encode_dir() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g'; }

die() { printf '%s\n' "$1" >&2; exit 1; }

direction=right
case "${1:-}" in
  right | r | vertical | vsplit | v) direction=right; shift ;;
  left | l) direction=left; shift ;;
  bottom | below | down | b | d | horizontal | hsplit | h) direction=bottom; shift ;;
  top | above | up | t | u) direction=top; shift ;;
  window | w | tab) direction=window; shift ;;
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
if [ "$#" -gt 0 ]; then
  cmd="$cmd $(printf '%q' "$*")"
fi

case "$direction" in
  right)  tmux split-window -h -c "$PWD" "$cmd" ;;
  left)   tmux split-window -h -b -c "$PWD" "$cmd" ;;
  bottom) tmux split-window -v -c "$PWD" "$cmd" ;;
  top)    tmux split-window -v -b -c "$PWD" "$cmd" ;;
  window) tmux new-window -c "$PWD" -n "fork:${PWD##*/}" "$cmd" ;;
esac

printf 'forked %s to the %s\n' "$session" "$direction"
