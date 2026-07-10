#!/usr/bin/env bash
# Compose a message and send it straight to a Claude pane's input box, without
# leaving the dashboard. The agent's reply then streams into the live preview.
# Usage: claude-agents-send.sh <pane_id>
set -u
p="${1:-}"
[ -n "$p" ] || exit 0

title="$(tmux display -p -t "$p" '#{pane_title}' 2>/dev/null)"
printf '\033[2J\033[H'                                            # clear compose screen
printf '\033[1;36m┃ chat → %s\033[0m\n' "$title"
printf '\033[2m┃ Enter sends · empty Enter cancels\033[0m\n\n'

IFS= read -r -e -p '❯ ' msg || exit 0
[ -n "$msg" ] || exit 0

# -l sends the text literally (no key-name lookup); a small gap lets the TUI
# ingest the text before the submit keypress.
tmux send-keys -t "$p" -l -- "$msg"
sleep 0.12
tmux send-keys -t "$p" Enter
