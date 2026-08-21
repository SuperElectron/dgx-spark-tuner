#!/usr/bin/env bash
# Stop the benchmark engine and drop the page cache so the next round
# starts clean. The runner's finally-path — always safe, even after a
# crash.
set -euo pipefail

if docker ps -a --format '{{.Names}}' | grep -q '^vllm-bench$'; then
  docker rm -f vllm-bench >/dev/null
  echo "stop: vllm-bench stopped"
else
  echo "stop: no vllm-bench running"
fi

sudo -n /usr/local/bin/spark-tuner-dropcaches 2>/dev/null \
  || echo "stop: drop-caches helper missing — run setup.sh" >&2
