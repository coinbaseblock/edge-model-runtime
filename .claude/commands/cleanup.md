---
description: Level-2 cleanup (remove containers + images, keep models)
---

```bash
bash scripts/10-cleanup-docker.sh
```

This is interactive and will prompt for confirmation. Models on the host are
preserved. For a full wipe (including models), the user must run
`bash scripts/20-wipe-models.sh` themselves and type `DELETE ALL`.
