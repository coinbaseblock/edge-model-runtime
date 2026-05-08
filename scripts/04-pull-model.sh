#!/usr/bin/env bash
# =============================================================================
# 04-pull-model.sh — download an Ollama model
# Usage:  bash scripts/04-pull-model.sh <model[:tag]>
# Example: bash scripts/04-pull-model.sh qwen2.5-coder:7b
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

MODEL="${1:-}"
if [[ -z "$MODEL" ]]; then
  cat <<EOF
Usage: bash scripts/04-pull-model.sh <model[:tag]>

Examples:
  bash scripts/04-pull-model.sh qwen2.5-coder:7b
  bash scripts/04-pull-model.sh llama3.2:3b
  bash scripts/04-pull-model.sh mistral:7b

Browse models: https://ollama.com/library
EOF
  exit 1
fi

check_docker
ensure_ollama_running
load_env

section "📥 Pulling: $MODEL"
info "Storage: ${AI_DATA_ROOT}/ollama"

docker exec -it edge-ollama ollama pull "$MODEL"

ok "Pulled: $MODEL"
log ""
bash "$(dirname "$0")/05-list-models.sh"
