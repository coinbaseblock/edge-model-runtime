#!/usr/bin/env bash
# =============================================================================
# 31-setup-claude-code.sh — wire Claude Code CLI to GitHub + local Ollama
# =============================================================================
# Option B: Claude Code (cloud subscription) does the heavy reasoning;
# the local Ollama instance is exposed as an MCP "worker" for cheap, private
# work (summarising long files, generating boilerplate, embeddings, etc.).
#
# What this does:
#   1. Verifies edge-ollama is running and a coding model is installed.
#   2. Installs the Claude Code CLI (npm) if missing.
#   3. Registers two MCP servers on the user's Claude Code config:
#        - github       (official MCP server, requires GITHUB_TOKEN)
#        - ollama       (local stdio server in this repo)
#
# Login to Claude Code is interactive — run `claude` afterwards and follow
# the prompts (use your existing Anthropic / Claude subscription).
#
# Env (optional):
#   GITHUB_TOKEN          fine-grained PAT with repo scope. If unset, the
#                         GitHub MCP server is skipped — you can re-run later.
#   OLLAMA_DEFAULT_MODEL  override the default Ollama model (default qwen2.5-coder:7b)
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

DEFAULT_MODEL="${OLLAMA_DEFAULT_MODEL:-qwen2.5-coder:7b}"
EMBED_MODEL="${OLLAMA_EMBED_MODEL:-nomic-embed-text}"
MCP_SERVER="$REPO_ROOT/scripts/lib/ollama-mcp-server.py"

section "🤝 Claude Code + Ollama-as-worker (Option B)"

check_docker
ensure_ollama_running

# --- 1. Coding model --------------------------------------------------------
if docker exec edge-ollama ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$DEFAULT_MODEL"; then
  ok "Coding model installed: $DEFAULT_MODEL"
else
  info "Pulling coding model: $DEFAULT_MODEL"
  bash "$REPO_ROOT/scripts/04-pull-model.sh" "$DEFAULT_MODEL"
fi

# --- 2. Claude Code CLI -----------------------------------------------------
if command -v claude >/dev/null 2>&1; then
  ok "Claude Code already installed: $(claude --version 2>/dev/null || echo 'unknown')"
else
  info "Installing Claude Code CLI via npm…"
  if ! command -v npm >/dev/null 2>&1; then
    die "npm not found. Install Node.js 18+ first: https://nodejs.org/"
  fi
  npm install -g @anthropic-ai/claude-code
fi

# --- 3. Verify MCP server -----------------------------------------------------
require_cmd python3
if [[ ! -f "$MCP_SERVER" ]]; then
  die "Missing MCP server: $MCP_SERVER"
fi
chmod u+rwX,g+rwX,o-rwx "$MCP_SERVER"

# --- 4. Register MCP servers with Claude Code -------------------------------
# `claude mcp add` writes to the user's Claude Code config.
# `--scope user` makes the server available from any directory.
register_mcp() {
  local name="$1"; shift
  if claude mcp list 2>/dev/null | grep -q "^$name"; then
    info "MCP '$name' already registered — updating"
    claude mcp remove "$name" --scope user >/dev/null 2>&1 || true
  fi
  claude mcp add "$name" --scope user "$@"
  ok "Registered MCP: $name"
}

# Local Ollama worker MCP
OLLAMA_URL="http://localhost:${OLLAMA_PORT:-11434}"
register_mcp ollama \
  --env "OLLAMA_URL=$OLLAMA_URL" \
  --env "OLLAMA_DEFAULT_MODEL=$DEFAULT_MODEL" \
  --env "OLLAMA_EMBED_MODEL=$EMBED_MODEL" \
  -- python3 "$MCP_SERVER"

# GitHub MCP (official, runs via npx)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  register_mcp github \
    --env "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_TOKEN" \
    -- npx -y @modelcontextprotocol/server-github
else
  warn "GITHUB_TOKEN not set — skipping GitHub MCP registration."
  warn "Create a fine-grained PAT (repo scope) at https://github.com/settings/tokens"
  warn "Then re-run:  GITHUB_TOKEN=ghp_xxx bash scripts/31-setup-claude-code.sh"
fi

log ""
section "✅ Done"
cat <<EOF
Next steps:

  1. Log in to Claude Code (uses your existing Anthropic subscription):
       claude login

  2. Start a session in this repo:
       cd $REPO_ROOT
       claude

  3. Inside Claude, verify the MCP servers are connected:
       /mcp

You should see 'ollama' (and 'github' if you set GITHUB_TOKEN) listed.
Claude can now offload local-friendly work to Ollama via tool calls like:
  ollama_generate, ollama_summarize, ollama_embed, ollama_list_models.

Full guide: docs/AI-CODING-SETUP.md
EOF
