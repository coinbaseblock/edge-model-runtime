#!/usr/bin/env bash
# 01-public.sh — start/stop the public (no-login) Open WebUI on port PUBLIC_WEBUI_PORT
# Usage: bash scripts/01-public.sh {start|stop}
#
# Port 3001 (default) = public instance, no authentication required
# Port 3000           = main instance (unchanged, unaffected)
set -euo pipefail
# shellcheck source=scripts/lib/common.sh
source "$(dirname "$0")/lib/common.sh"
load_env

cmd="${1:-start}"
PORT="${PUBLIC_WEBUI_PORT:-3001}"

case "$cmd" in
  start)
    section "Starting public Open WebUI (port ${PORT})"
    compose --profile public up -d open-webui-public
    wait_url "http://localhost:${PORT}" 60 --any || true
    ok "Public WebUI ready → http://$(hostname -I | awk '{print $1}'):${PORT}"
    info "Main WebUI (port 3000) is unaffected."
    ;;
  stop)
    section "Stopping public Open WebUI"
    compose --profile public stop open-webui-public
    ok "Done. Main WebUI (port 3000) is unaffected."
    ;;
  *)
    echo "Usage: $0 {start|stop}" >&2
    exit 1
    ;;
esac