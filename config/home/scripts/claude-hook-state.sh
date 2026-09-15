#!/usr/bin/env bash
# claude-hook-state.sh — record what a Claude Code pane is doing, on the pane.
#
# Wired to Claude Code hooks (see ~/.claude/settings.json). Every hook fires
# inside the claude process, where $TMUX_PANE names the pane, so the state can
# be stamped straight onto the pane as a tmux user option:
#
#   @claude_state        working | asking | blocked | done
#   @claude_state_since  epoch seconds the pane entered that state
#
# claude-window-status.sh and claude-agents-list.sh read those options out of
# the list-panes format string they already run, which is both cheaper and more
# truthful than inferring state from the pane title and /proc.
#
# States that want you (asking, blocked) also raise a desktop notification and
# force an immediate status repaint, because status-interval is 5s and a
# question should not sit invisible that long.
set -u

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

payload="$(cat)"
event="$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)"

prev="$(tmux show-option -qvp -t "$TMUX_PANE" @claude_state 2>/dev/null)"

case "$event" in
  UserPromptSubmit) state=working ;;
  Stop)             state=done ;;
  PreToolUse)
    case "$tool" in
      AskUserQuestion | ExitPlanMode) state=asking ;;
      *)                              state=working ;;
    esac
    ;;
  Notification)
    # Notification fires both for a real permission prompt and merely because
    # the prompt sat idle for 60s. Only the former interrupts work, so treat it
    # as blocking only when the pane was mid-task; an idle done/asking pane
    # keeps whatever state it already had.
    [ "$prev" = working ] || exit 0
    state=blocked
    ;;
  *) exit 0 ;;
esac

[ "$state" = "$prev" ] && exit 0

tmux set-option -p -t "$TMUX_PANE" @claude_state "$state" 2>/dev/null
tmux set-option -p -t "$TMUX_PANE" @claude_state_since "$(date +%s)" 2>/dev/null

notify_file="${TMPDIR:-/tmp}/claude-notify${TMUX_PANE//%/.}"

close_notification() {
  local id
  id="$(cat "$notify_file" 2>/dev/null)" || return 0
  rm -f "$notify_file"
  [ -n "$id" ] || return 0
  gdbus call --session \
    --dest org.freedesktop.Notifications \
    --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.CloseNotification "$id" >/dev/null 2>&1
}

case "$state" in
  asking | blocked)
    loc="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}:#{window_index}.#{pane_index}' 2>/dev/null)"
    dir="$(basename "$(tmux display-message -p -t "$TMUX_PANE" '#{pane_current_path}' 2>/dev/null)")"
    if [ "$state" = asking ]; then
      title="Claude is asking · $loc"
      body="$dir — waiting on your answer"
    else
      title="Claude is blocked · $loc"
      body="$dir — needs permission"
    fi
    close_notification
    notify-send -p -u critical -a claude -i utilities-terminal "$title" "$body" \
      >"$notify_file" 2>/dev/null
    ;;
  *)
    close_notification
    ;;
esac

tmux refresh-client -S 2>/dev/null

exit 0
