#!/usr/bin/env bash

# GitHub PR checker for eww
# Uses GitHub CLI to fetch open PRs

# Check if gh is installed and authenticated
if ! command -v gh &> /dev/null; then
  echo '[{"repo":"Error","count":"--","icon":"","url":"","prs":[]}]'
  exit 0
fi

# Check authentication
if ! gh auth status &> /dev/null; then
  echo '[{"repo":"Auth Required","count":"--","icon":"🔑","url":"","prs":[]}]'
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
  
  # Get PR count and details
  pr_count=$(gh pr list --repo "$repo" --state open --json number --jq '. | length' 2>/dev/null)
  
  if [ -z "$pr_count" ]; then
    pr_count="0"
  fi
  
  # Get PR details (title, URL, and status checks) for first 5 PRs
  prs_raw=$(gh pr list --repo "$repo" --state open --limit 5 --json number,title,url,statusCheckRollup 2>/dev/null)
  
  if [ -z "$prs_raw" ]; then
    prs_json="[]"
  else
    # Process status checks to get overall status
    prs_json=$(echo "$prs_raw" | jq '[.[] | {
      number: .number,
      title: .title,
      url: .url,
      status: (
        if (.statusCheckRollup | length) == 0 then "NONE"
        elif (.statusCheckRollup | any(.conclusion == "FAILURE")) then "FAILURE"
        elif (.statusCheckRollup | any(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING")) then "PENDING"
        elif (.statusCheckRollup | all(.conclusion == "SUCCESS")) then "SUCCESS"
        else "UNKNOWN"
        end
      )
    }]')
  fi
  
  # Repository URL
  repo_url="https://github.com/$repo/pulls"
  
  if [ "$first" = false ]; then
    json_array+=","
  fi
  first=false
  
  json_array+="{\"repo\":\"$name\",\"count\":\"$pr_count\",\"icon\":\"$icon\",\"url\":\"$repo_url\",\"prs\":$prs_json}"
done

json_array+="]"

echo "$json_array"
