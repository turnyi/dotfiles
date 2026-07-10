if [[ $OSTYPE == 'darwin'* ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Enable python-virtualenv
if which pyenv-virtualenv-init >/dev/null; then eval "$(pyenv virtualenv-init -)"; fi

# Pyenv
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - --no-rehash)"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
