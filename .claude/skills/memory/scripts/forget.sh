#!/usr/bin/env bash
# Delete memories by id. Reads ids from arguments or stdin, one per line.
#
#   forget.sh <id> [<id> ...]
#   recall.sh --list | cut -f1 | forget.sh -
#
# Deletion is permanent and the server keeps no undo, so this prints what it
# is about to do and requires --yes to proceed.
set -uo pipefail

USER_ID="dgx-spark-tuner"
PORT=8888
confirm=""

args=()
for a in "$@"; do
  case "$a" in
    --yes) confirm=1 ;;
    -)     while IFS= read -r line; do [ -n "$line" ] && args+=("$line"); done ;;
    *)     args+=("$a") ;;
  esac
done

[ "${#args[@]}" -gt 0 ] || { echo 'usage: forget.sh [--yes] <id>... | forget.sh --yes -' >&2; exit 2; }

host="$(jq -r '.host // empty' "$(git rev-parse --show-toplevel)/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "forget: no box configured" >&2; exit 1; }

if [ -z "$confirm" ]; then
  echo "forget: would delete ${#args[@]} memories. Re-run with --yes to proceed." >&2
  printf '  %s\n' "${args[@]}" >&2
  exit 1
fi

ok=0 fail=0
for id in "${args[@]}"; do
  status="$(ssh -n -o ConnectTimeout=10 -o BatchMode=yes "$host" \
    "curl -sS --max-time 15 -o /dev/null -w '%{http_code}' -X DELETE \
     'http://127.0.0.1:${PORT}/memories/${id}'" 2>/dev/null)"
  if [[ "$status" =~ ^2 ]]; then ok=$((ok+1)); else fail=$((fail+1)); echo "forget: $id -> http ${status:-000}" >&2; fi
done
echo "forget: deleted $ok, failed $fail" >&2
