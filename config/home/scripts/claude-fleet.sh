#!/usr/bin/env bash
# claude-fleet.sh — one row per worktree: who is on it, its PR, and what YOU do next.
#
#   claude-fleet.sh --popup          fzf dashboard (prefix F, or ctrl-f from the agents popup)
#   claude-fleet.sh --rows           the TSV rows the popup renders (key, sort, display)
#   claude-fleet.sh --preview KEY    right-hand pane for a row
#   claude-fleet.sh --refresh        drop the PR cache so the next --rows refetches
#
# Every column is computed by a program, never narrated by a model:
#   next     answer · approve · fix CI · triage review · merge · wait CI · open PR ·
#            review diff · reap · working · idle
#   session  @claude_* pane options stamped by claude-hook-state.sh, plus background
#            sessions from `claude agents --json`
#   PR       gh pr view, cached per branch for 90s and refreshed in the background so
#            the popup never blocks on the network
#   slot     centinel-slots.sh (dev-stack lock files)
#
# Repos scanned: every repo a live Claude session sits in, plus any listed one per
# line in ~/.config/claude-fleet/repos.
set -u

S="$(cd "$(dirname "$0")" && pwd)"
RUN="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-fleet"
PRCACHE="$RUN/pr"
BGCACHE="$RUN/bg.json"
PR_TTL=90
mkdir -p "$PRCACHE"

c_rst=$'\033[0m'; c_dim=$'\033[2;37m'; c_loc=$'\033[33m'
c_red=$'\033[1;31m'; c_mag=$'\033[1;35m'; c_cyan=$'\033[36m'; c_green=$'\033[32m'
c_yel=$'\033[33m'; c_orange=$'\033[38;5;215m'; c_bold=$'\033[1m'

now="$(date +%s)"
US=$'\x1f'

pad() {
  local str="$1" width="$2" vis
  vis="$(printf '%s' "$str" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' ')"
  printf '%s' "$str"
  [ "$vis" -lt "$width" ] && printf '%*s' "$((width - vis))" ''
  return 0
}

human() {
  local s=$1
  [ "$s" -lt 0 ] && s=0
  if   [ "$s" -lt 60 ];   then printf '%ss' "$s"
  elif [ "$s" -lt 3600 ]; then printf '%sm' "$((s / 60))"
  else                         printf '%sh%02dm' "$((s / 3600))" "$(((s % 3600) / 60))"
  fi
}

bg_sessions() {
  if [ ! -f "$BGCACHE" ] || [ "$((now - $(stat -c %Y "$BGCACHE")))" -gt 30 ]; then
    claude agents --json 2>/dev/null >"$BGCACHE.tmp" && mv -f "$BGCACHE.tmp" "$BGCACHE"
  fi
  jq -r '.[] | select(.kind == "background") | [.cwd, .name, .state // "", .status // "", .id // ""] | join("\u001f")' "$BGCACHE" 2>/dev/null
}

pane_fmt=$'#{pane_id}\x1f#{session_name}:#{window_index}.#{pane_index}\x1f#{pane_current_command}\x1f#{pane_current_path}\x1f#{@claude_state}\x1f#{@claude_state_since}\x1f#{@claude_started}\x1f#{@claude_budget}\x1f#{@claude_task}\x1f#{@claude_task_since}\x1f#{@claude_subs}\x1f#{@claude_sub_names}\x1f#{@claude_last}\x1f#{pane_title}'

panes() { tmux list-panes -a -F "$pane_fmt" 2>/dev/null | awk -F"$US" '$3 == "claude"'; }

title_state() {
  case "$(printf '%s' "$1" | head -c3 | xxd -p 2>/dev/null)" in
    e2a0* | e2a1* | e2a2* | e2a3*) echo working ;;
    *) echo done ;;
  esac
}

repo_root() { git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's#/\.git$##; s#/\.git/worktrees/.*$##'; }

repos() {
  {
    panes | cut -d"$US" -f4
    bg_sessions | cut -d"$US" -f1
    [ -f "$HOME/.config/claude-fleet/repos" ] && grep -v '^#' "$HOME/.config/claude-fleet/repos"
  } | while read -r d; do [ -d "$d" ] && repo_root "$d"; done | grep . | sort -u
}

worktrees() {
  repos | while read -r r; do
    git -C "$r" worktree list --porcelain 2>/dev/null |
      awk -v r="$r" '/^worktree /{p=$2} /^branch /{b=$2; sub("refs/heads/","",b)} /^$/{if(p){print r"\x1f"p"\x1f"b}; p="";b=""} END{if(p)print r"\x1f"p"\x1f"b}'
  done | sort -u -t$'\x1f' -k2,2
}

pr_file() { printf '%s/%s' "$PRCACHE" "$(printf '%s' "$1:$2" | md5sum | cut -c1-16)"; }

pr_fetch() {
  local wt="$1" branch="$2" f
  f="$(pr_file "$wt" "$branch")"
  (cd "$wt" && gh pr view "$branch" --json number,state,url,isDraft,reviewDecision,mergeStateStatus,statusCheckRollup,headRefOid,title 2>/dev/null) |
    jq -c '{n: .number, state: .state, url: .url, draft: .isDraft, review: .reviewDecision, merge: .mergeStateStatus, sha: .headRefOid, title: .title,
            ci: (if ([.statusCheckRollup[]? | select(.conclusion == "FAILURE" or .conclusion == "ERROR" or .conclusion == "TIMED_OUT" or .state == "FAILURE" or .state == "ERROR")] | length) > 0 then "fail"
                 elif ([.statusCheckRollup[]? | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or .state == "PENDING")] | length) > 0 then "pending"
                 elif ([.statusCheckRollup[]?] | length) == 0 then "none" else "pass" end)}' >"$f.tmp" 2>/dev/null
  if [ -s "$f.tmp" ]; then mv -f "$f.tmp" "$f"; else echo '{"n":null}' >"$f"; rm -f "$f.tmp"; fi
}

pr_get() {
  local wt="$1" branch="$2" f
  f="$(pr_file "$wt" "$branch")"
  if [ ! -f "$f" ] || [ "$((now - $(stat -c %Y "$f")))" -gt "$PR_TTL" ]; then
    [ -f "$f.lock" ] && [ "$((now - $(stat -c %Y "$f.lock")))" -lt 60 ] || {
      touch "$f.lock"
      ( pr_fetch "$wt" "$branch"; rm -f "$f.lock" ) >/dev/null 2>&1 &
    }
  fi
  [ -f "$f" ] && cat "$f" || echo '{"n":null,"stale":true}'
}

default_branch() {
  git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo staging
}

rows() {
  local pane_data bg_data wt_data
  pane_data="$(panes)"
  bg_data="$(bg_sessions)"
  wt_data="$(worktrees)"

  local seen_panes=""

  while IFS=$'\x1f' read -r repo wt branch; do
    [ -n "$wt" ] || continue
    local id="" loc="" path state since started budget task task_since subs sub_names last title
    local best="" bestlen=0
    while IFS=$'\x1f' read -r p_id p_loc _ p_path _rest; do
      case "$p_path" in
        "$wt" | "$wt"/*) if [ "${#wt}" -gt "$bestlen" ] || [ -z "$best" ]; then best="$p_id"; bestlen=${#wt}; fi ;;
      esac
    done <<<"$pane_data"
    state=""; since=""; started=""; budget=""; task=""; task_since=""; subs=""; sub_names=""; last=""; title=""
    if [ -n "$best" ]; then
      IFS=$'\x1f' read -r id loc _ path state since started budget task task_since subs sub_names last title \
        < <(printf '%s\n' "$pane_data" | awk -F"$US" -v p="$best" '$1 == p')
      seen_panes="$seen_panes $id"
      [ -n "$state" ] || state="$(title_state "$title")"
    fi

    local bg_name="" bg_state=""
    IFS=$'\x1f' read -r _ bg_name bg_state _ _ < <(printf '%s\n' "$bg_data" | awk -F"$US" -v w="$wt" 'index($1, w) == 1' | head -1)

    local dirty ahead base
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    base="$(default_branch "$repo")"
    ahead="$(git -C "$wt" rev-list --count "origin/$base..HEAD" 2>/dev/null || echo 0)"
    local is_main=0
    [ "$wt" = "$repo" ] && is_main=1

    local pr pr_n pr_state pr_ci pr_review pr_merge pr_draft
    pr='{"n":null}'
    [ "$is_main" = 0 ] && [ -n "$branch" ] && pr="$(pr_get "$wt" "$branch")"
    IFS=$'\x1f' read -r pr_n pr_state pr_ci pr_review pr_merge pr_draft < <(printf '%s' "$pr" | jq -r '[(.n // ""), (.state // ""), (.ci // ""), (.review // ""), (.merge // ""), (.draft // false)] | map(tostring) | join("\u001f")')

    local slot_row slot="" slot_alive="" slot_port=""
    slot_row="$("$S/centinel-slots.sh" --for "$wt" 2>/dev/null)"
    [ -n "$slot_row" ] && IFS=$'\t' read -r slot slot_alive slot_port <<<"$slot_row"

    local next prio
    if   [ "$state" = asking ] || [ "$bg_state" = blocked ] && [ -z "$id" ]; then next="answer"; prio=0
    elif [ "$state" = blocked ]; then next="approve"; prio=0
    elif [ "$pr_state" = OPEN ] && [ "$pr_ci" = fail ]; then next="fix CI"; prio=1
    elif [ "$pr_state" = OPEN ] && [ "$pr_review" = CHANGES_REQUESTED ]; then next="triage review"; prio=1
    elif [ "$pr_state" = OPEN ] && [ "$pr_ci" != pending ] && [ "$pr_merge" = CLEAN ] && [ "$pr_draft" != true ]; then next="merge"; prio=1
    elif [ "$pr_state" = OPEN ] && [ "$pr_ci" = pending ]; then next="wait CI"; prio=3
    elif [ "$pr_state" = MERGED ] && [ "$dirty" = 0 ] && [ "$is_main" = 0 ]; then next="reap"; prio=2
    elif [ "$state" = working ]; then next="working"; prio=3
    elif [ -n "$id" ] && [ "$dirty" -gt 0 ] && [ "$is_main" = 0 ]; then next="review diff"; prio=2
    elif [ -z "$pr_n" ] && [ "$ahead" -gt 0 ] && [ "$is_main" = 0 ]; then next="open PR"; prio=2
    elif [ -n "$id" ]; then next="idle"; prio=4
    else next="—"; prio=5
    fi

    local ncol
    case "$next" in
      answer|approve) ncol="$c_red" ;;
      "fix CI"|"triage review") ncol="$c_orange" ;;
      merge|"open PR"|"review diff"|reap) ncol="$c_mag" ;;
      working) ncol="$c_cyan" ;;
      *) ncol="$c_dim" ;;
    esac

    local prcol=""
    if [ -n "$pr_n" ]; then
      local ci_glyph
      case "$pr_ci" in pass) ci_glyph="${c_green}✔${c_rst}" ;; fail) ci_glyph="${c_red}✘${c_rst}" ;; pending) ci_glyph="${c_yel}◌${c_rst}" ;; *) ci_glyph="${c_dim}·${c_rst}" ;; esac
      case "$pr_state" in
        MERGED) prcol="#$pr_n ${c_mag}merged${c_rst}" ;;
        CLOSED) prcol="#$pr_n ${c_dim}closed${c_rst}" ;;
        *) prcol="#$pr_n $ci_glyph"
           [ "$pr_draft" = true ] && prcol="$prcol ${c_dim}draft${c_rst}"
           [ "$pr_review" = CHANGES_REQUESTED ] && prcol="$prcol ${c_orange}changes${c_rst}"
           [ "$pr_review" = APPROVED ] && prcol="$prcol ${c_green}approved${c_rst}"
           [ "$pr_merge" = CLEAN ] && prcol="$prcol ${c_green}ready${c_rst}"
           [ "$pr_merge" = DIRTY ] && prcol="$prcol ${c_red}conflict${c_rst}" ;;
      esac
    elif [ "$ahead" -gt 0 ] && [ "$is_main" = 0 ]; then prcol="${c_dim}+$ahead no PR${c_rst}"
    else prcol="${c_dim}—${c_rst}"
    fi
    [ "$dirty" -gt 0 ] && prcol="$prcol ${c_yel}~$dirty${c_rst}"

    local sess=""
    if [ -n "$id" ]; then
      local age=$((now - ${since:-$now}))
      case "$state" in
        asking)  sess="${c_mag}? asking $(human $age)${c_rst}" ;;
        blocked) sess="${c_red}! blocked $(human $age)${c_rst}" ;;
        working) sess="${c_cyan}● $(human $age)${c_rst}" ;;
        *)       sess="${c_green}✓ idle $(human $age)${c_rst}" ;;
      esac
      if [ -n "$budget" ] && [ -n "$started" ]; then
        local used=$((now - started)) bcol="$c_dim"
        [ "$used" -gt "$budget" ] && bcol="$c_red"
        sess="$sess ${bcol}$(human $used)/$(human "$budget")${c_rst}"
      fi
      case "$subs" in ''|0) ;; *) sess="$sess ${c_orange}↳$subs${c_rst}" ;; esac
    elif [ -n "$bg_name" ]; then
      sess="${c_dim}bg${c_rst} ${bg_state:+${c_red}$bg_state${c_rst}}"
    else
      sess="${c_dim}no session${c_rst}"
    fi
    [ -n "$slot" ] && { [ "$slot_alive" = 1 ] && sess="$sess ${c_yel}⧉$slot${c_rst}" || sess="$sess ${c_dim}⧉$slot↓${c_rst}"; }

    local what
    if [ "$state" = working ] && [ -n "$task" ]; then what="$task"
    elif [ -n "$last" ]; then what="$last"
    elif [ -n "$title" ]; then what="$(printf '%s' "$title" | sed -E 's/^[^ ]+[[:space:]]+//')"
    elif [ -n "$bg_name" ]; then what="$bg_name"
    else what="$(git -C "$wt" log -1 --format=%s 2>/dev/null)"
    fi

    local name; name="$(basename "$wt")"
    [ "$is_main" = 1 ] && name="$name ${c_dim}(main)${c_rst}"

    printf '%s\t%s\t%s %s %s %s %s%s%s\n' \
      "${id:-$wt}" "$prio" \
      "$(pad "${ncol}${next}${c_rst}" 13)" \
      "$(pad "${c_loc}${name}${c_rst}" 24)" \
      "$(pad "$prcol" 26)" "$(pad "$sess" 22)" \
      "$c_dim" "$(printf '%s' "$what" | head -c 70)" "$c_rst"
  done <<<"$wt_data"

  while IFS=$'\x1f' read -r id loc _ path state since started budget task task_since subs sub_names last title; do
    [ -n "$id" ] || continue
    case " $seen_panes " in *" $id "*) continue ;; esac
    [ -n "$state" ] || state="$(title_state "$title")"
    local age=$((now - ${since:-$now})) sess prio next ncol
    case "$state" in
      asking)  next="answer"; prio=0; ncol="$c_red"; sess="${c_mag}? asking $(human $age)${c_rst}" ;;
      blocked) next="approve"; prio=0; ncol="$c_red"; sess="${c_red}! blocked $(human $age)${c_rst}" ;;
      working) next="working"; prio=3; ncol="$c_cyan"; sess="${c_cyan}● $(human $age)${c_rst}" ;;
      *)       next="idle"; prio=4; ncol="$c_dim"; sess="${c_green}✓ idle $(human $age)${c_rst}" ;;
    esac
    printf '%s\t%s\t%s %s %s %s %s%s%s\n' \
      "$id" "$prio" "$(pad "${ncol}${next}${c_rst}" 13)" "$(pad "${c_loc}$(basename "$path")${c_rst}" 24)" \
      "$(pad "${c_dim}—${c_rst}" 26)" "$(pad "$sess" 22)" "$c_dim" "$(printf '%s' "${last:-$(printf '%s' "$title" | sed -E 's/^[^ ]+[[:space:]]+//')}" | head -c 70)" "$c_rst"
  done <<<"$pane_data"

  while IFS=$'\x1f' read -r cwd bname bstate bstatus bid; do
    [ -n "$bid" ] || continue
    local next prio ncol sess
    if [ "$bstate" = blocked ]; then next="answer"; prio=0; ncol="$c_red"; sess="${c_red}! bg blocked${c_rst}"
    elif [ "$bstatus" = busy ]; then next="working"; prio=3; ncol="$c_cyan"; sess="${c_cyan}● bg${c_rst}"
    else next="idle"; prio=4; ncol="$c_dim"; sess="${c_green}✓ bg idle${c_rst}"
    fi
    printf '%s\t%s\t%s %s %s %s %s%s%s\n' \
      "bg:$bid" "$prio" "$(pad "${ncol}${next}${c_rst}" 13)" "$(pad "${c_loc}$(basename "$cwd") ${c_dim}bg${c_rst}" 24)" \
      "$(pad "${c_dim}—${c_rst}" 26)" "$(pad "$sess" 22)" "$c_dim" "$(printf '%s' "$bname" | head -c 70)" "$c_rst"
  done <<<"$bg_data"
}

sorted_rows() { rows | sort -s -t$'\t' -k2,2n; }

preview() {
  local key="$1"
  case "$key" in
    %*) tmux capture-pane -ep -t "$key" 2>/dev/null; return ;;
    bg:*) claude logs "${key#bg:}" 2>/dev/null | tail -40; return ;;
  esac
  [ -d "$key" ] || return 0
  local branch; branch="$(git -C "$key" branch --show-current 2>/dev/null)"
  printf '\033[1m%s\033[0m  \033[35m%s\033[0m\n\n' "$key" "$branch"
  local f; f="$(pr_file "$key" "$branch")"
  if [ -f "$f" ]; then
    jq -r 'select(.n != null) | "PR #\(.n)  \(.state)  ci=\(.ci)  review=\(.review)  merge=\(.merge)\n\(.title)\n\(.url)\n"' "$f" 2>/dev/null
  fi
  git -C "$key" -c color.ui=always status --short 2>/dev/null | head -15
  echo
  git -C "$key" -c color.ui=always log --oneline -8 2>/dev/null
}

goto() {
  local key="$1"
  case "$key" in
    %*) exec "$S/claude-agents-goto.sh" "$key" ;;
    bg:*) tmux new-window "claude attach ${key#bg:}"; return ;;
  esac
  [ -d "$key" ] || exit 0
  tmux new-window -c "$key" "claude --continue || claude"
}

open_pr() {
  local key="$1" dir
  case "$key" in %*) dir="$(tmux display -p -t "$key" '#{pane_current_path}')" ;; *) dir="$key" ;; esac
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  gh pr view --web >/dev/null 2>&1 </dev/null
  true
}

reap() {
  local key="$1"
  case "$key" in %*) return 0 ;; esac
  local repo; repo="$(repo_root "$key")"
  printf 'reap worktree %s? [y/N] ' "$key"; read -r a; [ "$a" = y ] || return 0
  if [ -x "$repo/scripts/worktree-remove.sh" ]; then
    (cd "$repo" && ./scripts/worktree-remove.sh "$key" --yes)
  else
    git -C "$repo" worktree remove "$key"
  fi
  read -r -p 'enter to continue' _
}

case "${1:-}" in
  --rows) sorted_rows ;;
  --preview) preview "${2:-}" ;;
  --refresh) rm -f "$PRCACHE"/* "$BGCACHE"; sorted_rows ;;
  --goto) goto "${2:-}" ;;
  --open-pr) open_pr "${2:-}" ;;
  --reap) reap "${2:-}" ;;
  --popup | "")
    self="$S/claude-fleet.sh"
    out="$("$self" --rows | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=3 \
      --prompt='fleet ❯ ' \
      --header="$(printf '%-13s %-24s %-25s %-21s %s' NEXT WORKTREE PR SESSION 'LAST / TASK')" \
      --footer='enter: go (or start claude there) · ctrl-y: open PR · ctrl-s: send msg · ctrl-d: reap · ctrl-r: refetch · ctrl-f: agents view · esc: quit' \
      --expect=ctrl-f \
      --preview="'$self' --preview {1}" \
      --preview-window='right,55%,follow,border-left' \
      --bind="load:reload-sync(sleep 5; '$self' --rows)+refresh-preview" \
      --bind="focus:refresh-preview" \
      --bind="ctrl-r:reload('$self' --refresh)+refresh-preview" \
      --bind="ctrl-/:toggle-preview" \
      --bind="ctrl-y:execute-silent('$self' --open-pr {1})" \
      --bind="ctrl-s:execute('$S/claude-agents-send.sh' {1})+refresh-preview" \
      --bind="ctrl-d:execute('$self' --reap {1})+reload('$self' --refresh)")"
    key="${out%%$'\n'*}"
    sel="${out#*$'\n'}"; [ "$sel" = "$out" ] && sel=""
    [ "$key" = ctrl-f ] && exec "$S/claude-agents.sh" --popup
    target="${sel%%$'\t'*}"
    [ -n "$target" ] && "$self" --goto "$target"
    ;;
esac
