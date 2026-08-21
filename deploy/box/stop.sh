#!/usr/bin/env bash
# Stop the benchmark engine and drop the page cache so the next round (or
# the restored engines) start clean. The runner's finally-path — always
# safe, even after a crash.
#
#   ./stop.sh             # stop vllm-bench, leave box idle
#   ./stop.sh --restore   # also restart the standing engines start.sh parked
set -euo pipefail

PARKED=/tmp/spark-tuner-parked.txt
START_MODELS="$HOME/runKali/box/scripts/start-models.sh"

if docker ps -a --format '{{.Names}}' | grep -q '^vllm-bench$'; then
  docker rm -f vllm-bench >/dev/null
  echo "stop: vllm-bench stopped"
else
  echo "stop: no vllm-bench running"
fi

sudo -n /usr/local/bin/spark-tuner-dropcaches 2>/dev/null \
  || echo "stop: drop-caches helper missing — run setup.sh" >&2

if [ "${1:-}" = "--restore" ]; then
  if [ ! -s "$PARKED" ]; then
    echo "stop: nothing was parked, leaving box idle"
    exit 0
  fi
  [ -x "$START_MODELS" ] || { echo "stop: $START_MODELS missing" >&2; exit 1; }
  echo "stop: restoring standing engines via $START_MODELS"
  "$START_MODELS"
  rm -f "$PARKED"
fi
