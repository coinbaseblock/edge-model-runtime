#!/usr/bin/env bash
# =============================================================================
# 34-setup-claude-local.sh — drive Claude Code with a LOCAL Ollama model
# =============================================================================
# Option E: Same `claude` CLI you're already using, but the brain is a
# local Ollama model running through the LiteLLM proxy. No cloud calls.
#
# Trick (popularised by various LM-Studio + Claude Code tutorials):
# Claude Code respects ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN. Point
# them at LiteLLM (which serves /v1/messages in Anthropic shape) and
# Claude Code talks to whatever model LiteLLM is configured to forward
# to. We added Ollama models in litellm/config.yaml so the loop closes.
#
# What this does:
#   1. Verifies edge-litellm is running (asks 32-setup-cloud-models if not).
#   2. Reads LITELLM_MASTER_KEY + LITELLM_PORT from .env.
#   3. Renders claude-settings/edge-local.template.json into
#      ~/.claude/settings-edge-local.json (one per chosen model).
#   4. Prints how to launch:
#        claude --settings ~/.claude/settings-edge-local.json
#
# Usage:
#   bash scripts/34-setup-claude-local.sh                  # default qwen2.5-coder
#   bash scripts/34-setup-claude-local.sh qwen2.5-coder-large
#   bash scripts/34-setup-claude-local.sh deepseek-coder
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

ENV_FILE="$REPO_ROOT/.env"
TEMPLATE="$REPO_ROOT/claude-settings/edge-local.template.json"

MODEL="${1:-qwen2.5-coder}"

section "🧠 Claude Code with local model (Option E)"

[[ -f "$ENV_FILE" ]] || die ".env not found. Run: bash scripts/00-install.sh"
[[ -f "$TEMPLATE" ]] || die "Template not found: $TEMPLATE"

load_env

# --- 1. LiteLLM running? ----------------------------------------------------
if ! docker ps --format '{{.Names}}' | grep -qx 'edge-litellm'; then
  warn "edge-litellm is not running."
  warn "Run this first:  bash scripts/32-setup-cloud-models.sh"
  die "Aborting."
fi

master_key="${LITELLM_MASTER_KEY:-}"
[[ -n "$master_key" ]] || die "LITELLM_MASTER_KEY missing in .env"

port="${LITELLM_PORT:-4000}"
base_url="http://localhost:${port}"

# --- 2. Validate the model is in LiteLLM's catalogue ------------------------
section "🔎 Checking LiteLLM knows '$MODEL'"
models_json="$(curl -sf -H "Authorization: Bearer $master_key" \
                  "$base_url/v1/models" 2>/dev/null || true)"
if [[ -z "$models_json" ]]; then
  die "Could not reach LiteLLM at $base_url. Is the cloud profile up?"
fi

if command -v jq >/dev/null 2>&1; then
  if ! echo "$models_json" | jq -e --arg m "$MODEL" '.data[] | select(.id==$m)' >/dev/null; then
    err "Model '$MODEL' not registered with LiteLLM."
    log ""
    log "Models LiteLLM currently serves:"
    echo "$models_json" | jq -r '.data[].id' | sed 's/^/  - /'
    log ""
    log "Edit litellm/config.yaml to add it, then:"
    log "  docker compose --profile cloud up -d --force-recreate litellm"
    exit 1
  fi
else
  warn "jq not installed — skipping catalogue check"
fi
ok "LiteLLM serves '$MODEL'"

# --- 3. Confirm Ollama actually has the underlying model --------------------
# Map LiteLLM model_name -> the Ollama tag in litellm/config.yaml
case "$MODEL" in
  qwen2.5-coder)        ollama_tag="qwen2.5-coder:7b"          ;;
  qwen2.5-coder-large)  ollama_tag="qwen2.5-coder:32b"         ;;
  deepseek-coder)       ollama_tag="deepseek-coder-v2:16b"     ;;
  nemotron-nano)        ollama_tag="nemotron-3-nano:latest"    ;;
  *)                    ollama_tag=""                          ;;
esac

if [[ -n "$ollama_tag" ]]; then
  if ollama_running; then
    if ! docker exec edge-ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$ollama_tag"; then
      warn "Ollama doesn't have $ollama_tag yet."
      warn "Pull it first: bash scripts/04-pull-model.sh $ollama_tag"
      if ! confirm "Pull it now?"; then
        die "Aborted."
      fi
      bash "$REPO_ROOT/scripts/04-pull-model.sh" "$ollama_tag"
    else
      ok "Ollama has $ollama_tag"
    fi
  else
    warn "edge-ollama not running — can't verify $ollama_tag is pulled"
  fi
fi

# --- 4. Render the settings file -------------------------------------------
# Two destinations:
#   (a) ~/.claude/settings-edge-local-<model>.json
#       — for the host's `claude` CLI to use directly.
#   (b) ${AI_DATA_ROOT}/agents-web/claude/settings-edge-local-<model>.json
#       — for the agents-web container, which bind-mounts that dir as
#         /root/.claude. Letting the in-browser launcher pick option [3].
section "📝 Rendering Claude Code settings"

filename="settings-edge-local-${MODEL}.json"

# If invoked via sudo, write to the invoking user's home so the file
# ends up where their `claude` CLI expects it (not under /root).
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
  user_home="$HOME"
fi
host_out="$user_home/.claude/$filename"
container_out=""
if [[ -n "${AI_DATA_ROOT:-}" && -d "$AI_DATA_ROOT/agents-web/claude" ]]; then
  container_out="$AI_DATA_ROOT/agents-web/claude/$filename"
fi

mkdir -p "$(dirname "$host_out")"
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
  chown "$SUDO_USER:$SUDO_USER" "$(dirname "$host_out")" 2>/dev/null || true
fi

# Use python for safe JSON-aware substitution (handles quoting).
render_to() {
  local target="$1"
  python3 - "$TEMPLATE" "$target" \
    "$base_url" "$master_key" "$MODEL" <<'PY'
import json, sys
src, dst, base_url, token, model = sys.argv[1:6]
with open(src) as f:
    data = json.load(f)
data.pop("_comment", None)
env = data.setdefault("env", {})
for k, v in list(env.items()):
    if isinstance(v, str):
        env[k] = (v.replace("__ANTHROPIC_BASE_URL__", base_url)
                   .replace("__LITELLM_MASTER_KEY__", token)
                   .replace("__LOCAL_MODEL__", model))
with open(dst, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
  chmod 0600 "$target"
  ok "Wrote $target"
}

render_to "$host_out"
out="$host_out"
if [[ -n "$container_out" ]]; then
  render_to "$container_out"
fi

# --- 5. Done ---------------------------------------------------------------
log ""
section "✅ Done"
cat <<EOF
Run Claude Code with local '$MODEL' as the brain:

  claude --settings $out

Tip: alias it for speed.
  echo "alias claude-local='claude --settings $out'" >> ~/.bashrc

To use a different local model, re-run with its LiteLLM name:
  bash scripts/34-setup-claude-local.sh qwen2.5-coder-large
  bash scripts/34-setup-claude-local.sh deepseek-coder

Caveats — read me first:
  • Tool-use quality on small local models is hit-or-miss. Claude Code
    expects clean Anthropic tool calls; smaller Qwen / DeepSeek models
    sometimes mangle them. The 32B variants are notably better.
  • Subscription Claude is still the default \`claude\` (no --settings).
    Only this command opts into the local model.
  • Cost: \$0 (everything runs on this host).

Full guide: docs/AI-CODING-SETUP.md
EOF
