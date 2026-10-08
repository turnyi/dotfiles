#!/usr/bin/env bash
# gh-deploys.sh — status-right segment with the live GitHub Actions deploys.
#
#   󰑮 app staging 3m   󰑮 v2 develop 12m   ✓ web prod backend   ✗ app prod
#
# One chip per deploy workflow run that is queued/running, plus any that
# finished in the last RECENT_SECS so the outcome is seen even when the
# deploy ended while looking elsewhere. Empty when nothing is happening.
#
# The runs API costs ~0.5s per repo and the status line redraws every 5s, so
# the fetch runs detached and only the cached result is rendered here. A
# missing/unauthenticated `gh` or no network just leaves the segment blank.
set -uo pipefail

REPOS=(
  "Centinel-Finance/centinel-app app"
  "Centinel-Finance/centinel-v2 v2"
  "Opti-Task/Web web"
)
REFRESH_SECS=20
RECENT_SECS=600

CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/gh-deploys"
CACHE="$CACHE_DIR/runs.tsv"
LOCK="$CACHE_DIR/lock"

DIM="#7f8490"
BLUE="#76cce0"
YELLOW="#e7c664"
RED="#fc5d7c"
GREEN="#9ed072"

ICON_RUN=$'\U000f0470'
ICON_QUEUE=$'\U000f0150'
ICON_OK=$'✓'
ICON_FAIL=$'✗'

fetch() {
  local now out="" repo alias
  now=$(date -u +%s)
  for entry in "${REPOS[@]}"; do
    read -r repo alias <<<"$entry"
    out+=$(timeout 15 gh api "repos/$repo/actions/runs?per_page=20" 2>/dev/null |
      jq -r --arg alias "$alias" --argjson now "$now" --argjson recent "$RECENT_SECS" '
        def ts: fromdateiso8601;
        def env_label:
          (.name
            | ascii_downcase
            | gsub("[^a-z0-9 ]"; "")
            | gsub("\\bdeploy\\b"; "")
            | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" ")) as $w
          | if $w != "" then $w
            elif .head_branch == "main" then "prod"
            else .head_branch end;
        .workflow_runs[]
        | select(.path | test("^\\.github/workflows/deploy"))
        | select(.status != "completed" or (($now - (.updated_at | ts)) < $recent))
        | [ .status, (.conclusion // "-"), $alias, env_label, (.created_at | ts) ]
        | @tsv')
    out+=$'\n'
  done
  printf '%s' "$out" | sed '/^$/d' >"$CACHE.tmp" && mv -f "$CACHE.tmp" "$CACHE"
}

mkdir -p "$CACHE_DIR"
if [ "${1:-}" = "--fetch" ]; then
  exec 9>"$LOCK"
  flock -n 9 || exit 0
  fetch
  exit 0
fi

command -v gh >/dev/null 2>&1 || exit 0
if [ ! -f "$CACHE" ] || [ "$(($(date +%s) - $(stat -c %Y "$CACHE")))" -ge "$REFRESH_SECS" ]; then
  setsid "$0" --fetch >/dev/null 2>&1 </dev/null &
fi
[ -s "$CACHE" ] || exit 0

now=$(date -u +%s)
out=""
while IFS=$'\t' read -r status conclusion alias env started; do
  [ -n "$status" ] || continue
  case "$status" in
    in_progress)
      mins=$(((now - started) / 60))
      out+="#[fg=$BLUE]$ICON_RUN $alias $env ${mins}m#[fg=default]  "
      ;;
    completed)
      case "$conclusion" in
        success) out+="#[fg=$GREEN]$ICON_OK $alias $env#[fg=default]  " ;;
        cancelled | skipped) out+="#[fg=$DIM]$ICON_FAIL $alias $env#[fg=default]  " ;;
        *) out+="#[fg=$RED,bold]$ICON_FAIL $alias $env#[fg=default,nobold]  " ;;
      esac
      ;;
    *)
      out+="#[fg=$YELLOW]$ICON_QUEUE $alias $env#[fg=default]  "
      ;;
  esac
done <"$CACHE"
printf '%s' "${out%  }"
