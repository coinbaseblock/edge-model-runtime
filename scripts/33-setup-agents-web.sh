#!/usr/bin/env bash
# =============================================================================
# 33-setup-agents-web.sh — OpenCode + Claude Code in your browser
# =============================================================================
# Option D: Unified Web Terminal. Builds a small container that bundles
# both `opencode` and `claude` CLIs and serves them over ttyd at
# http://localhost:${AGENTS_WEB_PORT:-7681}. You open the URL, log in
# with basic auth, and pick which agent to launch from a menu.
#
# What this does:
#   1. Verifies .env / .env.versions exist (run 00-install.sh otherwise).
#   2. Generates AGENTS_WEB_USER / AGENTS_WEB_PASS in .env if missing.
#   3. Creates persistent state dirs under ${AI_DATA_ROOT}/agents-web/.
#   4. Builds the agents-web image (multi-arch via TARGETARCH).
#   5. Starts the `agents` profile and prints the URL + credentials.
#
# Re-running is safe: existing creds are preserved. To rotate the password,
# clear AGENTS_WEB_PASS in .env and re-run.
# =============================================================================

# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

ENV_FILE="$REPO_ROOT/.env"

section "🌐 OpenCode + Claude Code in browser (Option D)"

check_docker
check_compose_v2

[[ -f "$ENV_FILE" ]] || die ".env not found. Run: bash scripts/00-install.sh"

# --- helpers (also used by 32-setup-cloud-models.sh) -----------------------
env_get() {
  local key="$1"
  awk -F= -v k="$key" '
    /^[[:space:]]*#/ { next }
    $1 == k { sub(/^[^=]*=/, ""); print; exit }
  ' "$ENV_FILE"
}

env_set() {
  local key="$1" value="$2"
  if grep -qE "^[[:space:]]*${key}=" "$ENV_FILE"; then
    local tmp; tmp="$(mktemp)"
    awk -v k="$key" -v v="$value" '
      BEGIN { done = 0 }
      {
        if (!done && $0 ~ "^[[:space:]]*"k"=") {
          print k"="v; done = 1
        } else { print }
      }
    ' "$ENV_FILE" > "$tmp"
    install -m 0640 "$tmp" "$ENV_FILE"
    rm -f "$tmp"
  else
    printf "%s=%s\n" "$key" "$value" >> "$ENV_FILE"
  fi
}

load_env

# --- 1. Credentials ---------------------------------------------------------
user="$(env_get AGENTS_WEB_USER)"
[[ -n "$user" ]] || { user="admin"; env_set AGENTS_WEB_USER "$user"; }

pass="$(env_get AGENTS_WEB_PASS)"
if [[ -z "$pass" ]]; then
  pass="$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
  env_set AGENTS_WEB_PASS "$pass"
  ok "Generated AGENTS_WEB_PASS (saved to .env)"
else
  ok "AGENTS_WEB_PASS already set"
fi

port="$(env_get AGENTS_WEB_PORT)"
[[ -n "$port" ]] || port=7681

# --- 2. Persistent state dirs ----------------------------------------------
load_env
: "${AI_DATA_ROOT:?AI_DATA_ROOT is not set in .env}"

state_root="$AI_DATA_ROOT/agents-web"
mkdir -p \
  "$state_root/claude" \
  "$state_root/claude-config" \
  "$state_root/opencode-share" \
  "$state_root/opencode-config"
chmod -R u+rwX,g+rwX,o-rwx "$state_root"
ok "Persistent state under: $state_root"

# --- 3. Build image ---------------------------------------------------------
section "🔨 Building agents-web image"
compose --profile agents build agents-web

# --- 4. Start --------------------------------------------------------------
section "🚀 Starting agents-web"
compose --profile agents up -d agents-web

# --- 5. Wait for it to listen ----------------------------------------------
url="http://localhost:${port}"
for i in $(seq 1 20); do
  # Don't use `curl -f` — basic auth returns 401 which counts as success here.
  http_code=$(curl -s -o /dev/null --max-time 2 -w '%{http_code}' "$url" 2>/dev/null || echo 000)
  case "$http_code" in
    200|401)
      ok "Listening at $url (HTTP $http_code)"
      break
      ;;
  esac
  sleep 1
  if [[ $i -eq 20 ]]; then
    warn "agents-web did not respond in 20s (last HTTP code: $http_code)"
    warn "Inspect logs:  docker logs --tail 50 edge-agents-web"
  fi
done

# --- 6. Done ----------------------------------------------------------------
log ""
section "✅ Done"
cat <<EOF
Open in your browser:

   $url

  Username:  $user
  Password:  $pass

You'll see a menu — pick:
  [1] OpenCode      — local Ollama models
  [2] Claude Code   — cloud Claude (run \`claude login\` the first time)
  [3] Bash shell    — for anything else

State that survives container rebuilds:
  $state_root/

To rotate the password: clear AGENTS_WEB_PASS in .env and re-run this script.
To stop only this service:
  docker compose --profile agents stop agents-web

Full guide: docs/AI-CODING-SETUP.md
EOF
