#!/usr/bin/env bash
# Shared helpers for the mem0 skill scripts: box host resolution, remote
# curl helpers, and endpoint paths. Source this, don't execute it directly.
#
# The mem0 REST server and vLLM embeddings server bind to 127.0.0.1 on the
# box, so every HTTP call is tunneled through `ssh <host> curl ...` rather
# than hit directly from wherever this script runs.
#
# shellcheck disable=SC2034  # CURL_BODY/CURL_STATUS are consumed by callers
# in the scripts that source this file, which shellcheck can't see per-file.

set -uo pipefail

# --- repo root + box host resolution ---------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
BOX_JSON="${MEM0_BOX_JSON:-$REPO_ROOT/.claude/box.json}"

if [ ! -f "$BOX_JSON" ]; then
  echo "mem0: box config not found at $BOX_JSON (gitignored; create it with a \"host\" field)" >&2
  exit 1
fi

if command -v jq >/dev/null 2>&1; then
  BOX_HOST="$(jq -r '.host // empty' "$BOX_JSON" 2>/dev/null)"
else
  # jq-less fallback: grab the first "host": "..." value.
  BOX_HOST="$(grep -o '"host"[[:space:]]*:[[:space:]]*"[^"]*"' "$BOX_JSON" | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/')"
fi

if [ -z "$BOX_HOST" ]; then
  echo "mem0: could not resolve \"host\" from $BOX_JSON" >&2
  exit 1
fi

# --- endpoints ---------------------------------------------------------------
# All paths are self-hosted mem0 server routes (no /v1 prefix); see
# https://github.com/mem0ai/mem0/blob/main/docs/open-source/features/rest-api.mdx

MEM0_PORT="${MEM0_PORT:-8888}"
EMBED_PORT="${EMBED_PORT:-8001}"
MEM0_BOX_DIR="${MEM0_BOX_DIR:-~/dgx-spark-tuner/memory}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-sparkmem}"

MEM0_USER_ID="${MEM0_USER_ID:-dgx-spark-tuner}"

MEM0_PATH_HEALTH="/"
MEM0_PATH_ADD="/memories"
MEM0_PATH_SEARCH="/search"
MEM0_PATH_LIST="/memories"
MEM0_PATH_DELETE="/memories"          # DELETE {path}/{memory_id}
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
  remote="$remote http://127.0.0.1:${port}${path}"

  if [ -n "$data" ]; then
    out="$(printf '%s' "$data" | ssh -o ConnectTimeout=10 "$BOX_HOST" "$remote" 2>/dev/null)" || true
  else
    out="$(ssh -o ConnectTimeout=10 "$BOX_HOST" "$remote" 2>/dev/null)" || true
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
mem0_search() { _box_curl "$MEM0_PORT" POST "$MEM0_PATH_SEARCH" "$1"; }

# mem0_list_by_user <user_id> -> sets CURL_BODY / CURL_STATUS
mem0_list_by_user() { _box_curl "$MEM0_PORT" GET "${MEM0_PATH_LIST}?user_id=$1"; }

# mem0_delete <memory_id> -> sets CURL_BODY / CURL_STATUS
mem0_delete() { _box_curl "$MEM0_PORT" DELETE "${MEM0_PATH_DELETE}/$1"; }

# mem0_health: 2xx from the (public) root route means the server is up.
mem0_health() { _box_curl "$MEM0_PORT" GET "$MEM0_PATH_HEALTH"; }

# embed_health: OpenAI-compatible /v1/models list.
embed_health() { _box_curl "$EMBED_PORT" GET "$EMBED_PATH_MODELS"; }

box_reachable() {
  ssh -o ConnectTimeout=8 -o BatchMode=yes "$BOX_HOST" true >/dev/null 2>&1
}
