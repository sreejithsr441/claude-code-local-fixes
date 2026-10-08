# A tool-capable model for each Mac size

Claude Code needs a model that **calls tools reliably** (fix 5). Small 4B-class models connect fine but tend to fumble
tool calls; **27B-class models are the practical minimum** for real agentic work. Check any pick with
`./doctor.sh --tools`, then one small edit in Claude Code.

Sizes are Ollama download sizes (from the Ring Zero "Which AI Model Fits Your Mac?" tests, checked Oct 2026). The model
must fit in the share of memory the graphics chip gets (about two-thirds of RAM up to 36 GB), **plus** room for a 32K–64K context.

| Mac memory | Use with Claude Code | Size | Notes |
|---|---|---|---|
| 8 GB | not recommended | — | `qwen3.5:4b` (3.3 GB) is fine for testing the plumbing (fixes 1–4), not for real edits |
| 16 GB | light tasks only | — | `qwen3.5:9b` (6.6 GB) lists tool support but is below the 27B class; expect fix-5 behaviour. `gpt-oss:20b` (14 GB) doesn't fit the ~11.5 GB budget |
| 24 GB | `gpt-oss:20b` | 14 GB | tool calling; leaves room for a 32K–64K context |
| 32 GB | `qwen3.6:27b-q4_K_M` | 17 GB | 27B class; on oMLX the MLX 4-bit build (e.g. `Qwen3.6-27B-4bit`) is about 15 GB |
| 36–48 GB | `qwen3.6:35b-a3b-q4_K_M` or `qwen3-coder:30b` | 24 GB (35B-A3B) | mixture-of-experts: big model, fast (about 3B active) |

**On oMLX or LM Studio** the IDs are different (for example `Qwen3.6-27B-4bit`): copy the exact ID from
`curl http://127.0.0.1:8000/v1/models` or let `./make-profile.sh` list them.

[TEST] Replace this table with the picks you measured (`TESTED.md`): did each one edit the file in the fix-5 test?
