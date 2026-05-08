#!/usr/bin/env bash
# =============================================================================
# 20-wipe-models.sh — LEVEL 3 wipe (DANGEROUS)
# =============================================================================
# Deletes ALL host data for this stack. Cannot be undone.
# Requires typing 'DELETE ALL' literally to proceed.
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

section "${C_RED}⛔  LEVEL 3 — DELETE EVERYTHING${C_RESET}"
load_env

cat <<EOF
This will PERMANENTLY DELETE:
  • $AI_DATA_ROOT/ollama       (all downloaded models — re-download required)
  • $AI_DATA_ROOT/open-webui   (chat history, users, settings)
  • $AI_DATA_ROOT/hf-cache     (HuggingFace cache)
  • $AI_DATA_ROOT/training     (training outputs)
  • All containers and images for this stack

This action CANNOT be undone.
EOF
log ""

if ! confirm_phrase "Type 'DELETE ALL' to confirm" "DELETE ALL"; then
  log "Cancelled. Nothing was deleted."
  exit 0
fi

log ""
warn "Last chance to abort with Ctrl+C..."
for i in 5 4 3 2 1; do
  printf "  %d...\n" "$i"
  sleep 1
done

# --- Stop containers --------------------------------------------------------
section "Stopping containers"
compose down --remove-orphans 2>/dev/null || true

# --- Remove images ----------------------------------------------------------
section "Removing images"
for var in OLLAMA_IMAGE OPEN_WEBUI_IMAGE VLLM_IMAGE TRAINING_IMAGE CUDA_TEST_IMAGE; do
  img="${!var:-}"
  [[ -z "$img" ]] && continue
  docker image rm -f "$img" >/dev/null 2>&1 || true
done

# --- Wipe data directories --------------------------------------------------
section "Deleting host data"
for d in ollama open-webui hf-cache training logs; do
  target="$AI_DATA_ROOT/$d"
  if [[ -d "$target" ]]; then
    if [[ -w "$target" ]]; then
      rm -rf "$target"
    else
      sudo rm -rf "$target"
    fi
    ok "deleted $target"
  fi
done

# --- Prune ------------------------------------------------------------------
docker network prune -f >/dev/null 2>&1 || true
docker builder prune -f >/dev/null 2>&1 || true

log ""
ok "All data wiped."
log ""
log "Reinstall with: bash scripts/00-install.sh"
