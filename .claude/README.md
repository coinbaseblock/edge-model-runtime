# Claude Code integration

This folder configures Claude Code for the edge-model-runtime repo.

## Slash commands

| Command | What it does |
|---|---|
| `/install` | First-time install (`scripts/00-install.sh`) |
| `/pull <model>` | Pull an Ollama model |
| `/nemotron [variant]` | Pull a Nemotron variant (default: `nano`) |
| `/verify` | Health check |
| `/status` | Alias for `/verify` |
| `/disk` | Disk usage breakdown |
| `/cleanup` | Level-2 cleanup (containers + images, keep models) |
| `/uninstall` | Interactive 4-tier uninstall menu |

## Unified CLI

The repo also ships a `bin/emr` dispatcher (Claude-Code / Codex-style UX). After
`scripts/00-install.sh` installs the symlink, `emr <subcommand>` works from
any directory. Run `emr help` for the full list.

## Permissions

`settings.json` allow-lists exactly the scripts and read-only Docker commands
needed for normal operation. Destructive commands (`20-wipe-models.sh`,
`docker volume rm`, `sudo rm -rf`, `.env` edits) are denied — the user must run
those themselves.
