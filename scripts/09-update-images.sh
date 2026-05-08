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
log ""

if ! confirm "Pull these images and recreate containers?"; then
  log "Cancelled."
  exit 0
fi

compose pull ollama open-webui
compose up -d ollama open-webui

ok "Update complete."
load_env
info "Models preserved at: ${AI_DATA_ROOT}/ollama"
log ""
log "Run 'bash scripts/03-verify.sh' to confirm health."
