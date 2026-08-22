#!/usr/bin/env bash
# Self-heal chain for the mem0 stack. Runs a sequence of checks, attempts a
# fix for each, prints PASS/FIXED/FAIL/SKIP per step, and drains the memory
# outbox at the end. Idempotent; exits nonzero only if still broken.
#
# Usage: memory-doctor.sh

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"

BROKEN=0

step() {
  # step <label> <check-fn> <fix-fn>
  local label="$1" check="$2" fix="$3"
  if "$check"; then
    echo "PASS  $label"
    return 0
  fi
  echo "...   $label failed, attempting fix"
  "$fix" >/dev/null 2>&1 || true
  if "$check"; then
    echo "FIXED $label"
    return 0
  fi
  echo "FAIL  $label"
  BROKEN=1
  return 1
}

skip() { echo "SKIP  $1 (box unreachable)"; }

compose() {
  # shellcheck disable=SC2029
  # MEM0_BOX_DIR is intentionally unquoted on the remote side so a leading
  # "~" (the documented default, ~/spark-tuner/memory) tilde-expands there.
  ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" "cd ${MEM0_BOX_DIR} && docker compose -p '${COMPOSE_PROJECT}' $*"
}

check_box() { [ -n "$BOX_HOST" ] && box_reachable; }
fix_box() { :; } # nothing we can do from here; ssh reachability is external

check_containers() {
  local out
  out="$(compose ps --status running --format '{{.Name}}' 2>/dev/null)" || return 1
  [ -n "$out" ]
}
fix_containers() { compose up -d; sleep 3; }

check_mem0() {
  mem0_health
  [[ "$CURL_STATUS" =~ ^2 ]]
}
fix_mem0() { compose restart mem0 2>/dev/null || compose up -d; sleep 5; }

check_embed() {
  embed_health
  [[ "$CURL_STATUS" =~ ^2 ]]
}
fix_embed() { compose restart embeddings 2>/dev/null || compose up -d; sleep 5; }

check_roundtrip() {
  local body id resp status
  body="$(jq -nc --arg uid "$MEM0_USER_ID" --arg sha "$(sha256_of "[LESSON] memory-doctor roundtrip probe")" \
    '{messages: [{role: "user", content: "[LESSON] memory-doctor roundtrip probe"}], user_id: $uid, metadata: {entity: "doctor:probe", sha256: $sha}, infer: false}')"
  mem0_add "$body"
  resp="$CURL_BODY"
  status="$CURL_STATUS"
  [[ "$status" =~ ^2 ]] || return 1

  id="$(jq -r 'if type == "array" then .[0].id elif has("results") then .results[0].id else (.id // empty) end' <<<"$resp" 2>/dev/null)"

  local search_body search_resp found
  search_body="$(jq -nc --arg uid "$MEM0_USER_ID" \
    '{query: "memory-doctor roundtrip probe", user_id: $uid, limit: 5}')"
  mem0_search "$search_body"
  search_resp="$CURL_BODY"
  [[ "$CURL_STATUS" =~ ^2 ]] || return 1
  found="$(jq -r '(if type == "array" then . else (.results // []) end) | map(select(.memory // "" | test("roundtrip probe"))) | length' <<<"$search_resp" 2>/dev/null)"

  if [ -n "$id" ]; then
    mem0_delete "$id" || true
  fi

  [ "${found:-0}" -gt 0 ]
}
fix_roundtrip() { :; } # covered by the mem0/embed fixes above; nothing extra to do

check_outbox_drained() {
  local outbox="$REPO_ROOT/.cache/memory-outbox.jsonl"
  # A failed drain parks its backlog in outbox.inflight, not the outbox
  # itself - check both, or a stuck drain false-greens this step.
  [ ! -s "$outbox" ] && [ ! -s "$outbox.inflight" ]
}
fix_outbox_drained() { "$SCRIPT_DIR/remember.sh" --drain; }

step "box reachable" check_box fix_box

if [ "$BROKEN" -ne 0 ]; then
  skip "containers up"
  skip "mem0 :${MEM0_PORT} healthy"
  skip "embeddings :${EMBED_PORT} healthy"
  skip "add/search/delete roundtrip"
else
  step "containers up" check_containers fix_containers
  step "mem0 :${MEM0_PORT} healthy" check_mem0 fix_mem0
  step "embeddings :${EMBED_PORT} healthy" check_embed fix_embed
  step "add/search/delete roundtrip" check_roundtrip fix_roundtrip
fi

step "outbox drained" check_outbox_drained fix_outbox_drained

if [ "$BROKEN" -ne 0 ]; then
  echo "memory-doctor: unresolved failures above"
  exit 1
fi

echo "memory-doctor: all checks passed"
exit 0
