#!/usr/bin/env bash
exec "$(dirname "$(readlink -f "$0")")/claude-statusline.sh" --prefix
