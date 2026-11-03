sync-tmux-env() {
  [[ -n "$TMUX" ]] || return 0
  eval "$(tmux show-environment -s 2>/dev/null)"
}
autoload -U add-zsh-hook
add-zsh-hook precmd sync-tmux-env
