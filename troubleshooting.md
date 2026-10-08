# Troubleshooting: Claude Code + a local model

Run `./doctor.sh` first: it checks most of these for you. Messages below are worded as in the Claude Code docs and the
oMLX issue tracker; **replace them with the exact lines from your own log** (`TESTED.md`) when you reproduce them.

## 1 · Connection refused (the door)
**You see:** `Connection refused — a firewall or proxy may be blocking it (ConnectionRefused)`, often after a quiet pause while Claude Code retries (up to 10 times by default).
**Cause:** the server isn't running, the port is wrong, or there's a `/v1` on the end of `ANTHROPIC_BASE_URL`.
**Fix:**
- Start the server and check it from the terminal first: `curl http://127.0.0.1:8000/health` (oMLX), `curl http://localhost:11434` (Ollama), `curl http://localhost:1234/v1/models` (LM Studio).
- Default ports: oMLX `8000` · Ollama `11434` · LM Studio `1234`.
- Use the plain address. Claude Code calls `/v1/messages` on top of `ANTHROPIC_BASE_URL`, so `http://127.0.0.1:8000/v1` becomes `/v1/v1/messages`.

Sources: [connect docs](https://code.claude.com/docs/en/llm-gateway-connect) · [env-vars (retries)](https://code.claude.com/docs/en/env-vars) · [gateway compatibility guide](https://code.claude.com/docs/en/llm-gateway-protocol)

## 2 · Login screen, auth warning, 401 (the badge)
| You see | Cause | Fix |
|---|---|---|
| The login screen, even though `curl` works | only `ANTHROPIC_BASE_URL` is set; with no token, a saved claude.ai login stays active | set `ANTHROPIC_AUTH_TOKEN` (shell export or the `env` block of the profile's `settings.json`) |
| A startup warning ending in `auth may not work as expected` | a token **and** a saved login or `ANTHROPIC_API_KEY` are both active | `/logout`, or a separate profile (`./make-profile.sh`), and `"ANTHROPIC_API_KEY": ""` |
| `API Error: 401 Invalid bearer token` and the server's log shows **nothing** | an old `env` block in `~/.claude/settings.json` points `ANTHROPIC_BASE_URL` somewhere else; the settings file usually beats your terminal | delete the old `ANTHROPIC_*` lines (`doctor.sh` section 0 shows where each value comes from), then `/status` again |
| `401` and the log **does** show the request | wrong key | copy the key again (oMLX → Security tab) |

Check with `/status` in Claude Code: a line naming `ANTHROPIC_AUTH_TOKEN` is good; a `Login method` line with your claude.ai account means it's still using the cloud.
Sources: [connect docs](https://code.claude.com/docs/en/llm-gateway-connect) · [LLM gateways](https://code.claude.com/docs/en/llm-gateway) · [env-vars (precedence)](https://code.claude.com/docs/en/env-vars) · [oMLX #2715](https://github.com/jundot/omlx/issues/2715)

## 3 · "There's an issue with the selected model" (the staff names)
**You see:** `There's an issue with the selected model (…). It may not exist or you may not have access to it.`
**Cause:** the ID doesn't match the server exactly (case matters), or one of Claude Code's other names (Opus, Sonnet, Haiku, the background model) still points at a Claude model.
**Fix:**
- Copy the ID: `curl -s http://127.0.0.1:8000/v1/models -H "Authorization: Bearer $OMLX_KEY"` (Ollama: `ollama list`).
- Set `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL` and `ANTHROPIC_DEFAULT_HAIKU_MODEL` to that ID.
- `ANTHROPIC_SMALL_FAST_MODEL` is deprecated: use `ANTHROPIC_DEFAULT_HAIKU_MODEL`.
- Authenticate with `ANTHROPIC_AUTH_TOKEN`, not `ANTHROPIC_API_KEY`: with an API key and a custom address, background jobs can fall back to the default Haiku name.

Sources: [errors](https://code.claude.com/docs/en/errors) · [env-vars](https://code.claude.com/docs/en/env-vars) · [model configuration](https://code.claude.com/docs/en/model-config) · [gateway compatibility guide](https://code.claude.com/docs/en/llm-gateway-protocol)

## 4 · "Prompt is too long", or it silently forgets (the notepad)
**You see:** `Prompt is too long` (or the server's own wording), or no error while the agent re-reads files it already read.
**Cause:** for an unrecognised model ID Claude Code assumes a 200K-token context; the server is set much smaller (Ollama: 4K on Macs with under 24 GB of graphics memory). When the server words the error differently, Claude Code doesn't recognise it and doesn't compact and retry by itself.
**Fix:**
1. Bigger context on the server: Ollama app → Settings, or `OLLAMA_CONTEXT_LENGTH=65536 ollama serve` (Ollama recommends 64K+ for Claude Code); LM Studio: more than ~25K; oMLX: the model's context window setting (oMLX's context scaling also makes auto-compact trigger at the right time).
2. Tell Claude Code the real size: `"CLAUDE_CODE_MAX_CONTEXT_TOKENS": "65536"`.
3. Stuck mid-session: `/compact`.
4. Bigger context = more memory. On 16 GB, check `ollama ps` still says `100% GPU`; if not, step down to 32K.

Don't use `CLAUDE_CODE_AUTO_COMPACT_WINDOW` for this: its minimum is 100,000.
Sources: [gateway compatibility guide](https://code.claude.com/docs/en/llm-gateway-protocol) · [env-vars](https://code.claude.com/docs/en/env-vars) · [connect docs](https://code.claude.com/docs/en/llm-gateway-connect) · [Ollama context length](https://docs.ollama.com/context-length) · [Ollama + Claude Code](https://docs.ollama.com/integrations/claude-code) · [LM Studio + Claude Code](https://lmstudio.ai/docs/integrations/claude-code) · [oMLX README](https://github.com/jundot/omlx)

## 5 · It explains the fix but never edits a file (the tools)
**You see:** a good explanation and no change to the file; or raw tool markup such as `<tool_call|>` or `[Tool call: …]` printed as text.
**Cause:** the model is too small or not trained for tool calling, or the server mis-parses that model's tool format.
**Fix:**
- Raw markup in the reply: update your server (both oMLX reports were parser bugs fixed in updates).
- Prose only: use a bigger model that supports tools ([models.md](models.md)). `./doctor.sh --tools` tells you which case you're in.
- Test with one tiny edit first ("add a comment to line 1 of hello.py").

Sources: [oMLX #159](https://github.com/jundot/omlx/issues/159) · [oMLX #617](https://github.com/jundot/omlx/issues/617)

## Bonus · It broke after a Claude Code update
**You see:** every request fails with `400`/`422`, for example `Extra inputs are not permitted`, `context_management`, or `Input should be 'user' or 'assistant'`.
**Cause:** a new Claude Code release sends fields the local server doesn't accept yet.
**Fix:** update the server first; then `"CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"` (suppresses most pre-release fields); last resort, install the previous Claude Code version until the server catches up.
Sources: [connect docs](https://code.claude.com/docs/en/llm-gateway-connect) · [oMLX #1503](https://github.com/jundot/omlx/issues/1503)

## Also seen
| Symptom | Cause | Fix | Source |
|---|---|---|---|
| Auto mode: `… is temporarily unavailable, so auto mode cannot determine the safety of Bash right now` | auto mode's safety check needs a second request at the same time; the server allows only one | raise the server's concurrent requests (oMLX: Max Concurrent Requests), or don't use auto mode locally | [oMLX #2067](https://github.com/jundot/omlx/issues/2067) |
| Every turn re-reads the whole prompt (very slow) | before Claude Code 2.1.181, an attribution block changed the start of the prompt each request, breaking the server's prompt cache | update Claude Code; `CLAUDE_CODE_ATTRIBUTION_HEADER=0` is still harmless (LM Studio's docs set it) | [gateway compatibility guide](https://code.claude.com/docs/en/llm-gateway-protocol) · [LM Studio docs](https://lmstudio.ai/docs/integrations/claude-code) |
