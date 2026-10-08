# Claude Code + Local Model: Fixing the 5 Most Common Errors

Companion folder for the Ring Zero video **"Claude Code + Local Model: Fixing the 5 Most Common Errors"** · [watch it here](VIDEO_URL)

Claude Code with a model on your own Mac (oMLX, Ollama or LM Studio) breaks in five ways, and every one is Claude Code looking for something from Anthropic's servers: the **door** (address), the **badge** (key), the **staff names** (model names), the **notepad** (context size) and the **tools**.

> Anthropic doesn't officially support routing Claude Code to non-Claude models ([Claude Code docs](https://code.claude.com/docs/en/llm-gateway)). These are fixes for the community setups people use anyway.

## Quick start

```bash
git clone https://github.com/sreejithsr441/claude-code-local-fixes.git
cd ring-zero-examples/claude-code-local-fixes
./doctor.sh            # which of the five is it? (read-only; works with the Wi-Fi off)
./doctor.sh --tools    # also asks your model to call one tool (fix 5)
```

Starting fresh? Make a separate profile with every fix built in (your normal `claude` and its login stay as they are):

```bash
./make-profile.sh omlx --key sk-omlx-...     # key from oMLX → Security tab
./make-profile.sh ollama
./make-profile.sh lmstudio
```

It lists your server's models, writes `~/.claude-<server>/settings.json`, and prints the alias to add to `~/.zshrc` (for example `alias claude-omlx="CLAUDE_CONFIG_DIR=~/.claude-omlx claude"`).

| | What it checks |
|---|---|
| `doctor.sh` | which servers are running on 8000 / 11434 / 1234 · where every `ANTHROPIC_*` value really comes from (settings file vs terminal) · no `/v1` on the address · the key works · every model name exists on the server · deprecated `ANTHROPIC_SMALL_FAST_MODEL` · the context size Claude Code assumes · optional: a real tool call |
| `make-profile.sh` | writes a profile with the plain address, the key, `ANTHROPIC_API_KEY=""`, all four model names = your exact ID, and `CLAUDE_CODE_MAX_CONTEXT_TOKENS` |
| [`settings.local-model.json`](settings.local-model.json) | the same settings as a template to copy by hand |

Needs: a Mac, `curl` and `python3` (both come with macOS; if `python3` asks, run `xcode-select --install`). Bash 3.2 (the macOS default) is fine.

## The steps (same order as the video chapters)

### 0:00 Claude Code + local model: 5 errors
Watch the first minute for what we're fixing. Then run `./doctor.sh`.

### 0:51 Why Claude Code breaks with local models
Claude Code was built to talk to Anthropic's servers; on your Mac it's a receptionist in a new office. One habit catches most problems: **check two windows.**
1. In Claude Code, type `/status`. A line naming `ANTHROPIC_AUTH_TOKEN` = it's using your server's key. A `Login method` line naming your claude.ai account = it's still using the cloud.
2. Open your server's log (oMLX: Logs tab). A working request shows `POST /v1/messages → 200`.

### 1:36 Fix 1: Connection refused (the door)
Claude Code retries quietly first (up to 10 times), so it can look frozen.
1. Start the server, then check it **before** opening Claude Code:
   ```bash
   curl http://127.0.0.1:8000/health      # oMLX
   curl http://localhost:11434            # Ollama
   curl http://localhost:1234/v1/models   # LM Studio
   ```
2. Default ports: **oMLX 8000 · Ollama 11434 · LM Studio 1234**.
3. **Spot the bug:** `"ANTHROPIC_BASE_URL": "http://127.0.0.1:8000/v1"`. Claude Code adds `/v1/messages` itself, so this calls `/v1/v1/messages`. Use the plain address, nothing after the port.

### 2:29 Fix 2: login screen, auth conflict, 401 (the badge)
| You see | Why | Fix |
|---|---|---|
| The login screen | only the address is set; a URL isn't a key | set `ANTHROPIC_AUTH_TOKEN` (oMLX: Security tab key · Ollama: `ollama` · LM Studio: `lmstudio`) |
| `…auth may not work as expected` | two badges: the token **and** a saved login or `ANTHROPIC_API_KEY` | `/logout`, or a separate profile (`make-profile.sh`), and `"ANTHROPIC_API_KEY": ""` |
| `401` and your server's log is **empty** | an old `ANTHROPIC_*` line in `~/.claude/settings.json` points somewhere else. A settings file **usually beats** what you typed in the terminal | delete the old `ANTHROPIC_*` lines, check `/status` again (`doctor.sh` section 0 shows where each value comes from) |
| `401` and the log **does** show the request | wrong key | copy it again (oMLX → Security tab) |

### 3:35 Fix 3: There's an issue with the selected model (the staff names)
Your server only answers to the model's **exact** ID (`Qwen3.6-27B-4bit` isn't `qwen3.6-27b`). Copy it, never type it:
```bash
curl -s http://127.0.0.1:8000/v1/models -H "Authorization: Bearer $OMLX_KEY"   # Ollama: ollama list
```
Claude Code also knows three staff names (Opus, Sonnet, Haiku) plus a background model for small jobs like titles. Point **all of them** at your model: `ANTHROPIC_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`. `ANTHROPIC_SMALL_FAST_MODEL` is **deprecated**: use `ANTHROPIC_DEFAULT_HAIKU_MODEL`.

### 4:21 Fix 4: Prompt is too long (the notepad)
For a model it doesn't recognise, Claude Code assumes a **200K** context. Ollama starts most Macs at **4K**. The conversation overflows: `Prompt is too long`, or no error and the agent forgets the file it just read. Two-part fix:
1. **Bigger notepad on the server.** Ollama: app Settings → context length, or `OLLAMA_CONTEXT_LENGTH=65536 ollama serve` (Ollama recommends 64K or more for Claude Code). LM Studio: load the model with more than ~25K context. oMLX: raise the model's context window in the app.
2. **Tell Claude Code the real size:** `"CLAUDE_CODE_MAX_CONTEXT_TOKENS": "65536"` (the same number as the server).

Already stuck? Type `/compact`. A bigger context uses more memory; on a 16 GB Mac check the model still fits (Ollama: `ollama ps` should say `100% GPU`). Don't use `CLAUDE_CODE_AUTO_COMPACT_WINDOW` for this: its minimum is 100,000.

### 5:24 Fix 5: it explains but won't edit files (the tools)
Claude Code works by calling tools (read a file, edit a file, run a command). Small models often can't call them reliably: you get a good explanation and **0 edits**. `./doctor.sh --tools` asks your model to call one tool and tells you which case you're in.
- Tool calls printed as plain text (`<tool_call>…`, `[Tool call: …]`)? **Update your server**: that's a parser bug, and those get fixed fast.
- Otherwise use a bigger model that supports tools: see [models.md](models.md) for a pick per Mac size.

### 6:06 Verify it works
Server up · plain address · one badge · exact model name · real notepad size · a model that uses tools. `./doctor.sh --tools` prints **No problems found**; then in Claude Code ask for one small edit and watch it happen with the Wi-Fi off.

### 6:29 Bonus: it broke after an update
Every request fails with a `400` after a Claude Code update (for example `Extra inputs are not permitted`)? **Update your server first.** Then try `"CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"`, which suppresses most pre-release fields. Last resort: install the previous Claude Code version until the server catches up.

## Files
| File | What it is |
|---|---|
| [`doctor.sh`](doctor.sh) | the five checks, read-only |
| [`make-profile.sh`](make-profile.sh) | a separate, fixed profile for oMLX, Ollama or LM Studio |
| [`settings.local-model.json`](settings.local-model.json) | settings template |
| [`troubleshooting.md`](troubleshooting.md) | every error, its message, cause, fix and source |
| [`models.md`](models.md) | a tool-capable pick per Mac size |
| [`TESTED.md`](TESTED.md) | the setup this was tested on |

## Sources
[Connect to a gateway (troubleshooting)](https://code.claude.com/docs/en/llm-gateway-connect) · [LLM gateways](https://code.claude.com/docs/en/llm-gateway) · [gateway compatibility guide](https://code.claude.com/docs/en/llm-gateway-protocol) · [environment variables](https://code.claude.com/docs/en/env-vars) · [model configuration](https://code.claude.com/docs/en/model-config) · [errors](https://code.claude.com/docs/en/errors) · [Ollama + Claude Code](https://docs.ollama.com/integrations/claude-code) · [Ollama context length](https://docs.ollama.com/context-length) · [LM Studio + Claude Code](https://lmstudio.ai/docs/integrations/claude-code) · [oMLX](https://github.com/jundot/omlx)

Questions or a different error? Paste the exact message and your Mac's RAM in the video's comments.
