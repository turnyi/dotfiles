#!/usr/bin/env bash
# pr-open — open the GitHub PR belonging to the pane you pressed the key in.
#
# "the PR of this Claude session" resolves to: pane cwd → its git branch → the PR
# whose head is that branch. Each Claude session lives in its own worktree/branch,
# so the branch IS the link; nothing extra has to be recorded anywhere.
#
#   pr-open            open the PR for the current pane's branch in the browser
#   pr-open --print    print "#num state title url" instead of opening (status bar)
#   pr-open <dir>      resolve against <dir> rather than the current pane
set -uo pipefail

msg() { tmux display-message "$*" 2>/dev/null || printf '%s\n' "$*"; }

mode=open
case "${1:-}" in
  --print) mode=print; shift ;;
esac

dir="${1:-$(tmux display -p '#{pane_current_path}' 2>/dev/null)}"
[ -n "$dir" ] && cd "$dir" 2>/dev/null || { msg "pr: can't resolve pane directory"; exit 0; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  { msg "pr: not a git repo — ${dir/#$HOME/\~}"; exit 0; }
branch=$(git branch --show-current 2>/dev/null)
[ -n "$branch" ] || { msg "pr: detached HEAD, no branch to match"; exit 0; }
command -v gh >/dev/null 2>&1 || { msg "pr: gh is not installed"; exit 0; }

# gh pr view with no argument resolves the PR whose head is the current branch.
info=$(gh pr view --json number,state,title,url -q '[.number,.state,.title,.url]|@tsv' 2>/dev/null)
if [ -z "$info" ]; then
  msg "pr: no PR open for  $branch"
  exit 0
fi
IFS=$'\t' read -r num state title url <<<"$info"

if [ "$mode" = print ]; then
  printf '#%s %s %s %s\n' "$num" "$state" "$title" "$url"
  exit 0
fi

if command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then open "$url" >/dev/null 2>&1 &
else msg "pr: no opener — $url"; exit 0
fi
msg "  #$num $state · $title"
