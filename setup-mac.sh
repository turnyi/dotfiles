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

# Desktop wallpaper: the kitty background photo, blurred and washed grey so the
# desktop and terminal read as one surface. Regenerate from config/images with:
#   magick background.jpg -resize 3024x -crop 3024x1964+0+1215 +repage \
#     -resize 50% -blur 0x11 -resize 3024x1964! -blur 0x2 \
#     -modulate 100,60 \( +clone -fill black -colorize 100 \) \
#     -compose blend -define compose:args=70 -composite -depth 8 desktop-blurred.png
# PNG, not JPEG: compression blocks show up as grain in a dark, smooth gradient.
# System Events' `set picture` silently no-ops on recent macOS; NSWorkspace sticks.
osascript -l JavaScript -e "
ObjC.import('AppKit');
const url = \$.NSURL.fileURLWithPath('$SCRIPT_DIR/config/images/desktop-blurred.png');
const screens = \$.NSScreen.screens;
for (let i = 0; i < screens.count; i++)
  \$.NSWorkspace.sharedWorkspace.setDesktopImageURLForScreenOptionsError(url, screens.objectAtIndex(i), \$(), null);"

echo "🏁 Setup complete."
