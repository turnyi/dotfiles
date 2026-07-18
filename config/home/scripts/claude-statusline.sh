#!/usr/bin/env bash
# claude-statusline.sh — Claude Code statusLine command (~/.claude/settings.json).
# Reads the session JSON Claude Code pipes on stdin and prints one line:
#   ★ [label] ~/dir  branch  Model
# The ★ (+ label) shows when THIS conversation is bookmarked in
# ~/.claude/bookmarks.tsv — toggled with prefix-b in tmux or ctrl-b inside the
# C-o resume picker (see claude-resume.sh).
set -u
BOOKMARKS="$HOME/.claude/bookmarks.tsv"

in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in")
model=$(jq -r '.model.display_name // empty' <<<"$in")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$in")

out=""
if [ -n "$sid" ] && [ -f "$BOOKMARKS" ] && grep -q "^$sid	" "$BOOKMARKS"; then
  label=$(grep -m1 "^$sid	" "$BOOKMARKS" | cut -f2)
  out+=$'\033[1;33m★'"${label:+ [$label]}"$'\033[0m '
fi
out+=$'\033[36m'"${dir/#$HOME/\~}"$'\033[0m'
branch=$(git -C "$dir" branch --show-current 2>/dev/null)
[ -n "$branch" ] && out+=$'  \033[35m'"$branch"$'\033[0m'
[ -n "$model" ] && out+=$'  \033[2m'"$model"$'\033[0m'
printf '%s' "$out"
