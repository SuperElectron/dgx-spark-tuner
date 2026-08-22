#!/usr/bin/env bash
# End-to-end smoke test for the mem0 memory stack, run from the laptop
# against the real box. Exercises the skill scripts in
# .claude/skills/mem0/scripts/ plus direct REST calls (via _common.sh) for
# setup/cleanup that has no dedicated script. Prints PASS/FAIL per step;
# nonzero exit if any step failed.
#
# Usage: memory/tests/smoke.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_DIR="$REPO_ROOT/.claude/skills/mem0/scripts"
# shellcheck source=../../.claude/skills/mem0/scripts/_common.sh
source "$SKILL_DIR/_common.sh"
require_box_host

TS="$(date +%s)"
ENTITY="smoke-test"
TEXT="[LESSON] smoke test line ${TS}"
TEXT_Q="[LESSON] smoke test queued line ${TS}"

FAILED=0
MEM0_CID=""
STOPPED_MEM0=0

pass() { echo "PASS  $1"; }
fail() { echo "FAIL  $1: ${2:-}"; FAILED=1; }

list_count() {
  # list_count <text> -> prints number of memories matching sha256(text)+entity
  local body
  body="$(jq -nc --arg uid "$MEM0_USER_ID" --arg sha "$(sha256_of "$1")" \
    '{user_id: $uid, filters: {sha256: $sha}}')"
  mem0_list "$body"
  [[ "$CURL_STATUS" =~ ^2 ]] || { echo 0; return; }
  jq '(.results // []) | length' <<<"$CURL_BODY" 2>/dev/null || echo 0
}

delete_matching() {
  # delete_matching <text>: deletes every memory matching sha256(text)
  local body ids
  body="$(jq -nc --arg uid "$MEM0_USER_ID" --arg sha "$(sha256_of "$1")" \
    '{user_id: $uid, filters: {sha256: $sha}}')"
  mem0_list "$body"
  [[ "$CURL_STATUS" =~ ^2 ]] || return 0
  ids="$(jq -r '(.results // [])[].id' <<<"$CURL_BODY" 2>/dev/null)"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    mem0_delete "$id"
  done <<<"$ids"
}

cleanup() {
  delete_matching "$TEXT"
  delete_matching "$TEXT_Q"
  if [ "$STOPPED_MEM0" -eq 1 ]; then
    ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" "docker start $MEM0_CID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# 1. memory.sh status healthy
out="$("$SKILL_DIR/memory.sh" status 2>&1)"
if echo "$out" | grep -q "mem0 (:${MEM0_PORT}): healthy" && echo "$out" | grep -q "embeddings (:${EMBED_PORT}): healthy"; then
  pass "memory.sh status healthy"
else
  fail "memory.sh status healthy" "$out"
fi

# 2. remember.sh posts a new line
out="$("$SKILL_DIR/remember.sh" "$TEXT" "$ENTITY" 2>&1)"
if echo "$out" | grep -qi "queued\|LOST"; then
  fail "remember.sh posts new line" "$out"
else
  pass "remember.sh posts new line"
fi

# 3. recall.sh finds it
sleep 1
out="$("$SKILL_DIR/recall.sh" "$TEXT" "$ENTITY" 2>&1)"
if echo "$out" | grep -qF "$TEXT"; then
  pass "recall.sh finds new line"
else
  fail "recall.sh finds new line" "$out"
fi

# 4. remember.sh same line again -> server dedupe, still exactly one
"$SKILL_DIR/remember.sh" "$TEXT" "$ENTITY" >/dev/null 2>&1
n="$(list_count "$TEXT")"
if [ "$n" = "1" ]; then
  pass "server dedupe keeps exactly one"
else
  fail "server dedupe keeps exactly one" "got $n matches"
fi

# 5. stop the mem0 container on the box
MEM0_CID="$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" \
  "cd ${MEM0_BOX_DIR} && docker compose -p '${COMPOSE_PROJECT}' ps -q mem0")"
if [ -n "$MEM0_CID" ] && ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" "docker stop $MEM0_CID" >/dev/null 2>&1; then
  STOPPED_MEM0=1
  pass "stopped mem0 container"
else
  fail "stopped mem0 container" "could not resolve/stop container"
fi

# 6. remember.sh while mem0 is down -> queues in outbox, exits 0
out="$("$SKILL_DIR/remember.sh" "$TEXT_Q" "$ENTITY" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "queued"; then
  pass "remember.sh queues while down (exit 0)"
else
  fail "remember.sh queues while down (exit 0)" "rc=$rc out=$out"
fi

# 7. memory-doctor.sh must FIX: restart container, drain outbox
out="$("$SKILL_DIR/memory-doctor.sh" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "FIXED.*mem0" && echo "$out" | grep -q "all checks passed"; then
  pass "memory-doctor.sh fixes and passes"
  STOPPED_MEM0=0
else
  fail "memory-doctor.sh fixes and passes" "rc=$rc out=$out"
fi

# 8. recall.sh finds the previously-queued line
sleep 1
out="$("$SKILL_DIR/recall.sh" "$TEXT_Q" "$ENTITY" 2>&1)"
if echo "$out" | grep -qF "$TEXT_Q"; then
  pass "recall.sh finds drained queued line"
else
  fail "recall.sh finds drained queued line" "$out"
fi

if [ "$FAILED" -eq 0 ]; then
  echo "smoke: all steps passed"
else
  echo "smoke: one or more steps FAILED"
fi
exit "$FAILED"
