# AI-assisted coding on this stack

Four ways to use this runtime. Pick one — they coexist.

| | Option A · OpenCode | Option B · Claude Code + Ollama worker | Option C · Unified Web UI | Option D · Claude Code TUI on local Ollama |
|---|---|---|---|---|
| Main interface | TUI (terminal) | TUI (terminal) | Open WebUI (browser) | TUI (terminal) |
| Main agent | OpenCode (open source) | Claude Code (subscription) | Whatever model you pick from the dropdown | Claude Code (TUI) — but the brain is Ollama |
| Inference | 100% local Ollama | Cloud Claude **+** local Ollama for offload | Local Ollama **and** cloud (Claude/GPT/Gemini) in one menu | 100% local Ollama (via LiteLLM Anthropic adapter) |
| Cost | $0 | Claude subscription | $0 for local, pay-per-token for cloud | $0 |
| Best when | offline / privacy required | hardest reasoning, multi-file refactor | quick chat, comparing models, non-coding work | you like Claude Code's UX but want a local model |

Both options share the same **local MCP worker** at
[`scripts/lib/ollama-mcp-server.py`](../scripts/lib/ollama-mcp-server.py),
a tiny Python-stdlib stdio server that exposes Ollama as MCP tools:
`ollama_generate`, `ollama_summarize`, `ollama_embed`, `ollama_list_models`.

---

## Prerequisites (both options)

```bash
# Stack up and at least one coding model installed
bash scripts/01-start.sh
bash scripts/04-pull-model.sh qwen2.5-coder:7b      # or :14b / :32b for more VRAM

# Optional, only needed for ollama_embed
bash scripts/04-pull-model.sh nomic-embed-text
```

Models suited to coding agents on this stack (see
[`docs/MODEL-RECOMMENDATIONS.md`](MODEL-RECOMMENDATIONS.md)):

| VRAM | Recommended |
|---|---|
| 8 GB  | `qwen2.5-coder:7b` |
| 16 GB | `qwen2.5-coder:14b`, `deepseek-coder-v2:16b` |
| 24 GB+| `qwen2.5-coder:32b`, `nemotron-3-nano` |

---

## Option A — OpenCode (100% local)

OpenCode is an open-source agentic coding TUI with the same shape as Claude
Code (slash commands, tool use, MCP). It speaks any OpenAI-compatible
endpoint, so it talks straight to Ollama.

```bash
bash scripts/30-setup-opencode.sh           # default model qwen2.5-coder:7b
bash scripts/30-setup-opencode.sh qwen2.5-coder:32b   # or pick your own
```

That script:
1. Confirms `edge-ollama` is running.
2. Pulls the chosen coding model if missing.
3. Installs the OpenCode CLI (one-line installer from `opencode.ai`).
4. Verifies `opencode.json` (project config, points at `http://localhost:11434/v1`).

Then:

```bash
cd /path/to/edge-model-runtime
opencode
```

The project-level [`opencode.json`](../opencode.json) registers the local
Ollama provider, sets `qwen2.5-coder:7b` as default, and wires the
`ollama-tools` MCP so OpenCode can also call `ollama_summarize` etc. on
sub-tasks.

### GitHub from OpenCode

OpenCode runs `git` and shell commands directly, so the simplest GitHub
workflow is:

```bash
gh auth login                 # one-time, host-level
```

Then ask OpenCode to "create a PR for these changes" and it will use `gh`.
For a structured GitHub MCP, add a block to `opencode.json` under `mcp`:

```jsonc
"github": {
  "type": "local",
  "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
  "environment": { "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_xxx" }
}
```

> Don't commit a real token. Use a shell env var or a local-only file.

---

## Option B — Claude Code + Ollama-as-worker

You already pay for Claude — keep using it as the main brain, but let the
local Ollama instance handle:

- summarising long log files / large source files before they go in context,
- generating boilerplate / first-draft unit tests,
- computing embeddings for code search,
- any quick question you'd rather not send out.

### One-time setup

```bash
# Optional — set this first to also register the GitHub MCP server
export GITHUB_TOKEN=ghp_yourFineGrainedPAT

bash scripts/31-setup-claude-code.sh
```

That script:
1. Confirms `edge-ollama` is running and the coding model is installed.
2. Installs Node.js 20 if missing — via [`nvm`](https://github.com/nvm-sh/nvm)
   when run as a normal user (no sudo, lives in `~/.nvm`), or via the NodeSource
   apt repo when run as root. Override with `EDGE_NODE_INSTALL=nvm|nodesource|skip`.
3. Installs the Claude Code CLI (`npm i -g @anthropic-ai/claude-code`).
4. Registers two MCP servers on your **user-scoped** Claude Code config:
   - `ollama`  → `python3 scripts/lib/ollama-mcp-server.py`
   - `github`  → `@modelcontextprotocol/server-github` (only if `GITHUB_TOKEN` is set)

> If you already exported `GITHUB_TOKEN` and need to re-run with sudo (for the
> NodeSource path), use `sudo -E` so the env var survives.

### Log in (uses your subscription)

```bash
claude login
```

Pick "Anthropic Console / Claude.ai subscription" when prompted — this binds
the CLI to the plan you're already paying for. No API key needed for that
flow; usage counts against your subscription.

### Use it

```bash
cd /path/to/edge-model-runtime
claude
```

Inside the session:

```
/mcp                    # should list:  ollama  (and github if configured)
```

Then prompt naturally — Claude will pick when to delegate. To force
delegation, be explicit:

> Use `ollama_summarize` to compress `scripts/00-install.sh`, then suggest
> three improvements based on the summary.

> Use `ollama_generate` with `qwen2.5-coder:7b` to draft 5 unit tests for
> `lib/common.sh::confirm_phrase`. I'll review and refine.

### Why this is "local 100%" on the worker side

The MCP server (`scripts/lib/ollama-mcp-server.py`) only talks to
`http://localhost:11434`. Anything routed through `ollama_*` tools never
leaves the host. The main Claude conversation still goes to Anthropic — only
explicit tool calls stay local. If you need *full* offline, use Option A.

---


> ต้องการทำงาน "Codex/Claude Code style" ผ่านหน้าเว็บอย่างเดียว? ดูคู่มือ
> [`docs/WEB-CODEX-PLAYBOOK.md`](./WEB-CODEX-PLAYBOOK.md).

## Option C — Unified Web UI (cloud + local in one dropdown)

You already get Open WebUI on `http://localhost:3000` for chatting with the
local Ollama models. Option C adds a small **LiteLLM** proxy that fronts
cloud providers (Anthropic, OpenAI, Gemini, …) as an OpenAI-compatible
endpoint, so cloud models show up in the **same model dropdown** as your
local ones. You log in once, pick a model from the menu, and chat — no
per-tool config.

### One-time setup

```bash
bash scripts/32-setup-cloud-models.sh
```

That wizard:
1. Generates a `LITELLM_MASTER_KEY` in `.env` (used by Open WebUI to talk
   to the proxy).
2. Prompts for `ANTHROPIC_API_KEY` if missing and saves it to `.env`.
   Press Enter to skip — you can edit `.env` later and re-run.
3. Brings up the `cloud` profile (`docker compose --profile cloud up -d
   litellm`) and recreates Open WebUI so it picks up the new endpoint.
4. Lists the cloud models LiteLLM is now serving.

### Use it from the browser

1. Open `http://localhost:3000` in your browser.
2. Click the model dropdown (top-left). Local Ollama models and Claude
   (or any cloud model you've enabled) appear in the same list.
3. Pick one and chat.

### Use it from OpenCode (TUI)

The same LiteLLM proxy is wired into [`opencode.json`](../opencode.json)
under a `litellm` provider, so the OpenCode model picker shows both
`ollama/...` and `litellm/claude-...` entries.

The proxy requires the master key, which lives in `.env` (gitignored).
Load it into the shell before starting OpenCode:

```bash
set -a && source .env && set +a
opencode
```

Use [direnv](https://direnv.net/) to make that automatic per directory.

### Adding more providers

Edit `.env`:

```env
OPENAI_PROVIDER_API_KEY=sk-...
GEMINI_API_KEY=...
```

Then uncomment the matching block in
[`litellm/config.yaml`](../litellm/config.yaml) and re-run
`bash scripts/32-setup-cloud-models.sh`. Anything you don't want listed,
delete from that file.

### Stopping the cloud proxy

The local stack keeps running:

```bash
docker compose --profile cloud stop litellm
```

The Open WebUI dropdown will fall back to local-only models on next
refresh.

### Privacy note

Calls routed to a cloud model leave your host (that's the whole point —
they're cloud models). Calls to local Ollama models still never leave.
LiteLLM logs requests at `INFO` level by default — set `LITELLM_LOG=WARNING`
in `.env` to quiet that.

---

## Option D — Claude Code TUI, local Ollama brain

Same `claude` CLI as Option B, but instead of going to Anthropic the
requests go to the LiteLLM proxy from Option C, which forwards them to a
local Ollama model. You get the polished Claude Code UI without burning
subscription tokens — useful for routine edits, drafts, and "rubber-duck"
work where cloud Claude is overkill.

The mechanism is a stock Claude Code feature: it reads
`ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` from the environment and
calls `/v1/messages` on whatever URL you point it at. LiteLLM speaks that
endpoint natively for Ollama backends.

```
┌──────────────┐  /v1/messages   ┌────────────┐   /api/chat   ┌─────────┐
│  claude TUI  │ ───────────────►│  LiteLLM   │ ─────────────►│ Ollama  │
│ (unmodified) │  Anthropic JSON │ (Anthropic │  Ollama JSON  │  (GPU)  │
└──────────────┘                 │  adapter)  │               └─────────┘
                                 └────────────┘
```

### Prerequisites

- Option C set up first (so LiteLLM is configured and `LITELLM_MASTER_KEY`
  exists in `.env`).
- The `claude` CLI installed (`bash scripts/31-setup-claude-code.sh` — you
  do not need to log in for Option D, the wrapper bypasses login).

### One-time setup

```bash
bash scripts/33-setup-claude-local.sh                       # default: qwen2.5-coder (7B)
# or pick another LiteLLM model_name:
bash scripts/33-setup-claude-local.sh qwen2.5-coder-large   # 32B, much better tool calls
bash scripts/33-setup-claude-local.sh nemotron-nano
```

That script:
1. Verifies `edge-ollama` and `edge-litellm` are running (starts LiteLLM if not).
2. Verifies the requested model is registered in
   [`litellm/config.yaml`](../litellm/config.yaml) and the underlying Ollama
   tag is pulled (offers to pull if missing).
3. Recreates LiteLLM if needed so newly added entries become visible.
4. Installs a wrapper script (`claude-local`, or `claude-local-<model>`) that
   exports the right env vars and execs `claude`.

### Use it

```bash
cd /path/to/anywhere
claude-local                      # qwen2.5-coder
claude-local-qwen2.5-coder-large  # 32B, if you ran the 32B setup
```

The TUI is identical to a normal `claude` session. The model line at the
top shows the local model name. All inference happens on the GPU.

The plain `claude` command (no `-local` suffix) is **untouched** and still
talks to Anthropic via your subscription.

### Adding a new local model

1. Pull it: `bash scripts/04-pull-model.sh <ollama-tag>`
2. Add an entry under `model_list:` in
   [`litellm/config.yaml`](../litellm/config.yaml):
   ```yaml
   - model_name: my-model
     litellm_params:
       model: ollama_chat/<ollama-tag>
       api_base: http://ollama:11434
   ```
3. `bash scripts/33-setup-claude-local.sh my-model`

### Caveats

- Claude Code expects Anthropic-style tool calls. 7B-class models mis-format
  them often — fine for chat / single-file edits, flaky for multi-step tool
  use. Use `qwen2.5-coder-large` (32B) when you need reliable tool use.
- The hardest reasoning still loses to cloud Claude. For multi-file refactors
  prefer Option B (cloud brain, local worker).
- LiteLLM logs every request at `INFO` by default. Set
  `LITELLM_LOG=WARNING` in `.env` to quiet the container logs.

---

## Verifying the MCP server by hand

Useful for debugging without launching a full agent:

```bash
# List the tools the server advertises
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | python3 scripts/lib/ollama-mcp-server.py

# Run a generation end-to-end
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"ollama_list_models","arguments":{}}}' \
  | python3 scripts/lib/ollama-mcp-server.py
```

---

## Troubleshooting

**`/mcp` shows the server as failed** — Run the verification snippet above. If
it errors with `URLError`, start the stack: `bash scripts/01-start.sh`.

**Model not found** — `bash scripts/05-list-models.sh` to see what's installed,
then `bash scripts/04-pull-model.sh <name>`.

**OpenCode can't see Ollama** — Confirm `curl -s http://localhost:11434/api/tags`
returns JSON. If you run OpenCode from a different host, change `baseURL` in
`opencode.json` to the EdgeXpert's IP.

**Claude Code MCP edits live where?** — `~/.claude.json` (user scope). To
remove: `claude mcp remove ollama --scope user`.

**Both setups break after I upgraded the stack** — Models live on the host
(`${AI_DATA_ROOT}/ollama`), so they survive. Re-run `01-start.sh`; nothing
about MCP wiring depends on container internals.
