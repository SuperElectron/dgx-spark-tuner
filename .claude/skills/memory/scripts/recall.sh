#!/usr/bin/env bash
# Read memories. Never writes.
#
#   recall.sh "<query>" [entity] [k]   relevance search — needs the embedder up
#   recall.sh --list [entity] [limit]  every memory, no vector search — embedder
#                                      may be down, which is the usual state
#   recall.sh --get <id>               one memory, full record
#
# Options on --list and search:
#   --json                 full records, metadata included, as a JSON array
#   --filter k=v,k=v       keep only records matching every pair, compared
#                          against metadata (dotted keys: epoch.vllm=abc123)
#
# Prints one line per memory: id, entity, text, then a config suffix showing
# the configuration the line was measured at. Exits 0 with no output when the
# service is down, so a caller is never blocked by memory.
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

json="" filter="" get="" mode="" args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --json)   json=1; shift ;;
    --filter) [ $# -ge 2 ] || { echo 'recall: --filter needs k=v[,k=v]' >&2; exit 2; }
              filter="$2"; shift 2 ;;
    --get)    [ $# -ge 2 ] || { echo 'recall: --get needs an id' >&2; exit 2; }
              get="$2"; shift 2 ;;
    --list)   mode=list; shift ;;
    --help)   sed -n '2,18p' "$0" >&2; exit 0 ;;
    *)        args+=("$1"); shift ;;
  esac
done

# The server has no get-one route, so --get pulls the list and picks the id.
if [ -n "$get" ]; then
  body="$(jq -nc --arg u "$USER_ID" '{user_id: $u, limit: 2000}')"
  out="$(call POST /memories/list "$body")"
  rec="$(jq -c --arg id "$get" '(if type == "array" then . else (.results // []) end)
         | map(select(.id == $id)) | first // empty' <<<"$out" 2>/dev/null)"
  [ -n "$rec" ] || { echo "recall: no memory $get" >&2; exit 0; }
  jq . <<<"$rec"
  exit 0
fi

if [ "$mode" = list ]; then
  entity="${args[0]:-}" limit="${args[1]:-500}"
  body="$(jq -nc --arg u "$USER_ID" --argjson l "$limit" --arg e "$entity" \
    '{user_id: $u, limit: $l} + (if $e == "" then {} else {filters: {entity: $e}} end)')"
  out="$(call POST /memories/list "$body")"
else
  [ "${#args[@]}" -ge 1 ] || { echo 'usage: recall.sh "<query>" [entity] [k]  |  recall.sh --list [entity] [limit]  |  recall.sh --get <id>' >&2; exit 2; }
  body="$(jq -nc --arg q "${args[0]}" --arg u "$USER_ID" --argjson k "${args[2]:-10}" --arg e "${args[1]:-}" \
    '{query: $q, user_id: $u, limit: $k} + (if $e == "" then {} else {filters: {entity: $e}} end)')"
  out="$(call POST /search "$body")"
fi

recs="$(jq -c '(if type == "array" then . else (.results // []) end)' <<<"$out" 2>/dev/null)"
[ -n "$recs" ] || exit 0

if [ -n "$filter" ]; then
  recs="$(jq -c --arg f "$filter" '
    ($f | split(",") | map(select(length > 0)
       | (index("=")) as $i | {k: .[:$i], v: .[$i+1:]})) as $want
    | map(select(. as $r | $want | all(. as $w
        | (($r.metadata // {}) | getpath($w.k | split("."))) as $got
        | $got != null and ($got | tostring) == $w.v)))' <<<"$recs" 2>/dev/null)"
fi

if [ -n "$json" ]; then
  jq . <<<"$recs"
  exit 0
fi

jq -r '.[] as $r | ($r.metadata // {}) as $m
  | ([ ($m.model // empty), ($m.quant // empty), ($m.runtime // empty), ($m.test // empty),
       (if $m.depth then "d\($m.depth)" else empty end),
       (if $m.conc  then "c\($m.conc)"  else empty end),
       (if $m.runs  then "runs=\($m.runs)" else empty end),
       ($m.bench // empty), ($m.date // empty) ] | join(" ")) as $cfg
  | "\($r.id)\t\($m.entity // "-")\t\($r.memory)\(if $cfg == "" then "" else "  · \($cfg)" end)"' <<<"$recs" 2>/dev/null
exit 0
