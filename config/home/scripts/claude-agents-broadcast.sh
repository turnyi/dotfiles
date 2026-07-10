#!/usr/bin/env bash
# Compose one message and send it to EVERY running Claude pane (with a confirm).
set -u

fmt=$'#{pane_id}\t#{pane_current_command}'
panes="$(tmux list-panes -a -F "$fmt" 2>/dev/null | awk -F'\t' '$2=="claude"{print $1}')"
count="$(printf '%s\n' "$panes" | grep -c .)"

printf '\033[2J\033[H'
printf '\033[1;35m┃ broadcast → %s agent(s)\033[0m\n' "$count"
printf '\033[2m┃ this message goes to ALL of them · empty Enter cancels\033[0m\n\n'
[ "$count" -gt 0 ] || { printf 'No Claude panes found.\n'; sleep 1; exit 0; }

IFS= read -r -e -p '❯ ' msg || exit 0
[ -n "$msg" ] || exit 0
printf '\033[1;31mSend to %s agents?\033[0m [y/N] ' "$count"
IFS= read -r ok
case "$ok" in
  y | Y) ;;
  *) printf 'cancelled\n'; sleep 0.4; exit 0 ;;
esac

printf '%s\n' "$panes" | while IFS= read -r p; do
  [ -n "$p" ] || continue
  tmux send-keys -t "$p" -l -- "$msg"
  sleep 0.05
  tmux send-keys -t "$p" Enter
done
printf '\033[32msent to %s agents\033[0m\n' "$count"
sleep 0.5
