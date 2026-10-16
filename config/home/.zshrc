

# The oh-my-zsh docker plugin regenerates its completion on every single start,
# forking OrbStack's 72MB docker binary twice to do it. This zstyle takes the
# plugin's cheap `cp`-a-bundled-file path instead; the block further down keeps
# a current, natively generated _docker ahead of it in fpath.
zstyle ':omz:plugins:docker' legacy-completion yes

#install plugins
source "$HOME/zsh/antigen_install.zsh"
source "$HOME/zsh/antigen.sh"
[[ -f "$HOME/.env" ]] && source "$HOME/.env"
export ZSH_DOTENV_ALLOWED_LIST=~/dotenv/allowed.list
export ZSH_DOTENV_DISALLOWED_LIST=~/dotenv/disallowed.list

# Add custom script stowed to ~/bin and ~/vntana_bin to path
export PATH="$HOME/scripts:$PATH"
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"
export PATH="$PATH:$HOME/.dotnet/tools"

# Configure the folder where all zsh configuration will live.
export ZDOTDIR=$HOME

# Useful zsh options. See man zshoptions
setopt autocd extendedglob nomatch menucomplete
setopt interactive_comments
# Automatically list choices on ambiguous completion.
setopt auto_list
# Automatically use menu completion.
setopt auto_menu
# Move cursor to end if word has one match.
setopt always_to_end

# Remove beep
unsetopt BEEP

# Change bindkey timeout to 1s
export KEYTIMEOUT=100

# Completitions
autoload -Uz compinit
zstyle ':completion:*' menu select
zmodload zsh/complist

# Compinit. Include hidden files.
_comp_options+=(globdots)

autoload -U up-line-or-beggining-search
autoload -U down-line-or-beggining-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
zle -N backward-delete-charbindkey
zle -N menuselect
zle -N up-lne-or-history

# Enable vi mode for zsh command line
bindkey -v

# Colors
autoload -Uz colors && colors

# Autosuggest Highlighting
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=7,bg=bold,underline"

export KEYTIMEOUT=100
export RIPGREP_CONFIG_PATH=$HOME/.ripgreprc
export GIT_EDITOR=nvim
export EDITOR=nvim

# fzf-tab recommended configuration.
# Disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# Set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# Set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Preview directory's content with exa when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'exa -1 --color=always $realpath'
# Switch group using `,` and `.`
zstyle ':fzf-tab:*' switch-group ',' '.'

# FD
FD_OPTIONS="--follow --exclude .git --exclude node_modules"
export FZF_DEFAULT_OPTS='--no-height'

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Ruby
export PATH="/usr/local/opt/ruby/bin:$PATH"

# Bat
export BAT_PAGER="less -R"

# Bun
export PATH="$HOME/.bun/bin:$PATH"

# Regenerate docker's own completion weekly in the background rather than every
# shell. Written via a temp file so compinit never reads a half-finished one.
() {
  local dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
  fpath=("$dir" $fpath)
  [[ -n $dir/_docker(#qN.mh-168) ]] && return
  (( $+commands[docker] )) || return
  mkdir -p "$dir"
  { docker completion zsh >| "$dir/_docker.new" 2>/dev/null &&
      mv -f "$dir/_docker.new" "$dir/_docker" } &!
}

autoload bashcompinit && bashcompinit
# Rebuild the completion dump at most once a day; -C otherwise skips both the
# compaudit security scan and the ~150ms compdump rewrite that oh-my-zsh's own
# compinit already invalidates on every start.
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# Normal files to source
source "$HOME/zsh/exports.zsh"
source "$HOME/zsh/aliases.zsh"
source "$HOME/zsh/prompt.zsh"
source "$HOME/zsh/history.zsh"
source "$HOME/zsh/mappings.zsh"
source "$HOME/zsh/keyring.zsh"
source "$HOME/zsh/linear.zsh"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/martinradovitzky/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/martinradovitzky/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/martinradovitzky/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/martinradovitzky/google-cloud-sdk/completion.zsh.inc'; fi
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
# Enable word navigation with Ctrl + arrow keys
bindkey '^[[1;5C' forward-word     # Ctrl + right arrow
bindkey '^[[1;5D' backward-word    # Ctrl + left arrow

export PATH="/opt/homebrew/opt/curl/bin:$PATH"

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# tabtab source for packages
# uninstall by removing these lines
[[ -f ~/.config/tabtab/zsh/__tabtab.zsh ]] && . ~/.config/tabtab/zsh/__tabtab.zsh || true


source "$HOME/zsh/evals.zsh"

# pnpm
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
# Self-heal a stale PNPM_HOME inherited from the environment (e.g. a macOS
# /Users/... path leaking into a Linux session via synced dotfiles). If the
# resolved home isn't a real directory here, fall back to the Linux default.
if [[ "$OSTYPE" != darwin* ]] && { [[ "$PNPM_HOME" == /Users/* ]] || [[ ! -d "$PNPM_HOME" ]]; }; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  mkdir -p "$PNPM_HOME"
fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/centinel/dev-cli.json"

# nvm (Node Version Manager)
# Must load LAST: exports.zsh and other blocks above re-prepend /opt/homebrew/bin,
# which would shadow nvm's node with Homebrew's.
export NVM_DIR="$HOME/.nvm"

# Sourcing nvm.sh and running `nvm use default` costs ~1.1s of the ~1.6s startup:
# nvm.sh is 4k lines of POSIX shell and every alias lookup forks. All it
# ultimately does here is prepend one bin dir, so do that by reading the alias
# file, and defer nvm.sh itself until something actually calls `nvm`.
() {
  local target dir
  local -a cands
  [[ -r "$NVM_DIR/alias/default" ]] || return
  target=$(<"$NVM_DIR/alias/default")
  # default may point at another alias (lts/*, node) rather than a version.
  [[ -r "$NVM_DIR/alias/$target" ]] && target=$(<"$NVM_DIR/alias/$target")
  # Numeric glob sort, else v24.9.0 would sort above v24.18.0.
  cands=("$NVM_DIR"/versions/node/v${target#v}*(Nn/))
  (( $#cands )) || return
  dir=$cands[-1]
  export NVM_BIN="$dir/bin"
  export PATH="$NVM_BIN:$PATH"
}

# First `nvm` call pays for the real thing. --no-use skips nvm_auto (~380ms),
# which would only redo the PATH prepend above.
nvm() {
  unfunction nvm
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" --no-use
  nvm "$@"
}

# PATH hygiene, last word after every block above (and after /etc/zprofile's
# path_helper, .zprofile, and orbstack have each had their turn). Without this
# PATH carried 88 entries, 36 of them nonexistent and 25 duplicated: every
# command lookup walked all of them and compinit scanned each one.
# -U keeps the first occurrence, so precedence is preserved; the glob drops
# entries that aren't directories. Both re-run each shell, so a directory
# created later (cargo, go, an Android SDK) reappears on the next one.
typeset -U path fpath
path=($^path(N-/))
fpath=($^fpath(N-/))
