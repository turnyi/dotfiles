# Global opencode Configuration
## Style Rules
Try to keep things in one function unless composable or reusable
DO NOT do unnecessary destructuring of variables
DO NOT use else statements unless necessary
DO NOT use try/catch if it can be avoided
AVOID try/catch where possible
AVOID else statements
AVOID using `any` type
AVOID `let` statements
PREFER single word variable names where possible
- Check for existing tests before adding new tests
- Do not add extra unnecessary comments

## Best Practices
- Write tests for every new feature or bugfix if the projects has tests
- Update or add documentation/README when introducing APIs
- Run lint/format/typecheck (e.g. `shellcheck`, `stylua`, `shfmt`, `nvim --headless -c 'checkhealth' -c q`) before committing
- Use imperative‑mood, issue‑referencing commit messages
- Keep PRs small and scoped to a single concern

## Nice‑to‑Have Additions
- Code‑review checklist (e.g. security, performance, accessibility)
- CONTRIBUTING.md with PR template and branch‑naming conventions
- Security guidelines (no secrets in code, validate external inputs)
- Performance benchmarking for long‑running scripts/functions
- Accessibility/localization reminders for UI components
