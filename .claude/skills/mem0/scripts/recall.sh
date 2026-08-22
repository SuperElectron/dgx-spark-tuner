#!/usr/bin/env bash
# Search memories. Prints "- <text>" bullets in the server's relevance
# order, capped at ~1200 total chars. Never blocks: empty output + exit 0
# on no hits, a down service, or a missing box config.
#
# Usage: recall.sh "<query>" [entity] [k]

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"

CHAR_CAP=1200

usage() {
  echo "usage: recall.sh \"<query>\" [entity] [k=10]" >&2
  exit 2
}

[ $# -ge 1 ] || usage
QUERY="$1"
ENTITY="${2:-}"
K="${3:-10}"
[ -n "$QUERY" ] || usage
[[ "$K" =~ ^[0-9]+$ ]] || usage

if [ -z "$BOX_HOST" ]; then
  echo "mem0: search unavailable (no box configured)" >&2
  exit 0
fi

BODY="$(jq -nc --arg q "$QUERY" --arg uid "$MEM0_USER_ID" --argjson k "$K" --arg entity "$ENTITY" \
  '{query: $q, user_id: $uid, limit: $k}
   + (if $entity == "" then {} else {filters: {entity: $entity}} end)')"

mem0_search "$BODY"

if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
  echo "mem0: search unavailable (status ${CURL_STATUS})" >&2
  exit 0
fi

# Server already applied relevance ranking and the entity filter; we only
# select the .memory field here — never re-sort before the char cap.
MEMORIES="$(jq -r '
  (if type == "array" then . else (.results // []) end)
  | .[].memory // empty
' <<<"$CURL_BODY" 2>/dev/null)"

[ -n "$MEMORIES" ] || exit 0

total=0
while IFS= read -r mem; do
  [ -z "$mem" ] && continue
  bullet="- $mem"
  len=${#bullet}
  if [ "$total" -gt 0 ] && [ $((total + len)) -gt "$CHAR_CAP" ]; then
    break
  fi
  printf '%s\n' "$bullet"
  total=$((total + len + 1))
done <<<"$MEMORIES"

exit 0
