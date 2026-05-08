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
║   [1] OpenCode             — local Ollama (Option A)     ║
║   [2] Claude Code (cloud)  — Claude subscription (Opt B) ║
║   [3] Claude Code (local)  — Claude UI + Ollama brain    ║
║                              via LiteLLM (Option E)      ║
║   [4] Bash shell           — manual                      ║
║                                                          ║
║   [Q] Quit                                               ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

  Workspace: /workspace  (host repo, read-write)
  Persistent state: /root/.claude, /root/.config, /root/.local

  First-time:
    [2]  cloud Claude → run `claude login` inside it
    [3]  local Claude → host must have run scripts/34-setup-claude-local.sh
                        and the cloud profile (LiteLLM) must be up

EOF
}

run_opencode() { exec opencode ; }
run_claude()   { exec claude ; }

run_claude_local() {
  # Pick the most recent edge-local settings file the host generated.
  local settings
  settings="$(ls -t /root/.claude/settings-edge-local-*.json 2>/dev/null | head -n1)"
  if [[ -z "$settings" ]]; then
    cat <<'EOF'

No local Claude settings found in /root/.claude/.

On the host, run:
  bash scripts/32-setup-cloud-models.sh    # if not done yet
  bash scripts/34-setup-claude-local.sh    # picks default qwen2.5-coder

Those write to ~/.claude/settings-edge-local-*.json on the host, which
this container sees via the bind mount.

EOF
    read -r -p "Press Enter to return to the menu… " _
    return
  fi
  echo "Using local settings: $settings"
  exec claude --settings "$settings"
}

run_bash() { exec bash --login ; }

while true; do
  print_menu
  read -r -p "Choose [1/2/3/4/Q]: " choice
  case "${choice,,}" in
    1) run_opencode ;;
    2) run_claude ;;
    3) run_claude_local ;;
    4) run_bash ;;
    q|quit|exit) exit 0 ;;
    "") continue ;;
    *) printf "\nUnknown choice: %s\n" "$choice"; sleep 1 ;;
  esac
done
