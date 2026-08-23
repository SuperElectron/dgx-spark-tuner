#!/usr/bin/env bash
# Read memories. Never writes.
#
#   recall.sh "<query>" [entity] [k]   relevance search — needs the embedder up
#   recall.sh --list [entity] [limit]  every memory, no vector search — embedder
#                                      may be down, which is the usual state
#
# Prints one line per memory: the entity scope, then the text. Exits 0 with no
# output when the service is down, so a caller is never blocked by memory.
set -uo pipefail

USER_ID="dgx-spark-tuner"
PORT=8888

host="$(jq -r '.host // empty' "$(git rev-parse --show-toplevel)/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "recall: no box configured" >&2; exit 0; }

call() {  # call <METHOD> <path> [body]
  local method="$1" path="$2" body="${3:-}"
  if [ -n "$body" ]; then
    printf '%s' "$body" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
      "curl -sS --max-time 20 -X $method -H 'Content-Type: application/json' \
       --data-binary @- 'http://127.0.0.1:${PORT}${path}'" 2>/dev/null
  else
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
      "curl -sS --max-time 20 -X $method 'http://127.0.0.1:${PORT}${path}'" 2>/dev/null
  fi
}

if [ "${1:-}" = "--list" ]; then
  entity="${2:-}" limit="${3:-500}"
  body="$(jq -nc --arg u "$USER_ID" --argjson l "$limit" --arg e "$entity" \
    '{user_id: $u, limit: $l} + (if $e == "" then {} else {filters: {entity: $e}} end)')"
  out="$(call POST /memories/list "$body")"
else
  [ $# -ge 1 ] || { echo 'usage: recall.sh "<query>" [entity] [k]  |  recall.sh --list [entity] [limit]' >&2; exit 2; }
  body="$(jq -nc --arg q "$1" --arg u "$USER_ID" --argjson k "${3:-10}" --arg e "${2:-}" \
    '{query: $q, user_id: $u, limit: $k} + (if $e == "" then {} else {filters: {entity: $e}} end)')"
  out="$(call POST /search "$body")"
fi

jq -r '(if type == "array" then . else (.results // []) end)
       | .[] | "\(.id)\t\(.metadata.entity // "-")\t\(.memory)"' <<<"$out" 2>/dev/null
exit 0
