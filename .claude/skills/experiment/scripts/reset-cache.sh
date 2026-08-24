#!/usr/bin/env bash
# Reset the engine's prefix cache between benchmark runs, as vLLM's own sweep
# does. Referenced from a recipe's `post_run_cmd:`, which llama-benchy runs as
# a single argv[0] — it neither shell-splits nor uses a shell, so this has to
# be one executable path taking no arguments.
#
# Needs VLLM_SERVER_DEV_MODE=1 in the recipe's env; without it the engine does
# not route /reset_prefix_cache and this reports the 404 rather than hiding it.
set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
host="$(jq -r '.host // empty' "$root/.claude/box.json" 2>/dev/null)"
[ -n "$host" ] || { echo "reset-cache: no box configured" >&2; exit 0; }

status="$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' \
  -X POST "http://${host}:8000/reset_prefix_cache" 2>/dev/null)"

case "$status" in
  2*) exit 0 ;;
  *)  echo "reset-cache: /reset_prefix_cache returned ${status:-000}" >&2; exit 1 ;;
esac
