#!/usr/bin/env bash
# Write a memory. Outbox-first: never blocks on the memory service being
# down, or on the box not being configured at all. Exits nonzero only for
# usage errors.
#
# Usage: remember.sh "<text>" [entity]
#        remember.sh --drain          # retry everything queued in the outbox

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"

OUTBOX="$REPO_ROOT/.cache/memory-outbox.jsonl"
OUTBOX_LOCK="$OUTBOX.lock"

usage() {
  echo "usage: remember.sh \"<text>\" [entity]" >&2
  echo "       remember.sh --drain" >&2
  exit 2
}

# --- portable outbox lock (mkdir is atomic on every POSIX fs; no flock on macOS) ---

acquire_lock() {
  local tries=200
  while ! mkdir "$OUTBOX_LOCK" 2>/dev/null; do
    tries=$((tries - 1))
    if [ "$tries" -le 0 ]; then
      echo "mem0: could not acquire outbox lock after 10s, giving up" >&2
      return 1
    fi
    sleep 0.05
  done
  return 0
}

release_lock() { rmdir "$OUTBOX_LOCK" 2>/dev/null || true; }

build_add_body() {
  local text="$1" entity="$2" sha="$3"
  jq -nc --arg text "$text" --arg entity "$entity" --arg sha "$sha" --arg uid "$MEM0_USER_ID" '
    {
      messages: [{role: "user", content: $text}],
      user_id: $uid,
      metadata: ({sha256: $sha} + (if $entity == "" then {} else {entity: $entity} end)),
      infer: false
    }'
}

# try_post_line <jsonl-line> -> 0 on 2xx, 1 otherwise
try_post_line() {
  local line="$1" text entity sha body
  text="$(jq -r '.text' <<<"$line")"
  entity="$(jq -r '.entity // ""' <<<"$line")"
  sha="$(jq -r '.sha256 // ""' <<<"$line")"
  body="$(build_add_body "$text" "$entity" "$sha")"
  mem0_add "$body"
  [[ "$CURL_STATUS" =~ ^2 ]]
}

# append_line <line>: locked append, creates the outbox file/dir if needed.
append_line() {
  mkdir -p "$(dirname "$OUTBOX")"
  touch "$OUTBOX"
  acquire_lock || { echo "mem0: outbox busy; memory NOT queued: $1" >&2; return 1; }
  printf '%s\n' "$1" >>"$OUTBOX"
  release_lock
}

# remove_line_once <line>: locked removal of the first exact match.
remove_line_once() {
  acquire_lock || return 1
  [ -f "$OUTBOX" ] || { release_lock; return 0; }
  local tmp found=0 l
  tmp="$(mktemp "${OUTBOX}.XXXXXX")"
  while IFS= read -r l; do
    if [ "$found" -eq 0 ] && [ "$l" = "$1" ]; then
      found=1
      continue
    fi
    printf '%s\n' "$l" >>"$tmp"
  done <"$OUTBOX"
  mv "$tmp" "$OUTBOX"
  release_lock
}

# claim_outbox: locked read-and-truncate. Prints whatever was queued so the
# caller can retry it outside the lock (network calls must never hold the
# lock, or a slow POST would starve concurrent remember.sh appends).
claim_outbox() {
  acquire_lock || return 1
  [ -f "$OUTBOX" ] && cat "$OUTBOX"
  : >"$OUTBOX"
  release_lock
}

drain_outbox() {
  [ -f "$OUTBOX" ] || return 0
  local claimed line remaining=0
  claimed="$(claim_outbox)" || return 1
  [ -n "$claimed" ] || return 0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ -n "$BOX_HOST" ] && try_post_line "$line"; then
      :
    else
      append_line "$line"
      remaining=$((remaining + 1))
    fi
  done <<<"$claimed"
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

SHA="$(sha256_of "$TEXT")"
LINE="$(jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg text "$TEXT" --arg entity "$ENTITY" --arg sha "$SHA" \
  '{ts:$ts,text:$text,entity:$entity,sha256:$sha}')"
append_line "$LINE"

if [ -n "$BOX_HOST" ] && try_post_line "$LINE"; then
  remove_line_once "$LINE"
  drain_outbox
else
  echo "mem0: memory service unavailable (status ${CURL_STATUS:-000}); queued in outbox" >&2
fi

exit 0
