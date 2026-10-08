#!/usr/bin/env bash
# doctor.sh — which of the five Claude Code + local model mistakes is it?
#
#   ./doctor.sh                       check the default Claude Code profile (~/.claude)
#   CLAUDE_CONFIG_DIR=~/.claude-omlx ./doctor.sh     check a separate profile (e.g. your claude-omlx alias)
#   ./doctor.sh --tools               also ask the model to call a tool once (fix 5; takes a while on big models)
#
# Read-only: it never changes your settings. Everything goes to 127.0.0.1, so it works with the Wi-Fi off.
# Exit code = number of problems found (0 = all good).
# Works with the bash that ships with macOS (3.2). Needs curl and python3 (xcode-select --install).

set -u
TOOLS=0; [ "${1:-}" = "--tools" ] && TOOLS=1
PROBLEMS=0
if [ -t 1 ]; then R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; D=$'\033[2m'; N=$'\033[0m'; else R=''; G=''; Y=''; B=''; D=''; N=''; fi
ok()   { echo "  ${G}✓${N} $*"; }
bad()  { echo "  ${R}✗${N} $*"; PROBLEMS=$((PROBLEMS + 1)); }
warn() { echo "  ${Y}!${N} $*"; }
fix()  { echo "    ${D}fix:${N} $*"; }
head_() { echo; echo "${B}$*${N}"; }
command -v curl >/dev/null 2>&1 || { echo "curl is missing"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is needed to read JSON (run: xcode-select --install)"; exit 1; }

CFG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CFG_DIR="${CFG_DIR/#\~/$HOME}"
TL='~'; short() { echo "${1/#$HOME/$TL}"; }
VARS="ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_SMALL_FAST_MODEL CLAUDE_CODE_MAX_CONTEXT_TOKENS CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS"

# env_from FILE VAR → value of "env": {"VAR": ...} in a settings file ("" if unset); __UNSET__ if the key is absent
env_from() {
  [ -f "$1" ] || { echo "__UNSET__"; return; }
  python3 - "$1" "$2" <<'PY' 2>/dev/null || echo "__BADJSON__"
import json, sys
d = json.load(open(sys.argv[1])); e = d.get("env") or {}
print(e[sys.argv[2]] if sys.argv[2] in e else "__UNSET__")
PY
}

# Settings files Claude Code reads, highest priority first (project local, project, user).
FILES="$PWD/.claude/settings.local.json $PWD/.claude/settings.json $CFG_DIR/settings.json"

# effective VAR → "value|source". A settings file usually beats the shell (Claude Code env-vars docs).
effective() {
  for f in $FILES; do
    v=$(env_from "$f" "$1")
    if [ "$v" = "__BADJSON__" ]; then echo "__BADJSON__|$f"; return; fi
    if [ "$v" != "__UNSET__" ]; then echo "$v|$f"; return; fi
  done
  if [ -n "${!1+x}" ]; then echo "${!1}|shell"; return; fi
  echo "|unset"
}
val() { effective "$1" | sed 's/|[^|]*$//'; }
src() { effective "$1" | sed 's/.*|//'; }
mask() { s="$1"; [ ${#s} -le 8 ] && { echo "$s"; return; }; echo "${s:0:6}…${s: -3}"; }

echo "${B}Claude Code + local model doctor${N}"
CCV=$(claude --version 2>/dev/null | head -1)
echo "${D}profile: $(short "$CFG_DIR") · project: $(short "$PWD")${CCV:+ · Claude Code $CCV}${N}"

# ------------------------------------------------------------------ 0. what Claude Code will use
head_ "0  What Claude Code will use (settings file usually beats the terminal)"
for f in $FILES; do
  [ -f "$f" ] || continue
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f" 2>/dev/null || { bad "$f isn't valid JSON, so Claude Code can't read it"; fix "check commas and quotes (python3 -m json.tool \"$f\")"; }
done
for v in $VARS; do
  e=$(effective "$v"); value="${e%|*}"; where="${e##*|}"
  [ "$where" = "unset" ] && continue
  shown="$value"; case "$v" in *TOKEN*|*KEY*) [ -n "$value" ] && shown=$(mask "$value");; esac
  [ "$where" = "shell" ] && where="terminal (export)"
  where=$(short "$where")
  printf "  %-34s %-38s ${D}%s${N}\n" "$v" "${shown:-\"\"}" "$where"
  # the terminal value is ignored when a settings file also sets it
  if [ "$where" != "terminal (export)" ] && [ -n "${!v+x}" ] && [ "${!v}" != "$value" ]; then
    warn "your terminal also sets $v=${!v}, but the settings file wins"
  fi
done

BASE=$(val ANTHROPIC_BASE_URL); TOKEN=$(val ANTHROPIC_AUTH_TOKEN); APIKEY=$(val ANTHROPIC_API_KEY)
MODEL=$(val ANTHROPIC_MODEL)

# ------------------------------------------------------------------ 1. the door: server + address
head_ "1  The door: is a server answering, at the right address?"
FOUND=""
probe() {  # name port path
  if curl -s -o /dev/null -m 2 "http://127.0.0.1:$2$3"; then ok "$1 is answering on port $2"; FOUND="$FOUND $2"; else echo "  ${D}·${N} $1 not running on port $2"; fi
}
probe "oMLX" 8000 /health
probe "Ollama" 11434 /api/version
probe "LM Studio" 1234 /v1/models
[ -n "$FOUND" ] || { bad "no local server is running"; fix "start oMLX (menu bar), Ollama (app or 'ollama serve') or LM Studio ('lms server start --port 1234')"; }

if [ -z "$BASE" ]; then
  bad "ANTHROPIC_BASE_URL isn't set, so Claude Code talks to Anthropic's servers"
  fix "set it to http://127.0.0.1:8000 (oMLX), http://localhost:11434 (Ollama) or http://localhost:1234 (LM Studio) — see settings.local-model.json"
else
  case "$BASE" in
    */v1|*/v1/) bad "ANTHROPIC_BASE_URL ends in /v1 ($BASE): Claude Code adds /v1/messages itself, so it calls …/v1/v1/messages"
                fix "use the plain address, nothing after the port: ${BASE%/v1*}"; BASE="${BASE%/v1*}";;
    */) BASE="${BASE%/}";;
  esac
  if curl -s -o /dev/null -m 3 "$BASE"; then ok "something answers at $BASE"
  else bad "nothing answers at $BASE (Connection refused)"; fix "start the server, or fix the port: oMLX 8000 · Ollama 11434 · LM Studio 1234"; fi
fi

# ------------------------------------------------------------------ 2. the badge: key
head_ "2  The badge: does it have a key for your server?"
MODELS_JSON=""
if [ -z "$TOKEN" ]; then
  bad "ANTHROPIC_AUTH_TOKEN isn't set: Claude Code falls back to your Claude login (login screen, or it ignores your server)"
  fix "oMLX: the key from its Security tab · Ollama: \"ollama\" · LM Studio: \"lmstudio\" (or your LM_API_TOKEN)"
else
  ok "ANTHROPIC_AUTH_TOKEN is set ($(mask "$TOKEN"))"
fi
if [ -n "$APIKEY" ]; then
  warn "ANTHROPIC_API_KEY is also set: two badges ('auth may not work as expected'), and background jobs may ask for a Claude model"
  fix "set \"ANTHROPIC_API_KEY\": \"\" (as Ollama's docs do), or remove it"
fi
STATE="$CFG_DIR/.claude.json"; [ "$CFG_DIR" = "$HOME/.claude" ] && STATE="$HOME/.claude.json"
if grep -q '"oauthAccount"' "$STATE" 2>/dev/null; then
  warn "this profile also has a saved Claude login: if /status shows 'Login method', run /logout, or use a separate profile (CLAUDE_CONFIG_DIR=~/.claude-local claude)"
fi
if [ -n "$BASE" ] && curl -s -o /dev/null -m 3 "$BASE"; then
  CODE=$(curl -s -o /tmp/rz_models.$$ -w '%{http_code}' -m 5 -H "Authorization: Bearer $TOKEN" -H "x-api-key: $TOKEN" "$BASE/v1/models")
  case "$CODE" in
    200) ok "the server accepts the key (GET /v1/models → 200)"; MODELS_JSON=/tmp/rz_models.$$;;
    401|403) bad "the server rejects the key ($CODE)"; fix "copy it again (oMLX: Security tab) — and check the request shows up in your server's log"
             echo "  ${D}401 in Claude Code but your server's log is empty? An old ANTHROPIC_* line in a settings file points somewhere else: section 0 shows where each value comes from${N}";;
    *) warn "GET $BASE/v1/models answered $CODE, so the model check below is skipped";;
  esac
fi

# ------------------------------------------------------------------ 3. the staff names: model IDs
head_ "3  The staff names: does every model name exist on your server?"
if [ -n "$MODELS_JSON" ]; then
  IDS=$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); print("\n".join(m.get("id","") for m in d.get("data",[])))' "$MODELS_JSON" 2>/dev/null)
  echo "  ${D}your server has:${N} $(echo "$IDS" | tr '\n' ' ')"
  for v in ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL; do
    m=$(val "$v")
    if [ -z "$m" ]; then
      if [ "$v" = ANTHROPIC_MODEL ]; then bad "$v isn't set"; fix "copy an ID from the list above"
      else warn "$v isn't set: when Claude Code asks for that name, your server gets a Claude model name"; fix "set it to the same ID as ANTHROPIC_MODEL"; fi
    elif echo "$IDS" | grep -qxF "$m"; then ok "$v = $m"
    else
      near=$(echo "$IDS" | grep -ixF "$m" | head -1)
      bad "$v = $m isn't on your server ('There's an issue with the selected model')"
      [ -n "$near" ] && fix "case matters: use $near" || fix "copy the exact ID from the list above (Ollama: 'ollama list')"
    fi
  done
else
  warn "skipped (the server didn't return a model list)"
fi
if [ -n "$(val ANTHROPIC_SMALL_FAST_MODEL)" ]; then
  warn "ANTHROPIC_SMALL_FAST_MODEL is deprecated"; fix "use ANTHROPIC_DEFAULT_HAIKU_MODEL instead"
fi

# ------------------------------------------------------------------ 4. the notepad: context size
head_ "4  The notepad: does Claude Code know the real context size?"
MAXCTX=$(val CLAUDE_CODE_MAX_CONTEXT_TOKENS)
if [ -z "$MAXCTX" ]; then
  warn "CLAUDE_CODE_MAX_CONTEXT_TOKENS isn't set: for a model it doesn't recognise, Claude Code assumes 200K"
  fix "set it to your server's real context, e.g. \"65536\" (oMLX's context scaling can do this for you)"
else
  ok "CLAUDE_CODE_MAX_CONTEXT_TOKENS = $MAXCTX"
fi
case " $FOUND " in *" 11434 "*)
  if command -v ollama >/dev/null 2>&1; then
    echo "  ${D}ollama ps (CONTEXT must match, PROCESSOR should say 100% GPU):${N}"; ollama ps 2>/dev/null | sed 's/^/    /'
  fi
  warn "Ollama starts most Macs at a 4K context; Ollama recommends 64K or more for Claude Code"
  fix "Ollama app → Settings → context length, or OLLAMA_CONTEXT_LENGTH=65536 ollama serve";;
esac
case " $FOUND " in *" 1234 "*) echo "  ${D}LM Studio: load the model with a bigger context, e.g. lms load <model> --context-length 32768 (its docs ask for more than ~25k)${N}";; esac
case " $FOUND " in *" 8000 "*) echo "  ${D}oMLX: raise the model's context window in the app (32K is tight for Claude Code)${N}";; esac
[ -n "$MAXCTX" ] && [ "$MAXCTX" -gt 0 ] 2>/dev/null && echo "  ${D}a bigger context uses more memory: on a 16 GB Mac, check the model still fits${N}"

# ------------------------------------------------------------------ 5. the tools
head_ "5  The tools: can the model call a tool?"
if [ $TOOLS -eq 0 ]; then
  echo "  ${D}skipped — run ./doctor.sh --tools to ask the model to call one tool (can take a minute on a big model)${N}"
elif [ -z "$MODELS_JSON" ] || [ -z "$MODEL" ]; then
  warn "skipped (fix sections 1–3 first)"
else
  BODY=$(python3 -c '
import json,sys
print(json.dumps({"model": sys.argv[1], "max_tokens": 300,
  "tools": [{"name": "write_file", "description": "Write text to a file.",
             "input_schema": {"type": "object", "properties": {"path": {"type": "string"}, "text": {"type": "string"}}, "required": ["path", "text"]}}],
  "messages": [{"role": "user", "content": "Use the write_file tool to write hello to hello.txt. Do not explain, just call the tool."}]}))' "$MODEL")
  echo "  ${D}asking $MODEL to call write_file…${N}"
  OUT=$(curl -s -m 300 "$BASE/v1/messages" -H "content-type: application/json" -H "anthropic-version: 2023-06-01" \
        -H "Authorization: Bearer $TOKEN" -H "x-api-key: $TOKEN" -d "$BODY")
  RES=$(echo "$OUT" | python3 -c '
import json,sys
try: r=json.load(sys.stdin)
except Exception: print("noreply"); sys.exit()
if r.get("type") == "error" or "error" in r: print("error " + json.dumps(r.get("error", r))[:200]); sys.exit()
blocks = r.get("content", [])
if any(b.get("type") == "tool_use" for b in blocks): print("tool")
else:
    t = " ".join(b.get("text", "") for b in blocks if b.get("type") == "text")
    print(("leak " if ("tool_call" in t or "[Tool call" in t) else "talk ") + t.strip().replace("\n", " ")[:160])')
  case "$RES" in
    tool) ok "the model called the tool (a real tool_use block)";;
    leak*) bad "the tool call came back as plain text: ${RES#leak }"; fix "update your server (that's a parser bug) — see troubleshooting.md, fix 5";;
    talk*) bad "the model answered in words instead of calling the tool: ${RES#talk }"; fix "use a bigger model that supports tools — see models.md";;
    error*) bad "the server returned an error: ${RES#error }"; fix "400 after a Claude Code update? update your server first, then try CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1";;
    *) bad "no reply from $BASE/v1/messages";;
  esac
fi
rm -f /tmp/rz_models.$$

# ------------------------------------------------------------------ summary
echo
if [ $PROBLEMS -eq 0 ]; then echo "${G}${B}No problems found.${N} Inside Claude Code, run /status and check it names ANTHROPIC_AUTH_TOKEN, then watch your server's log."
else echo "${R}${B}$PROBLEMS problem(s) found.${N} Fix them top to bottom (door → badge → names → notepad → tools), then run ./doctor.sh again."; fi
exit $PROBLEMS
