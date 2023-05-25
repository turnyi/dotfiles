#!/usr/bin/env bash

# Get script root folder
ROOT=$(dirname "$(readlink -f "$(which "$0")")")

red='\e[31m'
reset='\e[0m'

listComponents=$(tmuxinator ls 2> /dev/null)
projectLine=$(echo "$listComponents" | awk 'NR>1')

if [ -z "$projectLine" ]; then
  echo -e "${red}No tmuxinator projects${reset}"
  exit 1
fi

projects=$(echo "$projectLine" | awk '{ for(i=1; i<=NF; i++) print $i }')

open_projects=()
closed_projects=()

while IFS= read -r project; do
  if tmux has-session -t "$project" >/dev/null 2>&1; then
    open_projects+=("$project")
  else
    closed_projects+=("$project")
  fi
done <<< "$projects"

sorted_open_projects=($(printf '%s\n' "${open_projects[@]}" | sort))
sorted_closed_projects=($(printf '%s\n' "${closed_projects[@]}" | sort))

sorted_projects=()
for project in "${sorted_open_projects[@]}"; do
  sorted_projects+=("$project (Open)")
done
for project in "${sorted_closed_projects[@]}"; do
  sorted_projects+=("$project")
done

project=$(printf "%s\n" "${sorted_projects[@]}" | fzf-tmux -p 80%,60% --header 'Select project to open')

if [ -n "$project" ]; then
  tmuxinator start "$project" 2> /dev/null
fi
