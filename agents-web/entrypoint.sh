#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh — launches ttyd with optional basic auth.
# =============================================================================
# Reads from env (set in compose):
#   AGENTS_WEB_PORT   — port to listen on (default 7681)
#   AGENTS_WEB_USER   — basic auth username (no auth if empty)
#   AGENTS_WEB_PASS   — basic auth password (no auth if empty)
# =============================================================================

set -euo pipefail

PORT="${AGENTS_WEB_PORT:-7681}"

args=(
  --port "$PORT"
  --writable
  --check-origin
)

if [[ -n "${AGENTS_WEB_USER:-}" && -n "${AGENTS_WEB_PASS:-}" ]]; then
  args+=(--credential "${AGENTS_WEB_USER}:${AGENTS_WEB_PASS}")
else
  echo "WARNING: AGENTS_WEB_USER / AGENTS_WEB_PASS empty — running without auth" >&2
fi

exec /usr/local/bin/ttyd "${args[@]}" /usr/local/bin/edge-agent-menu
