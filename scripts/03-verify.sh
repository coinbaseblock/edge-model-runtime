#!/usr/bin/env bash
# =============================================================================
# 03-verify.sh — health check
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

section "🔍 edge-model-runtime — verify"

check_docker
load_env

# --- Containers --------------------------------------------------------------
section "📦 Container status"
compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" || true

# --- Disk --------------------------------------------------------------------
section "💾 Storage usage"
if [[ -d "${AI_DATA_ROOT:-}" ]]; then
  du -sh "$AI_DATA_ROOT"/* 2>/dev/null | sort -rh || warn "no data yet"
else
  warn "AI_DATA_ROOT not found: $AI_DATA_ROOT"
fi

# --- GPU ---------------------------------------------------------------------
section "🎮 GPU access (from inside Ollama container)"
if ollama_running; then
  if docker exec edge-ollama nvidia-smi --query-gpu=index,name,memory.used,memory.total \
       --format=csv,noheader 2>/dev/null; then
    :
  else
    warn "GPU not accessible inside container (CPU-only mode)"
  fi
else
  warn "edge-ollama container not running"
fi

# --- API health --------------------------------------------------------------
section "🔌 API health"
ollama_url="http://localhost:${OLLAMA_PORT:-11434}"
webui_url="http://localhost:${WEBUI_PORT:-3000}"

if curl -sf "$ollama_url/api/tags" >/dev/null 2>&1; then
  if command -v jq >/dev/null 2>&1; then
    n=$(curl -sf "$ollama_url/api/tags" | jq '.models | length')
    ok "Ollama: OK ($n model(s))"
  else
    ok "Ollama: OK"
  fi
else
  err "Ollama: unreachable at $ollama_url"
fi

if curl -sf "$webui_url" >/dev/null 2>&1; then
  ok "WebUI: OK"
else
  err "WebUI: unreachable at $webui_url"
fi

log ""
ok "Verification complete"
