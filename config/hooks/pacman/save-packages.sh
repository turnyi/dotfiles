#!/usr/bin/env bash

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
DOTFILES_DIR="$USER_HOME/Projects/dotfiles/packages"

mkdir -p "$DOTFILES_DIR"

comm -23 <(pacman -Qq | sort) <(pacman -Qqm | sort) >"$DOTFILES_DIR/pacman-packages.txt"

# Save AUR packages
pacman -Qmq >"$DOTFILES_DIR/yay-packages.txt"
