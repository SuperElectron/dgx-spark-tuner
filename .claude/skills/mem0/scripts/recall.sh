#!/usr/bin/env bash
# Search memories. Prints newest-first "- <text>" bullets, capped at ~1200
# chars. Never blocks: empty output + exit 0 on no hits or service down.
#
# Usage: recall.sh "<query>" [entity] [k]

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=./_common.sh
source ./_common.sh

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

BODY="$(jq -nc --arg q "$QUERY" --arg uid "$MEM0_USER_ID" --argjson k "$K" \
  '{query: $q, filters: {user_id: $uid}, top_k: $k}')"

mem0_search "$BODY"
RESPONSE="$CURL_BODY"

if [[ ! "$CURL_STATUS" =~ ^2 ]]; then
  echo "mem0: search unavailable (status ${CURL_STATUS})" >&2
  exit 0
fi

MEMORIES="$(jq -r --arg entity "$ENTITY" '
  (if type == "array" then . else (.results // []) end)
  | map(select($entity == "" or ((.metadata.entity // "") == $entity)))
  | sort_by(.created_at // "")
  | reverse
  | .[].memory // empty
' <<<"$RESPONSE" 2>/dev/null)"

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
