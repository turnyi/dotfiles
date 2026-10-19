#!/usr/bin/env bash
set -e

echo "🍺 Installing Homebrew..."

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "✅ Homebrew installed."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BREWFILE="$SCRIPT_DIR/packages/Brewfile"

if [[ -f "$BREWFILE" ]]; then
  echo "📦 Installing packages from $BREWFILE..."
  brew bundle --file="$BREWFILE"
else
  echo "⚠️  No Brewfile found at $BREWFILE — skipping package installation."
fi

POST_INSTALL="$SCRIPT_DIR/config/install.sh"

if [[ -f "$POST_INSTALL" ]]; then
  echo "🚀 Running $POST_INSTALL..."
  bash "$POST_INSTALL"
else
  echo "⚠️  No post-install script found at $POST_INSTALL."
fi

# Kitty's secure keyboard entry grabs macOS secure input, which blocks
# AeroSpace's global hotkeys whenever kitty is focused.
defaults write net.kovidgoyal.kitty SecureKeyboardEntry -bool false

echo "🏁 Setup complete."
