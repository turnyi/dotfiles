#!/usr/bin/env bash
# List every running Claude Code pane across all tmux sessions, with live status.
#
# Status comes from the @claude_state pane option stamped by
# claude-hook-state.sh off Claude Code's own hooks: working, asking, blocked or
# done. Panes started before the hooks existed have no option set, and fall back
# to reading the pane title, which Claude Code sets to "<glyph> <task summary>":
#   * a Braille spinner glyph (U+2800-U+28FF) => Claude is WORKING
#   * "✳" (U+2733) or anything else           => Claude is IDLE / DONE
# The fallback cannot see asking/blocked — that is the whole point of the hooks.
#
# Emits one TSV row per agent for the fzf dashboard:  <pane_id>\t<display>
# Agents wanting your attention sort to the top. Also detects working->done
# transitions and (opt-in) fires a desktop notification.
#
# Env:
#   CLAUDE_AGENTS_NOTIFY=1   send a desktop notification when an agent finishes
set -u

STATE="${TMPDIR:-/tmp}/claude-agents.state"
NOTIFY="${CLAUDE_AGENTS_NOTIFY:-0}"

now="$(date +%s)"
prev="$(cat "$STATE" 2>/dev/null || true)"
tmpstate="$(mktemp "${TMPDIR:-/tmp}/claude-agents.XXXXXX")"

# ANSI colours
c_work=$'\033[36m'      # cyan    - working
c_done=$'\033[32m'      # green   - idle a while
c_fresh=$'\033[1;92m'   # bright  - just finished
c_ask=$'\033[1;35m'     # magenta - asked you a question
c_block=$'\033[1;31m'   # red     - blocked on a permission prompt
c_loc=$'\033[33m'       # yellow - session:win.pane
c_dim=$'\033[2;37m'     # dim    - worktree/path
c_rst=$'\033[0m'

human() { # seconds -> compact human string
  local s=$1
  if   [ "$s" -lt 60 ];   then printf '%ss' "$s"
  elif [ "$s" -lt 3600 ]; then printf '%sm' "$((s / 60))"
  else                         printf '%sh' "$((s / 3600))"
  fi
}

fmt=$'#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_current_path}\t#{@claude_state}\t#{pane_title}'

# The loop emits rows prefixed with a sort key so agents wanting your attention
# rise to the top of the dashboard; the key is cut back off at the end.
{
tmux list-panes -a -F "$fmt" 2>/dev/null | sort -t $'\t' -k2,2 |
  while IFS=$'\t' read -r id loc cmd path state title; do
    [ "$cmd" = claude ] || [ -n "$state" ] || continue

    case "$state" in
      working | asking | blocked | done) status="$state" ;;
      *)
        # No hook-stamped state: infer from the leading title glyph. Only
        # working and done are recoverable this way.
        hex="$(printf '%s' "$title" | head -c3 | xxd -p 2>/dev/null)"
        case "$hex" in
          e2a0* | e2a1* | e2a2* | e2a3*) status=working ;;
          *)                             status=done ;;
        esac
        ;;
    esac

    # summary = title with the leading status glyph stripped off
    summary="$(printf '%s' "$title" | sed -E 's/^[^ ]+[[:space:]]+//')"
    [ -n "$summary" ] || summary="$title"

    # --- diff against previous poll to time the current state --------------
    pline="$(printf '%s\n' "$prev" | awk -F'\t' -v p="$id" '$1 == p {print $2"\t"$3; exit}')"
    pstatus="${pline%%$'\t'*}"
    psince="${pline#*$'\t'}"
    if [ "$pstatus" = "$status" ] && [ -n "$psince" ]; then
      since="$psince"
    else
      since="$now"
      # working -> done edge = the agent just finished
      if [ "$pstatus" = working ] && [ "$status" = done ] && [ "$NOTIFY" = 1 ]; then
        notify-send -a claude -i utilities-terminal \
          "✳ Claude finished · $loc" "$summary" >/dev/null 2>&1 &
      fi
    fi
    printf '%s\t%s\t%s\n' "$id" "$status" "$since" >>"$tmpstate"

    # --- render display row -----------------------------------------------
    age=$((now - since))
    case "$status" in
      asking)  prio=0; icon="?"; col="$c_ask";   label="asking $(human "$age")" ;;
      blocked) prio=0; icon="!"; col="$c_block"; label="blocked $(human "$age")" ;;
      working) prio=1; icon="●"; col="$c_work";  label="working $(human "$age")" ;;
      *)
        prio=2; icon="✓"
        if [ "$age" -lt 20 ]; then
          col="$c_fresh"; label="done $(human "$age")"
        else
          col="$c_done"; label="idle $(human "$age")"
        fi
        ;;
    esac

    printf '%s\t%s\t%s%s %-13s%s %s%-8s%s  %s  %s[%s]%s\n' \
      "$prio" \
      "$id" \
      "$col" "$icon" "$label" "$c_rst" \
      "$c_loc" "$loc" "$c_rst" \
      "$summary" \
      "$c_dim" "$(basename "$path")" "$c_rst"
  done
} | sort -s -t $'\t' -k1,1n | cut -f2-

mv -f "$tmpstate" "$STATE" 2>/dev/null || rm -f "$tmpstate" 2>/dev/null || true
