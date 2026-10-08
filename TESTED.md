# Tested

Fill this in from your own run before publishing. Copy error texts exactly (paste, don't retype).

| | Value |
|---|---|
| Mac / chip | |
| Memory | |
| macOS | |
| Claude Code (`claude --version`) | (latest on Oct 3, 2026: 2.1.289) |
| oMLX | |
| Ollama (`ollama --version`) | |
| LM Studio | |
| Model (fix 5, big) | |
| Model (fix 5, small) | |
| Context window (server / `CLAUDE_CODE_MAX_CONTEXT_TOKENS`) | / |
| Date | |

## Error log (exact texts)

| Fix | How you caused it | Exact message | Server log |
|---|---|---|---|
| 1 | server off | | |
| 1 | `/v1` on the address | | |
| 2 | address only, no token | | |
| 2 | token + saved login | | |
| 2 | stale `~/.claude/settings.json` | | (empty?) |
| 2 | wrong key | | |
| 3 | typo in `ANTHROPIC_MODEL` | | |
| 4 | Ollama at 4K / oMLX at 32K | | |
| 5 | small vs big model, same edit | small: edited? · big: edited? | |
| Bonus | 400 after an update (if it reproduces) | | |

## doctor.sh

Paste the output of `./doctor.sh --tools` on the final working setup.
