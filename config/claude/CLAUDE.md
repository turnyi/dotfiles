# Memory

## Tools & integrations
- **Trello**: available via Composio MCP (toolkit slug `trello`, account active as `martinradovitzky`). Use `COMPOSIO_SEARCH_TOOLS` then `COMPOSIO_MULTI_EXECUTE_TOOL` with tools like `TRELLO_GET_MEMBERS_BOARDS_BY_ID_MEMBER`. Do NOT say "I don't have Trello access" — it's connected through Composio.
- User's Trello boards (as of 2026-04-20):
  - Comercial — https://trello.com/b/iRHXdOe0/comercial
  - Marketing — https://trello.com/b/4R6cBnfb/marketing
  - My Trello board — https://trello.com/b/Zf6UVMcg/my-trello-board
  - Workspace/org id: `69e22bb31123cfad924ea97a`

## Coding Standards

- **NEVER generate inline explanations, block comments, or TODOs.**
- **Code must be self-documenting. Write only functional code.**
- **Remove any redundant or auto-generated comments if you modify a file.**

### Exception: this dotfiles repo

Comments are permitted in `~/Projects/dotfiles`, but only when **extremely
justified** — the bar is knowledge that cannot be recovered by reading the code:
an upstream bug or version-gated behaviour, a non-obvious exit code, a
destructive side effect, or why an obvious simpler approach was rejected.
Restating what a line does is still forbidden.

## Working style

- **Always work in a git worktree when writing code.** Before any task that edits
  files, runs/starts the app or dev stack, runs tests, or makes commits, move into a
  dedicated worktree instead of working in the main checkout. Read-only work
  (questions, explanations, code lookups, reviews with no edits) can stay in the
  current directory — no worktree needed.
  - If a suitable worktree for the task already exists, use it; otherwise create one.
  - In the Centinel repo, use `pnpm worktree:bootstrap <name>` (creates the worktree
    off `staging`, copies env files, installs deps), then `EnterWorktree` into it.
    Elsewhere, use `git worktree add` (and install deps).
  - When the work is merged/abandoned and the worktree is clean + pushed, remove it
    to avoid pile-up.

## Output style

- **Always invoke the `i-have-adhd` skill at the start of every session**, before
  responding to the first message, and follow it for every reply — coding, debugging,
  planning, and casual conversation alike. Do not wait for the user to type
  `/i-have-adhd`.
