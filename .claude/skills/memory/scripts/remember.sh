#!/usr/bin/env bash
# Write one memory.
#
#   remember.sh "<text>" <entity>
#
# Exits 0 even when the service is unreachable — memory never blocks work. It
# says on stderr whether the write landed.
set -uo pipefail

USER_ID="dgx-spark-tuner"
PORT=8888

[ $# -eq 2 ] || { echo 'usage: remember.sh "<text>" <entity>' >&2; exit 2; }
text="$1" entity="$2"

host="$(jq -r '.host // empty' "$(git rev-parse --show-toplevel)/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "remember: no box configured, not written" >&2; exit 0; }

# sha256 is the server's dedupe key: the same text posted twice returns the
# first memory's id instead of writing a second.
sha="$(printf '%s' "$text" | shasum -a 256 | cut -d' ' -f1)"
body="$(jq -nc --arg t "$text" --arg e "$entity" --arg s "$sha" --arg u "$USER_ID" \
  '{messages: [{role: "user", content: $t}], user_id: $u, metadata: {entity: $e, sha256: $s}, infer: false}')"

status="$(printf '%s' "$body" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$host" \
  "curl -sS --max-time 10 -o /dev/null -w '%{http_code}' -X POST \
   -H 'Content-Type: application/json' --data-binary @- \
   'http://127.0.0.1:${PORT}/memories'" 2>/dev/null)"

case "$status" in
  2*) echo "remember: written ($entity)" >&2 ;;
  *)  echo "remember: NOT written (http ${status:-000}) — $text" >&2 ;;
esac
exit 0
