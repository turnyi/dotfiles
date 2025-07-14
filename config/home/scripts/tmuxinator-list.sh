#!/usr/bin/env bash

# Get script root folder
root=$(dirname "$(readlink -f "$(which "$0")")")

red='\e[31m'
reset='\e[0m'

reload_projects() {
  listComponents=$(tmuxinator ls 2>/dev/null)
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
  done <<<"$projects"

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

# Si el script es llamado con --reload, solo imprime los proyectos y sale
if [[ "$1" == "--reload" ]]; then
  reload_projects
  exit 0
fi

# Llamado normal: mostrar selector interactivo
sortedProjects=$(reload_projects)

project=$(printf "%s\n" "${sortedProjects[@]}" | fzf-tmux -p 80%,60% \
  --bind "ctrl-x:execute-silent(tmux kill-session -t \"\$(echo {+} | cut -d ' ' -f 1)\")+reload($0 --reload)" \
  --header 'Press CTRL-X to close a session.')

if [ -n "$project" ]; then
  cleanProject=$(echo "$project" | sed 's/ (Open)//')
  tmuxinator start "$cleanProject" 2>/dev/null
fi
