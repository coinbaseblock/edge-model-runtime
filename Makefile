SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help setup lint test format verify quick-check hooks-install ai-review ai-fix ai-pr

help:
	@echo "Targets:"
	@echo "  make setup         - bootstrap local tooling"
	@echo "  make lint          - run shellcheck on scripts"
	@echo "  make test          - compose render + safety invariants"
	@echo "  make format        - normalize shell script permissions"
	@echo "  make verify        - run runtime verification"
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
	sed -i 's|^WEBUI_SECRET_KEY=$|WEBUI_SECRET_KEY=local-test-key|' .env.ci
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
