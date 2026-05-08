# edge-model-runtime

> Production-grade Docker runtime for running and training local LLMs on MSI EdgeXpert / Ubuntu NVIDIA edge machines.

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

---

## 📋 Requirements

| Component | Version |
|-----------|---------|
| Ubuntu Linux | 22.04+ |
| Docker Engine | 24.0+ |
| Docker Compose | v2.20+ |
| NVIDIA Driver | 535+ |
| NVIDIA Container Toolkit | latest |
| Mounted disk | `/mnt/edge-backup` |

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

All persistent data is on the host disk — **never inside containers**:

```text
/mnt/edge-backup/ai-data/
├── ollama/        # Ollama models — DO NOT DELETE
├── open-webui/    # WebUI database & settings
├── hf-cache/      # HuggingFace cache (optional vLLM)
├── training/      # Optional training output
└── logs/          # Container logs (rotated)
```

> ⚠️ **Critical:** Do not delete `/mnt/edge-backup/ai-data/ollama` unless you intentionally want to wipe all downloaded models. The protection layers in `scripts/` are designed to prevent accidental deletion.

---

## 🚀 Quick Start

```bash
# 1. Clone
git clone https://github.com/<your-username>/edge-model-runtime.git
cd edge-model-runtime

# 2. Install (first time only)
bash scripts/00-install.sh

# 3. Pull a model
bash scripts/04-pull-model.sh qwen2.5-coder:7b

# Or pull a Nemotron variant (default: nano — see docs/MODEL-RECOMMENDATIONS.md)
bash scripts/0a-pull-nemotron.sh nano

# 4. Open WebUI
open http://localhost:3000
```

---

## 🎓 Usage

### Daily ops

```bash
bash scripts/01-start.sh       # Start (fast, no auto-pull)
bash scripts/02-stop.sh        # Safe stop (preserves models)
bash scripts/03-verify.sh      # Health check
```

### Model management

```bash
bash scripts/04-pull-model.sh qwen2.5-coder:7b
bash scripts/05-list-models.sh
bash scripts/06-remove-model.sh qwen2.5-coder:7b   # specific model
bash scripts/07-run-model.sh qwen2.5-coder:7b      # interactive CLI
bash scripts/08-disk-report.sh                      # disk usage
bash scripts/09-update-images.sh                    # update Docker images
```

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
│   ├── 05-list-models.sh
│   ├── 06-remove-model.sh
│   ├── 07-run-model.sh
│   ├── 08-disk-report.sh
│   ├── 09-update-images.sh
│   ├── 10-cleanup-docker.sh
│   ├── 20-wipe-models.sh
│   ├── uninstall.sh
│   └── lib/
│       └── common.sh
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
    └── MODEL-RECOMMENDATIONS.md
```

---

## 🔄 Rebuild Safety Matrix

| Action | Containers | Images | Models | Re-download? |
|--------|-----------|--------|--------|--------------|
| `02-stop.sh` | removed | kept | kept | ❌ no |
| `09-update-images.sh` | restarted | upgraded | kept | ❌ no |
| `10-cleanup-docker.sh` | removed | removed | kept | ❌ no |
| `20-wipe-models.sh` | removed | removed | **deleted** | ✅ yes |

The model directory (`/mnt/edge-backup/ai-data/ollama`) is bind-mounted into the container at `/root/.ollama`. Removing the container does not touch the host directory — Ollama just sees its models again on next start.

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
