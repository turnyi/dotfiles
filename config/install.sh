#!/usr/bin/env bash

set -e

# Install link of home files
rm -rf ~/scripts ~/zsh ~/.tmux.conf ~/.zprofile ~/.zshrc ~/.DS_Store ~/Notes ~/.bashrc rm -rf ~/.fonts

echo "$(pwd)"
stow -t ~ home

# Install config files
rm -rf ~/.config/ohmyposh ~/.config/nvim ~/.config/gh ~/.config/tmuxinator 
mkdir -p .config && cd .config &&  mkdir ~/.config/ohmyposh && stow -t ~/.config/ohmyposh ohmyposh 
mkdir ~/.config/nvim && stow -t ~/.config/nvim nvim
mkdir ~/.config/gh && stow -t ~/.config/gh gh
mkdir ~/.config/tmuxinator && stow -t ~/.config/tmuxinator tmuxinator

