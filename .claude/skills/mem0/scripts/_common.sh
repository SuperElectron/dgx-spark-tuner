#!/usr/bin/env bash
# Shared helpers for the mem0 skill scripts: box host resolution, remote
# curl helpers, and endpoint paths. Source this, don't execute it directly
# (it isn't chmod +x on purpose).
#
# The mem0 REST server and vLLM embeddings server bind to 127.0.0.1 on the
# box, so every HTTP call is tunneled through `ssh <host> curl ...` rather
# than hit directly from wherever this script runs. The REST server is our
# own FastAPI app (memory/server/app.py, built in the parallel stack PR)
# — endpoint shapes below are that app's contract, not upstream mem0's.
#
# shellcheck disable=SC2034  # CURL_BODY/CURL_STATUS are consumed by callers
# in the scripts that source this file, which shellcheck can't see per-file.

set -uo pipefail

# --- repo root + box host resolution ---------------------------------------
# Callers must source this file via an absolute (or script-dir-relative)
# path and must NOT `cd` into the script's own directory first — doing so
# would break any relative path argument the caller passed in ($1 etc).

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BOX_JSON="${MEM0_BOX_JSON:-$REPO_ROOT/.claude/box.json}"

BOX_HOST=""
if [ -f "$BOX_JSON" ]; then
  if command -v jq >/dev/null 2>&1; then
    BOX_HOST="$(jq -r '.host // empty' "$BOX_JSON" 2>/dev/null)"
  else
    # jq-less fallback: grab the first "host": "..." value.
    BOX_HOST="$(grep -o '"host"[[:space:]]*:[[:space:]]*"[^"]*"' "$BOX_JSON" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"
  fi
fi

if [ -z "$BOX_HOST" ]; then
  echo "mem0: box host not configured (missing/unreadable $BOX_JSON, gitignored, needs a \"host\" field)" >&2
fi

# require_box_host: hard-fail helper for scripts that cannot proceed
# without the box (memory.sh, memory-doctor.sh, memory-backfill.sh).
# remember.sh/recall.sh must NOT call this — they degrade gracefully
# instead so a missing box config never blocks the caller.
require_box_host() {
  if [ -z "$BOX_HOST" ]; then
    echo "mem0: cannot continue without a configured box host" >&2
    exit 1
  fi
}

# --- endpoints ---------------------------------------------------------------
# Paths are this repo's own memory/server/app.py FastAPI contract.

MEM0_PORT="${MEM0_PORT:-8888}"
EMBED_PORT="${EMBED_PORT:-8001}"
MEM0_BOX_DIR="${MEM0_BOX_DIR:-~/spark-tuner/memory}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-sparkmem}"

MEM0_USER_ID="${MEM0_USER_ID:-dgx-spark-tuner}"

MEM0_PATH_HEALTH="/health"
MEM0_PATH_ADD="/memories"
MEM0_PATH_SEARCH="/search"
MEM0_PATH_LIST="/memories/list"        # POST {user_id, filters?, limit?} -> get_all, no vector search
MEM0_PATH_DELETE="/memories"           # DELETE {path}/{memory_id}
EMBED_PATH_MODELS="/v1/models"

# --- remote curl helper -------------------------------------------------------
# _box_curl <port> <method> <path> [json-body]
# Sets globals CURL_BODY (response body) and CURL_STATUS (HTTP status, or
# "000" on any transport failure: ssh unreachable, timeout, connection
# refused). Does NOT print/return via stdout — callers must invoke it as a
# plain statement, never inside $(...), since that runs it in a subshell
# and the global assignments would be lost.
CURL_BODY=""
CURL_STATUS="000"
_box_curl() {
  local port="$1" method="$2" path="$3" data="${4:-}"
  local remote out marker="__HTTP_STATUS__"

  remote="curl -sS --max-time 10 -X ${method} -w '\\n${marker}%{http_code}'"
  if [ -n "$data" ]; then
    remote="$remote -H 'Content-Type: application/json' --data-binary @-"
  fi
  remote="$remote 'http://127.0.0.1:${port}${path}'"

  if [ -n "$data" ]; then
    out="$(printf '%s' "$data" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" "$remote" 2>/dev/null)" || true
  else
    out="$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" "$remote" 2>/dev/null)" || true
  fi

  if [[ "$out" == *$'\n'"${marker}"[0-9][0-9][0-9] ]]; then
    CURL_STATUS="${out##*"$marker"}"
    CURL_BODY="${out%$'\n'"${marker}${CURL_STATUS}"}"
  else
    CURL_STATUS="000"
    CURL_BODY=""
  fi
}

# mem0_add <json-body> -> sets CURL_BODY / CURL_STATUS
mem0_add() { _box_curl "$MEM0_PORT" POST "$MEM0_PATH_ADD" "$1"; }

# mem0_search <json-body> -> sets CURL_BODY / CURL_STATUS
# body shape: {query, user_id, limit, filters?}
mem0_search() { _box_curl "$MEM0_PORT" POST "$MEM0_PATH_SEARCH" "$1"; }

# mem0_list <json-body> -> sets CURL_BODY / CURL_STATUS
# body shape: {user_id, filters?, limit?} — no vector search, wraps get_all.
mem0_list() { _box_curl "$MEM0_PORT" POST "$MEM0_PATH_LIST" "$1"; }

# mem0_delete <memory_id> -> sets CURL_BODY / CURL_STATUS
mem0_delete() { _box_curl "$MEM0_PORT" DELETE "${MEM0_PATH_DELETE}/$1"; }

# mem0_health: 2xx from /health means the server is up.
mem0_health() { _box_curl "$MEM0_PORT" GET "$MEM0_PATH_HEALTH"; }

# embed_health: OpenAI-compatible /v1/models list.
embed_health() { _box_curl "$EMBED_PORT" GET "$EMBED_PATH_MODELS"; }

box_reachable() {
  ssh -o ConnectTimeout=8 -o BatchMode=yes "$BOX_HOST" true >/dev/null 2>&1
}

# sha256_of <text> -> prints the hex sha256 digest (portable: sha256sum on
# Linux, shasum -a 256 on macOS).
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}
