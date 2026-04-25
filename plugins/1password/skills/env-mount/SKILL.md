---
name: env-mount
description: Use when setting up secrets management in a project, mounting a 1Password Environment as a local .env file, installing or troubleshooting the 1Password agent-hook validator, or diagnosing missing environment variables in a project that uses (or should use) a 1Password Environment. Specifically covers the named-pipe local .env mount feature and the agent-hooks PreToolUse validator from github.com/1Password/agent-hooks.
allowed-tools: Bash(ls:*), Bash(file:*), Bash(test:*), Bash(stat:*), Bash(cat .claude/settings.json), Bash(grep -i 1password .claude/settings.json)
---

# 1Password local-`.env` mount + agent-hook validator

This skill is about *one specific* 1Password workflow: secrets sourced from a 1Password Environment that's mounted at `./.env` as a **named pipe** (FIFO), with the upstream agent-hook validator installed in the repo to fail-fast when the mount isn't unlocked.

It is NOT about the broader `op` CLI — for that, see the `cli-usage` skill.

## Hard rule for the agent

**Never read the contents of `.env` from this skill.** Only use metadata commands (`ls`, `file`, `stat`) on it. The mount feeds application processes; reading the FIFO when 1Password is unlocked streams real secrets into the conversation transcript (and any log/cache touching it). The agent-hook protects the locked case; this rule covers the unlocked case.

## Detect current state first

Before suggesting any setup steps, check what's already in place. The cheapest checks:

```bash
ls -la .env                              # named pipe = "prw-" perms; regular file = "-rw-"
file .env 2>/dev/null                    # explicit confirmation: "fifo (named pipe)"
test -e .claude/settings.json && cat .claude/settings.json | grep -i 1password   # hook installed?
test -f .1password/environments.toml     # explicit mount-paths config?
test -f .env.example                     # documented var names?
```

Decision tree based on what you find:

| `.env` is | Hook in `.claude/settings.json`? | Action |
|---|---|---|
| Missing | n/a | Walk user through mounting in the 1Password app (see "First-time mount") |
| Regular file | n/a | User is on plain `.env`. Confirm they want to switch before doing anything destructive. |
| Named pipe (FIFO) | No | Run `/1password:setup` to install the hook |
| Named pipe (FIFO) | Yes | Already set up. If they're hitting an error, see "Troubleshooting" |

## First-time mount (must be done in the 1Password app)

The mount itself cannot be created from the command line — it's a desktop-app feature, even in the latest `op` beta (2.35.0-beta.01 only adds `op environment read`, no creation/destination/mount verbs). Instruct the user:

1. Open the 1Password desktop app.
2. In the sidebar, expand **Developer** → click **Environments** (currently in beta).
3. Click **+ New environment**, give it a name (often the project name), click **Save**.
4. Click **View environment** on the new row, then switch to the **Destinations** tab.
5. Click **Choose file path** and select `<project root>/.env` in the file picker (the picker creates the destination entry; you don't need to make the file first).
6. Click **Mount .env file**. The destination row should switch to "Enabled".
7. Approve the auth prompt the first time something reads the file.

Variables can be left empty for setup purposes — the mount itself works without them. To populate later: use "New variable" for one-off entries, or drag a `.env`-shaped file (with real values filled in) onto the Variables tab's drop zone for bulk import. Never drag `.env.example` directly if it's committed to the repo with dummy values; copy it to a temp file, fill in real values, drag that, then delete.

After this, `ls -la .env` should show `prw-------` perms — that's the named pipe.

Then run `/1password:setup` to install the agent-hook validator.

## Installing the agent-hook validator

Always prefer `/1password:setup` over manual installation — it's idempotent, pins the upstream agent-hooks SHA for reproducibility, and handles the edge cases. The manual equivalent (mainly useful as a reference) is:

```bash
git clone https://github.com/1Password/agent-hooks /tmp/1p-agent-hooks
git -C /tmp/1p-agent-hooks checkout 22c246013ccf52113c6151708a4140b31aa47a95   # pinned in /1password:setup
/tmp/1p-agent-hooks/install.sh --agent claude-code --target-dir "$(pwd)"
```

This creates two things in the current repo:
- `.claude/claude-code-1password-hooks-bundle/` — the validator script
- `.claude/settings.json` — a `PreToolUse` Bash matcher that runs the validator before every Bash call

The hook fails-open (no-ops) if 1Password's database is unreachable, and it fails-closed (blocks the Bash call) if a configured mount isn't currently unlocked. That's intentional: it's a guardrail, not a hard security boundary.

## `.1password/environments.toml` — when to use it

For a single-mount repo, the validator auto-detects the mount and you don't need any config. For multi-mount repos, create `.1password/environments.toml` at project root listing the mount paths the hook should validate. Keep this committed — it's metadata, not secrets.

## Anti-patterns — refuse these or push back

- **`op run --env-file=.env -- <cmd>`** when a mount is already set up. The mount IS the env source; layering `op run` on top resolves nothing and confuses the next person to read the docker-compose. If the user asks for this, ask whether they meant to remove the mount and switch to the `op run` pattern.
- **Installing the hook in a repo that has no mount and no plans for one.** The hook is fail-open in that case so it won't break anything, but it's noise.
- **Storing provider keys in an app's admin UI before the app's *own* encryption key (e.g. `LITELLM_SALT_KEY`) is set in the Environment.** Rotating the encryption key later invalidates anything stored before it was set.
- **Putting the literal salt/encryption key in `.env.example`.** `.env.example` is documentation of *required var names*, not a copy template — the values come from the 1Password Environment.

## Caveats to surface to the user

- The mount feature is **beta**, **macOS/Linux only** (no Windows), and requires the desktop app running.
- Once unlocked, the pipe is readable like any file in the same shell session — protection comes from the locked state + the hook, not from the pipe itself being unreadable post-unlock.
- `docker compose restart` reuses the env captured at container creation. To pick up a rotated secret, use `docker compose up -d` (which re-reads the pipe) or `docker compose down && up -d`.
- Concurrent reads of the pipe can occasionally fail. For most workflows (single `docker compose up` reading once at startup) this is fine.

## Troubleshooting

- **`docker compose up` starts but the service errors with "missing key"**: the mount likely isn't unlocked. The user can trigger a 1Password auth prompt by running `cat .env > /dev/null` *in their own shell* (not via the agent — see the hard rule above) and approving, then retry.
- **Hook blocks every Bash call with no useful message**: check `/tmp/1password-hooks.log` per the upstream docs.
- **Hook doesn't fire at all**: confirm `.claude/settings.json` has the `PreToolUse` matcher and that the bundle directory exists.

## Authoritative docs (always link, don't re-encode)

Append `.md` to any 1Password docs URL to get clean markdown for `WebFetch`:

- Mount feature: <https://developer.1password.com/docs/environments/local-env-file.md>
- Agent-hook validator: <https://developer.1password.com/docs/environments/agent-hook-validate.md>
- Hook source: <https://github.com/1Password/agent-hooks>
- LLM-friendly index of all 1P docs: <https://developer.1password.com/llms.txt>

When the user asks something this skill doesn't explicitly cover (Connect, K8s Operator, service accounts), fetch the relevant `.md` URL rather than guessing.
