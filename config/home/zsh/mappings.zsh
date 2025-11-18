# Enable edit-command-line widget
autoload -Uz edit-command-line
zle -N edit-command-line

# # [C-x] - Edit the current command line in $EDITOR
bindkey '^x' edit-command-line

# # [C-space] - Accept current suggestion
bindkey '^ ' autosuggest-accept

# Vi mode mappings
bindkey -M vicmd 'k' up-line-or-beginning-search
bindkey -M vicmd 'j' down-line-or-beginning-search

# # =============
# # Key-bindings
# # =============
bindkey -s '^b' 'tls^M'
bindkey -s '^p' 'tmuxinator-list.sh^M'
bindkey -s '^f' 'tmux-sessionizer.sh^M'
bindkey -s '^n' 'tns^M'
bindkey -s '^e' 'hexec.sh^M'
bindkey -s '^h' 'history.sh^M'
bindkey -s '^g' '. get-process.sh^M'
bindkey -s '^z' 'squash-pr-commits.sh^M'
bindkey -s '^d' 'commit-branch-name.sh^M'

# File path operations
bindkey -s 'fn' 'fn^M'
bindkey -s 'fm' 'fm^M'
