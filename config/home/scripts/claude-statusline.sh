#!/usr/bin/env bash
# claude-statusline.sh — Claude Code statusLine command (~/.claude/settings.json).
# Reads the session JSON Claude Code pipes on stdin and prints one line:
#   [VIM MODE] ★ [label] ~/dir  branch  Model
# The vim pill only shows when vim mode is on; it also sets the cursor shape
# (block in NORMAL/VISUAL, beam in INSERT).
# The ★ (+ label) shows when THIS conversation is bookmarked in
# ~/.claude/bookmarks.tsv — toggled with prefix-b in tmux or ctrl-b inside the
# C-o resume picker (see claude-resume.sh).
set -u
BOOKMARKS="$HOME/.claude/bookmarks.tsv"

in=$(cat)
sid=$(jq -r '.session_id // empty' <<<"$in")
model=$(jq -r '.model.display_name // empty' <<<"$in")
dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$in")
vim_mode=$(jq -r '.vim.mode // empty' <<<"$in")

# Claude Code (2.1.x) never emits DECSCUSR itself, and stdout here is rendered
# as text inside its TUI, so the shape escape is written to the pts of the
# nearest ancestor that owns one. Claude re-runs this script on every vim mode
# change after a 300ms debounce, which is the latency of the cursor switch.
claude_tty() {
  local pid=$PPID tty
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ -n "$tty" ] && [ "$tty" != "?" ]; then
      printf '/dev/%s' "$tty"
      return
    fi
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
}

mode_pill() {
  local bg
  case "$1" in
    NORMAL) bg='122;162;247' ;;
    INSERT) bg='158;206;106' ;;
    VISUAL*) bg='187;154;247' ;;
    REPLACE) bg='219;75;75' ;;
    *) bg='130;139;184' ;;
  esac
  printf '\033[38;2;%sm\xee\x82\xb6\033[1;38;2;30;30;46;48;2;%sm %s \033[0;38;2;%sm\xee\x82\xb4\033[0m ' "$bg" "$bg" "$1" "$bg"
}

if [ -n "$vim_mode" ]; then
  [ "$vim_mode" = INSERT ] && shape=6 || shape=2
  tty=$(claude_tty)
  [ -n "$tty" ] && [ -w "$tty" ] && printf '\033[%s q' "$shape" >"$tty"
fi

out=""
[ -n "$vim_mode" ] && out+=$(mode_pill "$vim_mode")
if [ -n "$sid" ] && [ -f "$BOOKMARKS" ] && grep -q "^$sid	" "$BOOKMARKS"; then
  label=$(grep -m1 "^$sid	" "$BOOKMARKS" | cut -f2)
  out+=$'\033[1;33m★'"${label:+ [$label]}"$'\033[0m '
fi
out+=$'\033[36m'"${dir/#$HOME/\~}"$'\033[0m'
branch=$(git -C "$dir" branch --show-current 2>/dev/null)
[ -n "$branch" ] && out+=$'  \033[35m'"$branch"$'\033[0m'
[ -n "$model" ] && out+=$'  \033[2m'"$model"$'\033[0m'
slot=$("$HOME/scripts/centinel-slot.sh" <<<"$in" 2>/dev/null)
[ -n "$slot" ] && out+=$'  \033[33m'"⧉ $slot"$'\033[0m'
if [ -n "${TMUX_PANE:-}" ]; then
  subs=$(tmux show-option -qvp -t "$TMUX_PANE" @claude_subs 2>/dev/null)
  case "$subs" in ''|0) ;; *) out+=$'  \033[38;5;215m'"↳ $subs"$'\033[0m' ;; esac
  budget=$(tmux show-option -qvp -t "$TMUX_PANE" @claude_budget 2>/dev/null)
  started=$(tmux show-option -qvp -t "$TMUX_PANE" @claude_started 2>/dev/null)
  if [ -n "$budget" ] && [ -n "$started" ]; then
    used=$(( $(date +%s) - started ))
    col=$'\033[2m'; [ "$used" -gt "$budget" ] && col=$'\033[1;31m'
    out+="  ${col}$((used / 60))/$((budget / 60))m"$'\033[0m'
  fi
fi
printf '%s' "$out"
