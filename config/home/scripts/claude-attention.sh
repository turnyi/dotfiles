#!/usr/bin/env bash
# claude-attention.sh — status-right segment summarising every Claude pane.
#
# The per-window tab glyph from claude-window-status.sh only tells you about the
# window it is drawn on, so an agent asking a question in another window goes
# unseen. This segment is global: it renders in status-right from every window.
#
#   ! 1  ? 1  ● 5  ✓ 2  ↳ 4  ⧉ 1/4
#   blocked · asking · working · idle · live subagents · dev-stack slots used/max
#
# Background sessions (claude --bg) have no pane; the ones flagged blocked are
# folded into "!" so a forgotten one still shows. That listing costs ~0.3s, so it
# is cached for 30s rather than paid on every 5s status refresh.
set -u

S="$(cd "$(dirname "$0")" && pwd)"
CACHE="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-fleet/bg-blocked"

blocked=0; asking=0; working=0; idle=0; subs=0

while IFS=$'\x1f' read -r cmd state n title; do
  [ "$cmd" = claude ] || continue
  if [ -z "$state" ]; then
    case "$(printf '%s' "$title" | head -c3 | xxd -p 2>/dev/null)" in
      e2a0* | e2a1* | e2a2* | e2a3*) state=working ;;
      *) state=done ;;
    esac
  fi
  case "$state" in
    blocked) blocked=$((blocked + 1)) ;;
    asking)  asking=$((asking + 1)) ;;
    working) working=$((working + 1)) ;;
    *)       idle=$((idle + 1)) ;;
  esac
  case "$n" in ''|*[!0-9]*) ;; *) subs=$((subs + n)) ;; esac
done < <(tmux list-panes -a -F $'#{pane_current_command}\x1f#{@claude_state}\x1f#{@claude_subs}\x1f#{pane_title}' 2>/dev/null)

mkdir -p "$(dirname "$CACHE")"
if [ ! -f "$CACHE" ] || [ "$(( $(date +%s) - $(stat -c %Y "$CACHE") ))" -gt 30 ]; then
  claude agents --json 2>/dev/null |
    jq '[.[] | select(.kind == "background" and .state == "blocked")] | length' >"$CACHE.tmp" 2>/dev/null &&
    mv -f "$CACHE.tmp" "$CACHE"
fi
bg="$(cat "$CACHE" 2>/dev/null || echo 0)"
case "$bg" in ''|*[!0-9]*) bg=0 ;; esac
blocked=$((blocked + bg))

[ $((blocked + asking + working + idle)) -eq 0 ] && exit 0

out=""
[ "$blocked" -gt 0 ] && out="$out#[fg=#f38ba8,bold]! $blocked#[fg=default,nobold]  "
[ "$asking" -gt 0 ]  && out="$out#[fg=#cba6f7,bold]? $asking#[fg=default,nobold]  "
[ "$working" -gt 0 ] && out="$out#[fg=#89dceb]● $working#[fg=default]  "
[ "$idle" -gt 0 ]    && out="$out#[fg=#a6e3a1]✓ $idle#[fg=default]  "
[ "$subs" -gt 0 ]    && out="$out#[fg=#fab387]↳ $subs#[fg=default]  "

slots="$("$S/centinel-slots.sh" --summary 2>/dev/null)"
if [ -n "$slots" ] && [ "${slots%%/*}" -gt 0 ]; then
  out="$out#[fg=#f9e2af]⧉ $slots#[fg=default]  "
fi

printf '%s' "$out"
