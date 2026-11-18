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

mkdir -p "$HOME/.config/svim"
for f in blacklist svimrc svim.sh; do
  ln -sfn "$SCRIPT_DIR/config/.config/svim/$f" "$HOME/.config/svim/$f"
done

# Patched svim: lets Option (AeroSpace) and F6 (Ctrl+h/j/k/l section cycling)
# through in NORMAL. Pinned so brew upgrade doesn't overwrite it; rerun after unpinning.
SVIM_SRC="$(mktemp -d)"
git clone --depth 1 https://github.com/FelixKratz/SketchyVim "$SVIM_SRC"
git -C "$SVIM_SRC" apply --unidiff-zero "$SCRIPT_DIR/packages/svim/pass-option-and-f6.patch"
make -C "$SVIM_SRC"

# Sign with a stable self-signed identity so the Accessibility grant survives
# rebuilds (an ad-hoc signature changes every build and macOS drops the grant).
SVIM_SIGN_IDENTITY="svim-codesign"
LOGIN_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
if ! security find-certificate -c "$SVIM_SIGN_IDENTITY" "$LOGIN_KEYCHAIN" >/dev/null 2>&1; then
  SIGN_TMP="$(mktemp -d)"
  /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -subj "/CN=$SVIM_SIGN_IDENTITY" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -keyout "$SIGN_TMP/key.pem" -out "$SIGN_TMP/cert.pem"
  /usr/bin/openssl pkcs12 -export -passout pass:svim \
    -inkey "$SIGN_TMP/key.pem" -in "$SIGN_TMP/cert.pem" -out "$SIGN_TMP/identity.p12"
  security import "$SIGN_TMP/identity.p12" -k "$LOGIN_KEYCHAIN" -P svim -T /usr/bin/codesign
  rm -rf "$SIGN_TMP"
fi
codesign --force --sign "$SVIM_SIGN_IDENTITY" --identifier svim "$SVIM_SRC/bin/svim"

cp "$SVIM_SRC/bin/svim" "$(brew --prefix)/bin/svim"
rm -rf "$SVIM_SRC"
brew pin svim
brew services restart svim

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
