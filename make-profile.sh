#!/usr/bin/env bash
# make-profile.sh — a separate Claude Code profile for your local server, with every fix from the video built in.
#
#   ./make-profile.sh omlx --key sk-omlx-...         (key from oMLX → Security tab)
#   ./make-profile.sh ollama
#   ./make-profile.sh lmstudio
# Options:  --model ID      exact model ID (default: asks, from the server's own list)
#           --context N     your server's real context window, in tokens (default 65536; it must match the server)
#           --force         replace an existing profile (the old settings.json is kept as settings.json.bak)
#
# Writes ~/.claude-<server>/settings.json and prints the alias to add to ~/.zshrc. Your normal `claude`
# (and its Claude login) stays untouched: the profile has its own folder, so the two badges never clash.
set -eu
SERVER="${1:-}"; shift || true
KEY=""; MODEL=""; CTX=65536; FORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEY="$2"; shift 2;; --model) MODEL="$2"; shift 2;; --context) CTX="$2"; shift 2;; --force) FORCE=1; shift;;
    *) echo "unknown option: $1"; exit 1;;
  esac
done
case "$SERVER" in
  omlx)     BASE="http://127.0.0.1:8000";  TOKEN="${KEY:-${OMLX_KEY:-}}"
            [ -n "$TOKEN" ] || { echo "oMLX needs its key: ./make-profile.sh omlx --key <key from oMLX → Security tab>"; exit 1; };;
  ollama)   BASE="http://localhost:11434"; TOKEN="${KEY:-ollama}";;
  lmstudio) BASE="http://localhost:1234";  TOKEN="${KEY:-${LM_API_TOKEN:-lmstudio}}";;
  *) echo "usage: ./make-profile.sh omlx|ollama|lmstudio [--key KEY] [--model ID] [--context N] [--force]"; exit 1;;
esac
command -v python3 >/dev/null 2>&1 || { echo "python3 is needed (run: xcode-select --install)"; exit 1; }
case "$CTX" in ''|*[!0-9]*) echo "--context must be a number of tokens, e.g. 65536"; exit 1;; esac

# fix 1: the door — the server must answer at the plain address (no /v1)
curl -s -o /dev/null -m 3 "$BASE" || { echo "Nothing answers at $BASE. Start $SERVER first, then run this again."; exit 1; }

# fix 3: the names — copy the exact ID from the server, never type it
LIST=$(curl -s -m 5 -H "Authorization: Bearer $TOKEN" "$BASE/v1/models" | python3 -c '
import json,sys
try: print("\n".join(m["id"] for m in json.load(sys.stdin).get("data", [])))
except Exception: pass')
[ -n "$LIST" ] || { echo "The server didn't return a model list (wrong key? no model downloaded?). Check: curl $BASE/v1/models"; exit 1; }
if [ -z "$MODEL" ]; then
  echo "Models on your $SERVER server:"; i=0
  echo "$LIST" | while read -r m; do i=$((i + 1)); echo "  $i) $m"; done
  printf "Pick one (number): "; read -r n
  MODEL=$(echo "$LIST" | sed -n "${n}p")
  [ -n "$MODEL" ] || { echo "No model picked."; exit 1; }
elif ! echo "$LIST" | grep -qxF "$MODEL"; then
  echo "\"$MODEL\" isn't on your server. It has:"; echo "$LIST" | sed 's/^/  /'; exit 1
fi

DIR="$HOME/.claude-$SERVER"; OUT="$DIR/settings.json"
if [ -f "$OUT" ] && [ $FORCE -eq 0 ]; then echo "$OUT already exists. Add --force to replace it (a .bak copy is kept)."; exit 1; fi
mkdir -p "$DIR"; [ -f "$OUT" ] && cp "$OUT" "$OUT.bak"
python3 - "$OUT" "$SERVER" "$BASE" "$TOKEN" "$MODEL" "$CTX" <<'PY'
import json, sys
out, server, base, token, model, ctx = sys.argv[1:]
env = {
    "ANTHROPIC_BASE_URL": base,                 # fix 1: plain address, nothing after the port
    "ANTHROPIC_AUTH_TOKEN": token,              # fix 2: the badge for your server
    "ANTHROPIC_API_KEY": "",                    # fix 2: no second badge
    "ANTHROPIC_MODEL": model,                   # fix 3: every name points at your model
    "ANTHROPIC_DEFAULT_OPUS_MODEL": model,
    "ANTHROPIC_DEFAULT_SONNET_MODEL": model,
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": model,     # also the background model (replaces ANTHROPIC_SMALL_FAST_MODEL)
    "CLAUDE_CODE_MAX_CONTEXT_TOKENS": ctx,      # fix 4: the real notepad size
}
if server == "lmstudio": env["CLAUDE_CODE_ATTRIBUTION_HEADER"] = "0"   # LM Studio's Claude Code docs set this
json.dump({"env": env}, open(out, "w"), indent=2); open(out, "a").write("\n")
PY
chmod 600 "$OUT"
echo
echo "Wrote $OUT (model $MODEL, context $CTX)."
echo "Make sure your server's own context window is $CTX too (Ollama: OLLAMA_CONTEXT_LENGTH=$CTX ollama serve)."
echo
echo "Add this to ~/.zshrc, then open a new terminal:"
echo "  alias claude-$SERVER=\"CLAUDE_CONFIG_DIR=~/.claude-$SERVER claude\""
echo
echo "Check it:  CLAUDE_CONFIG_DIR=~/.claude-$SERVER ./doctor.sh --tools"
