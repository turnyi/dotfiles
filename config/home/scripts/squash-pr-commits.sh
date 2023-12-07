#!/usr/bin/env bash
#

COMMIT_COUNT=$(gh pr view --json commits | jq '.commits | length')
PR_NAME=$(gh pr view --json title | jq '.title' | sed -e 's/^"//' -e 's/"$//')

echo -e "🔍 Found $COMMIT_COUNT commits in PR: '$PR_NAME'"

echo -e "🚀 Squashing commits..."

git reset --soft HEAD~"$COMMIT_COUNT"

git add .

echo -e "📝 Committing changes..."

git commit -m "$PR_NAME"

echo -e "✅ Done!"
