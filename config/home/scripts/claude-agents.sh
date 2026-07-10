#!/usr/bin/env bash
# Claude Code agents dashboard — a live fzf list of every running `claude` pane.
#
# Modes:
#   --popup            floating command-palette: list + live preview. enter = go
#                      to pane, tab = pin into the workspace, ctrl-x = close,
#                      alt-b = broadcast, :q/esc = quit.
#   --stage %N --loop  the tiled WORKSPACE list (left column). enter = go to pane,
#                      tab = pin/unpin a tile on stage %N, ctrl-u = unpin,
#                      ctrl-x = close, :q / esc esc = quit.
#
# Env:
#   CLAUDE_AGENTS_LOOP=1     keep reopening on esc (workspace list)
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
POPUP=0
while [ $# -gt 0 ]; do
  case "$1" in
    --stage) STAGE="${2:-}"; shift 2 ;;
    --loop)  LOOP=1; shift ;;
    --popup) POPUP=1; shift ;;
    *)       shift ;;
  esac
done
STAGE="${STAGE:-${CLAUDE_AGENTS_STAGE:-}}"
[ "${CLAUDE_AGENTS_LOOP:-0}" = 1 ] && LOOP=1
SEL="${TMPDIR:-/tmp}/claude-agents-sel.$STAGE"

run_once() {
  if [ "$POPUP" = 1 ]; then
    # ---- floating popup (C-g): list + live preview, pin into the workspace ---
    # enter uses fzf's default accept so the selected row is PRINTED and fzf
    # exits; we then jump to the pane from here (outside fzf). Doing the jump
    # after the popup's fzf exits — rather than via execute+abort inside it —
    # is what makes switch-client actually move the client. Typing :q filters
    # the list empty, so accept prints nothing and the popup just closes.
    local sel pane
    sel="$("$list" | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=2 \
      --prompt='agents ❯ ' \
      --header='enter: go to pane · tab: pin to workspace · ctrl-x: close · alt-b: broadcast · :q/esc: quit' \
      --preview="tmux capture-pane -ep -t {1} 2>/dev/null" \
      --preview-window='right,60%,follow,border-left' \
      --bind="load:reload-sync(sleep 1; '$list')+refresh-preview" \
      --bind="focus:refresh-preview" \
      --bind="ctrl-r:reload('$list')+refresh-preview" \
      --bind="ctrl-/:toggle-preview" \
      --bind="tab:execute-silent('$S/claude-agents-pin.sh' {1})+reload('$list')+refresh-preview" \
      --bind="ctrl-x:execute(printf 'close agent %s? [y/N] ' {2}; read -r a; [ \"\$a\" = y ] && '$S/claude-agents-kill.sh' {1})+reload('$list')+refresh-preview" \
      --bind="alt-b:execute('$S/claude-agents-broadcast.sh')+refresh-preview")"
    pane="${sel%%$'\t'*}"
    [ -n "$pane" ] && "$S/claude-agents-goto.sh" "$pane"
    return 0
  elif [ -n "$STAGE" ]; then
    # ---- mission-control mode: the stage pane is the view ------------------
    "$list" | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=2 \
      --prompt='agents ❯ ' \
      --header='enter: go to pane · tab: pin/unpin tile · ctrl-u: unpin · ctrl-x: close · alt-b: broadcast · :q or esc esc: quit · C-b: hide list' \
      --bind="start:execute-silent(printf %s {1} > '$SEL')" \
      --bind="focus:execute-silent(printf %s {1} > '$SEL')" \
      --bind="load:reload-sync(sleep 1; '$list')" \
      --bind="ctrl-r:reload('$list')" \
      --bind="enter:execute-silent('$S/claude-agents-enter.sh' {q} {1} '$STAGE')+abort" \
      --bind="tab:execute-silent('$S/claude-agents-dock.sh' {1} '$STAGE')" \
      --bind="ctrl-u:execute-silent('$S/claude-agents-dock.sh' --untile {1} '$STAGE')" \
      --bind="ctrl-x:execute(printf 'close agent %s? [y/N] ' {2}; read -r a; [ \"\$a\" = y ] && '$S/claude-agents-kill.sh' {1} '$STAGE')+reload('$list')" \
      --bind="alt-b:execute('$S/claude-agents-broadcast.sh')" \
      --bind="esc:execute-silent('$S/claude-agents-quit.sh' --tap '$STAGE')+abort" \
      --bind="ctrl-g:execute-silent('$S/claude-agents-goto.sh' {1})"
  else
    # ---- popup / plain mode: read-only preview on the right ----------------
    "$list" | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=2 \
      --prompt='agents ❯ ' \
      --header='enter/tab: go to pane   ctrl-x: close pane   ctrl-o: open beside list   ctrl-b: broadcast   ctrl-r: refresh' \
      --preview="tmux capture-pane -ep -t {1} 2>/dev/null" \
      --preview-window='right,62%,follow,border-left' \
      --bind="load:reload-sync(sleep 1; '$list')+refresh-preview" \
      --bind="ctrl-r:reload('$list')+refresh-preview" \
      --bind="ctrl-/:toggle-preview" \
      --bind="ctrl-x:execute(printf 'close agent %s? [y/N] ' {2}; read -r a; [ \"\$a\" = y ] && '$S/claude-agents-kill.sh' {1})+reload('$list')+refresh-preview" \
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
