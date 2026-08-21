#!/usr/bin/env bash
# Write a memory. Outbox-first: never blocks on the memory service being
# down. Exits nonzero only for usage errors; a service-down write is a
# warning on stderr and exit 0.
#
# Usage: remember.sh "<text>" [entity]
#        remember.sh --drain          # retry everything queued in the outbox

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
# shellcheck source=./_common.sh
source ./_common.sh

OUTBOX="$REPO_ROOT/.cache/memory-outbox.jsonl"

usage() {
  echo "usage: remember.sh \"<text>\" [entity]" >&2
  echo "       remember.sh --drain" >&2
  exit 2
}

build_add_body() {
  local text="$1" entity="$2"
  jq -nc --arg text "$text" --arg entity "$entity" --arg uid "$MEM0_USER_ID" '
    {
      messages: [{role: "user", content: $text}],
      user_id: $uid,
      metadata: (if $entity == "" then {} else {entity: $entity} end),
      infer: false
    }'
}

# try_post_line <jsonl-line> -> 0 on 2xx, 1 otherwise
try_post_line() {
  local line="$1" text entity body
  text="$(jq -r '.text' <<<"$line")"
  entity="$(jq -r '.entity // ""' <<<"$line")"
  body="$(build_add_body "$text" "$entity")"
  mem0_add "$body" >/dev/null
  [[ "$CURL_STATUS" =~ ^2 ]]
}

remove_line_once() {
  local target="$1" tmp found=0 l
  tmp="$(mktemp "${OUTBOX}.XXXXXX")"
  while IFS= read -r l; do
    if [ "$found" -eq 0 ] && [ "$l" = "$target" ]; then
      found=1
      continue
    fi
    printf '%s\n' "$l" >>"$tmp"
  done <"$OUTBOX"
  mv "$tmp" "$OUTBOX"
}

drain_outbox() {
  [ -f "$OUTBOX" ] || return 0
  local tmp remaining=0 line
  tmp="$(mktemp "${OUTBOX}.XXXXXX")"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if try_post_line "$line"; then
      :
    else
      printf '%s\n' "$line" >>"$tmp"
      remaining=$((remaining + 1))
    fi
  done <"$OUTBOX"
  mv "$tmp" "$OUTBOX"
  if [ "$remaining" -gt 0 ]; then
    echo "mem0: $remaining memory line(s) still pending in outbox" >&2
  fi
}

[ $# -ge 1 ] || usage

if [ "$1" = "--drain" ]; then
  drain_outbox
  exit 0
fi

TEXT="$1"
ENTITY="${2:-}"
[ -n "$TEXT" ] || usage

mkdir -p "$(dirname "$OUTBOX")"
touch "$OUTBOX"
LINE="$(jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg text "$TEXT" --arg entity "$ENTITY" \
  '{ts:$ts,text:$text,entity:$entity}')"
printf '%s\n' "$LINE" >>"$OUTBOX"

if try_post_line "$LINE"; then
  remove_line_once "$LINE"
  drain_outbox
else
  echo "mem0: memory service unavailable (status ${CURL_STATUS}); queued in outbox" >&2
fi

exit 0
