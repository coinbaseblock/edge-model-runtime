# AI-assisted coding on this stack

Two ways to use this runtime as the brain for AI-assisted coding. Pick one — or
run both side by side.

| | Option A · OpenCode | Option B · Claude Code + Ollama worker |
|---|---|---|
| Main agent | OpenCode (open source) | Claude Code (subscription) |
| Inference | 100% local Ollama | Cloud Claude **+** local Ollama for offload |
| Cost | $0 | Claude subscription |
| Privacy | Code never leaves the host | Main edits go through Claude; offloaded work stays local |
| Best when | offline / privacy required | hardest reasoning, multi-file refactor |

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
