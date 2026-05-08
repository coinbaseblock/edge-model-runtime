#!/usr/bin/env bash
# =============================================================================
# 09-update-images.sh — pull latest pinned images and recreate containers
# =============================================================================
# Models on host are NOT touched. Only container images are updated.
# Edit .env.versions first if you want a different tag.
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

section "⬆️  Updating Docker images"

check_docker
load_env

info "Current pinned versions (.env.versions):"
log "  OLLAMA_IMAGE     = ${OLLAMA_IMAGE:-?}"
log "  OPEN_WEBUI_IMAGE = ${OPEN_WEBUI_IMAGE:-?}"

# LiteLLM is opt-in — only refresh it if the user has already pulled it
# (i.e. previously ran scripts/32-setup-cloud-models.sh).
update_litellm=0
if [[ -n "${LITELLM_IMAGE:-}" ]] && docker image inspect "$LITELLM_IMAGE" >/dev/null 2>&1; then
  update_litellm=1
  log "  LITELLM_IMAGE    = ${LITELLM_IMAGE}"
fi
log ""

if ! confirm "Pull these images and recreate containers?"; then
  log "Cancelled."
  exit 0
fi

compose pull ollama open-webui
compose up -d ollama open-webui

if (( update_litellm )); then
  compose --profile cloud pull litellm
  compose --profile cloud up -d litellm
fi

ok "Update complete."
load_env
info "Models preserved at: ${AI_DATA_ROOT}/ollama"
log ""
log "Run 'bash scripts/03-verify.sh' to confirm health."
