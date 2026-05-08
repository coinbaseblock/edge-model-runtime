#!/usr/bin/env bash
# =============================================================================
# scripts/lib/common.sh — shared helpers
# =============================================================================
# Source this from every script:
#   source "$(dirname "$0")/lib/common.sh"
# =============================================================================

set -euo pipefail

# --- Resolve repo root (parent of scripts/) ---------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Colors ------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_BLUE=$'\033[0;34m'
  C_BOLD=$'\033[1m'
else
  C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_BOLD=""
fi

log()      { printf "%s\n" "$*"; }
info()     { printf "%sℹ%s  %s\n"  "$C_BLUE"   "$C_RESET" "$*"; }
ok()       { printf "%s✓%s  %s\n"  "$C_GREEN"  "$C_RESET" "$*"; }
warn()     { printf "%s⚠%s  %s\n"  "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()      { printf "%s✗%s  %s\n"  "$C_RED"    "$C_RESET" "$*" >&2; }
section()  { printf "\n%s%s%s\n"   "$C_BOLD"   "$*"      "$C_RESET"; }
die()      { err "$*"; exit 1; }

# --- Env file loader ---------------------------------------------------------
# Loads .env and .env.versions safely (handles spaces, quotes, comments).
load_env() {
  local f
  for f in "$REPO_ROOT/.env" "$REPO_ROOT/.env.versions"; do
    [[ -f "$f" ]] || continue
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
  done
}

# --- Compose wrapper ---------------------------------------------------------
# Always passes both env files. Usage: compose up -d
compose() {
  local args=()
  [[ -f "$REPO_ROOT/.env" ]]          && args+=(--env-file "$REPO_ROOT/.env")
  [[ -f "$REPO_ROOT/.env.versions" ]] && args+=(--env-file "$REPO_ROOT/.env.versions")
  ( cd "$REPO_ROOT" && docker compose "${args[@]}" "$@" )
}

# --- Preflight checks --------------------------------------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

check_docker() {
  require_cmd docker
  docker info >/dev/null 2>&1 || die "Docker daemon not reachable. Is it running? Are you in the 'docker' group?"
}

check_compose_v2() {
  docker compose version >/dev/null 2>&1 || \
    die "Docker Compose v2 required. Install: https://docs.docker.com/compose/install/"
}

check_data_root() {
  load_env
  : "${AI_DATA_ROOT:?AI_DATA_ROOT is not set in .env}"
  if [[ ! -d "$AI_DATA_ROOT" ]]; then
    warn "AI_DATA_ROOT does not exist: $AI_DATA_ROOT"
    warn "Run: bash scripts/00-install.sh"
    return 1
  fi
  return 0
}

# --- Confirmation helpers ----------------------------------------------------
confirm() {
  local prompt="${1:-Continue?}"
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

confirm_phrase() {
  local prompt="$1"
  local phrase="$2"
  local reply
  read -r -p "$prompt (type '$phrase' to confirm): " reply
  [[ "$reply" == "$phrase" ]]
}

# --- Container helpers -------------------------------------------------------
ollama_running() {
  docker ps --format '{{.Names}}' | grep -qx 'edge-ollama'
}

ensure_ollama_running() {
  if ! ollama_running; then
    die "Container 'edge-ollama' is not running. Start with: bash scripts/01-start.sh"
  fi
}
