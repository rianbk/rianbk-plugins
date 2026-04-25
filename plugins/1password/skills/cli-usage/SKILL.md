---
name: cli-usage
description: Use when the user wants to interact with 1Password from the command line via the `op` CLI — installing/signing in, reading secrets, creating or editing items, listing vaults, or writing `op://vault/item/field` references for use in shell scripts, dotenv files, Docker, or language-level dotenv libraries. Includes the `op run --env-file` injection pattern and when to prefer it vs the local-`.env` mount (covered by the `env-mount` skill).
allowed-tools: Bash(op:*), Bash(brew:*), Bash(which:*), Bash(cat:*), Bash(grep:*)
---

# 1Password `op` CLI

Covers the everyday `op` CLI surface: install, signin, read/write items, reference syntax, and the `op run` injection pattern.

For the local-`.env` mount workflow (named pipe + agent-hook), see the `env-mount` skill — these two skills are intentionally separate because they serve different needs and can both apply in one repo.

## Install + signin

```bash
brew install 1password-cli              # macOS
op --version                            # confirm
op signin                               # interactive; integrates with desktop app if installed
```

If the desktop app is installed and signed in, `op` uses biometric/system auth. Without the desktop app, `op signin` prompts for the secret key + master password and stores a session token in the shell.

For non-interactive use (CI, servers), use a **service account** instead — set `OP_SERVICE_ACCOUNT_TOKEN` in the environment and `op` runs without an interactive signin. (Service-account workflow is broader than this skill covers; for depth, fetch <https://developer.1password.com/docs/service-accounts.md>.)

## Reading secrets

```bash
op item get "GitHub Token"                          # by name (or UUID)
op item get "GitHub Token" --vault Personal         # disambiguate by vault
op item get "GitHub Token" --fields token           # specific field
op item get "GitHub Token" --format json | jq       # full item as JSON

op read "op://Personal/GitHub Token/token"          # the canonical read-by-reference form
```

`op read` with an `op://` reference is the form you'll use most — it's what `op run`, the local-`.env` mount, and most SDK integrations resolve at runtime.

## Writing items

```bash
# Create a new password-category item with a generated 32-char hex value
op item create --category=password --title="myapp" --vault=Personal \
  salt_key="$(openssl rand -hex 32)"

# Add or update a field on an existing item
op item edit "myapp" salt_key="$(openssl rand -hex 32)" --vault=Personal

# Delete (be careful — this is irreversible without a vault backup)
op item delete "myapp" --vault=Personal --archive    # --archive is safer than hard delete
```

For multi-field items, pass `field=value` pairs after the title — each becomes a field on the item.

## `op://vault/item/field` reference syntax

The canonical form is `op://<vault>/<item>/<field>`. Spaces in vault or item names are URL-allowed; quote in shells:

```text
op://Personal/GitHub Token/token
op://Shared/myapp/ANTHROPIC_API_KEY
op://Shared/myapp/master_key/password    # for password-category items, the value lives at .password
```

Where you can use these references:

- **In `.env` files** consumed by `op run --env-file`: `ANTHROPIC_API_KEY=op://Shared/myapp/ANTHROPIC_API_KEY`
- **In Docker `env_file:`** the same way (after `op run` resolves them — Docker doesn't resolve `op://` natively).
- **In language-level dotenv libraries**: most don't resolve `op://` directly; resolve via `op run` or via the local-`.env` mount.
- **In templates** with `op inject`: `op inject -i config.tpl -o config.json` reads `op://...` placeholders and writes the resolved file.

## `op run` — injection pattern

```bash
op run --env-file=.env -- docker compose up -d
op run --env-file=.env -- npm start
```

`op run` reads `.env`, resolves any `op://` references via your active 1Password session, exports the results into the child process env, and never writes plaintext to disk.

**Decision: `op run` vs the local-`.env` mount** (which is the `env-mount` skill's territory):

| Situation | Recommendation |
|---|---|
| Mac/Linux desktop, single project | Local-`.env` mount + agent-hook (env-mount skill) |
| Linux server, no desktop app | `op run` with a service account token |
| Cross-platform team including Windows | `op run` (mount is Mac/Linux only) |
| CI | Service account + `op run` |

Don't layer them: if a mount is active at `./.env`, an additional `op run --env-file=.env` is redundant and confusing. Pick one.

## Common workflows

**Generate a strong secret + store it:**
```bash
op item edit "myapp" --vault=Shared salt_key="$(openssl rand -hex 32)"
```

**Pull a secret into a one-off shell variable:**
```bash
export GITHUB_TOKEN="$(op read 'op://Personal/GitHub Token/token')"
```

**See what's in a vault:**
```bash
op vault list
op item list --vault=Personal --format=json | jq '.[] | .title'
```

## Anti-patterns

- **Pasting secrets directly into the shell** when `op read` would work — they end up in shell history.
- **Storing the secret value in source control** "just for testing" — use `op run` with a fake-but-real-shaped placeholder Environment instead.
- **Hardcoding `op://` references that name a specific vault when the project might run under different vaults per developer** — agree on a vault naming convention up front.

## Authoritative docs

Append `.md` to any 1Password docs URL for clean markdown:

- CLI getting started: <https://developer.1password.com/docs/cli/get-started.md>
- `op` reference: <https://developer.1password.com/docs/cli/reference.md>
- Secret references syntax: <https://developer.1password.com/docs/cli/secret-references.md>
- Service accounts: <https://developer.1password.com/docs/service-accounts.md>
- LLM-friendly index of all 1P docs: <https://developer.1password.com/llms.txt>

When the user asks about something not covered here (SDKs, Connect server, K8s Operator, SSH agent), fetch the relevant `.md` URL rather than guessing.
