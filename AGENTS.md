# AGENTS
## Architecture
- System files are symlinked (via `ln -s`) to files in this dotfiles project
- Changes to files in this project will reflect in the system locations
- Bootstrap script (`./install.sh`) creates the necessary symlinks
## Commands
- Bootstrap: `./install.sh`
- Arch setup: `./setup-arch.sh`
- Mac setup: `./setup-mac.sh`
- Lint shell: `shellcheck ./**/*.sh`
- Format shell: `shfmt -w .`
- Format Lua: `stylua .`
- Validate Neovim: `nvim --headless -c 'checkhealth' -c q`
- Tests: none defined
## Style Guidelines
- Indentation: 2 spaces, no tabs
- Strings: always double-quoted
- Imports: externals first, then relative
- Naming: snake_case for shell, camelCase for Lua, kebab-case for CSS
- Constants: UPPER_SNAKE
- Functions: lower_snake_case in shell, camelCase in Lua
- Error handling: `set -euo pipefail`, validate args, exit early
- Types/Annotations: use `---@` annotations in Lua
## Cursor & Copilot: none detected