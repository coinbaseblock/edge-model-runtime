#!/usr/bin/env bash
# =============================================================================
# 10-cleanup-docker.sh — LEVEL 2 cleanup
# =============================================================================
# Removes containers, this stack's images, and Docker build cache.
# Models on host are PRESERVED.
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

section "🧹 LEVEL 2 cleanup — containers + images"
load_env

cat <<EOF
This will remove:
  • All containers from this stack
  • Docker images: $OLLAMA_IMAGE, $OPEN_WEBUI_IMAGE, $CUDA_TEST_IMAGE
    (and LiteLLM/vLLM/training images if pulled)
  • Dangling images and build cache

This will PRESERVE:
  • $AI_DATA_ROOT/ollama       (models)
  • $AI_DATA_ROOT/open-webui   (chat history & users)
  • $AI_DATA_ROOT/hf-cache     (HuggingFace cache)
  • $AI_DATA_ROOT/training     (training outputs)
EOF
log ""
if ! confirm "Continue?"; then
  log "Cancelled."
  exit 0
fi

# --- Remove containers from compose ----------------------------------------
section "Removing containers"
compose down --remove-orphans

# --- Remove images from this stack -----------------------------------------
section "Removing images"
for var in OLLAMA_IMAGE OPEN_WEBUI_IMAGE LITELLM_IMAGE VLLM_IMAGE TRAINING_IMAGE CUDA_TEST_IMAGE; do
  img="${!var:-}"
  [[ -z "$img" ]] && continue
  if docker image inspect "$img" >/dev/null 2>&1; then
    if docker image rm "$img" >/dev/null 2>&1; then
      ok "removed $img"
    else
      warn "could not remove $img (in use?)"
    fi
  fi
done

# Locally-built agents-web image (no pinned tag).
if docker image inspect edge-agents-web:local >/dev/null 2>&1; then
  if docker image rm edge-agents-web:local >/dev/null 2>&1; then
    ok "removed edge-agents-web:local"
  else
    warn "could not remove edge-agents-web:local (in use?)"
  fi
fi

# --- Prune dangling --------------------------------------------------------
section "Pruning"
docker image prune -f
docker builder prune -f
docker network prune -f

ok "Level 2 cleanup complete."
log ""
log "Models preserved at: $AI_DATA_ROOT/ollama"
log "Restart with: bash scripts/01-start.sh   (will re-pull only if image was removed)"
