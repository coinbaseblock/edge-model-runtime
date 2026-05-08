#!/usr/bin/env bash
# =============================================================================
# 08-disk-report.sh — disk usage breakdown
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

load_env

section "💾 Host data usage — $AI_DATA_ROOT"
if [[ -d "${AI_DATA_ROOT:-}" ]]; then
  du -sh "$AI_DATA_ROOT"/* 2>/dev/null | sort -rh
  log ""
  log "Total:"
  du -sh "$AI_DATA_ROOT" 2>/dev/null
else
  warn "AI_DATA_ROOT not found: ${AI_DATA_ROOT:-(unset)}"
fi

section "📋 Ollama models"
if ollama_running; then
  docker exec edge-ollama ollama list
else
  warn "edge-ollama not running — start with bash scripts/01-start.sh"
fi

section "🐳 Docker disk usage (system-wide)"
docker system df

section "📦 Docker images for this stack"
load_env
for var in OLLAMA_IMAGE OPEN_WEBUI_IMAGE LITELLM_IMAGE VLLM_IMAGE TRAINING_IMAGE CUDA_TEST_IMAGE; do
  img="${!var:-}"
  [[ -z "$img" ]] && continue
  if docker image inspect "$img" >/dev/null 2>&1; then
    size=$(docker image inspect "$img" --format '{{.Size}}' | numfmt --to=iec 2>/dev/null || echo "?")
    ok  "$img ($size)"
  else
    warn "$img — not pulled"
  fi
done

section "💽 Filesystem"
df -h "${AI_DATA_ROOT:-/}" 2>/dev/null || df -h /
