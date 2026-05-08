# Project context for Claude Code

This file is read automatically by Claude Code when working in this repo. Keep it concise — it's loaded into every session.

## What this project is

A Docker-based runtime for local LLMs on Linux + NVIDIA. Targets MSI EdgeXpert but works on any Ubuntu+NVIDIA machine. Two core services (Ollama + Open WebUI) plus optional vLLM and PyTorch training profiles.

## Non-negotiable invariants

These rules MUST be preserved by any change:

1. **Models live on the host**, never inside container layers. The bind mount `${AI_DATA_ROOT}/ollama → /root/.ollama` is the entire reason this stack works. Do not replace it with named volumes. Do not add a second mount for "models" elsewhere.
2. **Rebuilds must not re-download models.** Test any compose change with: `docker compose down && docker compose up -d` — `ollama list` afterwards must show the same models.
3. **Three cleanup levels are deliberate**: `02-stop.sh` (containers only), `10-cleanup-docker.sh` (images too, models kept), `20-wipe-models.sh` (everything, requires `DELETE ALL` phrase). Do not collapse these into one script.
4. **No `chmod 777`.** Use `u+rwX,g+rwX,o-rwx`.
5. **No `latest` or `main` tags in `.env.versions`** for production. Pinned tags only.
6. **vLLM and training images are opt-in via Compose profiles.** They must NOT be pulled by `00-install.sh`.

## Where things live

| Concern | File |
|---|---|
| Service definitions | `docker-compose.yml` |
| Runtime config (paths, ports, tunables) | `.env` (from `.env.example`) |
| Pinned image tags | `.env.versions` |
| Shared bash helpers | `scripts/lib/common.sh` |
| Operations | `scripts/NN-*.sh` (numbered by lifecycle) |
| Architecture rationale | `docs/ARCHITECTURE.md` |
| User-facing fixes | `docs/TROUBLESHOOTING.md` |

## Conventions

- All scripts source `scripts/lib/common.sh` for `compose`, `load_env`, `confirm`, logging helpers.
- Scripts are numbered by lifecycle stage: `0x` install/start, `1x` cleanup, `2x` destructive.
- All compose invocations go through the `compose` wrapper — it always passes both env files.
- Use `set -euo pipefail` in every script (already in `common.sh`).
- Bash, not zsh. Target Ubuntu 22.04+.

## Common requests and how to handle them

- **"Add a new model"** → don't edit code; the user runs `bash scripts/04-pull-model.sh <name>`.
- **"Add a new service"** → add to `docker-compose.yml` under a profile if it's heavy. Bind-mount any persistent data under `${AI_DATA_ROOT}/<service>`. Update `08-disk-report.sh` and `10-cleanup-docker.sh` to know about its image.
- **"Update images"** → edit `.env.versions`, then run `bash scripts/09-update-images.sh`.
- **"Reset everything"** → `bash scripts/20-wipe-models.sh` then `bash scripts/00-install.sh`.

## Testing changes

After any compose or script change:

```bash
bash scripts/02-stop.sh
bash scripts/01-start.sh
bash scripts/03-verify.sh
bash scripts/05-list-models.sh   # must still show pre-existing models
```

## Things to push back on

If a user asks for any of these, explain the trade-off before doing it:

- Switching to Docker named volumes (loses host visibility, harder backup)
- Adding `chmod 777` "to fix permissions" (wrong fix; check ownership instead)
- Pinning to `latest` (breaks reproducibility)
- Auto-pulling vLLM/training images in `00-install.sh` (large download, opt-in is intentional)
- Merging cleanup scripts into one (loses safety tier)
