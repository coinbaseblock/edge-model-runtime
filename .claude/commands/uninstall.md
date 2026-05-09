---
description: Interactive uninstall menu (4 tiers: stop / remove containers / + host tools / wipe everything)
---

```bash
bash scripts/uninstall.sh
```

The menu offers four tiers:

| Tier | Removes | Models? |
|---|---|---|
| 1 | Running containers (`02-stop.sh`) | kept |
| 2 | Containers + Docker images (`10-cleanup-docker.sh`) | kept |
| 3 | Tier 2 + host wrappers / MCP regs / npm globals (`--include-host-tools`) | kept |
| 4 | EVERYTHING incl. models (`20-wipe-models.sh`, requires typing `DELETE ALL`) | DELETED |

If the user wants to fully reclaim disk space, suggest Tier 4 explicitly.
For "just remove the agentic CLIs but keep my downloaded models," suggest
Tier 3.
