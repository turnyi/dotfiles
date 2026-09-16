#!/usr/bin/env bash
# claude-fleet.sh — one row per worktree: who is on it, its PR, and what YOU do next.
#
#   claude-fleet.sh --popup          fzf dashboard (prefix F, or ctrl-f from the agents popup)
#   claude-fleet.sh --rows           the rows the popup renders (key \t sort \t display)
#   claude-fleet.sh --preview KEY    the focus card for a row (state, task, PR, git, pane tail)
#   claude-fleet.sh --refresh        drop the PR cache so the next --rows refetches
#   claude-fleet.sh --sidebar        compact looping list for a narrow pane (prefix S toggles it)
#   claude-fleet.sh --stage %N       mission-control list pane, card below, stage %N on the right
#   claude-fleet.sh --diff KEY       uncommitted + ahead-of-base diff in a new window
#
# Every column is computed by a program, never narrated by a model:
#   next     answer · approve · fix CI · triage review · merge · wait CI · reap · open PR ·
#            review diff · working · idle
#   session  @claude_* pane options stamped by claude-hook-state.sh, plus background
#            sessions from `claude agents --json`
#   PR       gh pr view + unresolved review threads (GraphQL), cached per branch for 90s
#            and refreshed in the background so the popup never blocks on the network.
#            With ~/.centinel-fleet present, "merge" also requires the fleet gates: triage
#            and quiz recorded at the PR's current head SHA (see scripts/fleet.sh there).
#   slot     centinel-slots.sh (dev-stack lock files)
#
# Rows whose next action is "—" (no session, nothing pending) are hidden until ctrl-a.
# Repos scanned: every repo a live Claude session sits in, plus any listed one per
# line in ~/.config/claude-fleet/repos.
set -u

S="$(cd "$(dirname "$0")" && pwd)"
RUN="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-fleet"
PRCACHE="$RUN/pr"
CARDS="$RUN/cards"
BGCACHE="$RUN/bg.json"
SHOW_ALL_FLAG="$RUN/show-all"
FLEET_DIR="${FLEET_DIR:-$HOME/.centinel-fleet}"
AGENTS_STATE="${TMPDIR:-/tmp}/claude-agents.state"
PR_TTL=90
mkdir -p "$PRCACHE" "$CARDS"

US=$'\x1f'
now="$(date +%s)"

c_rst=$'\033[0m'; c_dim=$'\033[2;37m'; c_loc=$'\033[33m'; c_bold=$'\033[1m'
c_red=$'\033[1;31m'; c_mag=$'\033[1;35m'; c_cyan=$'\033[36m'; c_green=$'\033[32m'
c_yel=$'\033[33m'; c_orange=$'\033[38;5;215m'; c_blue=$'\033[34m'

strip() { sed 's/\x1b\[[0-9;]*m//g'; }

pad() {
  local str="$1" width="$2" vis
  vis="$(printf '%s' "$str" | strip | wc -m | tr -d ' ')"
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

key_hash() { printf '%s' "$1" | md5sum | cut -c1-16; }

# ---------------------------------------------------------------- sources

bg_sessions() {
  if [ ! -f "$BGCACHE" ] || [ "$((now - $(stat -c %Y "$BGCACHE")))" -gt 30 ]; then
    claude agents --json 2>/dev/null >"$BGCACHE.tmp" && mv -f "$BGCACHE.tmp" "$BGCACHE"
  fi
  jq -r '.[] | select(.kind == "background") | [.cwd, .name, .state // "", .status // "", .id // ""] | join("")' "$BGCACHE" 2>/dev/null
}

pane_fmt="#{pane_id}${US}#{session_name}:#{window_index}.#{pane_index}${US}#{pane_current_command}${US}#{pane_current_path}${US}#{@claude_state}${US}#{@claude_state_since}${US}#{@claude_started}${US}#{@claude_budget}${US}#{@claude_task}${US}#{@claude_task_since}${US}#{@claude_subs}${US}#{@claude_sub_names}${US}#{@claude_last}${US}#{pane_title}"

panes() { tmux list-panes -a -F "$pane_fmt" 2>/dev/null | awk -F"$US" '$3 == "claude" || $5 != ""'; }

title_state() {
  case "$(printf '%s' "$1" | head -c3 | xxd -p 2>/dev/null)" in
    e2a0* | e2a1* | e2a2* | e2a3*) echo working ;;
    *) echo done ;;
  esac
}

# Panes started before the hooks existed carry no @claude_state_since; the agents
# list has been timing them by polling, so borrow its timestamp.
polled_since() { awk -F'\t' -v p="$1" '$1 == p {print $3; exit}' "$AGENTS_STATE" 2>/dev/null; }

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
  done | sort -u -t"$US" -k2,2
}

default_branch() {
  git -C "$1" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || echo staging
}

# ---------------------------------------------------------------- PR cache

pr_file() { printf '%s/%s' "$PRCACHE" "$(key_hash "$1:$2")"; }

fleet_gates() {
  local n="$1" head="$2" triaged="" quiz=""
  [ -d "$FLEET_DIR" ] || { printf 'n/a\tn/a'; return; }
  triaged="$(jq -r '.lastTriagedSha // ""' "$FLEET_DIR/pr-$n.json" 2>/dev/null)"
  quiz="$(jq -r --argjson n "$n" 'select(.pr == $n and .passed == true) | .sha' "$FLEET_DIR/quiz.jsonl" 2>/dev/null | tail -1)"
  local t=missing q=missing
  [ -n "$triaged" ] && { [ "$triaged" = "$head" ] && t=ok || t=stale; }
  [ -n "$quiz" ]    && { [ "$quiz" = "$head" ] && q=ok || q=stale; }
  printf '%s\t%s' "$t" "$q"
}

pr_fetch() {
  local wt="$1" branch="$2" f base slug threads n head triage quiz
  f="$(pr_file "$wt" "$branch")"
  base="$(cd "$wt" && gh pr view "$branch" --json number,state,url,isDraft,reviewDecision,mergeStateStatus,statusCheckRollup,headRefOid,title 2>/dev/null)"
  if [ -z "$base" ]; then echo '{"n":null}' >"$f"; return; fi
  n="$(printf '%s' "$base" | jq -r .number)"
  head="$(printf '%s' "$base" | jq -r .headRefOid)"
  slug="$(cd "$wt" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)"
  threads="$(gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{isResolved}}}}}' \
    -F o="${slug%%/*}" -F r="${slug##*/}" -F n="$n" --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not)] | length' 2>/dev/null)"
  [ -n "$threads" ] || threads=-1
  IFS=$'\t' read -r triage quiz < <(fleet_gates "$n" "$head")
  printf '%s' "$base" | jq -c --argjson threads "$threads" --arg triage "$triage" --arg quiz "$quiz" \
    '{n: .number, state: .state, url: .url, draft: .isDraft, review: .reviewDecision, merge: .mergeStateStatus, sha: .headRefOid, title: .title,
      threads: $threads, triage: $triage, quiz: $quiz,
      ci: (if ([.statusCheckRollup[]? | select(.conclusion == "FAILURE" or .conclusion == "ERROR" or .conclusion == "TIMED_OUT" or .state == "FAILURE" or .state == "ERROR")] | length) > 0 then "fail"
           elif ([.statusCheckRollup[]? | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING" or .state == "PENDING")] | length) > 0 then "pending"
           elif ([.statusCheckRollup[]?] | length) == 0 then "none" else "pass" end)}' >"$f.tmp" 2>/dev/null
  if [ -s "$f.tmp" ]; then mv -f "$f.tmp" "$f"; else echo '{"n":null}' >"$f"; rm -f "$f.tmp"; fi
}

pr_get() {
  local wt="$1" branch="$2" f
  f="$(pr_file "$wt" "$branch")"
  if [ ! -f "$f" ] || [ "$((now - $(stat -c %Y "$f")))" -gt "$PR_TTL" ]; then
    if [ ! -f "$f.lock" ] || [ "$((now - $(stat -c %Y "$f.lock")))" -gt 60 ]; then
      touch "$f.lock"
      ( pr_fetch "$wt" "$branch"; rm -f "$f.lock" ) >/dev/null 2>&1 &
    fi
  fi
  if [ -f "$f" ]; then cat "$f"; else echo '{"n":null,"stale":true}'; fi
}

# ---------------------------------------------------------------- rows

emit() {
  local key="$1" prio="$2" next="$3" ncol="$4" name="$5" prcol="$6" sess="$7" what="$8" short="${9:-}"
  if [ "${FLEET_COMPACT:-0}" = 1 ]; then
    local plain; plain="$(printf '%s' "$name" | strip | cut -c1-18)"
    printf '%s\t%s\t%s %s %s\n' "$key" "$prio" "$(pad "${ncol}${next}${c_rst}" 10)" "$(pad "${c_loc}${plain}${c_rst}" 18)" "$short"
    return
  fi
  printf '%s\t%s\t%s %s %s %s %s%s%s\n' \
    "$key" "$prio" \
    "$(pad "${ncol}${next}${c_rst}" 13)" \
    "$(pad "$name" 24)" \
    "$(pad "$prcol" 28)" "$(pad "$sess" 22)" \
    "$c_dim" "$(printf '%s' "$what" | head -c 70)" "$c_rst"
}

next_color() {
  case "$1" in
    answer|approve) printf '%s' "$c_red" ;;
    "fix CI"|"triage review") printf '%s' "$c_orange" ;;
    merge|"open PR"|"review diff"|reap) printf '%s' "$c_mag" ;;
    working) printf '%s' "$c_cyan" ;;
    *) printf '%s' "$c_dim" ;;
  esac
}

session_label() {
  local id="$1" state="$2" since="$3" started="$4" budget="$5" subs="$6" bg_name="$7" bg_state="$8" slot="$9" slot_alive="${10}"
  local sess="" age
  if [ -n "$id" ]; then
    age=$((now - ${since:-$now}))
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
    sess="${c_dim}bg${c_rst}${bg_state:+ ${c_red}$bg_state${c_rst}}"
  else
    sess="${c_dim}no session${c_rst}"
  fi
  if [ -n "$slot" ]; then
    [ "$slot_alive" = 1 ] && sess="$sess ${c_yel}⧉$slot${c_rst}" || sess="$sess ${c_dim}⧉$slot↓${c_rst}"
  fi
  printf '%s' "$sess"
}

short_label() {
  local id="$1" state="$2" since="$3" subs="$4" bg_state="$5" age
  if [ -n "$id" ]; then
    age=$((now - ${since:-$now}))
    case "$state" in
      asking)  printf '%s? %s%s' "$c_mag" "$(human $age)" "$c_rst" ;;
      blocked) printf '%s! %s%s' "$c_red" "$(human $age)" "$c_rst" ;;
      working) printf '%s● %s%s' "$c_cyan" "$(human $age)" "$c_rst" ;;
      *)       printf '%s✓ %s%s' "$c_green" "$(human $age)" "$c_rst" ;;
    esac
    case "$subs" in ''|0) ;; *) printf ' %s↳%s%s' "$c_orange" "$subs" "$c_rst" ;; esac
  elif [ -n "$bg_state" ]; then printf '%sbg %s%s' "$c_red" "$bg_state" "$c_rst"
  else printf '%s·%s' "$c_dim" "$c_rst"
  fi
}

rows() {
  local pane_data bg_data wt_data show_all=0
  [ -f "$SHOW_ALL_FLAG" ] && show_all=1
  pane_data="$(panes)"
  bg_data="$(bg_sessions)"
  wt_data="$(worktrees)"
  local seen_panes=""

  while IFS="$US" read -r repo wt branch; do
    [ -n "$wt" ] || continue
    local id="" loc="" path="" state="" since="" started="" budget="" task="" task_since="" subs="" sub_names="" last="" title=""
    local best=""
    while IFS="$US" read -r p_id _ _ p_path _; do
      case "$p_path" in "$wt" | "$wt"/*) [ -z "$best" ] && best="$p_id" ;; esac
    done <<<"$pane_data"
    if [ -n "$best" ]; then
      IFS="$US" read -r id loc _ path state since started budget task task_since subs sub_names last title \
        < <(printf '%s\n' "$pane_data" | awk -F"$US" -v p="$best" '$1 == p')
      seen_panes="$seen_panes $id"
      [ -n "$state" ] || state="$(title_state "$title")"
      [ -n "$since" ] || since="$(polled_since "$id")"
    fi

    local bg_name="" bg_state=""
    IFS="$US" read -r _ bg_name bg_state _ _ < <(printf '%s\n' "$bg_data" | awk -F"$US" -v w="$wt" 'index($1, w) == 1' | head -1)

    local dirty ahead base is_main=0
    dirty="$(git -C "$wt" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    base="$(default_branch "$repo")"
    ahead="$(git -C "$wt" rev-list --count "origin/$base..HEAD" 2>/dev/null || echo 0)"
    [ "$wt" = "$repo" ] && is_main=1

    local pr='{"n":null}' pr_n pr_state pr_ci pr_review pr_merge pr_draft pr_threads pr_triage pr_quiz
    [ "$is_main" = 0 ] && [ -n "$branch" ] && pr="$(pr_get "$wt" "$branch")"
    IFS="$US" read -r pr_n pr_state pr_ci pr_review pr_merge pr_draft pr_threads pr_triage pr_quiz \
      < <(printf '%s' "$pr" | jq -r '[(.n // ""), (.state // ""), (.ci // ""), (.review // ""), (.merge // ""), (.draft // false), (.threads // ""), (.triage // ""), (.quiz // "")] | map(tostring) | join("")')

    local slot_row slot="" slot_alive="" slot_port=""
    slot_row="$("$S/centinel-slots.sh" --for "$wt" 2>/dev/null)"
    [ -n "$slot_row" ] && IFS=$'\t' read -r slot slot_alive slot_port <<<"$slot_row"

    local gates_ok=1
    case "$pr_triage" in stale|missing) gates_ok=0 ;; esac
    case "$pr_quiz" in stale|missing) gates_ok=0 ;; esac
    local open=0; [ "$pr_state" = OPEN ] && open=1
    local threads_n="${pr_threads:-0}"; [ "$threads_n" -ge 0 ] 2>/dev/null || threads_n=0

    local next prio why
    if   [ "$state" = asking ]; then next="answer"; prio=0; why="the session asked you a question"
    elif [ "$state" = blocked ]; then next="approve"; prio=0; why="the session is waiting on a permission prompt"
    elif [ -z "$id" ] && [ "$bg_state" = blocked ]; then next="answer"; prio=0; why="background session needs input"
    elif [ "$open" = 1 ] && [ "$pr_ci" = fail ]; then next="fix CI"; prio=1; why="a check failed on PR #$pr_n"
    elif [ "$open" = 1 ] && [ "$pr_merge" = DIRTY ]; then next="fix CI"; prio=1; why="PR #$pr_n has merge conflicts"
    elif [ "$open" = 1 ] && { [ "$pr_review" = CHANGES_REQUESTED ] || [ "$threads_n" -gt 0 ]; }; then next="triage review"; prio=1; why="$threads_n unresolved review threads${pr_review:+, review $pr_review}"
    elif [ "$open" = 1 ] && [ "$pr_ci" = pass ] && [ "$pr_merge" = CLEAN ] && [ "$pr_draft" != true ] && [ "$gates_ok" = 1 ]; then next="merge"; prio=1; why="CI green, no open threads, mergeable clean"
    elif [ "$open" = 1 ] && [ "$pr_ci" = pass ] && [ "$pr_merge" = CLEAN ] && [ "$gates_ok" = 0 ]; then next="triage review"; prio=1; why="fleet gates: triage $pr_triage, quiz $pr_quiz"
    elif [ "$open" = 1 ] && [ "$pr_ci" = pending ]; then next="wait CI"; prio=3; why="checks still running"
    elif [ "$pr_state" = MERGED ] && [ "$dirty" = 0 ] && [ "$is_main" = 0 ]; then next="reap"; prio=2; why="PR merged and the tree is clean"
    elif [ "$state" = working ]; then next="working"; prio=3; why="${task:-the session is mid-turn}"
    elif [ -n "$id" ] && [ "$dirty" -gt 0 ] && [ "$is_main" = 0 ]; then next="review diff"; prio=2; why="$dirty uncommitted files, session idle"
    elif [ -z "$pr_n" ] && [ "$ahead" -gt 0 ] && [ "$is_main" = 0 ] && [ "$dirty" = 0 ]; then next="open PR"; prio=2; why="$ahead commits ahead of $base, no PR"
    elif [ -n "$id" ]; then next="idle"; prio=4; why="session idle, nothing pending"
    else next="—"; prio=5; why="no session"
    fi

    local prcol=""
    if [ -n "$pr_n" ]; then
      local ci_glyph
      case "$pr_ci" in pass) ci_glyph="${c_green}✔${c_rst}" ;; fail) ci_glyph="${c_red}✘${c_rst}" ;; pending) ci_glyph="${c_yel}◌${c_rst}" ;; *) ci_glyph="${c_dim}·${c_rst}" ;; esac
      case "$pr_state" in
        MERGED) prcol="#$pr_n ${c_mag}merged${c_rst}" ;;
        CLOSED) prcol="#$pr_n ${c_dim}closed${c_rst}" ;;
        *) prcol="#$pr_n $ci_glyph"
           [ "$pr_draft" = true ] && prcol="$prcol ${c_dim}draft${c_rst}"
           [ "$threads_n" -gt 0 ] && prcol="$prcol ${c_orange}${threads_n}✎${c_rst}"
           [ "$pr_review" = CHANGES_REQUESTED ] && prcol="$prcol ${c_orange}changes${c_rst}"
           [ "$pr_review" = APPROVED ] && prcol="$prcol ${c_green}approved${c_rst}"
           [ "$pr_merge" = CLEAN ] && prcol="$prcol ${c_green}ready${c_rst}"
           [ "$pr_merge" = DIRTY ] && prcol="$prcol ${c_red}conflict${c_rst}" ;;
      esac
    elif [ "$ahead" -gt 0 ] && [ "$is_main" = 0 ]; then prcol="${c_dim}+$ahead no PR${c_rst}"
    else prcol="${c_dim}—${c_rst}"
    fi
    [ "$dirty" -gt 0 ] && prcol="$prcol ${c_yel}~$dirty${c_rst}"

    local sess; sess="$(session_label "$id" "$state" "$since" "$started" "$budget" "$subs" "$bg_name" "$bg_state" "$slot" "$slot_alive")"

    local what
    if [ "$state" = working ] && [ -n "$task" ]; then what="$task"
    elif [ -n "$last" ]; then what="$last"
    elif [ -n "$title" ]; then what="$(printf '%s' "$title" | sed -E 's/^[^ ]+[[:space:]]+//')"
    elif [ -n "$bg_name" ]; then what="$bg_name"
    else what="$(git -C "$wt" log -1 --format=%s 2>/dev/null)"
    fi

    local name; name="${c_loc}$(basename "$wt")${c_rst}"
    [ "$is_main" = 1 ] && name="$name ${c_dim}(main)${c_rst}"

    local key="${id:-$wt}"
    jq -nc --arg key "$key" --arg wt "$wt" --arg branch "$branch" --arg base "$base" --arg pane "$id" --arg loc "$loc" \
      --arg state "$state" --arg since "$since" --arg started "$started" --arg budget "$budget" \
      --arg task "$task" --arg task_since "$task_since" --arg subs "$subs" --arg sub_names "$sub_names" --arg last "$last" \
      --arg next "$next" --arg why "$why" --arg dirty "$dirty" --arg ahead "$ahead" \
      --arg slot "$slot" --arg slot_alive "$slot_alive" --arg slot_port "$slot_port" \
      --arg bg_name "$bg_name" --arg bg_state "$bg_state" --argjson pr "$pr" \
      '$ARGS.named' >"$CARDS/$(key_hash "$key").json" 2>/dev/null

    [ "$show_all" = 0 ] && [ "$next" = "—" ] && continue
    emit "$key" "$prio" "$next" "$(next_color "$next")" "$name" "$prcol" "$sess" "$what" "$(short_label "$id" "$state" "$since" "$subs" "$bg_state")"
  done <<<"$wt_data"

  while IFS="$US" read -r id loc _ path state since started budget task task_since subs sub_names last title; do
    [ -n "$id" ] || continue
    case " $seen_panes " in *" $id "*) continue ;; esac
    [ -n "$state" ] || state="$(title_state "$title")"
    [ -n "$since" ] || since="$(polled_since "$id")"
    local next prio why
    case "$state" in
      asking)  next="answer"; prio=0; why="the session asked you a question" ;;
      blocked) next="approve"; prio=0; why="waiting on a permission prompt" ;;
      working) next="working"; prio=3; why="${task:-mid-turn}" ;;
      *)       next="idle"; prio=4; why="session idle" ;;
    esac
    local sess; sess="$(session_label "$id" "$state" "$since" "$started" "$budget" "$subs" "" "" "" "")"
    jq -nc --arg key "$id" --arg wt "$path" --arg pane "$id" --arg loc "$loc" --arg state "$state" --arg since "$since" \
      --arg started "$started" --arg budget "$budget" --arg task "$task" --arg task_since "$task_since" --arg subs "$subs" \
      --arg sub_names "$sub_names" --arg last "$last" --arg next "$next" --arg why "$why" --argjson pr '{"n":null}' \
      '$ARGS.named' >"$CARDS/$(key_hash "$id").json" 2>/dev/null
    emit "$id" "$prio" "$next" "$(next_color "$next")" "${c_loc}$(basename "$path")${c_rst}" "${c_dim}—${c_rst}" "$sess" \
      "${last:-$(printf '%s' "$title" | sed -E 's/^[^ ]+[[:space:]]+//')}" "$(short_label "$id" "$state" "$since" "$subs" "")"
  done <<<"$pane_data"

  while IFS="$US" read -r cwd bname bstate bstatus bid; do
    [ -n "$bid" ] || continue
    local next prio why sess
    if [ "$bstate" = blocked ]; then next="answer"; prio=0; why="background session needs input"; sess="${c_red}! bg blocked${c_rst}"
    elif [ "$bstatus" = busy ]; then next="working"; prio=3; why="background session mid-turn"; sess="${c_cyan}● bg${c_rst}"
    else next="idle"; prio=4; why="background session idle"; sess="${c_green}✓ bg idle${c_rst}"
    fi
    jq -nc --arg key "bg:$bid" --arg wt "$cwd" --arg bg_name "$bname" --arg bg_state "$bstate" --arg state "$bstatus" \
      --arg next "$next" --arg why "$why" --argjson pr '{"n":null}' '$ARGS.named' >"$CARDS/$(key_hash "bg:$bid").json" 2>/dev/null
    emit "bg:$bid" "$prio" "$next" "$(next_color "$next")" "${c_loc}$(basename "$cwd") ${c_dim}bg${c_rst}" "${c_dim}—${c_rst}" "$sess" "$bname" "$(short_label "" "" "" "" "${bstate:-bg}")"
  done <<<"$bg_data"
}

sorted_rows() { rows | sort -s -t$'\t' -k2,2n; }

# ---------------------------------------------------------------- card

line() { printf '%s%s%s  %s\n' "$c_dim" "$1" "$c_rst" "$2"; }

card() {
  local key="$1" f
  f="$CARDS/$(key_hash "$key").json"
  [ -f "$f" ] || { printf '%sno card yet — wait for the next refresh%s\n' "$c_dim" "$c_rst"; return; }
  g() { jq -r --arg k "$1" '.[$k] // ""' "$f"; }
  local wt branch base pane loc state since started budget task task_since subs sub_names last next why dirty ahead slot slot_alive slot_port bg_name
  wt="$(g wt)"; branch="$(g branch)"; base="$(g base)"; pane="$(g pane)"; loc="$(g loc)"; state="$(g state)"; since="$(g since)"
  started="$(g started)"; budget="$(g budget)"; task="$(g task)"; task_since="$(g task_since)"; subs="$(g subs)"; sub_names="$(g sub_names)"
  last="$(g last)"; next="$(g next)"; why="$(g why)"; dirty="$(g dirty)"; ahead="$(g ahead)"; slot="$(g slot)"; slot_alive="$(g slot_alive)"
  slot_port="$(g slot_port)"; bg_name="$(g bg_name)"

  printf '%s%s%s  %s%s%s\n' "$c_bold" "$(basename "$wt")" "$c_rst" "$c_mag" "$branch" "$c_rst"
  printf '%s%s%s\n\n' "$c_dim" "$wt" "$c_rst"

  line "NEXT " "$(next_color "$next")${c_bold}${next}${c_rst}  ${c_dim}${why}${c_rst}"

  local sl=""
  if [ -n "$pane" ]; then
    local age=$((now - ${since:-$now}))
    case "$state" in
      asking)  sl="${c_mag}? asking for $(human $age)${c_rst}" ;;
      blocked) sl="${c_red}! blocked for $(human $age)${c_rst}" ;;
      working) sl="${c_cyan}● working for $(human $age)${c_rst}" ;;
      *)       sl="${c_green}✓ idle for $(human $age)${c_rst}" ;;
    esac
    sl="$sl  ${c_dim}pane $loc${c_rst}"
    if [ -n "$started" ]; then
      sl="$sl  ${c_dim}session $(human $((now - started)))${c_rst}"
      if [ -n "$budget" ]; then
        local used=$((now - started)) bcol="$c_green"
        [ "$used" -gt "$budget" ] && bcol="$c_red"
        sl="$sl ${bcol}($(human $used) of $(human "$budget") budget)${c_rst}"
      fi
    fi
  elif [ -n "$bg_name" ]; then sl="${c_dim}background session${c_rst} $bg_name"
  else sl="${c_dim}no live session${c_rst}"
  fi
  line "STATE" "$sl"

  case "$subs" in
    ''|0) ;;
    *) line "AGENT" "${c_orange}↳ $subs live${c_rst}  ${c_dim}${sub_names}${c_rst}" ;;
  esac
  if [ -n "$task" ]; then
    local ts=""; [ -n "$task_since" ] && ts="  ${c_dim}for $(human $((now - task_since)))${c_rst}"
    line "TASK " "${task}${ts}"
  fi
  [ -n "$last" ] && line "LAST " "${c_dim}${last}${c_rst}"

  local prn; prn="$(jq -r '.pr.n // ""' "$f")"
  if [ -n "$prn" ]; then
    local prl; prl="$(jq -r '.pr | "#\(.n) \(.state)\(if .draft then " draft" else "" end)  ci \(.ci)  threads \(.threads)  review \(if .review == "" then "—" else .review end)  merge \(.merge)" + (if .triage != "n/a" then "  triage \(.triage)  quiz \(.quiz)" else "" end)' "$f")"
    line "PR   " "$prl"
    line "     " "${c_dim}$(jq -r '.pr.title' "$f")${c_rst}"
    line "     " "${c_blue}$(jq -r '.pr.url' "$f")${c_rst}"
  elif [ -n "$branch" ] && [ "${ahead:-0}" -gt 0 ]; then
    line "PR   " "${c_dim}none — $ahead commits ahead of $base${c_rst}"
  fi

  [ -n "$branch" ] && line "GIT  " "+${ahead:-0} ahead of ${base:-?}  ~${dirty:-0} dirty"
  if [ -n "$slot" ]; then
    if [ "$slot_alive" = 1 ]; then line "SLOT " "${c_yel}⧉ $slot · :$slot_port · live${c_rst}"; else line "SLOT " "${c_dim}⧉ $slot · down${c_rst}"; fi
  fi

  if [ -d "$wt" ] && git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '\n%s── commits ahead ──%s\n' "$c_dim" "$c_rst"
    if [ -n "$base" ]; then git -C "$wt" -c color.ui=always log --oneline "origin/$base..HEAD" 2>/dev/null | head -6
    else git -C "$wt" -c color.ui=always log --oneline -6 2>/dev/null; fi
    if [ "${dirty:-0}" -gt 0 ]; then
      printf '%s── dirty ──%s\n' "$c_dim" "$c_rst"
      git -C "$wt" -c color.ui=always status --short 2>/dev/null | head -8
    fi
  fi

  if [ -n "$pane" ]; then
    printf '\n%s── pane ──%s\n' "$c_dim" "$c_rst"
    tmux capture-pane -ep -t "$pane" 2>/dev/null | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' | tail -25
  elif [ "${key#bg:}" != "$key" ]; then
    printf '\n%s── log ──%s\n' "$c_dim" "$c_rst"
    claude logs "${key#bg:}" 2>/dev/null | tail -20
  fi
}

# ---------------------------------------------------------------- actions

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
  local key="$1" f url
  f="$CARDS/$(key_hash "$key").json"
  url="$(jq -r '.pr.url // ""' "$f" 2>/dev/null)"
  [ -n "$url" ] || return 0
  xdg-open "$url" >/dev/null 2>&1 </dev/null &
}

interrupt() {
  local key="$1"
  case "$key" in %*) ;; *) return 0 ;; esac
  printf 'send Escape to %s (stops the turn and its subagents)? [y/N] ' "$key"; read -r a
  [ "$a" = y ] && tmux send-keys -t "$key" Escape
}

reap() {
  local key="$1"
  case "$key" in %*|bg:*) return 0 ;; esac
  local repo; repo="$(repo_root "$key")"
  printf 'reap worktree %s? [y/N] ' "$key"; read -r a; [ "$a" = y ] || return 0
  if [ -x "$repo/scripts/worktree-remove.sh" ]; then
    (cd "$repo" && ./scripts/worktree-remove.sh "$key" --yes)
  else
    git -C "$repo" worktree remove "$key"
  fi
  read -r -p 'enter to continue' _
}

show_diff() {
  local key="$1" f wt base
  f="$CARDS/$(key_hash "$key").json"
  wt="$(jq -r '.wt // ""' "$f" 2>/dev/null)"; base="$(jq -r '.base // ""' "$f" 2>/dev/null)"
  [ -d "$wt" ] && git -C "$wt" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  tmux new-window -n "diff:$(basename "$wt")" -c "$wt" "$S/claude-fleet.sh --diff-view '$wt' '$base'"
}

diff_view() {
  local wt="$1" base="$2"
  {
    printf '\033[1m══ uncommitted ══\033[0m\n'
    git -C "$wt" diff --color=always
    git -C "$wt" diff --color=always --cached
    if [ -n "$base" ]; then
      printf '\n\033[1m══ commits ahead of %s ══\033[0m\n' "$base"
      git -C "$wt" log --color=always --oneline "origin/$base..HEAD"
      echo
      git -C "$wt" diff --color=always "origin/$base...HEAD"
    fi
  } | less -R
}

sidebar_loop() {
  local self="$S/claude-fleet.sh"
  while :; do
    FLEET_COMPACT=1 "$self" --rows | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=hidden --no-scrollbar \
      --delimiter=$'\t' --with-nth=3 \
      --prompt='fleet ' \
      --header='enter go · F full · v diff · x stop · q close' \
      --expect=q \
      --bind="load:reload-sync(sleep 5; FLEET_COMPACT=1 '$self' --rows)" \
      --bind="enter:execute-silent('$self' --goto {1})" \
      --bind="F:execute-silent(tmux display-popup -E -w 96% -h 85% '$self --popup')" \
      --bind="v:execute-silent('$self' --diff {1})" \
      --bind="x:execute('$self' --interrupt {1})" \
      --bind="ctrl-r:reload('$self' --refresh | FLEET_COMPACT=1 '$self' --rows)" \
      --bind="esc:ignore" | grep -q '^q$' && return 0
    sleep 0.2
  done
}

stage_loop() {
  local stage="$1" self="$S/claude-fleet.sh"
  local SEL="${TMPDIR:-/tmp}/claude-agents-sel.$stage"
  while :; do
    "$self" --rows | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=3 \
      --prompt='fleet ❯ ' \
      --footer='enter: go · tab: pin/unpin tile · ctrl-v: diff · ctrl-s: message · ctrl-x: interrupt · ctrl-a: all · :q / esc esc: quit · C-b: hide list' \
      --preview="'$self' --preview {1}" \
      --preview-window='down,55%,border-top,wrap' \
      --bind="start:execute-silent(printf %s {1} > '$SEL')" \
      --bind="focus:execute-silent(printf %s {1} > '$SEL')+refresh-preview" \
      --bind="load:reload-sync(sleep 5; '$self' --rows)+refresh-preview" \
      --bind="ctrl-r:reload('$self' --refresh)+refresh-preview" \
      --bind="ctrl-a:execute-silent('$self' --toggle-all)+reload('$self' --rows)" \
      --bind="enter:execute-silent('$S/claude-agents-enter.sh' {q} '' '$stage'; '$self' --goto {1})+abort" \
      --bind="tab:execute-silent('$S/claude-agents-dock.sh' {1} '$stage')" \
      --bind="ctrl-u:execute-silent('$S/claude-agents-dock.sh' --untile {1} '$stage')" \
      --bind="ctrl-v:execute-silent('$self' --diff {1})" \
      --bind="ctrl-s:execute('$S/claude-agents-send.sh' {1})+refresh-preview" \
      --bind="ctrl-x:execute('$self' --interrupt {1})+refresh-preview" \
      --bind="esc:execute-silent('$S/claude-agents-quit.sh' --tap '$stage')+abort"
    sleep 0.2
  done
}

toggle_all() { if [ -f "$SHOW_ALL_FLAG" ]; then rm -f "$SHOW_ALL_FLAG"; else touch "$SHOW_ALL_FLAG"; fi; }

case "${1:-}" in
  --rows) sorted_rows ;;
  --preview) card "${2:-}" ;;
  --refresh) rm -f "$PRCACHE"/* "$BGCACHE"; sorted_rows ;;
  --toggle-all) toggle_all ;;
  --goto) goto "${2:-}" ;;
  --open-pr) open_pr "${2:-}" ;;
  --interrupt) interrupt "${2:-}" ;;
  --reap) reap "${2:-}" ;;
  --diff) show_diff "${2:-}" ;;
  --diff-view) diff_view "${2:-}" "${3:-}" ;;
  --sidebar) sidebar_loop ;;
  --stage) stage_loop "${2:-}" ;;
  --popup | "")
    self="$S/claude-fleet.sh"
    out="$("$self" --rows | fzf \
      --ansi --no-sort --cycle --layout=reverse --info=inline \
      --delimiter=$'\t' --with-nth=3 \
      --prompt='fleet ❯ ' \
      --header="$(printf '%-13s %-24s %-28s %-22s %s' NEXT WORKTREE PR SESSION 'TASK / LAST')" \
      --footer='enter: go · ctrl-y: PR · ctrl-v: diff · ctrl-s: message · ctrl-x: interrupt · ctrl-d: reap · ctrl-a: all/active · ctrl-r: refetch · ctrl-f: agents · esc: quit' \
      --expect=ctrl-f \
      --preview="'$self' --preview {1}" \
      --preview-window='right,58%,border-left,wrap' \
      --bind="load:reload-sync(sleep 5; '$self' --rows)+refresh-preview" \
      --bind="focus:refresh-preview" \
      --bind="ctrl-r:reload('$self' --refresh)+refresh-preview" \
      --bind="ctrl-a:execute-silent('$self' --toggle-all)+reload('$self' --rows)" \
      --bind="ctrl-/:toggle-preview" \
      --bind="ctrl-y:execute-silent('$self' --open-pr {1})" \
      --bind="ctrl-v:execute-silent('$self' --diff {1})+abort" \
      --bind="ctrl-s:execute('$S/claude-agents-send.sh' {1})+refresh-preview" \
      --bind="ctrl-x:execute('$self' --interrupt {1})+refresh-preview" \
      --bind="ctrl-d:execute('$self' --reap {1})+reload('$self' --refresh)")"
    key="${out%%$'\n'*}"
    sel="${out#*$'\n'}"; [ "$sel" = "$out" ] && sel=""
    [ "$key" = ctrl-f ] && exec "$S/claude-agents.sh" --popup
    target="${sel%%$'\t'*}"
    [ -n "$target" ] && "$self" --goto "$target"
    ;;
esac
