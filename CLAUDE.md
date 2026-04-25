# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal Claude Code plugin marketplace owned by Rian Brooks-Kane (`rian@rianbk.com`, GitHub: `rianbk`). Every plugin in here ships under one marketplace named `rianbk-plugins`. The marketplace name controls the `<plugin>@rianbk-plugins` install syntax — don't change it without updating every README and the `.claude-plugin/marketplace.json` `name` field together.

## Plugin contract (read before adding or modifying anything)

- **Marketplace manifest** (`.claude-plugin/marketplace.json`) is the single source of truth for which plugins exist. Each plugin must be listed in the `plugins: []` array with a `source` field pointing at its directory. If a plugin's `plugins/<name>/` directory exists but isn't registered here, it's invisible to installers.
- **`marketplace.json` schema gotchas** (caught by `claude plugin validate .`):
  - The marketplace-level description goes under `metadata.description`, NOT at the root.
  - Don't add a `$schema` key at the root — the validator rejects it as unrecognized even though JSON tolerates it.
  - Required root keys: `name`, `owner`, `plugins`.
- **Plugin manifest** (`plugins/<name>/.claude-plugin/plugin.json`) only requires `name`, but always include `version`, `description`, `author`, `repository`, `license`, and `keywords` for marketplace presentation.
- **Two descriptions, keep them in sync**: the `/plugin install` UI reads `description` from the plugin's entry in `marketplace.json`, NOT from `plugin.json`. Update both together when the plugin's scope changes.
- **Components auto-discover** from `skills/`, `commands/`, `agents/`, `hooks/`, `.mcp.json`, `.lsp.json`, `monitors/` — don't add manifest paths unless the layout deviates.
- **Skills**: each is a directory under `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, `allowed-tools`). The `description` is the trigger — write it as "Use when…" language, since that's what Claude pattern-matches against.
- **Commands**: each is a single markdown file under `commands/<name>.md` with frontmatter (`description`, `allowed-tools`). The body is instructions *for Claude* (not the user) — written in the imperative.
- **Per-plugin README** lives at `plugins/<name>/README.md` for human-facing docs. Top-level `README.md` is the marketplace overview.

## Adding a new plugin

1. `mkdir -p plugins/<new>/.claude-plugin plugins/<new>/skills plugins/<new>/commands`
2. Create `plugins/<new>/.claude-plugin/plugin.json` mirroring the existing one's shape.
3. Add an entry to the top-level `marketplace.json` `plugins: []` array with `source: "./plugins/<new>"`.
4. Update `marketplace.json`'s top-level `description` if it has become plugin-specific (currently scoped to 1password — generalize when broadening).
5. Add a row to the top-level `README.md` plugin table.
6. Write `plugins/<new>/README.md`.
7. Test locally: `/plugin marketplace remove rianbk-plugins; /plugin marketplace add .; /plugin install <new>@rianbk-plugins`.

## Local development workflow

- No build, lint, or test pipeline — plugins are markdown + JSON. Verification is manual: refresh the marketplace and exercise the skill/command in a real session.
- After any edit, the marketplace must be re-added or refreshed for changes to load. From a Claude Code session in another directory: `/plugin marketplace remove rianbk-plugins; /plugin marketplace add <path-to-this-repo>`.
- The `/plugin install` Discover screen also caches plugin metadata in-process. After remove+add, if an install screen still shows stale data, press `Esc` to back out and re-enter `/plugin install <name>@rianbk-plugins` — that re-fetches. (Quitting the session works too but is overkill.)
- Skills don't need a "reload" — once the marketplace refresh picks them up, they activate on matching prompts.
- Slash command frontmatter changes require a marketplace refresh; body changes hot-reload on next invocation.

## Plugin-specific notes

### `1password`

Targets the **local-`.env` mount** workflow (`.env` as a named pipe from the 1Password desktop app) plus the upstream [agent-hooks validator](https://github.com/1Password/agent-hooks). Deliberately scoped to skip: service accounts, Connect server, Kubernetes Operator, MCP server wrapping `op`, and rotation commands (`/1p-add`, `/1p-rotate`). Don't expand without checking with the user first — the small surface is intentional.

The agent-hooks installer is **SHA-pinned** for supply-chain reproducibility. The SHA appears in `plugins/1password/commands/setup.md` (frontmatter `allowed-tools` entry + Step 3 prose + Step 3 `git checkout` instruction) and `plugins/1password/skills/env-mount/SKILL.md` (manual-install snippet) — all four occurrences must agree. Bumps are automated by `.github/workflows/bump-agent-hooks.yml` (weekly cron + `workflow_dispatch`); when upstream `main` differs from the pinned SHA, the workflow opens a PR that includes the upstream commit log + diff stat. **Never auto-merge the bump PR** — review the diff for changes to `install.sh` or what the installer drops into target repos before approving.

## CI workflows

- `.github/workflows/validate.yml` — runs `claude plugin validate .` on every push and PR. Catches malformed `marketplace.json`/`plugin.json` and skill/command frontmatter before merge. No secrets, no auth — the validate command is local-structure-only.
- `.github/workflows/bump-agent-hooks.yml` — described above. Weekly auto-PR for upstream `agent-hooks` SHA bumps.

GitHub Actions in `.github/workflows/` use **SHA-pinned** third-party actions for the same supply-chain reason. When updating an action, look up the new tag's commit SHA via `git ls-remote --tags <repo>` and update both the SHA and the `# vX.Y.Z` comment together.

The mount feature is **beta, macOS/Linux only**. Refuse Windows requests cleanly.

When `/1password:setup` runs in a repo without an existing mount, the command short-circuits with instructions for the user to create the mount in the desktop app — that's by design, not a bug.

The 1Password developer docs accept a `.md` suffix on any URL (e.g. `https://developer.1password.com/docs/environments/local-env-file.md`) and there's an LLM-friendly index at `https://developer.1password.com/llms.txt`. Prefer `WebFetch` against those over encoding 1Password content into skill bodies — keeps the skills thin and the canonical source authoritative.

## Out of scope for this repo

- Cross-platform packaging (Cursor, Windsurf, Copilot). Skills are written in the SKILL.md format which is portable, but distribution is Claude Code-only. If cross-platform comes up, point at OpenSkills / agent-skill-creator rather than building it here.
- The user's local test-target repo (the real project they exercise the `1password` plugin against) stays untouched unless they explicitly ask. Don't write into other working trees on the user's machine to demo or validate.
