#!/usr/bin/env bash
# Control the mem0 memory stack (compose project "sparkmem") on the box.
#
# Usage: memory.sh start|stop|status|logs [service]

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_common.sh
source "$SCRIPT_DIR/_common.sh"
require_box_host

usage() {
  echo "usage: memory.sh start|stop|status|logs [service]" >&2
  exit 2
}

compose() {
  # shellcheck disable=SC2029  # intentional client-side expansion of $*
  # MEM0_BOX_DIR is intentionally unquoted on the remote side so a leading
  # "~" (the documented default, ~/spark-tuner/memory) tilde-expands there.
  ssh -o ConnectTimeout=10 -o BatchMode=yes "$BOX_HOST" "cd ${MEM0_BOX_DIR} && docker compose -p '${COMPOSE_PROJECT}' $*"
}

poll_health() {
  local label="$1" fn="$2" tries=30 i
  printf 'waiting for %s' "$label"
  for ((i = 0; i < tries; i++)); do
    "$fn"
    if [[ "$CURL_STATUS" =~ ^2 ]]; then
      echo " OK (${CURL_STATUS})"
      return 0
    fi
    printf '.'
    sleep 2
  done
  echo " TIMEOUT"
  return 1
}

cmd_start() {
  if ! box_reachable; then
    echo "mem0: box $BOX_HOST unreachable over ssh" >&2
    exit 1
  fi
  compose up -d
  local ok=0
  poll_health "mem0 (:${MEM0_PORT})" mem0_health || ok=1
  poll_health "embeddings (:${EMBED_PORT})" embed_health || ok=1
  if [ "$ok" -ne 0 ]; then
    echo "mem0: stack started but health checks did not pass; run memory-doctor.sh" >&2
    exit 1
  fi
  echo "mem0: stack up and healthy"
}

cmd_stop() {
  if ! box_reachable; then
    echo "mem0: box $BOX_HOST unreachable over ssh" >&2
    exit 1
  fi
  compose down
}

cmd_status() {
  if ! box_reachable; then
    echo "box: UNREACHABLE ($BOX_HOST)"
    exit 1
  fi
  echo "box: reachable ($BOX_HOST)"
  compose ps || true

  mem0_health
  if [[ "$CURL_STATUS" =~ ^2 ]]; then
    echo "mem0 (:${MEM0_PORT}): healthy (${CURL_STATUS})"
  else
    echo "mem0 (:${MEM0_PORT}): unhealthy (${CURL_STATUS})"
  fi

  embed_health
  if [[ "$CURL_STATUS" =~ ^2 ]]; then
    echo "embeddings (:${EMBED_PORT}): healthy (${CURL_STATUS})"
  else
    echo "embeddings (:${EMBED_PORT}): unhealthy (${CURL_STATUS})"
  fi
}

cmd_logs() {
  if ! box_reachable; then
    echo "mem0: box $BOX_HOST unreachable over ssh" >&2
    exit 1
  fi
  compose logs --tail=200 "${1:-}"
}

[ $# -ge 1 ] || usage
case "$1" in
  start) cmd_start ;;
  stop) cmd_stop ;;
  status) cmd_status ;;
  logs) shift; cmd_logs "${1:-}" ;;
  *) usage ;;
esac
