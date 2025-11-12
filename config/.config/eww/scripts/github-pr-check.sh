#!/usr/bin/env bash

# GitHub PR checker for eww
# Uses GitHub CLI to fetch open PRs

# Check if gh is installed and authenticated
if ! command -v gh &> /dev/null; then
  echo '[{"repo":"Error","count":"--","icon":""}]'
  exit 0
fi

# Check authentication
if ! gh auth status &> /dev/null; then
  echo '[{"repo":"Auth Required","count":"--","icon":"🔑"}]'
  exit 0
fi

# Repositories to check
repos=(
  "opti-Task/backend:Back:🖥"
  "opti-Task/Web:Web:🌐"
  "opti-Task/Mobile:Mobile:📱"
)

json_array="["
first=true

for repo_info in "${repos[@]}"; do
  IFS=':' read -r repo name icon <<< "$repo_info"
  
  # Get PR count
  pr_count=$(gh pr list --repo "$repo" --state open --json number --jq '. | length' 2>/dev/null)
  
  if [ -z "$pr_count" ]; then
    pr_count="0"
  fi
  
  if [ "$first" = false ]; then
    json_array+=","
  fi
  first=false
  
  json_array+="{\"repo\":\"$name\",\"count\":\"$pr_count\",\"icon\":\"$icon\"}"
done

json_array+="]"

echo "$json_array"
