#!/usr/bin/env bash
# Bring the memory stack up to write, and take the embedder back down after.
#
#   memory.sh start   the stack, waiting until mem0 and the embedder answer
#   memory.sh stop    the embedder only — frees the card, leaves the rest up
#
# The embedder is a vLLM instance on the same GB10 as the benchmarks, so it
# must be down for every run. `stop` is idempotent.
set -uo pipefail

COMPOSE_PROJECT=sparkmem
BOX_DIR='~/spark-tuner/memory'   # quoted: the ~ must reach the box unexpanded
MEM0_PORT=8888
EMBED_PORT=8001

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
host="$(jq -r '.host // empty' "$root/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "memory: no box configured" >&2; exit 1; }

ssh -o ConnectTimeout=8 -o BatchMode=yes "$host" true 2>/dev/null ||
  { echo "memory: box $host unreachable over ssh" >&2; exit 1; }

compose() {
  # BOX_DIR is unquoted on the remote side so its leading ~ expands there.
  # shellcheck disable=SC2029
  ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
    "cd ${BOX_DIR} && docker compose -p '${COMPOSE_PROJECT}' $*"
}

# The embedder is a model load, so give it time rather than failing early.
wait_healthy() {
  local label="$1" port="$2" path="$3" status i
  printf 'waiting for %s' "$label"
  for ((i = 0; i < 30; i++)); do
    status="$(ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$host" \
      "curl -sS --max-time 10 -o /dev/null -w '%{http_code}' 'http://127.0.0.1:${port}${path}'" 2>/dev/null)"
    if [[ "$status" =~ ^2 ]]; then echo " OK"; return 0; fi
    printf '.'
    sleep 2
  done
  echo " TIMEOUT"
  return 1
}

case "${1:-}" in
  start)
    compose up -d || { echo "memory: start failed" >&2; exit 1; }
    ok=0
    wait_healthy "mem0" "$MEM0_PORT" /health || ok=1
    wait_healthy "embeddings" "$EMBED_PORT" /v1/models || ok=1
    [ "$ok" -eq 0 ] || { echo "memory: stack up but not healthy" >&2; exit 1; }
    echo "memory: up"
    ;;
  stop)
    compose stop embeddings || { echo "memory: stop failed" >&2; exit 1; }
    echo "memory: embedder down, card free"
    ;;
  *)
    echo "usage: memory.sh start|stop" >&2
    exit 2
    ;;
esac
