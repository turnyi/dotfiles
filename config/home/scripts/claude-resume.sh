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
#   claude-resume.sh --mark-pane [%pane]  toggle ★ on the conversation running
#                                         in a pane (bound to prefix b)
#
# ctrl-g inside the picker flips to the live-agents view (claude-agents.sh),
# whose ctrl-o flips back — one palette, two views.
#
# ctrl-b in the picker toggles a ★ on the highlighted conversation (instant,
# no prompt). ctrl-f opens the ★ menu (also `--marks-popup`: C-b / prefix B):
# a harpoon-style numbered list — 1-9 resume a slot instantly, j/k move,
# s bookmarks the pane the menu was opened from, r sets a searchable label,
# d un-bookmarks. Bookmarks live in ~/.claude/bookmarks.tsv keyed by session
# id, so they survive dir moves/deletions like everything else.
set -u

PROJECTS="$HOME/.claude/projects"
BOOKMARKS="$HOME/.claude/bookmarks.tsv"
SELF="$(readlink -f "$0")"

encode_dir() { printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g'; }

# One line per session, newest first, tab-separated:
#   1 session-id  2 cwd  3 jsonl path  4 date  5 dir (display)  6 branch  7 title
# One session row (fields 1-7) built from a transcript file; prints nothing
# for files that aren't conversation transcripts.
session_row() {
  local f="$1" id cwd branch title ts when
  id="${f##*/}"; id="${id%.jsonl}"
  # most recent cwd from the tail; fall back to the launch cwd in the head
  cwd=$(tail_chunk "$f" | grep -ao '"cwd":"[^"]*"' | tail -1 | cut -d'"' -f4)
  [ -n "$cwd" ] || cwd=$(head -c 65536 "$f" | grep -ao '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -n "$cwd" ] || return 0 # not a conversation transcript
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
  # Left column = time of the LAST message (received or sent): the final
  # "timestamp" in the transcript, shown in local time. Fall back to the file
  # mtime only if no timestamp parses.
  ts=$(tail_chunk "$f" | grep -ao '"timestamp":"[^"]*"' | tail -1 | cut -d'"' -f4)
  when=$(date -d "$ts" '+%m-%d %H:%M' 2>/dev/null) || when=$(date -r "$f" '+%m-%d %H:%M')
  printf '%s\t%s\t%s\t%s\t%-34.34s\t%-20.20s\t%s\n' \
    "$id" "$cwd" "$f" "$when" \
    "${cwd/#$HOME/\~}" "${branch:-–}" "${title:-(no title)}"
}

list() {
  local f
  # ls -t orders by file mtime, which the OS bumps on every append to the
  # transcript — so this IS "latest message first", and it streams into fzf
  # instantly (no sort barrier that would blank the popup while it loads).
  # resume() uses `cp -p` so relocated sessions keep their real last-message time.
  ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null | while IFS= read -r f; do
    session_row "$f"
  done | awk -F'\t' '!seen[$1]++' | decorate # resume() copies transcripts across project dirs; show each session once
}

# Prefix bookmarked sessions' title column with a yellow ★ (and the label, if
# any). The ★/label are real match text for fzf (--ansi strips color before
# matching), which is what makes ctrl-f's ★-query filter and label search work.
decorate() {
  [ -s "$BOOKMARKS" ] || { cat; return; }
  awk -F'\t' -v OFS='\t' '
    FILENAME != "-" { if ($1 != "") bm[$1] = $2; next }
    $1 in bm { $7 = "\033[1;33m★" (bm[$1] != "" ? " [" bm[$1] "]" : "") "\033[0m " $7 }
    { print }
  ' "$BOOKMARKS" -
}

# Bookmarks joined with live session data, in bookmark-file order (stable
# "slots" like harpoon), with a slot number appended as field 8. Reads ONLY
# the bookmarked transcripts (newest copy of each) — never the full session
# scan, so the ★ menu opens instantly no matter how many conversations exist.
marks_list() {
  [ -s "$BOOKMARKS" ] || return 0
  local id label f
  while IFS=$'\t' read -r id label; do
    [ -n "$id" ] || continue
    f=$(ls -t "$PROJECTS"/*/"$id.jsonl" 2>/dev/null | head -1)
    [ -n "$f" ] && session_row "$f"
  done <"$BOOKMARKS" | decorate \
    | awk -F'\t' -v OFS='\t' '{ print $0, "\033[1;35m" NR "\033[0m" }'
}

# Quick-menu rows: "id cwd file display" where display is just the slot
# number + the label you set (falling back to the conversation's AI title).
quick_list() {
  [ -s "$BOOKMARKS" ] || return 0
  local id label f cwd n=0
  while IFS=$'\t' read -r id label; do
    [ -n "$id" ] || continue
    f=$(ls -t "$PROJECTS"/*/"$id.jsonl" 2>/dev/null | head -1)
    [ -n "$f" ] || continue
    if [ -z "$label" ]; then
      label=$(tail_chunk "$f" | grep -ao '"aiTitle":"[^"]*"' | tail -1 | cut -d'"' -f4)
      [ -n "$label" ] || label="(no title)"
    fi
    cwd=$(tail_chunk "$f" | grep -ao '"cwd":"[^"]*"' | tail -1 | cut -d'"' -f4)
    [ -n "$cwd" ] || cwd=$(head -c 65536 "$f" | grep -ao '"cwd":"[^"]*"' | head -1 | cut -d'"' -f4)
    n=$((n + 1))
    printf '%s\t%s\t%s\t\033[1;35m%d\033[0m \033[1;33m★\033[0m %s\n' \
      "$id" "$cwd" "$f" "$n" "$label"
  done <"$BOOKMARKS"
}

# The C-b QUICK menu: a tiny popup with just numbered titles — harpoon-style.
# 1-9 open that slot, j/k and the arrow keys move, l/enter open, h/esc close.
quick() {
  local target="${1:-}" out key sel i digitbinds=()
  # plain digits work because typing is disabled; alt-digits for modifier
  # muscle memory (terminals cannot encode ctrl+digits at all)
  for i in 1 2 3 4 5 6 7 8 9; do
    digitbinds+=(--bind "$i:pos($i)+accept" --bind "alt-$i:pos($i)+accept")
  done
  out=$(quick_list | fzf --ansi --reverse --disabled \
    --delimiter '\t' --with-nth 4 \
    --prompt '★ ' --info=hidden --no-separator \
    --header '1-9/enter: open · C-c: window · C-\: vsplit · C--: hsplit · s: ★ pane · r: label · d/C-d: remove · f: full' \
    --expect=f,ctrl-c --expect='ctrl-\' --expect=ctrl-_ \
    --bind 'j:down,k:up,l:accept,h:abort' \
    "${digitbinds[@]}" \
    --bind "s:execute-silent($SELF --mark-here $target)+reload($SELF --quick-list)" \
    --bind "r:execute($SELF --relabel {1})+reload($SELF --quick-list)" \
    --bind "d:execute-silent($SELF --unmark {1})+reload($SELF --quick-list)" \
    --bind "ctrl-d:execute-silent($SELF --unmark {1})+reload($SELF --quick-list)") || return 0
  key="${out%%$'\n'*}"
  sel="${out#*$'\n'}"; [ "$sel" = "$out" ] && sel=""
  [ "$key" = f ] && exec "$SELF" --marks "$target"
  [ -n "$sel" ] || return 0
  open_sel "$key" "$sel" "$target"
}

# Shared open router for the bookmark menus. Ctrl + the tmux bind keys:
# C-c = new window, C-\ = vertical split, C-- = horizontal split (arrives as
# ctrl-_ — terminals encode ctrl+minus that way).
# enter/1-9/alt-1-9 = smart (jump to the running pane, else replace origin).
open_sel() {
  local key="$1" sel="$2" target="$3" id cwd f
  id=$(cut -f1 <<<"$sel"); cwd=$(cut -f2 <<<"$sel"); f=$(cut -f3 <<<"$sel")
  case "$key" in
    ctrl-c)    resume "$id" "$cwd" "$f" "$target" window ;;
    "ctrl-\\") resume "$id" "$cwd" "$f" "$target" vsplit ;;
    ctrl-_)    resume "$id" "$cwd" "$f" "$target" hsplit ;;
    *)         open_smart "$id" "$cwd" "$f" "$target" ;;
  esac
}

# The ★ menu: fzf with --disabled (typing does not search), so plain keys are
# free to act as controls — harpoon-style. 1-9 resume that slot instantly,
# j/k move, l/enter resume, d un-bookmarks, h flips back to the full picker.
marks() {
  local target="${1:-}" out key sel i digitbinds=()
  for i in 1 2 3 4 5 6 7 8 9; do
    digitbinds+=(--bind "$i:pos($i)+accept" --bind "alt-$i:pos($i)+accept")
  done
  out=$(marks_list | fzf --ansi --reverse --disabled \
    --delimiter '\t' --with-nth 8,7,4,5,6 \
    --prompt '★ ❯ ' \
    --header '1-9/enter: open · C-c: window · C-\: vsplit · C--: hsplit · s: ★ pane · r: label · d/C-d: remove · h: all convos · ctrl-g: agents' \
    --expect=ctrl-g,h,ctrl-c --expect='ctrl-\' --expect=ctrl-_ \
    --bind 'j:down,k:up,l:accept' \
    "${digitbinds[@]}" \
    --bind "s:execute-silent($SELF --mark-here $target)+reload($SELF --marks-list)+refresh-preview" \
    --bind "r:execute($SELF --relabel {1})+reload($SELF --marks-list)+refresh-preview" \
    --bind "d:execute-silent($SELF --unmark {1})+reload($SELF --marks-list)+refresh-preview" \
    --bind "ctrl-d:execute-silent($SELF --unmark {1})+reload($SELF --marks-list)+refresh-preview" \
    --preview "$SELF --preview {3}" \
    --preview-window 'right,55%,wrap,<110(down,55%,wrap)') || return 0
  key="${out%%$'\n'*}"
  sel="${out#*$'\n'}"; [ "$sel" = "$out" ] && sel=""
  [ "$key" = h ] && exec "$SELF" --pick "$target"
  [ "$key" = ctrl-g ] && exec "$(dirname "$SELF")/claude-agents.sh" --popup
  [ -n "$sel" ] || return 0
  open_sel "$key" "$sel" "$target"
}

# Pane already running this session, if any: every claude pane's dir maps to
# its newest transcript (same heuristic as pane_session).
find_pane_for() {
  local id="$1" p cmd
  tmux list-panes -a -F $'#{pane_id}\t#{pane_current_command}' 2>/dev/null \
    | while IFS=$'\t' read -r p cmd; do
        [ "$cmd" = claude ] || continue
        [ "$(pane_session "$p" 2>/dev/null | cut -f1)" = "$id" ] || continue
        printf '%s\n' "$p"; break
      done
}

# Default open for a bookmark: jump to the pane already running it; otherwise
# take over the pane the menu was opened from ("here" mode in resume()).
open_smart() {
  local id="$1" cwd="$2" f="$3" target="$4" p
  p=$(find_pane_for "$id")
  [ -n "$p" ] && exec "$(dirname "$SELF")/claude-agents-goto.sh" "$p"
  resume "$id" "$cwd" "$f" "$target" here
}

# The conversation running in a tmux pane, as "id<TAB>file<TAB>title". The
# live session is the newest transcript under the pane dir's project folder —
# Claude appends to it on every message, so mtime wins even over
# resume-copies (cp -p keeps their old mtime).
pane_session() {
  local pane="$1" cwd f id title
  cwd="$(tmux display -p -t "$pane" '#{pane_current_path}' 2>/dev/null)"
  [ -n "$cwd" ] || return 1
  f=$(ls -t "$PROJECTS/$(encode_dir "$cwd")"/*.jsonl 2>/dev/null | head -1)
  [ -n "$f" ] || return 1
  id="${f##*/}"; id="${id%.jsonl}"
  title=$(tail_chunk "$f" | grep -ao '"aiTitle":"[^"]*"' | tail -1 | cut -d'"' -f4)
  printf '%s\t%s\t%s\n' "$id" "$f" "$title"
}

# Bookmark the conversation running in a tmux pane (prefix b / C-S-b).
mark_pane() {
  local pane sess id title
  pane="${1:-$(tmux display -p '#{pane_id}')}"
  if ! sess=$(pane_session "$pane"); then
    tmux display-message "no claude conversation found in $pane"
    return 0
  fi
  id=$(cut -f1 <<<"$sess")
  title=$(cut -f3 <<<"$sess")
  touch "$BOOKMARKS"
  if grep -q "^$id	" "$BOOKMARKS"; then
    grep -v "^$id	" "$BOOKMARKS" >"$BOOKMARKS.tmp"
    mv "$BOOKMARKS.tmp" "$BOOKMARKS"
    tmux display-message "★ removed: ${title:-$id}"
  else
    # label popup: the AI title shows as grey ghost text — enter accepts it,
    # typing replaces it, esc cancels. (run-shell has no tty, hence the popup.)
    tmux display-popup -E -w 64 -h 6 -T " ★ ${title:-bookmark} " \
      -b rounded -S 'fg=#e0af68' -s 'bg=default' \
      "$SELF --mark-add $id $(printf '%q' "$title")"
  fi
}

# One-line input box built on fzf so ESC actually cancels (a bare `read`
# just swallows escape). enter prints the typed text (exit 1 = no match, fine);
# esc exits 130 with no output — callers treat that as "don't bookmark".
# $1 (optional) shows as grey ghost text — the suggested label; callers use it
# when enter is pressed with nothing typed.
prompt_label() {
  local ghost=()
  [ -n "${1:-}" ] && ghost=(--ghost "$1")
  : | fzf --print-query --reverse --info=hidden --no-separator \
      "${ghost[@]}" \
      --prompt '★ label ❯ ' \
      --header 'enter: save · esc: cancel'
}

toggle_bookmark() {
  local id="$1" label
  touch "$BOOKMARKS"
  if grep -q "^$id	" "$BOOKMARKS"; then
    # no `&&`: grep -v exits 1 when the last bookmark is removed (empty output)
    grep -v "^$id	" "$BOOKMARKS" >"$BOOKMARKS.tmp"
    mv "$BOOKMARKS.tmp" "$BOOKMARKS"
  else
    # save instantly, no label prompt — add/edit a label with r in the ★ menu
    printf '%s\t\n' "$id" >>"$BOOKMARKS"
  fi
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
  local id="$1" cwd="$2" f="$3" target="${4:-}" mode="${5:-auto}" dir dest claude_bin cmd rcmd pane_cmd
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
    cp -p "$f" "$dest" # -p keeps mtime so the copy still sorts by its last message
  fi
  claude_bin="$(command -v claude || echo claude)"
  rcmd="$claude_bin --resume $id --dangerously-skip-permissions"
  if [ -z "$target" ]; then
    # invoked from a shell: take over this pane/terminal
    cd "$dir" && exec "$claude_bin" --resume "$id" --dangerously-skip-permissions
  fi
  case "$mode" in
    window)
      tmux new-window -c "$dir" -n "${dir##*/}" "$rcmd" ;;
    vsplit)
      tmux split-window -h -c "$dir" -t "$target" "$rcmd" ;;
    hsplit)
      tmux split-window -v -c "$dir" -t "$target" "$rcmd" ;;
    *)
      # here/auto. The pane the menu was opened in is only safe to send-keys
      # to if it's sitting at a shell prompt — if a program is running there,
      # the command would just be typed INTO that program.
      cmd="cd $(printf '%q' "$dir") && $rcmd"
      pane_cmd="$(tmux display -p -t "$target" '#{pane_current_command}' 2>/dev/null)"
      case "$pane_cmd" in
        bash|zsh|fish|sh|-bash|-zsh|-fish|-sh)
          tmux send-keys -t "$target" "$cmd" Enter 2>/dev/null \
            || tmux new-window -c "$dir" -n "${dir##*/}" "$rcmd" ;;
        *)
          if [ "$mode" = here ]; then
            # bookmark open: REPLACE whatever runs in this pane. Safe for a
            # claude pane — the conversation stays resumable from disk.
            tmux respawn-pane -k -t "$target" -c "$dir" "$rcmd" \
              || tmux new-window -c "$dir" -n "${dir##*/}" "$rcmd"
          else
            tmux new-window -c "$dir" -n "${dir##*/}" "$rcmd"
          fi ;;
      esac ;;
  esac
}

pick() {
  local target="${1:-}" out key sel
  # Tab cycles the search scope (which columns typing filters on): ALL → DIR →
  # TITLE → ALL. --nth picks the searched fields; the header mirrors the scope.
  # Fields: 2=cwd(full path) 6=branch 7=title. Ordering stays newest-first.
  out=$(list | fzf --ansi --reverse \
    --delimiter '\t' --with-nth 4,5,6,7 \
    --nth 2,6,7 \
    --prompt 'resume ❯ ' \
    --header 'search ▸ ALL (dir · branch · title) · tab: scope · enter: resume · ctrl-b: ★ mark · ctrl-f: ★ menu · ctrl-g: agents' \
    --expect=ctrl-g,ctrl-f \
    --bind "tab:change-nth(2|7|2,6,7)+transform-header($SELF --scope-header)" \
    --bind "ctrl-b:execute-silent($SELF --toggle-bookmark {1})+reload($SELF --list)+refresh-preview" \
    --preview "$SELF --preview {3}" \
    --preview-window 'right,55%,wrap,<110(down,55%,wrap)') || return 0
  key="${out%%$'\n'*}"
  sel="${out#*$'\n'}"; [ "$sel" = "$out" ] && sel=""
  # flip to the live-agents view or the ★ bookmarks menu of the same palette
  [ "$key" = ctrl-g ] && exec "$(dirname "$SELF")/claude-agents.sh" --popup
  [ "$key" = ctrl-f ] && exec "$SELF" --marks "$target"
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
  --scope-header)
    # header text mirroring the live --nth search scope (Tab-cycled in pick()).
    # fzf exports the current --nth as $FZF_NTH before running this.
    case "${FZF_NTH:-}" in
      2)   printf '%s' 'search ▸ DIR · tab: scope · enter: resume · ctrl-b: ★ mark · ctrl-f: ★ menu · ctrl-g: agents' ;;
      7)   printf '%s' 'search ▸ TITLE · tab: scope · enter: resume · ctrl-b: ★ mark · ctrl-f: ★ menu · ctrl-g: agents' ;;
      *)   printf '%s' 'search ▸ ALL (dir · branch · title) · tab: scope · enter: resume · ctrl-b: ★ mark · ctrl-f: ★ menu · ctrl-g: agents' ;;
    esac
    ;;
  --toggle-bookmark)
    toggle_bookmark "$2"
    ;;
  --mark-pane)
    mark_pane "${2:-}"
    ;;
  --mark-add)
    # runs inside the prefix-b / C-S-b popup. Empty query + enter = accept the
    # ghost suggestion (the AI title); rc>1 = esc or no tty — don't save.
    id="$2"; suggest="${3:-}"
    label=$(prompt_label "$suggest"); [ $? -gt 1 ] && exit 0
    [ -n "$label" ] || label="$suggest"
    printf '%s\t%s\n' "$id" "$label" >>"$BOOKMARKS"
    tmux display-message "★ bookmarked${label:+ [$label]}"
    ;;
  --quick-popup)
    # C-b: small centered popup, sized to the number of bookmarks
    target="$(tmux display -p '#{pane_id}')"
    n=$(grep -c . "$BOOKMARKS" 2>/dev/null) || n=0
    h=$((n + 5)); [ "$h" -lt 7 ] && h=7; [ "$h" -gt 20 ] && h=20
    exec tmux display-popup -E -w 64 -h "$h" -T ' ★ bookmarks ' \
      -b rounded -S 'fg=#e0af68' -s 'bg=default' "$SELF --quick $target"
    ;;
  --quick)
    quick "${2:-$(tmux display -p '#{pane_id}' 2>/dev/null)}"
    ;;
  --quick-list)
    quick_list
    ;;
  --marks-popup)
    # standalone ★ menu (prefix B): same styling as the C-o popup
    target="$(tmux display -p '#{pane_id}')"
    exec tmux display-popup -E -w 88% -h 82% -T ' ★ bookmarks ' \
      -b rounded -S 'fg=#e0af68' -s 'bg=default' "$SELF --marks $target"
    ;;
  --quick-popup)
    # compact ★ menu (C-b): small centered popup, built for 1-9 fast jumps
    target="$(tmux display -p '#{pane_id}')"
    exec tmux display-popup -E -w 64% -h 50% -T ' ★ bookmarks ' \
      -b rounded -S 'fg=#e0af68' -s 'bg=default' "$SELF --marks $target"
    ;;
  --marks)
    marks "${2:-$(tmux display -p '#{pane_id}' 2>/dev/null)}"
    ;;
  --marks-list)
    marks_list
    ;;
  --mark-here)
    # s in the ★ menu: instantly bookmark the session of the pane the menu
    # was opened from
    if ! sess=$(pane_session "${2:-}"); then
      tmux display-message "no claude conversation found in that pane"
      exit 0
    fi
    id=$(cut -f1 <<<"$sess")
    touch "$BOOKMARKS"
    if grep -q "^$id	" "$BOOKMARKS"; then
      tmux display-message "★ already bookmarked"
      exit 0
    fi
    printf '%s\t\n' "$id" >>"$BOOKMARKS"
    tmux display-message "★ bookmarked: $(cut -f3 <<<"$sess")"
    ;;
  --relabel)
    # r in the ★ menu: set/replace the searchable label of a bookmark.
    # Runs inside fzf execute(), so prompt_label has the popup's tty;
    # rc>1 = esc or no tty — keep the existing label.
    id="$2"
    touch "$BOOKMARKS"
    grep -q "^$id	" "$BOOKMARKS" || exit 0
    # ghost = current label, or the AI title when unlabeled; enter keeps it
    suggest=$(grep -m1 "^$id	" "$BOOKMARKS" | cut -f2)
    if [ -z "$suggest" ]; then
      f=$(ls "$PROJECTS"/*/"$id.jsonl" 2>/dev/null | head -1)
      [ -n "$f" ] && suggest=$(tail_chunk "$f" | grep -ao '"aiTitle":"[^"]*"' | tail -1 | cut -d'"' -f4)
    fi
    label=$(prompt_label "$suggest"); [ $? -gt 1 ] && exit 0
    [ -n "$label" ] || label="$suggest"
    awk -F'\t' -v OFS='\t' -v id="$id" -v l="$label" \
      '$1 == id { $2 = l } { print }' "$BOOKMARKS" >"$BOOKMARKS.tmp"
    mv "$BOOKMARKS.tmp" "$BOOKMARKS"
    ;;
  --unmark)
    # remove only (d in the ★ menu) — never prompts
    touch "$BOOKMARKS"
    grep -v "^$2	" "$BOOKMARKS" >"$BOOKMARKS.tmp"
    mv "$BOOKMARKS.tmp" "$BOOKMARKS"
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
