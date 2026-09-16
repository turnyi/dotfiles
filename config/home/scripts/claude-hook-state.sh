#!/usr/bin/env bash
# claude-hook-state.sh — record what a Claude Code pane is doing, on the pane.
#
# Wired to Claude Code hooks (see ~/.claude/settings.json). Every hook fires
# inside the claude process, where $TMUX_PANE names the pane, so the state can
# be stamped straight onto the pane as tmux user options:
#
#   @claude_state        working | asking | blocked | done
#   @claude_state_since  epoch seconds the pane entered that state
#   @claude_session      session id
#   @claude_started      epoch seconds of the first prompt this session
#   @claude_budget       seconds the operator allowed ("budget 45m" in a prompt)
#   @claude_task         the todo item currently in progress
#   @claude_task_since   epoch seconds that item became current
#   @claude_subs         live subagent count
#   @claude_sub_names    their agent types, comma separated
#   @claude_last         first line of the last assistant message
#
# claude-window-status.sh, claude-agents-list.sh, claude-attention.sh and
# claude-fleet.sh read those options out of list-panes format strings, which is
# both cheaper and more truthful than inferring state from the pane title.
#
# Subagents are counted through files rather than a counter on the pane because
# SubagentStart/Stop hooks run async and concurrently; two increments racing on
# one option lose a subagent, two files never do.
#
# States that want you (asking, blocked) also raise a desktop notification and
# force an immediate status repaint, because status-interval is 5s and a
# question should not sit invisible that long.
set -u

[ -n "${TMUX_PANE:-}" ] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

payload="$(cat)"
field() { printf '%s' "$payload" | jq -r "$1 // empty" 2>/dev/null; }

event="$(field .hook_event_name)"
tool="$(field .tool_name)"
session="$(field .session_id)"
now="$(date +%s)"

SUBS_ROOT="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-fleet/subs"

setp() { tmux set-option -p -t "$TMUX_PANE" "$1" "$2" 2>/dev/null; }
getp() { tmux show-option -qvp -t "$TMUX_PANE" "$1" 2>/dev/null; }
unsetp() { tmux set-option -pu -t "$TMUX_PANE" "$1" 2>/dev/null; }

one_line() { tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//' | head -c 160; }

stamp_subs() {
  local dir="$SUBS_ROOT/$session" n names
  n=0; names=""
  if [ -d "$dir" ]; then
    n="$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')"
    names="$(cat "$dir"/* 2>/dev/null | sort | uniq -c | sort -rn |
      awk '{printf "%s%s%s", (NR>1?",":""), ($1>1?$1"×":""), $2}')"
  fi
  setp @claude_subs "$n"
  setp @claude_sub_names "$names"
}

parse_budget() {
  printf '%s' "$1" | grep -oiE '(budget|eta)[: ]+[0-9]+ ?(m|min|h|hr)' | head -1 |
    awk '{ v=$0; sub(/^[^0-9]*/, "", v); n=v+0; if (v ~ /h/) n*=3600; else n*=60; print n }'
}

state=""
case "$event" in
  SessionStart)
    setp @claude_session "$session"
    [ -n "$(getp @claude_started)" ] || setp @claude_started "$now"
    stamp_subs
    exit 0
    ;;
  SessionEnd)
    for o in @claude_state @claude_state_since @claude_session @claude_started @claude_budget \
             @claude_task @claude_task_since @claude_subs @claude_sub_names @claude_last; do
      unsetp "$o"
    done
    rm -rf "$SUBS_ROOT/$session" 2>/dev/null
    tmux refresh-client -S 2>/dev/null
    exit 0
    ;;
  UserPromptSubmit)
    state=working
    setp @claude_session "$session"
    [ -n "$(getp @claude_started)" ] || setp @claude_started "$now"
    budget="$(parse_budget "$(field .prompt)")"
    if [ -n "$budget" ] && [ "$budget" -gt 0 ]; then
      setp @claude_budget "$budget"
      setp @claude_started "$now"
    fi
    ;;
  Stop)
    state=done
    last="$(field .last_assistant_message | one_line)"
    [ -n "$last" ] && setp @claude_last "$last"
    ;;
  PreToolUse)
    case "$tool" in
      AskUserQuestion | ExitPlanMode) state=asking ;;
      TodoWrite)
        task="$(printf '%s' "$payload" |
          jq -r '[.tool_input.todos[]? | select(.status == "in_progress") | .activeForm // .content][0] // empty' 2>/dev/null |
          one_line)"
        if [ -n "$task" ] && [ "$task" != "$(getp @claude_task)" ]; then
          setp @claude_task "$task"
          setp @claude_task_since "$now"
        fi
        state=working
        ;;
      TaskCreate)
        task="$(field .tool_input.subject | one_line)"
        if [ -n "$task" ]; then
          setp @claude_task "$task"
          setp @claude_task_since "$now"
        fi
        state=working
        ;;
      *) state=working ;;
    esac
    ;;
  Notification)
    case "$(field .notification_type)" in
      permission_prompt) state=blocked ;;
      elicitation_dialog | agent_needs_input) state=asking ;;
      *) exit 0 ;;
    esac
    ;;
  SubagentStart)
    mkdir -p "$SUBS_ROOT/$session"
    printf '%s\n' "$(field .agent_type)" >"$SUBS_ROOT/$session/$(field .agent_id)"
    stamp_subs
    tmux refresh-client -S 2>/dev/null
    exit 0
    ;;
  SubagentStop)
    rm -f "$SUBS_ROOT/$session/$(field .agent_id)" 2>/dev/null
    stamp_subs
    tmux refresh-client -S 2>/dev/null
    exit 0
    ;;
  *) exit 0 ;;
esac

prev="$(getp @claude_state)"
[ "$state" = "$prev" ] && exit 0

setp @claude_state "$state"
setp @claude_state_since "$now"

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
