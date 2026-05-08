# edge-model-runtime

> Production-grade Docker runtime for running and training local LLMs on NVIDIA edge machines — MSI EdgeXpert, NVIDIA DGX Spark, or any Ubuntu + NVIDIA host.

Tested on:
- **MSI EdgeXpert** (x86_64, discrete GPU)
- **NVIDIA DGX Spark** (arm64/aarch64, GB10 / DGX OS 7.x, kernel 6.17 nvidia)
- Generic Ubuntu 22.04+ with NVIDIA Container Toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/docker-compose-blue.svg)](https://docs.docker.com/compose/)
[![NVIDIA](https://img.shields.io/badge/NVIDIA-GPU-76B900.svg)](https://developer.nvidia.com/cuda-toolkit)

This stack runs local LLMs (Ollama + Open WebUI) with optional vLLM and PyTorch training profiles. **All models and data live outside containers**, so rebuilds, image upgrades, and Docker cleanups never force model re-downloads.

---

## ✨ Features

- 🐳 **100% Dockerized** — nothing installed on host OS
- 💾 **Persistent models** — host-side storage, survives rebuilds
- 🛡️ **3-tier cleanup** — safe → medium → nuclear
- 🎮 **Full NVIDIA GPU** support via Container Toolkit
- 🔌 **Optional profiles** — vLLM and PyTorch training (not pulled by default)
- 📌 **Pinned image versions** — reproducible deployments
- 🔐 **No `chmod 777`** — proper permission management
- 🩺 **Health checks** built in
- 🤖 **Claude Code ready** — see [`.claude/`](./.claude) for AI-assisted workflows
- 🧠 **Local AI coding agent** — drive [OpenCode (100% offline)](./docs/AI-CODING-SETUP.md#option-a--opencode-100-local) or [Claude Code + Ollama-as-worker via MCP](./docs/AI-CODING-SETUP.md#option-b--claude-code--ollama-as-worker)
- ☁️ **Unified Web UI** — optional [LiteLLM proxy](./docs/AI-CODING-SETUP.md#option-c--unified-web-ui-cloud--local-in-one-dropdown) puts Claude / GPT / Gemini in the same Open WebUI dropdown as your local models, also surfaced in OpenCode
- 🌐 **Web Codex playbook (TH)** — step-by-step browser workflow for Codex/Claude-style local coding in Open WebUI: [docs/WEB-CODEX-PLAYBOOK.md](./docs/WEB-CODEX-PLAYBOOK.md)
- 🪄 **Claude Code TUI on local Ollama** — [Option D](./docs/AI-CODING-SETUP.md#option-d--claude-code-tui-local-ollama-brain) routes the official `claude` CLI through LiteLLM's Anthropic adapter so a local model is the brain — same UX, no subscription burn

---

## 📋 Requirements

| Component | Version |
|-----------|---------|
| Ubuntu Linux (or DGX OS) | 22.04+ / DGX OS 7.x |
| Architecture | `x86_64` or `arm64` (aarch64) |
| Docker Engine | 24.0+ |
| Docker Compose | v2.20+ |
| NVIDIA Driver | 535+ (any driver shipped with DGX OS works) |
| NVIDIA Container Toolkit | latest |
| Data disk | any path with ≥ 100 GB free, set via `AI_DATA_ROOT` in `.env` |

> **DGX Spark note:** DGX OS ships with Docker + NVIDIA Container Toolkit pre-installed, so you can skip the toolkit install below. Verify with `docker info | grep -i runtime` — you should see `nvidia`.

Install NVIDIA Container Toolkit:
```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

---

## 📁 Data Layout

All persistent data is on the host disk — **never inside containers**. The root path is whatever you set `AI_DATA_ROOT` to in `.env`:

```text
${AI_DATA_ROOT}/
├── ollama/        # Ollama models — DO NOT DELETE
├── open-webui/    # WebUI database & settings
├── hf-cache/      # HuggingFace cache (optional vLLM)
├── training/      # Optional training output
└── logs/          # Container logs (rotated)
```

Recommended values for `AI_DATA_ROOT`:

| Host | Recommended path |
|---|---|
| MSI EdgeXpert | `/mnt/edge-backup/ai-data` (external/secondary disk) |
| NVIDIA DGX Spark | `/home/<user>/ai-data` (single 1 TB NVMe; ~915 GB usable) |
| Generic Ubuntu | wherever you have ≥ 100 GB free |

> ⚠️ **Critical:** Do not delete `${AI_DATA_ROOT}/ollama` unless you intentionally want to wipe all downloaded models. The protection layers in `scripts/` are designed to prevent accidental deletion.

---

## 🚀 Quick Start

```bash
# 1. Clone
git clone https://github.com/coinbaseblock/edge-model-runtime.git
cd edge-model-runtime

# 2. Configure: copy .env.example to .env and set AI_DATA_ROOT for your host
cp .env.example .env
$EDITOR .env   # set AI_DATA_ROOT (see "Data Layout" above)

# 3. Install (first time only)
bash scripts/00-install.sh

# 4. Pull a model
bash scripts/04-pull-model.sh qwen2.5-coder:7b

# Or pull a Nemotron variant (default: nano — see docs/MODEL-RECOMMENDATIONS.md)
bash scripts/0a-pull-nemotron.sh nano

# 5. Open WebUI
open http://localhost:3000   # or http://<host-ip>:3000 from another machine
```

> **Recommended clone location on DGX Spark:** `/home/<user>/edge-model-runtime` (e.g. `/home/expert/edge-model-runtime`). Keep `AI_DATA_ROOT` on the same disk to avoid cross-mount copies.

---

## 🎓 Usage

### Upgrading an existing install

You **do not** need `docker compose down` to pull updates. Models live on
the host (`${AI_DATA_ROOT}/ollama`) — they survive every flow below. Only
restart containers when `docker-compose.yml` or `.env.versions` actually
changes.

| What changed in the update | What to run |
|---|---|
| Only scripts / docs / `opencode.json` / `.claude/` | `git pull` — done. Running containers untouched. |
| `docker-compose.yml` or `.env.example` | `git pull && bash scripts/01-start.sh` (Compose recreates only what changed). |
| `.env.versions` (image bumps) | `git pull && bash scripts/09-update-images.sh`. |
| Want a clean container restart anyway | `bash scripts/02-stop.sh && bash scripts/01-start.sh`. Models kept. |

The simple **"works for any update"** recipe:

```bash
cd ~/edge-model-runtime
git status                          # check for local edits (your .env is gitignored & safe)
git pull                            # fetch latest
bash scripts/03-verify.sh           # confirm stack is still healthy
```

After the AI-coding update specifically:

```bash
# Option A — local agent
bash scripts/30-setup-opencode.sh

# Option B — Claude Code + Ollama worker (re-run any time to refresh MCP wiring)
GITHUB_TOKEN=ghp_xxx bash scripts/31-setup-claude-code.sh
```

If `git pull` complains about local changes, stash first:

```bash
git stash && git pull && git stash pop
```

### Daily ops

```bash
bash scripts/01-start.sh       # Start (fast, no auto-pull)
bash scripts/02-stop.sh        # Safe stop (preserves models)
bash scripts/03-verify.sh      # Health check
```

### Model management

```bash
bash scripts/04-pull-model.sh qwen2.5-coder:7b
bash scripts/04b-sync-models.sh                     # pull every enabled entry in models.txt
bash scripts/05-list-models.sh
bash scripts/06-remove-model.sh qwen2.5-coder:7b   # specific model
bash scripts/07-run-model.sh qwen2.5-coder:7b      # interactive CLI
bash scripts/08-disk-report.sh                      # disk usage
bash scripts/09-update-images.sh                    # update Docker images
```

### Multi-model Runtime (declarative registry)

For stacks that run more than one model, list them in [`models.txt`](./models.txt)
instead of pulling each one by hand. Edit the file, run sync, done.

```text
# models.txt
ollama:qwen2.5-coder:7b
ollama:llama3.2:3b
!ollama:mistral:7b      # leading '!' = disabled, kept on disk, not re-pulled
```

Format:

| Token | Meaning |
|---|---|
| `provider:model:tag` | full spec (today only `ollama:` is supported; `vllm:`, `hf:` reserved) |
| `model:tag` | provider defaults to `ollama` |
| `# …` | comment (line or trailing) |
| `!entry` | disabled — skipped by sync, **not deleted** |

Then:

```bash
bash scripts/04b-sync-models.sh
```

The sync script:
- pulls every **enabled** entry that isn't already installed
- prints the **disabled** list for visibility, but never removes anything
  (use `06-remove-model.sh` to actually free disk — keeps the 3-tier
  cleanup invariant intact)

Adding / removing a model is now an edit to a text file plus one command —
no need to touch `docker-compose.yml` or any script.


### Codex/Claude-style repo automation

```bash
make hooks-install   # install git hooks (pre-commit + commit-msg)
make quick-check     # shellcheck + compose config + safety invariants
make ai-review       # quick-check then show git status
make ai-fix          # chmod normalize + quick-check
make ai-pr           # write a PR notes stub in .pr-notes.md
```

These commands provide a repeatable local workflow for plan→patch→validate→PR.

### Cleanup levels

| Level | Script | What it removes | Models? |
|-------|--------|-----------------|---------|
| **L1** | `02-stop.sh` | Running containers | ✅ kept |
| **L2** | `10-cleanup-docker.sh` | Containers + images + caches | ✅ kept |
| **L3** | `20-wipe-models.sh` | **Everything including models** | ❌ deleted |

### Optional profiles

```bash
# vLLM (HuggingFace inference)
docker compose --env-file .env --env-file .env.versions \
  --profile vllm up -d vllm

# Training (PyTorch interactive)
docker compose --env-file .env --env-file .env.versions \
  --profile training run --rm training bash
```

---

## 🏗️ Project Structure

```text
edge-model-runtime/
├── docker-compose.yml         # Inference + optional vLLM/training profiles
├── .env.example               # Copy to .env
├── .env.versions              # Pinned image versions
├── models.txt                 # Declarative model registry (see Multi-model Runtime)
├── .gitignore
├── README.md
├── LICENSE
│
├── .claude/                   # Claude Code config
│   ├── settings.json
│   └── commands/
│
├── scripts/
│   ├── 00-install.sh
│   ├── 01-start.sh
│   ├── 02-stop.sh
│   ├── 03-verify.sh
│   ├── 04-pull-model.sh
│   ├── 04b-sync-models.sh
│   ├── 05-list-models.sh
│   ├── 06-remove-model.sh
│   ├── 07-run-model.sh
│   ├── 08-disk-report.sh
│   ├── 09-update-images.sh
│   ├── 10-cleanup-docker.sh
│   ├── 20-wipe-models.sh
│   ├── uninstall.sh
│   └── lib/
│       ├── common.sh
│       └── models.sh
│
├── training/
│   ├── README.md
│   ├── requirements.txt
│   └── examples/
│       └── lora-finetune.py
│
└── docs/
    ├── ARCHITECTURE.md
    ├── TROUBLESHOOTING.md
    ├── MODEL-RECOMMENDATIONS.md
    └── AI-CODING-SETUP.md      # OpenCode / Claude Code + local Ollama worker
```

---

## 🔄 Rebuild Safety Matrix

| Action | Containers | Images | Models | Re-download? |
|--------|-----------|--------|--------|--------------|
| `02-stop.sh` | removed | kept | kept | ❌ no |
| `09-update-images.sh` | restarted | upgraded | kept | ❌ no |
| `10-cleanup-docker.sh` | removed | removed | kept | ❌ no |
| `20-wipe-models.sh` | removed | removed | **deleted** | ✅ yes |

The model directory (`${AI_DATA_ROOT}/ollama`) is bind-mounted into the container at `/root/.ollama`. Removing the container does not touch the host directory — Ollama just sees its models again on next start.

---

## 🤖 Recommended Models

### Small (≤ 8 GB VRAM)
- `qwen2.5-coder:7b` — coding
- `llama3.2:3b` — general
- `mistral:7b` — general

### Medium (16 GB VRAM)
- `qwen2.5-coder:14b` — coding
- `llama3.1:8b-instruct-q8_0` — high-quality general

### Large (24 GB+ VRAM)
- `qwen2.5-coder:32b`
- `llama3.3:70b-instruct-q4_K_M`

See [`docs/MODEL-RECOMMENDATIONS.md`](./docs/MODEL-RECOMMENDATIONS.md) for full list.

---

## 🛠️ Claude Code Integration

This repo ships with `.claude/commands/` for common operations. From Claude Code:

```
/install        # run installer
/pull <model>   # download a model
/verify         # health check
/cleanup        # level 2 cleanup
```

See [`.claude/README.md`](./.claude/README.md).

---

## 🐛 Troubleshooting

See [`docs/TROUBLESHOOTING.md`](./docs/TROUBLESHOOTING.md).

Quick checks:
```bash
docker compose ps
docker compose logs ollama
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi
bash scripts/03-verify.sh
```

---

## 📜 License

MIT — see [LICENSE](./LICENSE)

---

## 🙏 Credits

Built on top of [Ollama](https://github.com/ollama/ollama), [Open WebUI](https://github.com/open-webui/open-webui), [vLLM](https://github.com/vllm-project/vllm), and the [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-container-toolkit).
