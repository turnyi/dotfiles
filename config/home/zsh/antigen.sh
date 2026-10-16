# *** *** Plugins *** ***

# Load the oh-my-zsh library
antigen use oh-my-zsh

# Bundles from the default repo
antigen bundle brew
antigen bundle docker
antigen bundle docker-compose
antigen bundle dotenv
antigen bundle fzf
antigen bundle git
antigen bundle jira
antigen bundle man
antigen bundle node
antigen bundle z
antigen bundle jq
antigen bundle gcloud
# antigen bundle yarn-autocompletions
# nvm is loaded once, last, from ~/.zshrc (this bundle loaded it early, behind Homebrew's node)
# antigen bundle lukechilds/zsh-nvm
antigen bundle Aloxaf/fzf-tab
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle zsh-users/zsh-completions
antigen bundle zdharma-continuum/fast-syntax-highlighting
antigen bundle hlissner/zsh-autopair
# antigen bundle buonomo/yarn-completion
antigen bundle lukechilds/zsh-better-npm-completion
# pyenv is initialised in ~/.zprofile. This bundle re-ran `pyenv init --path`,
# `pyenv init -` and `pyenv virtualenv-init -` a second time (~170ms).
# antigen bundle mattberther/zsh-pyenv
antigen bundle greymd/docker-zsh-completion
antigen bundle nekofar/zsh-pnpm
antigen bundle g-plane/pnpm-shell-completion@main
antigen apply
