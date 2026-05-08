# AI-assisted coding on this stack

Five ways to use this runtime. Pick one — they coexist.

| | A · OpenCode | B · Claude Code + Ollama worker | C · Unified Web Chat | D · Agents in browser | E · Claude Code + local brain |
|---|---|---|---|---|---|
| Main interface | TUI | TUI | Open WebUI | ttyd terminal | TUI / ttyd |
| What you get | Local agentic | Cloud agent + local offload | Chat with any model | A and B in a browser | Claude UI + Ollama brain |
| Inference | 100% local | Cloud Claude **+** local | Local + cloud dropdown | Same as A and B | 100% local (via LiteLLM) |
| Cost | $0 | Claude subscription | $0 + per-cloud-token | Same as A and B | $0 |
| Best when | offline | hardest reasoning | quick chat | tablet, no SSH | you like Claude Code's UX but want local |

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

## Option D — Agents in the browser (no terminal needed)

Spins up a small container that bundles **both** OpenCode and Claude Code
behind [ttyd](https://github.com/tsl0922/ttyd) — a terminal in a browser
tab. Open the URL, log in with basic auth, and a menu lets you pick which
agent to launch:

```
[1] OpenCode      — local Ollama
[2] Claude Code   — cloud Claude
[3] Bash shell    — anything else
```

Useful when:
- You're on a tablet / Chromebook / locked-down machine without an SSH
  client.
- You want to leave a long-running agent session attached to the host
  and reconnect from any browser.
- You're demoing the stack to someone and just want to share a URL.

### One-time setup

```bash
bash scripts/33-setup-agents-web.sh
```

That wizard:
1. Generates `AGENTS_WEB_USER` / `AGENTS_WEB_PASS` in `.env`.
2. Creates persistent state dirs under `${AI_DATA_ROOT}/agents-web/`
   so `claude login` and OpenCode config survive container rebuilds.
3. Builds the `agents-web` image (Node 20 + claude + opencode + ttyd).
4. Starts the `agents` profile.
5. Prints the URL and credentials.

### Use it

1. Open `http://localhost:7681` in your browser.
2. Log in with the printed user / password.
3. Pick `[1]`, `[2]`, or `[3]`.

First time you pick **Claude Code**, run `claude login` inside it to
authenticate against your subscription. The OAuth token is written to
`/root/.claude` in the container, which is bind-mounted to
`${AI_DATA_ROOT}/agents-web/claude` on the host — so it persists across
rebuilds and image upgrades.

OpenCode reads `opencode.json` from `/workspace` (your repo). Both local
Ollama and (if `cloud` profile is up) LiteLLM cloud models appear in the
picker.

### Networking

The container uses **`network_mode: host`** so the same `localhost:11434`
and `localhost:4000` URLs that work from your terminal also work from
inside it. No URL rewriting in `opencode.json` needed.

That means by default, the ttyd port (7681) is bound by the entrypoint
to `0.0.0.0` and reachable from your LAN. If you want to restrict it to
localhost only (recommended unless you have other auth in front), put
ttyd behind a reverse proxy or change `entrypoint.sh` to add
`--interface lo`.

### Stopping

```bash
docker compose --profile agents stop agents-web
```

To rotate the password: clear `AGENTS_WEB_PASS` in `.env` and re-run
`bash scripts/33-setup-agents-web.sh`.

---

## Option E — Claude Code TUI driving a local model

The `claude` CLI is just a frontend — it does HTTP to whatever
`ANTHROPIC_BASE_URL` points to. LiteLLM (already running for Option C)
exposes Anthropic's `/v1/messages` shape, so Claude Code can talk to
your local Qwen / DeepSeek / Nemotron without any of its requests
leaving the host.

### Prerequisites

- LiteLLM up: `bash scripts/32-setup-cloud-models.sh` (cloud API key
  optional — local models work without it)
- The Ollama model you want pulled: `bash scripts/04-pull-model.sh qwen2.5-coder:7b`

### One-time setup

```bash
bash scripts/34-setup-claude-local.sh                # default qwen2.5-coder
bash scripts/34-setup-claude-local.sh qwen2.5-coder-large
bash scripts/34-setup-claude-local.sh deepseek-coder
```

That writes `~/.claude/settings-edge-local-<model>.json` with these env
overrides (mirrors the LM-Studio + Claude Code recipe shown in
[this video](https://www.youtube.com/watch?v=Cyn_Dm05_eU), but using the
LiteLLM proxy you already run):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_AUTH_TOKEN": "<your LITELLM_MASTER_KEY>",
    "ANTHROPIC_MODEL": "qwen2.5-coder",
    ...
  }
}
```

### Use it

```bash
claude --settings ~/.claude/settings-edge-local-qwen2.5-coder.json
```

Or, more conveniently:

```bash
echo "alias claude-local='claude --settings ~/.claude/settings-edge-local-qwen2.5-coder.json'" >> ~/.bashrc
```

The TUI looks identical to cloud Claude Code — same slash commands,
same agent loop, same MCP servers (Ollama, GitHub) — but every
completion comes from your local GPU.

In the **agents-web** browser terminal (Option D), this is menu
option `[3]` — it auto-picks the most recently generated settings file.

### Caveats

- **Tool-use quality varies**. Claude Code emits Anthropic-format tool
  calls; LiteLLM converts them, but the local model still has to obey
  the schema. 7B models miss often; 32B is much more reliable; for
  hardest jobs cloud Claude is still ahead.
- **No subscription needed for this mode.** Cloud Claude is still
  available with plain `claude` (no `--settings`).
- **Model size matters**. `qwen2.5-coder-large` (32B) ~ 19 GB VRAM,
  `qwen2.5-coder` (7B) ~ 4.7 GB. Pick what fits.

### Adding a model

Edit [`litellm/config.yaml`](../litellm/config.yaml), add a new entry under
`model_list:`:

```yaml
- model_name: my-model
  litellm_params:
    model: ollama_chat/some-tag:latest
    api_base: http://ollama:11434
```

Then reload LiteLLM and re-run the setup script:

```bash
docker compose --profile cloud up -d --force-recreate litellm
bash scripts/34-setup-claude-local.sh my-model
```

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
