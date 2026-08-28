#!/usr/bin/env bash
# claude-window-status.sh <window_id>
# Emit compact status markers for every pane in a tmux window, for display in
# the window tab (wired into window-status-format in .tmux.conf) so you can see,
# at a glance across the tabs, which windows want your attention.
#
# Claude panes:
#   ● cyan    agent is working
#   ✓ green   agent is idle / waiting for you
# Claude Code sets each pane's title to "<glyph> <summary>", where the leading
# glyph is a Braille spinner (U+2800-U+28FF, UTF-8 e2 a0..a3) while it is WORKING
# and "✳" once it is IDLE.
#
# Ordinary panes:
#   ● yellow  a command is running
#   ! red     a command is blocked reading the terminal (sudo password, [Y/n])
#   ○ grey    shell prompt, nothing running
# The foreground process is found via the shell's tpgid (field 8 of
# /proc/PID/stat, after the comm field which may itself contain spaces and
# parens). A process parked in wait_woken with stdin on the pane's own tty is
# blocked on a terminal read; anything else running is just busy. A shell
# builtin `read` is indistinguishable from a prompt this way and reads as idle.
#
# Runs on every status refresh for every window, so the per-pane path stays
# fork-free: /proc reads only, no ps.
set -u

win="${1:-}"
[ -n "$win" ] || exit 0

while IFS=$'\t' read -r cmd title pid tty paneid; do
  if [ "$cmd" = claude ]; then
    # The title spinner only runs while the model is streaming; during a tool
    # call the title shows the idle "✳" even though work is running. The tell
    # for that: claude keeps one persistent shell child, and a running tool
    # gives that shell children of its own.
    # Walk the login-shell chain (bash -> zsh -> claude) down to the claude
    # process itself, then ask whether claude's persistent tool shell has
    # children of its own — it only does while a tool command is running.
    busy=""
    cur=$pid
    for _ in 1 2 3 4; do
      [ "$(cat /proc/$cur/comm 2>/dev/null)" = claude ] && break
      cur=$(cat "/proc/$cur/task/$cur/children" 2>/dev/null | awk '{print $1}')
      [ -n "$cur" ] || break
    done
    if [ -n "$cur" ] && [ "$(cat /proc/$cur/comm 2>/dev/null)" = claude ]; then
      for shpid in $(cat "/proc/$cur/task/$cur/children" 2>/dev/null); do
        if [ -n "$(cat "/proc/$shpid/task/$shpid/children" 2>/dev/null)" ]; then
          busy=1
          break
        fi
      done
    fi
    if [ -n "$busy" ]; then
      printf ' #[fg=cyan]●#[fg=default]'
      continue
    fi
    hex="$(printf '%s' "$title" | head -c3 | xxd -p 2>/dev/null)"
    case "$hex" in
      e2a0* | e2a1* | e2a2* | e2a3*) printf ' #[fg=cyan]●#[fg=default]' ;;
      *)                             printf ' #[fg=green]✓#[fg=default]' ;;
    esac
    continue
  fi

  [ -r "/proc/$pid/stat" ] || continue
  stat=$(</proc/"$pid"/stat)
  set -- ${stat#*") "}
  tpgid=$6

  if [ "$tpgid" -le 0 ] 2>/dev/null; then
    printf ' #[fg=#585b70]○#[fg=default]'
    continue
  fi

  fgcomm=$(</proc/"$tpgid"/comm) 2>/dev/null || fgcomm=""
  case "$fgcomm" in
    bash | zsh | fish | sh | dash | ksh | "")
      printf ' #[fg=#585b70]○#[fg=default]'
      continue
      ;;
  esac

  wchan=$(</proc/"$tpgid"/wchan) 2>/dev/null || wchan=""
  fd0=$(readlink "/proc/$tpgid/fd/0" 2>/dev/null)

  # An unreadable process reports wchan as the literal "0", not an empty
  # string, so both spellings mean "we cannot see inside this one".
  if [ -z "$wchan" ] || [ "$wchan" = 0 ]; then
    # setuid or root-owned (sudo, pacman, passwd): wchan and fd/0 are both
    # unreadable, so fall back to what the pane is showing. Only reached for
    # those, so the extra tmux call stays off the common path.
    tail2=$(tmux capture-pane -p -t "$paneid" -S -2 2>/dev/null | tr -d '\r' | grep -v '^[[:space:]]*$' | tail -1)
    case "$tail2" in
      *[Pp]assword*|*[Pp]assphrase*|*"[Y/n]"*|*"[y/N]"*|*"(y/n)"*|*"(Y/n)"*|*"[Y/n/?]"*|*"Proceed"*|*"proceed"*|*"Enter a number"*|*"press ENTER"*|*"Press enter"*)
        printf ' #[fg=red,bold]!#[fg=default,nobold]'
        continue
        ;;
    esac
    printf ' #[fg=yellow]●#[fg=default]'
    continue
  fi

  if [ "$wchan" = wait_woken ] && [ "$fd0" = "$tty" ]; then
    printf ' #[fg=red,bold]!#[fg=default,nobold]'
  else
    printf ' #[fg=yellow]●#[fg=default]'
  fi
done < <(tmux list-panes -t "$win" \
  -F $'#{pane_current_command}\t#{pane_title}\t#{pane_pid}\t#{pane_tty}\t#{pane_id}' 2>/dev/null)
