# Local AI Coding Demo

This document demonstrates local Ollama-powered AI coding through emr aider.

## Usage

Interactive local mode:

    emr aider

One-shot local mode:

    emr aider -- --message "Edit the repo" --yes-always

List local models:

    emr models

Validate changes:

    make quick-check

Rollback:

    git reset --hard HEAD~1

Safety notes: do not delete Ollama model volumes, AI_DATA_ROOT, or .env secrets.
