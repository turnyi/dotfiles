# Running a script test

hello world

## shot2server — paste screenshots into Claude Code over SSH

Claude Code's `Ctrl+V` reads the clipboard of the machine it runs on, so an
image copied locally never reaches a remote session. `scripts/shot2server.sh`
uploads the screenshot to `~/.shots` on the `server` ssh host and puts the
absolute remote path on the clipboard; paste it as text (`Ctrl+Shift+V` in
kitty) and Claude reads the image.

Bindings: Hyprland `Super+Alt+S` (region select → server), Aerospace
`Alt+Ctrl+S` (clipboard image → server). Override the target with
`SHOT2SERVER_HOST` / `SHOT2SERVER_DEST`.

### Mac setup

```sh
cd ~/Projects/dotfiles && git pull
brew bundle --file=packages/Brewfile        # adds pngpaste
bash config/install.sh scripts              # re-stow ~/scripts (.aerospace.toml is a file symlink, already live)
aerospace reload-config
grep -q '^Host server' ~/.ssh/config || cat >> ~/.ssh/config <<'EOF'
Host server
    HostName 100.67.199.59
    User turny
    IdentityFile ~/.ssh/id_ed25519
EOF
ssh server true                             # accept the host key once
pngpaste - >/dev/null && ~/scripts/shot2server.sh && pbpaste   # smoke test with an image on the clipboard
```

Take screenshots with `Cmd+Ctrl+Shift+4` so they land on the clipboard, then
`Alt+Ctrl+S`. Files land outside the project cwd, so Claude Code prompts once
per read; point `SHOT2SERVER_DEST` at a gitignored dir inside the repo to skip
the prompt.

## ClipCascade — shared clipboard (text and images) across machines

A self-hosted [ClipCascade](https://github.com/Sathvik-Rao/ClipCascade) server
runs in Docker on the `turny` box, published tailnet-only at
`https://turny.tail02a788.ts.net:8686` by `tailscale serve`. Every machine runs
a client; `scripts/clipcascade.sh setup` installs and logs it in, and
`config/install.sh` calls that, so a fresh checkout needs nothing else:

```sh
cd ~/Projects/dotfiles && git pull
bash config/install.sh scripts
```

- **Server host (`turny`)**: starts the container, replaces the default admin
  password with a random one in `~/.config/clipcascade/password` (never in the
  repo), and Hyprland autostarts the headless client.
- **Mac**: downloads the app into `/Applications`, fetches the password over
  ssh from the server host, pre-seeds the login, adds a login item, and opens
  it. Needs Tailscale up and `ssh turny@turny.tail02a788.ts.net` working
  (override with `CLIPCASCADE_SSH` / `CLIPCASCADE_HOST`).

Encryption is off on every client on purpose: it is the only mode where a
client can log back in unattended, and traffic already rides Tailscale + TLS.
A server restart logs all devices out; the Linux launcher restarts its client
within a minute, the Mac app needs a relaunch.

Manual Mac login, if the script cannot be used: server URL above, user
`admin`, password from the server host's `~/.config/clipcascade/password`,
"Enable Encryption" unchecked, "Save Password" checked.

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
