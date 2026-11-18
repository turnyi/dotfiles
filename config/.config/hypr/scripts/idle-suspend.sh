#!/usr/bin/env bash
dry=0
[[ "$1" == "--dry-run" ]] && dry=1

block() { (( dry )) && echo "would NOT suspend: $1"; exit 0; }

[[ -e "$HOME/.config/hypr/no-suspend" ]] && block "no-suspend flag file"

while read -r id _; do
  [[ "$(loginctl show-session "$id" -p Remote --value)" == "yes" ]] && block "remote logind session $id"
done < <(loginctl list-sessions --no-legend)

pgrep -x sshd-session >/dev/null && block "sshd-session process"

(( dry )) && { echo "would suspend"; exit 0; }
exec systemctl suspend
