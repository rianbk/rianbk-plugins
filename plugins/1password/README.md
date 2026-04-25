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

The plugin layers a few mechanisms, each covering a different concern. This is *defense in depth*, not a hard security boundary — read the honest caveats at the end.

### When 1Password is locked

The mount itself is the defense. `.env` is a named pipe served by 1Password's desktop app — when 1P is locked, the OS auth flow blocks reads of the pipe (or fails them outright). This is built into how the mount works, not something the plugin adds.

### When 1Password is unlocked

The harder case. Once 1P is unlocked, reading the FIFO succeeds and values stream to whoever read them. The plugin layers two structural defenses + one instructional one:

1. **FIFO-read blocker** (this plugin's own hook, `plugins/1password/hooks/hooks.json`) — auto-loads at plugin install. PreToolUse matcher on `Read|Edit|MultiEdit|Write|NotebookEdit` runs `scripts/block-fifo-read.sh`, which denies any tool call whose target path is a named pipe. This is the actual runtime guardrail against AI-agent reads of `.env` via non-Bash tools — the path Claude Code defaults to for "show me file X."
2. **Upstream agent-hook config validator** (installed by `/1password:setup`) — a Bash PreToolUse matcher provided by 1Password. **It's a configuration validator, not a security tool** ([per its README](https://github.com/1Password/agent-hooks/blob/main/hooks/1password-validate-mounted-env-files/README.md)): it "validates and verifies 1Password setup" and uses a "fail open" approach when 1P is unavailable. Its value: catches misconfiguration (disabled destinations, missing FIFOs, path mismatches) and surfaces clear "fix this" messages before Bash execution. Limit: it only fires on Bash, so non-Bash tool calls bypass it (which is why layer 1 above exists).
3. **Hard rule in command + skill bodies** — instructional guardrail telling Claude not to read `.env` via any tool. Backstop for tool surfaces neither hook catches (e.g., a future CC tool we haven't enumerated in layer 1's matcher).

### Operational hardening

- **SHA-pinned upstream installer.** `/1password:setup` installs from a specific commit of [github.com/1Password/agent-hooks](https://github.com/1Password/agent-hooks), not whatever upstream `main` happens to be. Bumps are automated weekly via [a GitHub Action](https://github.com/rianbk/rianbk-plugins/blob/main/.github/workflows/bump-agent-hooks.yml) that opens a review-required PR with the upstream commit log + diff stat. Bump PRs are not auto-merged.

### Honest caveats

- The plugin can't protect against an attacker with shell access in your unlocked session.
- Layer 1's matcher only covers the file tools we enumerated. A future tool that reads files through a different mechanism would bypass it until we extend the matcher.
- Layer 2 (upstream) is fail-open by design: when 1P is locked or its database is unavailable, it allows execution rather than blocks. It's helping you keep your 1P config correct, not enforcing lock state.
- The "1P locked → mount unreadable" defense holds for *initial* reads but not for already-cached values: once a process has the secret in memory, locking 1P doesn't claw it back.

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
