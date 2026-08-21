#!/usr/bin/env bash
# Validates the mem0 stack after `docker compose up -d`: waits for the API,
# confirms the embedder dimension matches EMBEDDING_DIMS, and round-trips a
# throwaway memory (add -> search -> delete). Our own mem0 server (see
# server/app.py) is env-configured, so there is no runtime config API call
# to make here - this script only verifies, and can drop+recreate the
# pgvector collection when the embedder dimension changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Preserve a caller-supplied CONFIRM_RESET_MEMORY: .env ships it empty, and
# sourcing .env must not clobber an explicit `CONFIRM_RESET_MEMORY=1 ./configure-memory.sh`.
CLI_CONFIRM_RESET_MEMORY="${CONFIRM_RESET_MEMORY-}"
# shellcheck disable=SC1091
[ -f .env ] && set -a && source .env && set +a
[ -n "$CLI_CONFIRM_RESET_MEMORY" ] && CONFIRM_RESET_MEMORY="$CLI_CONFIRM_RESET_MEMORY"

MEM0_PORT="${MEM0_PORT:-8888}"
EMBED_PORT="${EMBED_PORT:-8001}"
EMBED_MODEL="${EMBED_MODEL:-Qwen/Qwen3-Embedding-0.6B}"
EMBEDDING_DIMS="${EMBEDDING_DIMS:-1024}"
MEM0_URL="http://127.0.0.1:${MEM0_PORT}"
EMBED_URL="http://127.0.0.1:${EMBED_PORT}"
PROBE_USER="sparkmem-configure-probe"

log() { echo "[configure-memory] $*"; }
die() { log "ERROR: $*"; exit 1; }

wait_for() {
  local url="$1" name="$2" tries=30
  for ((i = 1; i <= tries; i++)); do
    if curl -fsS -o /dev/null "$url"; then
      log "$name is up"
      return 0
    fi
    sleep 1
  done
  die "$name did not become healthy at $url after ${tries}s"
}

wait_for "${EMBED_URL}/health" "vLLM embeddings server"
wait_for "${MEM0_URL}/health" "mem0 server"

log "checking embedding dimensions"
dims=$(curl -fsS "${EMBED_URL}/v1/embeddings" \
  -H 'Content-Type: application/json' \
  -d '{"model":"'"${EMBED_MODEL}"'","input":"dimension probe"}' \
  | python3 -c 'import json,sys; print(len(json.load(sys.stdin)["data"][0]["embedding"]))')

if [ "$dims" != "$EMBEDDING_DIMS" ]; then
  log "embedder returns ${dims}-dim vectors but EMBEDDING_DIMS=${EMBEDDING_DIMS}"
  [ "${CONFIRM_RESET_MEMORY:-}" = "1" ] || die "refusing to reset the mem0 collection. Fix" \
    "EMBEDDING_DIMS (and re-run with CONFIRM_RESET_MEMORY=1 to wipe + recreate the collection)."
  log "CONFIRM_RESET_MEMORY=1 set - dropping the memories collection and restarting mem0"
  docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" \
    -c "DROP TABLE IF EXISTS ${POSTGRES_COLLECTION_NAME:-memories};"
  docker compose restart mem0
  wait_for "${MEM0_URL}/health" "mem0 server (post-reset)"
fi

log "round-tripping a probe memory (add -> search -> delete)"
add_resp=$(curl -fsS -X POST "${MEM0_URL}/memories" \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"[LESSON] configure-memory.sh probe - safe to ignore"}],"user_id":"'"${PROBE_USER}"'","infer":false}')

memory_id=$(echo "$add_resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["results"][0]["id"])') \
  || die "add response had no results[0].id: $add_resp"

search_resp=$(curl -fsS -X POST "${MEM0_URL}/search" \
  -H 'Content-Type: application/json' \
  -d '{"query":"configure-memory.sh probe","user_id":"'"${PROBE_USER}"'"}')

echo "$search_resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("results") else 1)' \
  || die "probe memory not found on search-back: $search_resp"

curl -fsS -X DELETE "${MEM0_URL}/memories/${memory_id}" >/dev/null \
  || die "delete of probe memory ${memory_id} failed"

log "OK: mem0 healthy, embedder dims match (${dims}), add/search/delete verified"
