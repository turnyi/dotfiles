#!/usr/bin/env bash
set -e

DOTFILES_DIR=~/Projects/dotfiles
CONFIG_PATH="$DOTFILES_DIR/config/.config"
HOME_SOURCE="$DOTFILES_DIR/config/home"
CONFIG_DIR="$HOME/.config"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Starting dotfiles setup..."

process_directories() {
  local source_path="$1"
  local target_base="$2"
  local label="$3"

  echo -e "\n📁 Processing $label directories:"
  local dirs=($(find "$source_path" -mindepth 1 -maxdepth 1 -type d | sed "s|^$source_path/||"))

  cd "$source_path"
  for dir in "${dirs[@]}"; do
    local target_dir="$target_base/$dir"
    echo "  ➤ 🧹 Removing existing directory: $target_dir"
    rm -rf "$target_dir"

    echo "  ➤ 🔗 Stowing directory: $dir → $target_dir"
    mkdir -p "$target_dir"
    stow -t "$target_dir" "$dir"
  done
}

process_files() {
  local source_path="$1"
  local target_base="$2"
  local label="$3"

  echo -e "\n📄 Processing $label files:"
  local files=($(find "$source_path" -mindepth 1 -maxdepth 1 -type f ! -name '.DS_Store' | sed "s|^$source_path/||"))

  for file in "${files[@]}"; do
    local source_file="$source_path/$file"
    local target_file="$target_base/$file"
    echo "  ➤ 🧹 Removing existing file: $target_file"
    rm -f "$target_file"

    echo "  ➤ 🔗 Symlinking file: $source_file → $target_file"
    ln -s "$source_file" "$target_file"
  done
}

process_path() {
  local source_path="$1"
  local target_path="$2"
  local label="$3"

  process_directories "$source_path" "$target_path" "$label"
  process_files "$source_path" "$target_path" "$label"
}

# process_path "$CONFIG_PATH" "$CONFIG_DIR" ".config"
# process_path "$HOME_SOURCE" "$HOME" "HOME"

if grep -qi "arch" /etc/os-release; then
  echo "🟢 Running on Arch Linux"
  arch_install="$SCRIPT_DIR/install-arch.sh"
  bash $arch_install
fi

echo -e "\n✅ Dotfiles setup completed successfully."
