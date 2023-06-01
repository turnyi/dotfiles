#!/usr/bin/env bash

# Get script root folder
root=$(dirname "$(readlink -f "$(which "$0")")")

red='\e[31m'
reset='\e[0m'

reload_projects() {
  listComponents=$(tmuxinator ls 2> /dev/null)
  projectLine=$(echo "$listComponents" | awk 'NR>1')

  if [ -z "$projectLine" ]; then
    echo -e "${red}No tmuxinator projects${reset}"
    exit 1
  fi

  projects=$(echo "$projectLine" | awk '{ for(i=1; i<=NF; i++) print $i }')

  openProjects=()
  closedProjects=()

  while IFS= read -r project; do
    if tmux has-session -t "$project" >/dev/null 2>&1; then
      openProjects+=("$project")
    else
      closedProjects+=("$project")
    fi
  done <<< "$projects"

  sortedOpenProjects=($(printf '%s\n' "${openProjects[@]}" | sort -r))
  sortedClosedProjects=($(printf '%s\n' "${closedProjects[@]}" | sort -r))

  sortedProjects=()
  for project in "${sortedOpenProjects[@]}"; do
    sortedProjects+=("$project (Open)")
  done
  for project in "${sortedClosedProjects[@]}"; do
    sortedProjects+=("$project")
  done

  printf '%s\n' "${sortedProjects[@]}"
}

sortedProjects=$(reload_projects)

project=$(printf "%s\n" "${sortedProjects[@]}" | fzf-tmux -p 80%,60% \
  --bind 'ctrl-r:execute(tmux has-session -t "$(echo {+} | cut -d " " -f 3)" && tmux kill-session -t "$(echo {+} | cut -d " " -f 1)"; tmuxinator start "$(echo {+} | cut -d " " -f 1)" 2> /dev/null)' \
  --bind 'ctrl-x:execute-silent(tmux kill-session -t "$(echo {+} | cut -d " " -f 1)")+reload(reload_projects)' \
  --header 'Press CTRL-R to reload a session.
Press CTRL-X to close a session.')

if [[ $project == *" (Open)" ]]; then
  project="${project% (Open)}"
fi

if [ -n "$project" ]; then
  tmuxinator start "$project" 2> /dev/null
fi
