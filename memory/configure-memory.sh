#!/usr/bin/env bash
# Validates the mem0 stack after `docker compose up -d`: waits for the API,
# confirms the embedder dimension matches EMBEDDING_DIMS, and round-trips a
# throwaway memory (add -> search -> delete). mem0's embedder here is
# env-configured (OPENAI_BASE_URL / EMBEDDING_MODEL_DIMS in compose), so
# there is no runtime config API call to make - this script only verifies.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# shellcheck disable=SC1091
[ -f .env ] && set -a && source .env && set +a

MEM0_PORT="${MEM0_PORT:-8888}"
EMBED_PORT="${EMBED_PORT:-8001}"
EMBEDDING_DIMS="${EMBEDDING_DIMS:-1024}"
MEM0_URL="http://127.0.0.1:${MEM0_PORT}"
EMBED_URL="http://127.0.0.1:${EMBED_PORT}"
PROBE_USER="sparkmem-configure-probe"

log() { echo "[configure-memory] $*"; }

wait_for() {
  local url="$1" name="$2" tries=30
  for ((i = 1; i <= tries; i++)); do
    if curl -fsS -o /dev/null "$url"; then
      log "$name is up"
      return 0
    fi
    sleep 1
  done
  log "ERROR: $name did not become healthy at $url after ${tries}s"
  return 1
}

wait_for "${EMBED_URL}/health" "vLLM embeddings server"
wait_for "${MEM0_URL}/docs" "mem0 server"

log "checking embedding dimensions"
dims=$(curl -fsS "${EMBED_URL}/v1/embeddings" \
  -H 'Content-Type: application/json' \
  -d '{"model":"'"${EMBED_MODEL:-Qwen/Qwen3-Embedding-0.6B}"'","input":"dimension probe"}' \
  | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"][0]["embedding"]))')

if [ "$dims" != "$EMBEDDING_DIMS" ]; then
  log "ERROR: embedder returns ${dims}-dim vectors but EMBEDDING_DIMS=${EMBEDDING_DIMS}"
  if [ "${CONFIRM_RESET_MEMORY:-}" != "1" ]; then
    log "refusing to reset the mem0 collection. Fix EMBEDDING_DIMS (and re-run" \
        "with CONFIRM_RESET_MEMORY=1 if the collection must be wiped and recreated)."
    exit 1
  fi
  log "CONFIRM_RESET_MEMORY=1 set - dropping and recreating the memories collection"
  curl -fsS -X DELETE "${MEM0_URL}/memories?user_id=${PROBE_USER}" >/dev/null || true
fi

log "round-tripping a probe memory (add -> search -> delete)"
add_resp=$(curl -fsS -X POST "${MEM0_URL}/memories" \
  -H 'Content-Type: application/json' \
  -d '{"messages":"[LESSON] configure-memory.sh probe - safe to ignore","user_id":"'"${PROBE_USER}"'","infer":false}')

memory_id=$(echo "$add_resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["results"][0]["memory_id"] if "results" in d and d["results"] else d["results"][0]["id"])' 2>/dev/null || true)

search_resp=$(curl -fsS -X POST "${MEM0_URL}/search" \
  -H 'Content-Type: application/json' \
  -d '{"query":"configure-memory.sh probe","filters":{"user_id":"'"${PROBE_USER}"'"}}')

if ! echo "$search_resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("results") else 1)'; then
  log "ERROR: probe memory not found on search-back"
  exit 1
fi

if [ -n "$memory_id" ] && [ "$memory_id" != "None" ]; then
  curl -fsS -X DELETE "${MEM0_URL}/memories/${memory_id}" >/dev/null || true
fi

log "OK: mem0 healthy, embedder dims match (${dims}), add/search/delete verified"
