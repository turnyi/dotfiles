#!/usr/bin/env bash
set -e

DOTFILES_DIR=~/Projects/dotfiles
CONFIG_PATH="$DOTFILES_DIR/config/.config"
HOME_SOURCE="$DOTFILES_DIR/config/home"
CONFIG_DIR="$HOME/.config"

echo "🔧 Starting dotfiles setup..."

echo -e "\n📁 Processing .config directories:"
CONFIGS=($(find "$CONFIG_PATH" -mindepth 1 -maxdepth 1 -type d | sed "s|^$CONFIG_PATH/||"))

cd "$CONFIG_PATH"
for dir in "${CONFIGS[@]}"; do
  targetDir="$CONFIG_DIR/$dir"
  echo "  ➤ 🧹 Removing existing directory: $targetDir"
  rm -rf "$targetDir"

  echo "  ➤ 🔗 Stowing directory: $dir → $targetDir"
  mkdir -p "$targetDir"
  stow -t "$targetDir" "$dir"
done

echo -e "\n📄 Processing individual files in .config:"
FILES=($(find "$CONFIG_PATH" -mindepth 1 -maxdepth 1 -type f ! -name '.DS_Store' | sed "s|^$CONFIG_PATH/||"))

for file in "${FILES[@]}"; do
  sourceFile="$CONFIG_PATH/$file"
  targetFile="$CONFIG_DIR/$file"
  echo "  ➤ 🧹 Removing existing file: $targetFile"
  rm -f "$targetFile"

  echo "  ➤ 🔗 Symlinking file: $sourceFile → $targetFile"
  ln -s "$sourceFile" "$targetFile"
done

cd "$DOTFILES_DIR"

echo -e "\n🏠 Processing HOME directories:"

HOME_DIRS=($(find "$HOME_SOURCE" -mindepth 1 -maxdepth 1 -type d | sed "s|^$HOME_SOURCE/||"))

cd "$HOME_SOURCE"
for dir in "${HOME_DIRS[@]}"; do
  targetDir="$HOME/$dir"
  echo "  ➤ 🧹 Removing existing HOME directory: $targetDir"
  rm -rf "$targetDir"

  echo "  ➤ 🔗 Stowing HOME directory: $dir → $targetDir"
  mkdir -p "$targetDir"
  stow -t "$targetDir" "$dir"
done

echo -e "\n✅ Dotfiles setup completed successfully."

FILES=($(find "$HOME_SOURCE" -mindepth 1 -maxdepth 1 -type f ! -name '.DS_Store' | sed "s|^$HOME_SOURCE/||"))

for file in "${FILES[@]}"; do
  sourceFile="$HOME_SOURCE/$file"
  targetFile="$HOME/$file"
  echo "  ➤ 🧹 Removing existing file: $targetFile"
  rm -f "$targetFile"

  echo "  ➤ 🔗 Symlinking file: $sourceFile → $targetFile"
  ln -s "$sourceFile" "$targetFile"
done
