#!/usr/bin/env bash
# Claude Code agents dashboard — a live fzf list of every running `claude` pane.
#
# Two flavours, chosen by environment:
#   * popup / plain (CLAUDE_AGENTS_STAGE unset): list + read-only preview on the
#     right. enter = go to pane, tab = chat, ctrl-o = open beside the list.
#   * mission control (CLAUDE_AGENTS_STAGE=<stage pane id>): list on the left, a
#     "stage" pane on the right. enter = swap the real agent onto the stage and
#     interact with it live; ctrl-u = send it home.
#
# Common keys: tab = chat with highlighted agent, ctrl-b = broadcast to all,
#              ctrl-r = refresh.
#
# Env:
#   CLAUDE_AGENTS_LOOP=1     keep reopening on esc (dedicated dashboard window)
#   CLAUDE_AGENTS_STAGE=%N   enable mission-control docking against stage pane %N
#   CLAUDE_AGENTS_NOTIFY=1   macOS notification when an agent finishes
set -u

S="$(cd "$(dirname "$0")" && pwd)"
list="$S/claude-agents-list.sh"
DASH="$(tmux display -p '#{session_name}:#{window_id}' 2>/dev/null)"

# Options may arrive as args (preferred — tmux's split-window -e is unreliable)
# or environment variables.
STAGE=""
LOOP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="${2:-}"; shift 2 ;;
    --loop)  LOOP=1; shift ;;
    *)       shift ;;
  esac
done
STAGE="${STAGE:-${CLAUDE_AGENTS_STAGE:-}}"
[ "${CLAUDE_AGENTS_LOOP:-0}" = 1 ] && LOOP=1
SEL="${TMPDIR:-/tmp}/claude-agents-sel.$STAGE"

run_once() {
  if [ -n "$STAGE" ]; then
    # ---- mission-control mode: the stage pane is the view ------------------
    "$list" | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=2 \
      --prompt='agents ❯ ' \
      --header='enter: go to pane   tab: dock onto stage (type in the REAL pane)   ctrl-u: send it home   ctrl-b: broadcast' \
      --bind="start:execute-silent(printf %s {1} > '$SEL')" \
      --bind="focus:execute-silent(printf %s {1} > '$SEL')" \
      --bind="load:reload-sync(sleep 1; '$list')" \
      --bind="ctrl-r:reload('$list')" \
      --bind="enter:execute-silent('$S/claude-agents-goto.sh' {1})+abort" \
      --bind="tab:execute-silent('$S/claude-agents-dock.sh' {1} '$STAGE')" \
      --bind="ctrl-u:execute-silent('$S/claude-agents-dock.sh' --release '$STAGE')" \
      --bind="ctrl-b:execute('$S/claude-agents-broadcast.sh')" \
      --bind="ctrl-g:execute-silent('$S/claude-agents-goto.sh' {1})"
  else
    # ---- popup / plain mode: read-only preview on the right ----------------
    "$list" | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=2 \
      --prompt='agents ❯ ' \
      --header='enter/tab: go to pane   ctrl-o: open beside list   ctrl-b: broadcast   ctrl-r: refresh' \
      --preview="tmux capture-pane -ep -t {1} 2>/dev/null" \
      --preview-window='right,62%,follow,border-left' \
      --bind="load:reload-sync(sleep 1; '$list')+refresh-preview" \
      --bind="ctrl-r:reload('$list')+refresh-preview" \
      --bind="ctrl-/:toggle-preview" \
      --bind="ctrl-b:execute('$S/claude-agents-broadcast.sh')+refresh-preview" \
      --bind="enter:execute-silent('$S/claude-agents-goto.sh' {1})+abort" \
      --bind="tab:execute-silent('$S/claude-agents-goto.sh' {1})+abort" \
      --bind="ctrl-o:execute-silent('$S/claude-agents-join.sh' {1} '$DASH')"
  fi
}

if [ "$LOOP" = 1 ]; then
  while :; do run_once || true; sleep 0.2; done
else
  run_once
fi
