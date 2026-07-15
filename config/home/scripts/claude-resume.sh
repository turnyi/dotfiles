#!/usr/bin/env bash
# claude-resume.sh — global Claude Code conversation picker (C-o, no prefix).
#
# Claude stores sessions under ~/.claude/projects/<encoded-launch-dir>/, so a
# conversation started in a worktree becomes unreachable once that worktree is
# moved or deleted. This picker lists EVERY conversation across every project
# dir (searchable by directory, git branch and title), and on enter resumes it with
# --dangerously-skip-permissions in a new tmux window. If the original dir is
# gone, the session file is copied into the project folder of the dir we
# resume from, so orphaned sessions keep working.
#
#   claude-resume.sh            fzf picker (takes over the current terminal)
#   claude-resume.sh --popup    open the picker in a floating tmux popup (C-o);
#                               enter resumes in the pane C-o was pressed in
#   claude-resume.sh --pick [%pane]     picker body (runs inside the popup)
#   claude-resume.sh --list     print the session table (debugging)
#   claude-resume.sh --preview <file>   fzf preview helper
#
# ctrl-g inside the picker flips to the live-agents view (claude-agents.sh),
# whose ctrl-o flips back — one palette, two views.
set -u

PROJECTS="$HOME/.claude/projects"
SELF="$(readlink -f "$0")"

encode_dir() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g'; }

# One line per session, newest first, tab-separated:
#   1 session-id  2 cwd  3 jsonl path  4 date  5 dir (display)  6 branch  7 title
list() {
  local f id cwd branch title when
  ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null | while IFS= read -r f; do
    id="${f##*/}"; id="${id%.jsonl}"
    # most recent cwd from the tail; fall back to the launch cwd in the head
    cwd=$(tail_chunk "$f" | grep -ao '"cwd":"[^"]*"' | tail -1 | cut -d'"' -f4)
    [ -n "$cwd" ] || cwd=$(head -c 65536 "$f" | grep -ao '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
    [ -n "$cwd" ] || continue # not a conversation transcript
    # git branch the session was last on (same recency logic as cwd)
    branch=$(tail_chunk "$f" | grep -ao '"gitBranch":"[^"]*"' | tail -1 | cut -d'"' -f4)
    [ -n "$branch" ] || branch=$(head -c 65536 "$f" | grep -ao '"gitBranch":"[^"]*"' | head -1 | cut -d'"' -f4)
    # Prefer Claude's generated "ai-title" — that's the title shown at the bottom
    # of the terminal, so searching by what you see on screen actually matches.
    # Fall back to the first real user message for sessions with no title yet.
    title=$(tail_chunk "$f" | grep -ao '"aiTitle":"[^"]*"' | tail -1 | cut -d'"' -f4)
    [ -n "$title" ] || title=$(head -c 262144 "$f" | grep -ao '"aiTitle":"[^"]*"' | head -1 | cut -d'"' -f4)
    [ -n "$title" ] || title=$(head -c 262144 "$f" | jq -r '
      select(.type=="user" and ((.isSidechain? // false) | not))
      | .message.content
      | if type=="string" then . else ([.[] | select(.type=="text") | .text] | join(" ")) end
    ' 2>/dev/null | sed 's/^[[:space:]]*//' \
      | grep -av -e '^$' -e '^<' -e '^Caveat:' | head -1 | cut -c1-120)
    printf '%s\t%s\t%s\t%s\t%-34.34s\t%-20.20s\t%s\n' \
      "$id" "$cwd" "$f" "$(date -r "$f" '+%m-%d %H:%M')" \
      "${cwd/#$HOME/\~}" "${branch:-–}" "${title:-(no title)}"
  done | awk -F'\t' '!seen[$1]++' # resume() copies transcripts across project dirs; show each session once
}

# Last chunk of a jsonl file with the (possibly truncated) first line dropped,
# so jq never chokes on a line cut in half.
tail_chunk() {
  if [ "$(stat -c%s "$1")" -gt 262144 ]; then
    tail -c 262144 "$1" | sed '1d'
  else
    cat "$1"
  fi
}

preview() {
  local f="$1" cwd
  cwd=$(tail_chunk "$f" | grep -ao '"cwd":"[^"]*"' | tail -1 | cut -d'"' -f4)
  if [ -d "$cwd" ]; then
    printf 'dir: \033[32m%s\033[0m\n\n' "$cwd"
  else
    printf 'dir: \033[31m%s (gone — will resume via copy)\033[0m\n\n' "$cwd"
  fi
  tail_chunk "$f" | jq -r '
    select(.type=="user" or .type=="assistant")
    | select((.isSidechain? // false) | not)
    | .type as $t
    | (.message.content
       | if type=="string" then . else ([.[] | select(.type=="text") | .text] | join(" ")) end) as $x
    | select(($x | length) > 0 and ($x | startswith("<") | not))
    | (if $t=="user" then "[33m❯ " else "[36m● " end)
      + ($x | gsub("\\s+"; " ") | .[0:400]) + "[0m"
  ' 2>/dev/null | tail -40
}

# The session's dir was moved/deleted — let the user pick where to resume
# (projects + worktrees, like tmux-sessionizer).
pick_dir() {
  { find ~/Projects -mindepth 1 -maxdepth 1 -type d 2>/dev/null
    find ~ -maxdepth 1 -type d -name '*worktrees*' \
      -exec find {} -mindepth 1 -maxdepth 1 -type d \; 2>/dev/null
    # dirs other sessions live in (catches nested ones like Centinel/centinel-app)
    list | cut -f2 | while IFS= read -r d; do [ -d "$d" ] && printf '%s\n' "$d"; done
  } | sed "s|^$HOME|~|" | sort -u | fzf --reverse --prompt 'resume in ❯ ' \
        --header 'original dir is gone — pick where to resume this conversation'
}

resume() {
  local id="$1" cwd="$2" f="$3" target="${4:-}" dir dest claude_bin cmd
  dir="$cwd"
  # cwd may be from a `cd` late in the session; try the launch dir next
  [ -d "$dir" ] || dir=$(head -c 65536 "$f" | grep -ao '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
  if [ ! -d "$dir" ]; then
    dir="$(pick_dir)" || return 0
    dir="${dir/#\~/$HOME}"
    [ -d "$dir" ] || return 0
  fi
  # claude --resume only sees sessions stored under the current dir's project
  # folder — copy the transcript there if it isn't already
  dest="$PROJECTS/$(encode_dir "$dir")/$id.jsonl"
  if [ ! -f "$dest" ]; then
    mkdir -p "${dest%/*}"
    cp "$f" "$dest"
  fi
  claude_bin="$(command -v claude || echo claude)"
  if [ -n "$target" ]; then
    # popup mode. The pane C-o was pressed in is only safe to reuse if it's
    # sitting at a shell prompt — if a Claude session (or any program) is already
    # running there, send-keys would just type the command into THAT program
    # instead of launching the picked session. In that case open a fresh window.
    cmd="cd $(printf '%q' "$dir") && $claude_bin --resume $id --dangerously-skip-permissions"
    pane_cmd="$(tmux display -p -t "$target" '#{pane_current_command}' 2>/dev/null)"
    case "$pane_cmd" in
      bash|zsh|fish|sh|-bash|-zsh|-fish|-sh)
        tmux send-keys -t "$target" "$cmd" Enter 2>/dev/null \
          || tmux new-window -c "$dir" -n "${dir##*/}" \
               "$claude_bin --resume $id --dangerously-skip-permissions" ;;
      *)
        tmux new-window -c "$dir" -n "${dir##*/}" \
          "$claude_bin --resume $id --dangerously-skip-permissions" ;;
    esac
  else
    # invoked from a shell: take over this pane/terminal
    cd "$dir" && exec "$claude_bin" --resume "$id" --dangerously-skip-permissions
  fi
}

pick() {
  local target="${1:-}" out key sel
  out=$(list | fzf --ansi --reverse \
    --delimiter '\t' --with-nth 4,5,6,7 \
    --prompt 'resume ❯ ' \
    --header 'enter: resume (skip permissions) · ctrl-g: live agents · search dir, branch or title' \
    --expect=ctrl-g \
    --preview "$SELF --preview {3}" \
    --preview-window 'right,55%,wrap,<110(down,55%,wrap)') || return 0
  key="${out%%$'\n'*}"
  sel="${out#*$'\n'}"; [ "$sel" = "$out" ] && sel=""
  # flip to the live-agents view of the same palette (mission control)
  [ "$key" = ctrl-g ] && exec "$(dirname "$SELF")/claude-agents.sh" --popup
  [ -n "$sel" ] || return 0
  resume "$(cut -f1 <<<"$sel")" "$(cut -f2 <<<"$sel")" "$(cut -f3 <<<"$sel")" "$target"
}

case "${1:-}" in
  --popup)
    # bg=default keeps the popup cells transparent (popup-style is reset after
    # catppuccin in .tmux.conf), so kitty's opacity + Hyprland's blur show
    # through. Remember the pane C-o was pressed in: enter resumes there.
    target="$(tmux display -p '#{pane_id}')"
    exec tmux display-popup -E -w 88% -h 82% -T ' claude resume ' \
      -b rounded -S 'fg=#bb9af7' -s 'bg=default' "$SELF --pick $target"
    ;;
  --pick)
    # no explicit target (flipped over from the agents view): the pane under
    # the popup is the one C-g/C-o was pressed in
    pick "${2:-$(tmux display -p '#{pane_id}' 2>/dev/null)}"
    ;;
  --list)
    list
    ;;
  --preview)
    preview "$2"
    ;;
  *)
    pick
    ;;
esac
