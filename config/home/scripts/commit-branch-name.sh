#!/usr/bin/env bash
set -euo pipefail

BRANCH_NAME=$(git branch --show-current)
BRANCH_CARD_ID=$(echo "$BRANCH_NAME" | sed -n 's/\(ORIG-[0-9]*\).*/[\1]/p')
CARD_TITLE=$(echo "$BRANCH_NAME" | sed 's/ORIG-[0-9]*/ /;s/-/ /g;s/  */ /g')

echo $BRANCH_CARD_ID$CARD_TITLE
git commit -m "$BRANCH_CARD_ID$CARD_TITLE"
