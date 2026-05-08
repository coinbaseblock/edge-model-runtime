---
description: Pull an NVIDIA Nemotron model (default: nano). Argument is the variant.
argument-hint: [mini|nano|nano-omni|super|cascade|70b]
---

Pull the requested Nemotron variant. If no variant is given, default to `nano`.

| Variant | Ollama tag | Active params | VRAM (rough) | Best for |
|---|---|---|---|---|
| `mini` | `nemotron-mini` | 4B | ~6 GB | edge, function calling, low VRAM |
| `nano` | `nemotron-3-nano` | 3.5B / 30B MoE | ~20 GB | default agent / reasoning |
| `nano-omni` | `nemotron3:33b` | 33B multimodal | ~24 GB | OCR, video+audio+image+text |
| `super` | `nemotron-3-super` | 12B / 120B MoE | ~80 GB | strong reasoning, IT automation |
| `cascade` | `nemotron-cascade-2` | 3B / 30B MoE | ~20 GB | agentic, low active params |
| `70b` | `nemotron` | 70B (Llama-3.1) | ~48 GB (q4) | RLHF helpfulness, big GPU |

If the user just types `/nemotron` with no argument, pick the variant that
best fits their machine's VRAM (use `nvidia-smi` if unsure) and explain the
choice in one line. Otherwise pass the argument straight through.

```bash
bash scripts/0a-pull-nemotron.sh ${ARGUMENTS:-nano}
```
