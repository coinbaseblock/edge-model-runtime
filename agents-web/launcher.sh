#!/usr/bin/env bash
# =============================================================================
# launcher.sh — interactive menu shown to ttyd users.
# =============================================================================
# Picks one of: OpenCode (local), Claude Code (cloud), bash, or quit.
# Lives at /usr/local/bin/edge-agent-menu inside the container.
# =============================================================================

set -uo pipefail

cd /workspace 2>/dev/null || cd /

# Load .env from the mounted repo so OpenCode sees LITELLM_MASTER_KEY etc.
if [[ -f /workspace/.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /workspace/.env
  set +a
fi

print_menu() {
  clear || true
  cat <<'EOF'
╔══════════════════════════════════════════════════════════╗
║   edge-model-runtime — AI Agents in your browser         ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║   [1] OpenCode      — local Ollama models (Option A)     ║
║   [2] Claude Code   — cloud Claude subscription (Opt B)  ║
║   [3] Bash shell    — manual (you're on your own)        ║
║                                                          ║
║   [Q] Quit                                               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

  Workspace: /workspace  (host repo, read-write)
  Persistent state: /root/.claude, /root/.config, /root/.local

  First-time Claude users: pick [2], then run `claude login`
  inside it to authenticate. The token persists across rebuilds.

EOF
}

run_opencode() { exec opencode ; }
run_claude()   { exec claude ; }
run_bash()     { exec bash --login ; }

while true; do
  print_menu
  read -r -p "Choose [1/2/3/Q]: " choice
  case "${choice,,}" in
    1) run_opencode ;;
    2) run_claude ;;
    3) run_bash ;;
    q|quit|exit) exit 0 ;;
    "") continue ;;
    *) printf "\nUnknown choice: %s\n" "$choice"; sleep 1 ;;
  esac
done
