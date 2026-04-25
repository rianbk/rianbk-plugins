# rianbk-plugins

Personal Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces). One repo, multiple plugins.

## Install the marketplace

```text
/plugin marketplace add https://github.com/rianbk/rianbk-plugins
```

Then install whichever plugins you want (see list below).

## Plugins

| Plugin | What it does |
|---|---|
| [`1password`](plugins/1password/) | Workflow guidance + `/1password:setup` for using 1Password Environments (local `.env` mount) with the agent-hook validator. Plus `op` CLI usage. |

Install a specific plugin:

```text
/plugin install <name>@rianbk-plugins
```

## Repo layout

```
.claude-plugin/marketplace.json     # marketplace manifest, lists every plugin in this repo
.github/workflows/                  # CI: scheduled dependency-pin bumps, etc.
plugins/
  <plugin-name>/
    .claude-plugin/plugin.json      # per-plugin manifest
    skills/<skill-name>/SKILL.md    # auto-discovered
    commands/<cmd-name>.md          # auto-discovered
    README.md                       # per-plugin docs
```

When adding a new plugin, register it in `.claude-plugin/marketplace.json` under `plugins:` and create the directory under `plugins/`. See [`CLAUDE.md`](CLAUDE.md) for the full contract.

## CI and supply-chain

Scheduled workflows live in `.github/workflows/`. Third-party GitHub Actions used by these workflows are SHA-pinned (with a `# vX.Y.Z` comment) for the same supply-chain reasons that motivate plugin-side pinning. The `1password` plugin pins the upstream `agent-hooks` installer to a specific commit; weekly automation opens a PR when upstream `main` moves.

## License

MIT — see [`LICENSE`](LICENSE).
