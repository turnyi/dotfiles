#!/usr/bin/env bash
# List every running Claude Code pane across all tmux sessions, with live status.
#
# Status is read straight from the pane title, which Claude Code sets to
# "<glyph> <task summary>":
#   * a Braille spinner glyph (U+2800-U+28FF) => Claude is WORKING
#   * "✳" (U+2733) or anything else           => Claude is IDLE / DONE
#
# Emits one TSV row per agent for the fzf dashboard:  <pane_id>\t<display>
# Also detects working->done transitions and (opt-in) fires a macOS notification.
#
# Env:
#   CLAUDE_AGENTS_NOTIFY=1   send a macOS notification when an agent finishes
set -u

STATE="${TMPDIR:-/tmp}/claude-agents.state"
NOTIFY="${CLAUDE_AGENTS_NOTIFY:-0}"

now="$(date +%s)"
prev="$(cat "$STATE" 2>/dev/null || true)"
tmpstate="$(mktemp "${TMPDIR:-/tmp}/claude-agents.XXXXXX")"

# ANSI colours
c_work=$'\033[36m'      # cyan   - working
c_done=$'\033[32m'      # green  - idle a while
c_fresh=$'\033[1;92m'   # bright - just finished
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

fmt=$'#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}'

tmux list-panes -a -F "$fmt" 2>/dev/null | sort -t $'\t' -k2,2 |
  while IFS=$'\t' read -r id loc cmd path title; do
    [ "$cmd" = claude ] || continue

    # --- status from the leading title glyph -------------------------------
    hex="$(printf '%s' "$title" | head -c3 | xxd -p 2>/dev/null)"
    case "$hex" in
      e2a0* | e2a1* | e2a2* | e2a3*) status=working ;;
      *)                             status=done ;;
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
        osascript -e "display notification \"${summary//\"/}\" with title \"✳ Claude finished · $loc\"" \
          >/dev/null 2>&1 &
      fi
    fi
    printf '%s\t%s\t%s\n' "$id" "$status" "$since" >>"$tmpstate"

    # --- render display row -----------------------------------------------
    age=$((now - since))
    if [ "$status" = working ]; then
      icon="●"; col="$c_work"; label="working $(human "$age")"
    elif [ "$age" -lt 20 ]; then
      icon="✓"; col="$c_fresh"; label="done $(human "$age")"
    else
      icon="✓"; col="$c_done"; label="idle $(human "$age")"
    fi

    printf '%s\t%s%s %-13s%s %s%-8s%s  %s  %s[%s]%s\n' \
      "$id" \
      "$col" "$icon" "$label" "$c_rst" \
      "$c_loc" "$loc" "$c_rst" \
      "$summary" \
      "$c_dim" "$(basename "$path")" "$c_rst"
  done

mv -f "$tmpstate" "$STATE" 2>/dev/null || rm -f "$tmpstate" 2>/dev/null || true
