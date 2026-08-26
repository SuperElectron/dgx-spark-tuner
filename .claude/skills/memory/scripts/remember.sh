#!/usr/bin/env bash
# Write one memory, with the metadata that makes it comparable.
#
#   remember.sh "<text>" <entity> [--meta k=v ...]
#
# Every write is stamped schema=1. The class marker at the head of the text
# decides which fields are required; a write missing one is REFUSED (exit 3).
#
#   [OBSERVATION]  model test depth conc bench date
#   [ENV]          date scope
#   [LESSON]       date basis
#   [IDEA]         date evidence
#   [EXPERIMENT]   retired — use [OBSERVATION]
#
# `cell` is the depth/conc pair, carried as two fields: depth=16384 conc=10.
# It prints back as `d16384 c10`.
#
# Metadata keys (all values are stored as strings):
#   date model quant runtime test depth conc runs bench protocol
#   epoch.image epoch.build_source epoch.vllm epoch.flashinfer
#   scope basis evidence
#
# Exits 0 even when the service is unreachable — memory never blocks work. A
# guard refusal is not the service being down: that exits 3.
set -uo pipefail

USER_ID="dgx-spark-tuner"
PORT=8888

KEYS="date
model
quant
runtime
test
depth
conc
runs
bench
protocol
epoch.image
epoch.build_source
epoch.vllm
epoch.flashinfer
scope
basis
evidence"

usage() {
  echo 'usage: remember.sh "<text>" <entity> [--meta k=v ...]' >&2
  echo "  meta keys: $(echo $KEYS)" >&2
}

text="" entity="" pairs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --meta) [ $# -ge 2 ] || { usage; exit 2; }; pairs+=("$2"); shift 2 ;;
    --help) usage; exit 0 ;;
    -*)     echo "remember: unknown flag $1" >&2; usage; exit 2 ;;
    *)      if [ -z "$text" ]; then text="$1"; elif [ -z "$entity" ]; then entity="$1";
            else echo "remember: unexpected argument $1" >&2; usage; exit 2; fi; shift ;;
  esac
done
[ -n "$text" ] && [ -n "$entity" ] || { usage; exit 2; }

meta="$(jq -nc --arg e "$entity" '{entity: $e, schema: "1"}')"
for p in ${pairs[@]+"${pairs[@]}"}; do
  case "$p" in *=*) ;; *) echo "remember: --meta needs k=v, got '$p'" >&2; exit 2 ;; esac
  k="${p%%=*}" v="${p#*=}"
  grep -qxF -- "$k" <<<"$KEYS" || { echo "remember: unknown meta key '$k'" >&2; usage; exit 2; }
  meta="$(jq -c --arg k "$k" --arg v "$v" 'setpath($k | split("."); $v)' <<<"$meta")"
done

has() { [ -n "$(jq -r --arg k "$1" 'getpath($k | split(".")) // "" | tostring' <<<"$meta")" ]; }

case "$text" in
  '[EXPERIMENT]'*)
    echo "remember: [EXPERIMENT] is retired — write it as [OBSERVATION] with model/test/depth/conc/bench/date" >&2
    exit 3 ;;
  '[OBSERVATION]'*) class="OBSERVATION"; need="model test depth conc bench date" ;;
  '[ENV]'*)         class="ENV";         need="date scope" ;;
  '[LESSON]'*)      class="LESSON";      need="date basis" ;;
  '[IDEA]'*)        class="IDEA";        need="date evidence" ;;
  *) echo "remember: text must open with [OBSERVATION], [ENV], [LESSON] or [IDEA]" >&2; exit 3 ;;
esac

missing=()
for k in $need; do has "$k" || missing+=("$k"); done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "remember: REFUSED — [$class] needs ${missing[*]} (pass --meta k=v)" >&2
  exit 3
fi

host="$(jq -r '.host // empty' "$(git rev-parse --show-toplevel)/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "remember: no box configured, not written" >&2; exit 0; }

# sha256 is the server's dedupe key: the same text posted twice returns the
# first memory's id instead of writing a second.
sha="$(printf '%s' "$text" | shasum -a 256 | cut -d' ' -f1)"
body="$(jq -nc --arg t "$text" --arg s "$sha" --arg u "$USER_ID" --argjson m "$meta" \
  '{messages: [{role: "user", content: $t}], user_id: $u, metadata: ($m + {sha256: $s}), infer: false}')"

status="$(printf '%s' "$body" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
  "curl -sS --max-time 10 -o /dev/null -w '%{http_code}' -X POST \
   -H 'Content-Type: application/json' --data-binary @- \
   'http://127.0.0.1:${PORT}/memories'" 2>/dev/null)"

case "$status" in
  2*) echo "remember: written ($entity)" >&2 ;;
  *)  echo "remember: NOT written (http ${status:-000}) — $text" >&2 ;;
esac
exit 0
