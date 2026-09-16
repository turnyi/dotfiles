#!/usr/bin/env bash
# claude-wt.sh — worktree lifecycle for Claude sessions, inside tmux.
#
#   claude-wt add <name> [-p "prompt"] [--budget 45m] [--count N] [--base BR] [--no-claude]
#   claude-wt open <name>          new window on the worktree running `claude --continue`
#   claude-wt close <name>         kill every window whose panes sit in the worktree
#   claude-wt merge <name>         PR must be MERGED on GitHub (you merge, never this script):
#                                  close windows, remove the worktree, drop the branch
#   claude-wt remove <name> [--force]   abandon: same teardown without the PR check
#   claude-wt resurrect            open a window for every worktree that has none
#   claude-wt path <name>          print the worktree path
#   claude-wt list                 the fleet rows
#
# The repo is the one you are standing in. Repos that ship scripts/worktree-bootstrap.sh
# and scripts/worktree-remove.sh (centinel-app, centinel-v2) get those — they copy env
# files, install deps and refuse to destroy unsaved work. Anywhere else: git worktree
# add into <repo>-worktrees/<name> on <prefix>/<name>, then the package manager's install.
set -u

S="$(cd "$(dirname "$0")" && pwd)"
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

main_root() {
  local top; top="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
  git -C "$top" rev-parse --path-format=absolute --git-common-dir | sed 's#/\.git$##; s#/\.git/worktrees/.*$##'
}

branch_prefix() {
  local p
  p="${WORKTREE_BRANCH_PREFIX:-$(git config --get centinel.branchprefix 2>/dev/null)}"
  [ -n "$p" ] || p="${CWT_BRANCH_PREFIX:-}"
  [ -n "$p" ] || die "no branch prefix: git config --global centinel.branchprefix <prefix>"
  printf '%s' "$p"
}

wt_path() {
  local root="$1" name="$2"
  git -C "$root" worktree list --porcelain | awk '/^worktree /{print $2}' |
    while read -r p; do [ "$(basename "$p")" = "$name" ] && { printf '%s' "$p"; break; }; done
}

windows_on() {
  local path="$1"
  tmux list-panes -a -F '#{window_id}	#{pane_current_path}' 2>/dev/null |
    awk -F'\t' -v p="$path" 'index($2, p) == 1 && (length($2) == length(p) || substr($2, length(p)+1, 1) == "/") {print $1}' | sort -u
}

open_window() {
  local path="$1" prompt="${2:-}" name
  name="$(basename "$path")"
  if [ -n "$prompt" ]; then
    tmux new-window -n "$name" -c "$path" "claude \"\$0\"; exec \${SHELL:-bash}" "$prompt"
  else
    tmux new-window -n "$name" -c "$path" "claude --continue || claude; exec \${SHELL:-bash}"
  fi
}

install_deps() {
  local path="$1"
  if   [ -f "$path/pnpm-lock.yaml" ]; then (cd "$path" && pnpm install --silent)
  elif [ -f "$path/yarn.lock" ];      then (cd "$path" && yarn install --silent)
  elif [ -f "$path/package-lock.json" ]; then (cd "$path" && npm install --silent)
  fi
}

create_one() {
  local root="$1" name="$2" base="$3" path
  if [ -x "$root/scripts/worktree-bootstrap.sh" ]; then
    (cd "$root" && ./scripts/worktree-bootstrap.sh "$name" ${base:+--base="$base"}) || die "bootstrap failed for $name"
    path="$(wt_path "$root" "$name")"
  else
    local dir="${root}-worktrees/$name" branch
    branch="$(branch_prefix)/$name"
    [ -n "$base" ] || base="$(git -C "$root" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')"
    if git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$root" worktree add "$dir" "$branch" || die "worktree add failed"
    else
      git -C "$root" worktree add -b "$branch" "$dir" "${base:-HEAD}" || die "worktree add failed"
    fi
    install_deps "$dir"
    path="$dir"
  fi
  [ -n "$path" ] && [ -d "$path" ] || die "worktree for $name not found after creation"
  printf '%s' "$path"
}

cmd_add() {
  local name="" prompt="" budget="" count=1 base="" no_claude=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -p|--prompt) prompt="$2"; shift 2 ;;
      --budget) budget="$2"; shift 2 ;;
      --count) count="$2"; shift 2 ;;
      --base) base="$2"; shift 2 ;;
      --no-claude) no_claude=1; shift ;;
      -*) die "unknown flag $1" ;;
      *) [ -z "$name" ] || die "one name only"; name="$1"; shift ;;
    esac
  done
  [ -n "$name" ] || die "usage: claude-wt add <name> [-p prompt] [--budget 45m] [--count N]"
  local root; root="$(main_root)"
  [ -n "$budget" ] && prompt="budget $budget. $prompt"
  local i path
  for i in $(seq 1 "$count"); do
    local n="$name"; [ "$count" -gt 1 ] && n="$name-$i"
    path="$(create_one "$root" "$n" "$base")"
    printf '✓ %s\n' "$path"
    [ "$no_claude" = 1 ] || open_window "$path" "$prompt"
  done
}

cmd_open() {
  local root path; root="$(main_root)"; path="$(wt_path "$root" "${1:-}")"
  [ -n "$path" ] || die "no worktree named ${1:-?}"
  open_window "$path"
}

cmd_close() {
  local root path; root="$(main_root)"; path="$(wt_path "$root" "${1:-}")"
  [ -n "$path" ] || die "no worktree named ${1:-?}"
  windows_on "$path" | while read -r w; do tmux kill-window -t "$w"; done
}

teardown() {
  local root="$1" path="$2" force="$3"
  windows_on "$path" | while read -r w; do tmux kill-window -t "$w"; done
  if [ -x "$root/scripts/worktree-remove.sh" ]; then
    (cd "$root" && ./scripts/worktree-remove.sh "$path" --yes ${force:+--force})
  else
    local branch; branch="$(git -C "$path" branch --show-current)"
    git -C "$root" worktree remove ${force:+--force} "$path" || die "worktree remove refused (dirty? use --force)"
    [ -n "$branch" ] && git -C "$root" branch -d "$branch" 2>/dev/null
  fi
}

cmd_merge() {
  local root path branch state force=""
  root="$(main_root)"
  [ "${2:-}" = --force ] && force=1
  path="$(wt_path "$root" "${1:-}")"
  [ -n "$path" ] || die "no worktree named ${1:-?}"
  [ "$path" != "$root" ] || die "refusing to remove the main checkout"
  branch="$(git -C "$path" branch --show-current)"
  state="$(cd "$path" && gh pr view "$branch" --json state --jq .state 2>/dev/null)"
  if [ "$state" != MERGED ] && [ -z "$force" ]; then
    die "PR for $branch is ${state:-not found}, not MERGED — merge it on GitHub first, or use 'remove' to abandon"
  fi
  teardown "$root" "$path" ""
  printf '✓ merged and removed %s\n' "$path"
}

cmd_remove() {
  local root path force=""
  root="$(main_root)"
  [ "${2:-}" = --force ] && force=1
  path="$(wt_path "$root" "${1:-}")"
  [ -n "$path" ] || die "no worktree named ${1:-?}"
  [ "$path" != "$root" ] || die "refusing to remove the main checkout"
  printf 'remove %s%s? [y/N] ' "$path" "${force:+ (FORCE, loses uncommitted work)}"; read -r a; [ "$a" = y ] || exit 0
  teardown "$root" "$path" "$force"
  printf '✓ removed %s\n' "$path"
}

cmd_resurrect() {
  local root; root="$(main_root)"
  git -C "$root" worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r p; do
    [ "$p" = "$root" ] && continue
    [ -n "$(windows_on "$p")" ] && continue
    open_window "$p"
    printf '✓ %s\n' "$p"
  done
}

case "${1:-}" in
  add) shift; cmd_add "$@" ;;
  open) cmd_open "${2:-}" ;;
  close) cmd_close "${2:-}" ;;
  merge) cmd_merge "${2:-}" "${3:-}" ;;
  remove|rm) cmd_remove "${2:-}" "${3:-}" ;;
  resurrect) cmd_resurrect ;;
  path) root="$(main_root)"; wt_path "$root" "${2:-}"; echo ;;
  list|ls) exec "$S/claude-fleet.sh" --rows | cut -f3- ;;
  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
