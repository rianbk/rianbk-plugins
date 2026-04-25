---
description: Wire up the 1Password agent-hook validator in the current repo and scaffold a .env.example. Idempotent.
allowed-tools: Bash(ls:*), Bash(file:*), Bash(test:*), Bash(stat:*), Bash(cat .claude/settings.json), Bash(head -200 .env.example), Bash(grep -i 1password .claude/settings.json), Bash(git rev-parse --show-toplevel), Bash(git clone https://github.com/1Password/agent-hooks /tmp/1p-agent-hooks), Bash(git -C /tmp/1p-agent-hooks fetch origin), Bash(git -C /tmp/1p-agent-hooks checkout 22c246013ccf52113c6151708a4140b31aa47a95), Bash(/tmp/1p-agent-hooks/install.sh:*)
---

## Context

- Current directory: !`pwd`
- `.env` status: !`ls -la .env 2>/dev/null && file .env 2>/dev/null || echo "NO .env FILE"`
- Existing hook config: !`test -f .claude/settings.json && cat .claude/settings.json | grep -i 1password || echo "NO HOOK CONFIG"`
- Existing hook bundle: !`test -d .claude/claude-code-1password-hooks-bundle && echo "BUNDLE EXISTS" || echo "NO BUNDLE"`
- `.env.example` contents (or "MISSING"): !`test -f .env.example && head -200 .env.example || echo "MISSING"`
- Repo root indicator: !`git rev-parse --show-toplevel 2>/dev/null || echo "NOT A GIT REPO"`
- 1p-agent-hooks repo at `/tmp`: !`test -d /tmp/1p-agent-hooks && echo "PRESENT" || echo "ABSENT"`

## Your task

Wire up the 1Password agent-hook validator in the current repository. This is a deterministic, idempotent operation. Follow these steps in order. Stop and report cleanly at any short-circuit condition rather than forcing forward.

**Never read the contents of `.env`.** Use only metadata commands (`ls`, `file`, `stat`) when inspecting it. The mount is intended for application processes, not the agent — reading the FIFO when 1Password is unlocked streams real secrets into this conversation.

### Step 1 — Verify the mount

Inspect the `.env` line above.

- **If `.env` is a named pipe** (perms start with `prw`, or `file` reports "fifo (named pipe)"): the mount is in place. Continue to step 2.
- **If `.env` is missing**: the user has not yet mounted a 1Password Environment here. STOP. Tell them:
  > No `.env` file found. Before I can install the agent-hook, you need to mount a 1Password Environment here:
  > 1. Open the 1Password desktop app.
  > 2. In the sidebar, expand **Developer** → click **Environments** (Beta).
  > 3. Click **+ New environment**, give it a name, then **Save**.
  > 4. Click **View environment** on the new row, then switch to the **Destinations** tab.
  > 5. Click **Choose file path** and select `<this directory>/.env` in the file picker.
  > 6. Click **Mount .env file** — the destination should now show "Enabled".
  >
  > Then re-run `/1password:setup`.

  If the context above includes `.env.example` contents (not "MISSING"), append a "Variables to populate in your Environment:" section to that message listing the env var names you can identify in the file. Use judgment — skip comments, prose, and section headers; surface the actual var names. This gives the user a checklist for the Variables tab.

  Also mention: the Variables tab supports drag-and-drop import as a bulk shortcut. The user can copy `.env.example` to a temporary file (e.g. `.env.values`), fill in real values, drag that file onto the Variables tab's drop zone, then delete the temp file. Do NOT suggest dragging `.env.example` itself — it's typically checked into the repo and lacks real values.
- **If `.env` is a regular file** (perms start with `-rw`): the user is on plain `.env`. STOP. Tell them:
  > `.env` exists as a regular file, not a 1Password mount. Installing the agent-hook on a non-mounted repo is noise. If you want to switch to a 1Password Environment, follow the mount steps above first; the existing `.env` will need to be removed (back up its values into a 1Password item before deleting). I won't touch it without your go-ahead.

### Step 2 — Check for an existing install (idempotency)

If the context above shows "BUNDLE EXISTS" AND does NOT show "NO HOOK CONFIG" (i.e. the bundle directory exists AND `.claude/settings.json` references 1password), the hook is already installed. STOP and report:
> Agent-hook validator is already installed in this repo. Nothing to do.

If only one of the two exists (partial install), report the inconsistency to the user and ask whether to overwrite before proceeding.

### Step 3 — Install the upstream agent-hook (pinned SHA)

The agent-hooks installer is pinned to commit `22c246013ccf52113c6151708a4140b31aa47a95` for supply-chain reproducibility. Every install runs from exactly this revision, regardless of where upstream `main` has moved.

Run these as **separate** Bash calls (do not combine into a single shell block — each must match an `allowed-tools` entry to skip the permission prompt).

Sync `/tmp/1p-agent-hooks` to the pinned SHA. Use the "1p-agent-hooks repo" line in the context above:
- **If "ABSENT"**: run `git clone https://github.com/1Password/agent-hooks /tmp/1p-agent-hooks`
- **If "PRESENT"**: run `git -C /tmp/1p-agent-hooks fetch origin`
- **(Always next)**: run `git -C /tmp/1p-agent-hooks checkout 22c246013ccf52113c6151708a4140b31aa47a95`

Then run the installer, substituting the absolute path from "Current directory" in the context for `<current-dir>` (do NOT use `$(pwd)` or any subshell):

```text
/tmp/1p-agent-hooks/install.sh --agent claude-code --target-dir <current-dir>
```

This creates `.claude/claude-code-1password-hooks-bundle/` and `.claude/settings.json` (or merges into an existing one). If it errors, surface the error to the user verbatim and stop — do not try to "fix" it by editing `.claude/settings.json` directly.

(To bump the pinned SHA: update the `git checkout` line above AND the matching `Bash(git -C /tmp/1p-agent-hooks checkout <SHA>)` entry in this file's frontmatter `allowed-tools`. They must agree.)

### Step 4 — Scaffold `.env.example` if missing

Only if `.env.example` is reported MISSING above, create it with this exact content:

```text
# This file documents the env vars the project needs.
# Values are not stored here — they come from a 1Password Environment
# mounted at ./.env (see https://developer.1password.com/docs/environments/local-env-file).
#
# Each line below names an env var the application reads. To onboard,
# add a matching field to the 1Password Environment item that feeds this mount.

# Add var names below, one per line, e.g.:
# DATABASE_URL=
# API_KEY=
```

If `.env.example` already exists, leave it alone. The user may have curated it.

### Step 5 — Report and ask about git tracking

Tell the user:
- What was created (paths)
- That the hook will fire on every `Bash` tool call in this repo and may prompt for 1Password unlock if locked
- If the context above includes `.env.example` contents, list the env var names you can identify from it so the user can verify their Environment's Variables tab is fully populated.
- Ask whether to add `.claude/` to git so the hook travels with the repo (recommended for personal repos; the user may prefer to gitignore it for shared/team repos). Do NOT run `git add` yourself — let them decide and act.

That's the full command. Don't do anything else.
