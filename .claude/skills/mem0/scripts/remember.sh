#!/usr/bin/env bash
# Write a memory. Outbox-first: never blocks on the memory service being
# down, or on the box not being configured at all. Exits nonzero only for
# usage errors.
#
# Durability: the outbox lock (a mkdir-spinlock) is released by a trap on
# EXIT/INT/TERM, and acquire_lock steals a lock dir older than 60s (from a
# SIGKILLed holder, which no trap can catch). Draining moves the outbox to
# a .inflight file first and deletes each line from it only after a
# confirmed 2xx, so a kill mid-drain leaves every undelivered line on disk
# (in the outbox or .inflight, never in a shell variable only) — a later
# run recovers any leftover .inflight automatically.
#
# Usage: remember.sh "<text>" [entity]
#        remember.sh --drain          # retry everything queued in the outbox

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"

OUTBOX="$REPO_ROOT/.cache/memory-outbox.jsonl"
OUTBOX_LOCK="$OUTBOX.lock"
INFLIGHT="$OUTBOX.inflight"
LOCK_STALE_SECS=60

usage() {
  echo "usage: remember.sh \"<text>\" [entity]" >&2
  echo "       remember.sh --drain" >&2
  exit 2
}

# --- portable outbox lock (mkdir is atomic on every POSIX fs; no flock on macOS) ---

lock_age_secs() {
  local d="$1" mtime now
  now="$(date +%s)"
  mtime="$(stat -f %m "$d" 2>/dev/null || stat -c %Y "$d" 2>/dev/null || echo "$now")"
  echo $((now - mtime))
}

# LOCK_HELD tracks whether THIS process is the current holder. Without
# it, release_lock's EXIT trap would rmdir the lock unconditionally on
# every exit - including a process that spun out waiting for a lock some
# OTHER live process still legitimately holds, yanking that other
# process's mutual exclusion out from under it mid-critical-section.
LOCK_HELD=0

acquire_lock() {
  local tries=200 stolen=0 age
  while ! mkdir "$OUTBOX_LOCK" 2>/dev/null; do
    if [ "$stolen" -eq 0 ] && [ -d "$OUTBOX_LOCK" ]; then
      age="$(lock_age_secs "$OUTBOX_LOCK")"
      if [ "$age" -ge "$LOCK_STALE_SECS" ]; then
        # A crashed/killed holder can't have released this itself (no trap
        # survives SIGKILL) - steal it once, then fall back to normal waits.
        rmdir "$OUTBOX_LOCK" 2>/dev/null || true
        stolen=1
        continue
      fi
    fi
    tries=$((tries - 1))
    if [ "$tries" -le 0 ]; then
      echo "mem0: could not acquire outbox lock after ~10s, giving up" >&2
      return 1
    fi
    sleep 0.05
  done
  LOCK_HELD=1
  return 0
}

release_lock() {
  [ "$LOCK_HELD" -eq 1 ] || return 0
  rmdir "$OUTBOX_LOCK" 2>/dev/null || true
  LOCK_HELD=0
}
trap 'release_lock; exit 130' INT
trap 'release_lock; exit 143' TERM
trap release_lock EXIT

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
  acquire_lock || return 1
  printf '%s\n' "$1" >>"$OUTBOX"
  release_lock
}

# remove_line_once <line>: locked removal of the first exact match from
# the persistent outbox (used by the direct-write success path, not by
# drain — drain works off .inflight instead).
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

# recover_inflight: folds a leftover .inflight (from a drain that got
# killed before finishing) back into the outbox. Runs at the start of
# every invocation, write or drain, so nothing queued by a crashed drain
# is ever silently forgotten.
recover_inflight() {
  [ -f "$INFLIGHT" ] || return 0
  acquire_lock || return 1
  if [ -s "$INFLIGHT" ]; then
    mkdir -p "$(dirname "$OUTBOX")"
    touch "$OUTBOX"
    cat "$INFLIGHT" "$OUTBOX" >"${OUTBOX}.recover.$$" 2>/dev/null
    mv "${OUTBOX}.recover.$$" "$OUTBOX"
  fi
  rm -f "$INFLIGHT"
  release_lock
}

# begin_drain: locked move of the outbox to .inflight. If .inflight
# already has content (a concurrent drain claimed it first, or recovery
# somehow raced), merge rather than clobber.
begin_drain() {
  acquire_lock || return 1
  if [ -s "$OUTBOX" ]; then
    if [ -s "$INFLIGHT" ]; then
      cat "$OUTBOX" >>"$INFLIGHT"
      : >"$OUTBOX"
    else
      mv "$OUTBOX" "$INFLIGHT"
    fi
  fi
  release_lock
}

# inflight_peek: locked read of .inflight's first line into $INFLIGHT_LINE
# (set as a plain statement, never via $(...), or the assignment would be
# lost in a subshell). Sets INFLIGHT_HAS_LINE to 1/0.
INFLIGHT_LINE=""
INFLIGHT_HAS_LINE=0
inflight_peek() {
  acquire_lock || { INFLIGHT_HAS_LINE=0; return 1; }
  if [ -s "$INFLIGHT" ]; then
    INFLIGHT_HAS_LINE=1
    INFLIGHT_LINE="$(head -n 1 "$INFLIGHT")"
  else
    INFLIGHT_HAS_LINE=0
    INFLIGHT_LINE=""
  fi
  release_lock
}

# inflight_remove_line <line>: locked removal of the first exact match of
# <line> in .inflight (content-addressed, NOT positional - under a
# concurrent drain, two processes can both peek the same still-present
# first line before either removes it; if removal were "whatever is first
# right now" instead of "this exact confirmed line", the second remover
# would silently delete a *different*, unconfirmed line). Call ONLY after
# a confirmed 2xx for that exact line - this is what makes a kill
# mid-drain safe: an in-flight (unconfirmed) line is never removed. A
# target already removed by a concurrent drain is a harmless no-op.
inflight_remove_line() {
  acquire_lock || return 1
  if [ -f "$INFLIGHT" ]; then
    local tmp found=0 l
    tmp="$(mktemp "${INFLIGHT}.tmp.XXXXXX")"
    while IFS= read -r l; do
      if [ "$found" -eq 0 ] && [ "$l" = "$1" ]; then
        found=1
        continue
      fi
      printf '%s\n' "$l" >>"$tmp"
    done <"$INFLIGHT"
    mv "$tmp" "$INFLIGHT"
    [ -s "$INFLIGHT" ] || rm -f "$INFLIGHT"
  fi
  release_lock
}

# Note on concurrent drains: every drainer peeks the SAME .inflight head
# until someone's remove succeeds, so N concurrent drains can each POST
# the same line before it's removed - observed ~4.6x redundant traffic
# under 5 concurrent drainers in testing. Harmless (server dedupes on
# metadata.sha256, so the extras just come back "deduped": true) and not
# worth optimizing for a low-frequency guardrail script.
drain_outbox() {
  recover_inflight
  begin_drain || return 1
  [ -f "$INFLIGHT" ] || return 0
  while :; do
    inflight_peek
    [ "$INFLIGHT_HAS_LINE" -eq 1 ] || break
    if [ -z "$INFLIGHT_LINE" ]; then
      inflight_remove_line "$INFLIGHT_LINE"
      continue
    fi
    if [ -n "$BOX_HOST" ] && try_post_line "$INFLIGHT_LINE"; then
      inflight_remove_line "$INFLIGHT_LINE"
    else
      echo "mem0: memory service unavailable (status ${CURL_STATUS:-000}); line(s) still pending in ${INFLIGHT}" >&2
      break
    fi
  done
}

[ $# -ge 1 ] || usage

if [ "$1" = "--drain" ]; then
  drain_outbox
  exit 0
fi

TEXT="$1"
ENTITY="${2:-}"
[ -n "$TEXT" ] || usage

recover_inflight

SHA="$(sha256_of "$TEXT")"
LINE="$(jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg text "$TEXT" --arg entity "$ENTITY" --arg sha "$SHA" \
  '{ts:$ts,text:$text,entity:$entity,sha256:$sha}')"

APPENDED=0
append_line "$LINE" && APPENDED=1

if [ -n "$BOX_HOST" ] && try_post_line "$LINE"; then
  [ "$APPENDED" -eq 1 ] && remove_line_once "$LINE"
  drain_outbox
elif [ "$APPENDED" -eq 1 ]; then
  echo "mem0: memory service unavailable (status ${CURL_STATUS:-000}); queued in outbox" >&2
else
  echo "mem0: memory service unavailable (status ${CURL_STATUS:-000}) AND outbox lock busy; memory LOST: $TEXT" >&2
fi

exit 0
