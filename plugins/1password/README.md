# 1password

Claude Code plugin for using [1Password Environments](https://developer.1password.com/docs/environments/local-env-file) (the local `.env` mount) with the [1Password agent-hooks validator](https://github.com/1Password/agent-hooks). Includes guidance for everyday `op` CLI usage.

## What it gives you

- **`/1password:setup`** — one shot to wire up the agent-hook validator in the current repo and scaffold a documentation `.env.example`. Idempotent. Installs from a SHA-pinned upstream agent-hooks revision.
- **`env-mount` skill** — Claude recognizes a 1Password-mounted `.env` (a named pipe), walks you through the desktop-only mount setup when missing, and knows how to install or troubleshoot the agent-hook validator. Refuses to read `.env` contents directly.
- **`cli-usage` skill** — Claude knows the `op` CLI verbs (`op signin`, `op item get/edit/create`, `op read`) and how to write `op://vault/item/field` references for use in shell, dotenv files, Docker, and language-level dotenv libraries.

## Why

The local-`.env` mount publishes secrets through a named pipe instead of writing them to disk. Combined with the agent-hooks validator, shell commands won't run when 1Password is locked or when the mount isn't configured — an agent operating in the repo can't see secrets that haven't been deliberately unlocked.

## Install

```text
/plugin marketplace add https://github.com/rianbk/rianbk-plugins
/plugin install 1password@rianbk-plugins
```

Then run `/1password:setup` inside any project where you want to use a 1Password Environment. The first run walks you through mounting `.env` in the desktop app if you haven't yet; subsequent runs install the agent-hook validator and scaffold a `.env.example` if missing.

## Security model

Three layers, each covering a different case:

1. **Agent-hook validator** (installed by `/1password:setup`) — fires on every `Bash` tool call in the repo. Fails-closed if 1Password is locked: shell commands won't run until you unlock. This is the runtime guardrail. Fails-open (no-op) if 1Password's database is unreachable — so it's a guardrail, not a hard security boundary.
2. **Hard rule against agent reads of `.env`** (in the command body and `env-mount` skill) — Claude won't `cat`/`grep`/`head` the `.env` mount itself, even when 1Password is unlocked. Prevents real secrets from streaming into Claude's conversation transcript and any log/cache touching it.
3. **SHA-pinned agent-hooks installer** — `/1password:setup` installs from a specific commit of [github.com/1Password/agent-hooks](https://github.com/1Password/agent-hooks), not whatever upstream `main` happens to be. Bumps are automated weekly via [a GitHub Action](https://github.com/rianbk/rianbk-plugins/blob/main/.github/workflows/bump-agent-hooks.yml) that opens a PR with the upstream commit log + diff stat for review. Bump PRs are not auto-merged.

Honest caveats: once 1Password is unlocked, the FIFO is readable like any file in the same shell session — protection here comes from the locked state plus the validator + soft rule, not from the pipe being unreadable post-unlock. The hook also doesn't protect against an attacker with shell access in your unlocked session.

## Requirements

- macOS or Linux (the local `.env` mount feature is in beta and not supported on Windows).
- 1Password desktop app + at least one [Environment](https://developer.1password.com/docs/environments/) configured to mount as a local `.env`.
- `git` (for `/1password:setup` to clone the upstream `agent-hooks` repo).
- Optional: `op` CLI (`brew install 1password-cli`) for the `cli-usage` skill's surface.

## Out of scope

- Service accounts and CI patterns
- 1Password Connect server / Kubernetes Operator
- Secret rotation slash commands (`/1p-add`, `/1p-rotate` may land later)
- Any CLI automation of Environment creation, destination configuration, or variable management — those are desktop-only as of `op` 2.35.0-beta.01 (the beta only adds `op environment read`).

For 1Password topics this plugin doesn't cover, see the [1Password developer docs](https://developer.1password.com/) — every page accepts a `.md` URL suffix and there's a [`/llms.txt`](https://developer.1password.com/llms.txt) index optimized for LLM consumption.

## License

MIT
