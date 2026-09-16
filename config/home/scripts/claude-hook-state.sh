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
#   @claude_tasks        "done/total" of the session's task list
#
# Per-session files under $XDG_RUNTIME_DIR/claude-fleet/ feed the fleet card:
#   tasks/<session>.json    {"<id>": {"subject", "status"}} from TaskCreate/TaskUpdate/TodoWrite
#   actions/<session>.log   "<epoch>\t<tool>\t<detail>" per tool call, last 60 kept
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

FLEET_RUN="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-fleet"
SUBS_ROOT="$FLEET_RUN/subs"
TASKS="$FLEET_RUN/tasks/$session.json"
ACTIONS="$FLEET_RUN/actions/$session.log"

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

log_action() {
  local detail
  detail="$(printf '%s' "$payload" | jq -r '.tool_input | (.file_path // .command // .pattern // .description // .subject // .prompt // .url // .query // (if .taskId then "#\(.taskId) \(.status // "")" else "" end)) | tostring' 2>/dev/null | one_line | head -c 100)"
  mkdir -p "$(dirname "$ACTIONS")"
  printf '%s\t%s\t%s\n' "$now" "$tool" "$detail" >>"$ACTIONS"
  [ "$(wc -l <"$ACTIONS")" -gt 80 ] && { tail -60 "$ACTIONS" >"$ACTIONS.tmp" && mv -f "$ACTIONS.tmp" "$ACTIONS"; }
  return 0
}

tasks_set() {
  local id="$1" subject="$2" status="$3"
  mkdir -p "$(dirname "$TASKS")"
  [ -s "$TASKS" ] || echo '{}' >"$TASKS"
  jq -c --arg id "$id" --arg subject "$subject" --arg status "$status" \
    '.[$id] = ((.[$id] // {}) + (if $subject != "" then {subject: $subject} else {} end) + (if $status != "" then {status: $status} else {} end))' \
    "$TASKS" >"$TASKS.tmp" 2>/dev/null && mv -f "$TASKS.tmp" "$TASKS"
}

stamp_tasks() {
  [ -s "$TASKS" ] || return 0
  local summary current
  summary="$(jq -r '[.[] | .status] | "\(map(select(. == "completed")) | length)/\(length)"' "$TASKS" 2>/dev/null)"
  current="$(jq -r '[.[] | select(.status == "in_progress") | .subject][0] // ""' "$TASKS" 2>/dev/null | one_line)"
  setp @claude_tasks "$summary"
  if [ -n "$current" ] && [ "$current" != "$(getp @claude_task)" ]; then
    setp @claude_task "$current"
    setp @claude_task_since "$now"
  fi
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
             @claude_task @claude_task_since @claude_subs @claude_sub_names @claude_last @claude_tasks; do
      unsetp "$o"
    done
    rm -rf "$SUBS_ROOT/$session" "$TASKS" "$ACTIONS" 2>/dev/null
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
    log_action
    case "$tool" in
      AskUserQuestion | ExitPlanMode) state=asking ;;
      TodoWrite)
        mkdir -p "$(dirname "$TASKS")"
        printf '%s' "$payload" | jq -c '[.tool_input.todos[]?] | to_entries | map({key: ("todo-" + (.key|tostring)), value: {subject: (.value.activeForm // .value.content), status: .value.status}}) | from_entries' >"$TASKS" 2>/dev/null
        stamp_tasks
        state=working
        ;;
      TaskUpdate)
        tasks_set "$(field .tool_input.taskId)" "$(field .tool_input.subject | one_line)" "$(field .tool_input.status)"
        stamp_tasks
        state=working
        ;;
      *) state=working ;;
    esac
    ;;
  PostToolUse)
    [ "$tool" = TaskCreate ] || exit 0
    created="$(printf '%s' "$payload" | jq -r '.tool_response | if type == "string" then . else (.content // .result // .text // tostring) end | tostring' 2>/dev/null | grep -oE 'Task #[0-9]+ created successfully: [^"}]*' | head -1)"
    id="$(printf '%s' "$created" | grep -oE '#[0-9]+' | tr -d '#')"
    subject="$(printf '%s' "$created" | sed -E 's/^Task #[0-9]+ created successfully: //' | one_line)"
    [ -n "$subject" ] || subject="$(field .tool_input.subject | one_line)"
    [ -n "$id" ] || id="new-$now"
    tasks_set "$id" "$subject" "pending"
    stamp_tasks
    exit 0
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
