SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help setup lint test format verify quick-check hooks-install \
        ai-review ai-fix ai-pr \
        up down webui codex claude-local claude-cloud cloud-models apply-patch

help:
	@echo "Stack:"
	@echo "  make up            - start core services (Ollama + Open WebUI)"
	@echo "  make down          - stop core services"
	@echo "  make webui         - open Open WebUI in your browser (http://localhost:3000)"
	@echo "  make verify        - run runtime verification"
	@echo ""
	@echo "AI coding entry points (pick one):"
	@echo "  make codex         - launch OpenCode TUI (Option A, 100% local, edits files & runs gh)"
	@echo "  make claude-local  - launch Claude Code TUI on a local Ollama model (Option D)"
	@echo "  make claude-cloud  - launch Claude Code TUI on Anthropic (Option B, brain) + local MCP worker"
	@echo "  make cloud-models  - register cloud models (Claude/GPT/Gemini) into the WebUI dropdown (Option C)"
	@echo "  make apply-patch P=/tmp/x.patch [COMMIT=1 PUSH=1 PR=1 FORCE=1] [MSG=\"...\"]"
	@echo "                     - apply a patch from WebUI (Web Codex flow); refuses dirty tree unless FORCE=1"
	@echo ""
	@echo "Dev:"
	@echo "  make setup         - bootstrap local tooling"
	@echo "  make lint          - run shellcheck on scripts"
	@echo "  make test          - compose render + safety invariants"
	@echo "  make format        - normalize shell script permissions"
	@echo "  make quick-check   - lint + test (pre-commit grade)"
	@echo "  make hooks-install - install git hooks for this repo"
	@echo "  make ai-review     - quick-check + git status"
	@echo "  make ai-fix        - format + quick-check"
	@echo "  make ai-pr         - generate PR notes stub"

setup:
	bash scripts/00-install.sh
	bash scripts/34-install-hooks.sh

lint:
	( cd scripts && shellcheck -x lib/common.sh ./*.sh )

test:
	cp .env.example .env.ci
	sed -i 's|^WEBUI_SECRET_KEY=$$|WEBUI_SECRET_KEY=local-test-key|' .env.ci
	docker compose --env-file .env.ci --env-file .env.versions config > /dev/null
	@if rg -n '^[[:space:]]*[^#]*chmod[[:space:]]+(-[A-Za-z]+[[:space:]]+)?777' scripts/; then \
		echo "FAIL: chmod 777 found"; exit 1; \
	fi
	@if rg -n '^[A-Z_]+_IMAGE=.*:(latest|main)$$' .env.versions; then \
		echo "FAIL: unpinned image tag found"; exit 1; \
	fi
	rg -n "DELETE ALL" scripts/20-wipe-models.sh > /dev/null
	@rm -f .env.ci

format:
	chmod +x scripts/*.sh

verify:
	bash scripts/03-verify.sh

quick-check: lint test

hooks-install:
	bash scripts/34-install-hooks.sh

ai-review: quick-check
	@git status --short

ai-fix: format quick-check

ai-pr:
	@echo "## Summary" > .pr-notes.md
	@echo "- Describe what changed" >> .pr-notes.md
	@echo "" >> .pr-notes.md
	@echo "## Validation" >> .pr-notes.md
	@echo "- make quick-check" >> .pr-notes.md
	@echo "Wrote .pr-notes.md"

up:
	bash scripts/01-start.sh

down:
	bash scripts/02-stop.sh

webui: up
	@PORT="$${WEBUI_PORT:-}"; \
	if [ -z "$$PORT" ] && [ -f .env ]; then \
	  PORT="$$(sed -n 's/^WEBUI_PORT=//p' .env | tail -1)"; \
	fi; \
	PORT="$${PORT:-3000}"; \
	URL="http://localhost:$$PORT"; \
	echo "Open WebUI: $$URL"; \
	if   command -v xdg-open >/dev/null 2>&1; then xdg-open "$$URL" >/dev/null 2>&1 || true; \
	elif command -v open      >/dev/null 2>&1; then open      "$$URL" >/dev/null 2>&1 || true; \
	fi

codex: up
	@command -v opencode >/dev/null 2>&1 || bash scripts/30-setup-opencode.sh
	cd $(CURDIR) && opencode

claude-local: up
	@command -v claude-local >/dev/null 2>&1 || bash scripts/33-setup-claude-local.sh
	cd $(CURDIR) && claude-local

claude-cloud: up
	@command -v claude >/dev/null 2>&1 || bash scripts/31-setup-claude-code.sh
	cd $(CURDIR) && claude

cloud-models:
	bash scripts/32-setup-cloud-models.sh

# Usage: make apply-patch P=/tmp/web.patch [COMMIT=1 PUSH=1 PR=1] [FORCE=1] [MSG="subject"]
# MSG is forwarded as a single argument so spaces/quotes survive, e.g.:
#   make apply-patch P=/tmp/x.patch COMMIT=1 MSG="fix: handle empty config"
apply-patch: export APPLY_PATCH_MSG = $(MSG)
apply-patch:
	@test -n "$(P)" || { echo "Usage: make apply-patch P=<patch-file> [COMMIT=1 PUSH=1 PR=1] [FORCE=1] [MSG=\"...\"]"; exit 2; }
	@set -- "$(P)"; \
	[ "$(COMMIT)" = "1" ] && set -- "$$@" --commit; \
	[ "$(PUSH)"   = "1" ] && set -- "$$@" --push; \
	[ "$(PR)"     = "1" ] && set -- "$$@" --pr; \
	[ "$(FORCE)"  = "1" ] && set -- "$$@" --force-dirty; \
	if [ -n "$$APPLY_PATCH_MSG" ]; then set -- "$$@" -m "$$APPLY_PATCH_MSG"; fi; \
	bash scripts/35-apply-web-patch.sh "$$@"
