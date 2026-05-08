---
description: Pull an Ollama model. Argument is `<model[:tag]>` from https://ollama.com/library.
argument-hint: <model[:tag]>
---

Pull the requested model:

```bash
bash scripts/04-pull-model.sh $ARGUMENTS
```

If the user did not specify a model, suggest one based on their machine's VRAM
(see `docs/MODEL-RECOMMENDATIONS.md`). For a Nemotron variant, prefer
`/nemotron` instead — it picks the right tag and prints VRAM expectations.
