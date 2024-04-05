
#!/usr/bin/env bash

ROOT=$(dirname $(readlink -f $(which "$0")))

if [ -f "$ROOT/secrets.zsh" ]; then
  source "$ROOT/secrets.zsh"
fi

if [ -f "$ROOT/secrets.zsh" ]; then
  source "$ROOT/secrets.zsh"
fi
# Configure default ansible config file
export ANSIBLE_CONFIG=~/.ansible.cfg

# Color man pages
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# Use nvim to read Man pages
export MANPAGER='nvim +Man!'
export MANWIDTH=999

# Add cargo binary directory to the path.
export PATH=$PATH:${HOME}/.cargo/bin

# Add a user binary directory to the path.
export PATH=$PATH:${HOME}/.local/bin

# Fix perl locale issue
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

# Fix OpenSSL link issue
export LDFLAGS="-L/usr/local/opt/openssl@1.1/lib"
export CPPFLAGS="-I/usr/local/opt/openssl@1.1/include"
export PATH="/usr/local/opt/openssl@1.1/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "${HOME}/.local/google-cloud-sdk/path.zsh.inc" ]; then . "${HOME}/.local/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "${HOME}/.local/google-cloud-sdk/completion.zsh.inc" ]; then . "${HOME}/.local/google-cloud-sdk/completion.zsh.inc"; fi

# Add gcloud to the global path
export PATH=$PATH:"${HOME}/.local/google-cloud-sdk/bin"
export USE_GKE_GCLOUD_AUTH_PLUGIN=True

# Add n to the global path and configure N_PREFIX
export PATH=$PATH:"${HOME}/.local/n/bin"
export N_PREFIX="${HOME}/.local/n/versions"

# Configure Perl path
PATH="${HOME}/perl5/bin${PATH:+:${PATH}}"
export PATH
PERL5LIB="${HOME}/perl5/lib/perl5${PERL5LI:+:${PERL5LIB}}"
export PERL5LIB
PERL_LOCAL_LIB_ROOT="${HOME}/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
export PERL_LOCAL_LIB_ROOT
PERL_MB_OPT="--install_base \"${HOME}/perl5\""
export PERL_MB_OPT
PERL_MM_OPT="INSTALL_BASE=${HOME}/perl5"
export PERL_MM_OPT

# Configure `fd` to work nicely with `fzf`.
export FZF_DEFAULT_COMMAND='fd --type file --follow --hidden --exclude .git --exclude node_modules'
export FZF_DEFAULT_OPTS="--color=bg+:#292e42,spinner:#bb9af7,hl:#565f89,fg:#c0caf5,header:#565f89,info:#7dcfff,pointer:#bb9af7,marker:#7dcfff,fg+:#c0caf5,prompt:#bb9af7,hl+:#bb9af7"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"


# Configure nvim as the default editor
export EDITOR=nvim

# Add Go binary folder to the PATH
export PATH=$PATH:"$HOME/go/bin"
export GO111MODULE='on'

# Enable nvm autocompletions
export NVM_COMPLETION=true

## Colours and font styles
## Syntax: echo -e "${FOREGROUND_COLOUR}${BACKGROUND_COLOUR}${STYLE}Hello world!${RESET_ALL}"

# Escape sequence and resets
export ESC_SEQ="\x1b["
export RESET_ALL="${ESC_SEQ}0m"
export RESET_BOLD="${ESC_SEQ}21m"
export RESET_UL="${ESC_SEQ}24m"

export ZSH_TMUX_AUTOSTART=true
export ZSH_TMUX_ITERM2=true
export ZSH_TMUX_CONFIG=$HOME/.tmux.conf

export ZSH_DOTENV_ALLOWED_LIST=~/dotenv/allowed.list
export ZSH_DOTENV_DISALLOWED_LIST=~/dotenv/disallowed.list

# Set andorid studio home variables
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

source ~/zsh/.env

