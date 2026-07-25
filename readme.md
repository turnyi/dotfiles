# Running a script test

hello world

## TODO — node / nvm cleanup (2026-07-24)

Context: `nvm use <ver>` wasn't sticking on the Mac — Homebrew's node (v26) shadowed
nvm because the `lukechilds/zsh-nvm` antigen bundle loaded nvm *early*, behind brew.
Fixed by disabling that bundle (`zsh/antigen.sh`) and adding `nvm use default --silent`
to `.zshrc`, then removing brew node. Remaining items:

- [ ] **Commit + push these dotfiles changes** so they sync to other machines:
      - `config/home/.zshrc` (added `nvm use default --silent`)
      - `config/home/zsh/antigen.sh` (commented out `antigen bundle lukechilds/zsh-nvm`)

- [ ] **On Arch, after pulling:** verify nvm still loads and node is correct:
      ```sh
      ls ~/.nvm/nvm.sh && node -v
      ```
      If `~/.nvm/nvm.sh` is missing (e.g. nvm installed via pacman at
      `/usr/share/nvm`), the `.zshrc` load block won't find it now that the
      antigen bundle is gone — make the nvm-load block OS-agnostic (source
      whichever path exists).

- [ ] **Remove unused, redundant node managers on the Mac** (kept only nvm):
      ```sh
      brew uninstall fnm          # fnm, unused
      rm -rf ~/.local/n           # 'n', unused; also drop ~/.local/n/bin from PATH
      ```
      Then check `~/.zshrc` / exports for any `N_PREFIX` or `~/.local/n/bin` PATH entry.

- [ ] (optional) The globals under `/opt/homebrew/lib/node_modules`
      (`ccstatusline`, `tree-sitter-cli`, `neovim`) still work via `#!/usr/bin/env node`
      → nvm node, but live in brew's prefix. Reinstall under nvm for tidiness if desired:
      `npm i -g ccstatusline tree-sitter-cli neovim` then remove the brew-prefix copies.
