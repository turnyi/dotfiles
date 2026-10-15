#!/usr/bin/env bash
# claude-auto-title.sh — keep a Claude Code session's name (and so its tmux pane
# title) in step with what the conversation is about now, not what it opened with.
#
# Wired to the UserPromptSubmit hook (synchronous: its stdout is the reply).
# Once every CLAUDE_AUTO_TITLE_INTERVAL seconds (default 1800) a Haiku call runs
# detached in the background and parks its answer in a pending file; the next
# prompt submits it as hookSpecificOutput.sessionTitle. Waiting on Haiku inline
# would stall every due prompt by ~3s.
set -euo pipefail

INTERVAL="${CLAUDE_AUTO_TITLE_INTERVAL:-1800}"
STATE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-fleet/titles"

generate() {
  local transcript="$1" current="$2" prompt="$3" pending="$4" recent title
  recent="$(jq -r 'select(.type == "user" and (.message.content | type) == "string")
      | .message.content | gsub("\\s+"; " ") | .[0:300]' "$transcript" 2>/dev/null | tail -n 8)"
  # --bare would be the obvious way to skip our own hooks, but it skips the
  # OAuth keychain too and fails "Not logged in"; dropping the user setting
  # source is what keeps this call from re-entering these hooks.
  title="$(
    printf 'Current session title: %s\n\nRecent user messages, oldest first:\n%s\n%s\n\n%s\n' \
      "$current" "$recent" "$prompt" \
      "Write a 3-6 word title for what this session is working on NOW. If the current title still fits, repeat it exactly. Output only the title, no quotes or punctuation at the end." |
      (cd "$STATE_DIR" &&
        env -u TMUX -u TMUX_PANE -u CLAUDE_CODE_PLUGIN_DIRS \
          claude -p --setting-sources project --model haiku --no-session-persistence --tools "") |
      head -n 1 | sed -E 's/^["'\''`]+|["'\''`.]+$//g' | cut -c 1-60
  )"
  [ -n "$title" ] && printf '%s' "$title" >"$pending"
}

if [ "${1:-}" = "--generate" ]; then
  shift
  generate "$@"
  exit 0
fi

payload="$(cat)"
session="$(jq -r '.session_id // empty' <<<"$payload")"
[ -n "$session" ] || exit 0
mkdir -p "$STATE_DIR"

due_file="$STATE_DIR/$session.due"
pending="$STATE_DIR/$session.pending"
now="$(date +%s)"
current="$(jq -r '.session_title // empty' <<<"$payload")"

if [ ! -f "$due_file" ]; then
  printf '%s' "$((now + INTERVAL))" >"$due_file"
elif [ "$now" -ge "$(cat "$due_file")" ]; then
  printf '%s' "$((now + INTERVAL))" >"$due_file"
  transcript="$(jq -r '.transcript_path // empty' <<<"$payload")"
  prompt="$(jq -r '.prompt // "" | gsub("\\s+"; " ") | .[0:300]' <<<"$payload")"
  [ -f "$transcript" ] &&
    setsid "$0" --generate "$transcript" "$current" "$prompt" "$pending" </dev/null >/dev/null 2>&1 &
fi

if [ -s "$pending" ]; then
  title="$(cat "$pending")"
  rm -f "$pending"
  [ "$title" != "$current" ] &&
    jq -nc --arg t "$title" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $t}}'
fi
exit 0
