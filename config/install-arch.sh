#!/usr/bin/env bash
set -e

PATTERN="$1"
echo "🔧 Installing system-wide and user-specific configurations..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_FILE="$SCRIPT_DIR/utils.sh"

echo $UTILS_FILE
source "$UTILS_FILE"
#
ETC_SOURCE="$SCRIPT_DIR/etc"
LOCAL_SHARE_SOURCE="$SCRIPT_DIR/.local/share"

# echo "📁 Stowing system configurations..."
# process_path "$ETC_SOURCE/keyd" "/etc/keyd" "keyd"
# process_path "$ETC_SOURCE/NetworkManager/conf.d" "/etc/NetworkManager/conf.d/" "conf.d"
# process_path "$ETC_SOURCE/pacman.d/hooks" "/etc/pacman.d/hooks" "pacman hooks"
# process_path "$ETC_SOURCE/udev/rules.d" "/etc/udev/rules.d/" "rules"
#
# # Process user-specific launchers
# echo "🎯 Stowing application launchers to ~/.local/share/applications..."
# mkdir -p "$HOME/.local/share/applications"
# process_path "$LOCAL_SHARE_SOURCE/applications" "$HOME/.local/share/applications" "user applications"

# Process user-specific rofi
echo "🎯 Stowing application launchers to ~/.local/share/applications..."
mkdir -p "$HOME/.local/share/rofi"
process_path "$LOCAL_SHARE_SOURCE/rofi" "$HOME/.local/share/rofi" "rofi"

# # Enable keyd if present
# if command -v keyd &>/dev/null; then
#   echo "🔑 Enabling keyd service..."
#   sudo systemctl enable --now keyd
# fi
#
# # Check and enable NetworkManager
# if systemctl list-unit-files | grep -q '^NetworkManager.service'; then
#   echo "🔍 NetworkManager is installed."
#
#   if ! systemctl is-enabled --quiet NetworkManager; then
#     echo "⚙️ Enabling and starting NetworkManager..."
#     sudo systemctl enable --now NetworkManager
#   else
#     echo "✅ NetworkManager is already enabled."
#   fi
# else
#   echo "❌ NetworkManager is not installed."
# fi
#
# # Check and enable bluetooth
# if systemctl list-unit-files | grep -q '^bluetooth.service'; then
#   echo "🔍 Bluetooth service is installed."
#
#   if ! systemctl is-enabled --quiet bluetooth; then
#     echo "⚙️ Enabling and starting Bluetooth..."
#     sudo systemctl enable --now bluetooth
#   else
#     echo "✅ Bluetooth is already enabled."
#   fi
# else
#   echo "❌ Bluetooth service is not installed."
# fi
#
# echo "🔒 Verificando grupo plugdev..."
# if ! getent group plugdev >/dev/null; then
#   echo "➕ Grupo 'plugdev' no existe. Creando..."
#   sudo groupadd plugdev
# else
#   echo "✅ Grupo 'plugdev' ya existe."
# fi
#
# echo "👤 Agregando usuario actual al grupo 'plugdev'..."
# sudo usermod -aG plugdev "$USER"
#
# echo "🔄 Recargando reglas udev..."
# sudo udevadm control --reload-rules
# sudo udevadm trigger
#
# echo "✅ System-wide and user dotfiles installed successfully."
