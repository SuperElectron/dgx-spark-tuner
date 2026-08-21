#!/usr/bin/env bash
# Start ONE benchmark vLLM engine (container: vllm-bench). Steps, in order:
# park any standing vllm-* engines, drop the page cache, boot the engine
# detached, wait until it answers, print the env fingerprint.
#
#   MODEL=Qwen/Qwen3-... PORT=8100 KV_CACHE_MEMORY_BYTES=... ./start.sh
#
# GB10 rules encoded here, not trusted to callers:
# - engines start sequentially, never in parallel
# - page cache is dropped first: 60+ GiB weight loads leave clean pages
#   CUDA cannot claim, and the next engine OOMs at context creation
# - KV_CACHE_MEMORY_BYTES is exact bytes: the fraction flag measures
#   whatever is free at boot, and unified-memory profiling can abort
# - image is digest-pinned (sm_121a/arm64) for rollback
set -euo pipefail

MODEL="${MODEL:?set MODEL}"
PORT="${PORT:-8100}"
IMAGE="${IMAGE:-ghcr.io/timothystewart6/vllm-gb10@sha256:fa87aea586e02719aba804f76e0895d1f096e8c387573e7981e2681589b3b712}"
GPU_UTIL="${GPU_UTIL:-0.90}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-}"
MAX_BATCHED_TOKENS="${MAX_BATCHED_TOKENS:-}"
KV_CACHE_MEMORY_BYTES="${KV_CACHE_MEMORY_BYTES:-}"
EXTRA_VLLM_ARGS="${EXTRA_VLLM_ARGS:-}"
WAIT_SECS="${WAIT_SECS:-600}"
# Engines we stop to free the GPU, recorded so `stop.sh --restore` knows
# to bring them back.
STOPPED_ENGINES_FILE=/tmp/spark-tuner-stopped-engines.txt

if docker ps --format '{{.Names}}' | grep -q '^vllm-bench$'; then
  echo "start: vllm-bench already running — run stop.sh first" >&2
  exit 1
fi

RUNNING_ENGINES="$(docker ps --filter 'name=vllm-' --format '{{.Names}}')"
if [ -n "$RUNNING_ENGINES" ]; then
  echo "start: stopping running engines: $(echo "$RUNNING_ENGINES" | tr '\n' ' ')"
  echo "$RUNNING_ENGINES" > "$STOPPED_ENGINES_FILE"
  echo "$RUNNING_ENGINES" | xargs -r docker stop >/dev/null
fi

sudo -n /usr/local/bin/spark-tuner-dropcaches 2>/dev/null || {
  echo "start: drop-caches helper missing — run setup.sh" >&2; exit 1; }

# No nvidia docker runtime on this box; Docker consumes the CDI spec.
if [ -e /var/run/cdi/nvidia.yaml ] || [ -e /etc/cdi/nvidia.yaml ]; then
  GPU_ARGS=(--device nvidia.com/gpu=all)
else
  GPU_ARGS=(--gpus all)
fi

ARGS=(--gpu-memory-utilization "$GPU_UTIL")
[ -n "$MAX_MODEL_LEN" ] && ARGS+=(--max-model-len "$MAX_MODEL_LEN")
[ -n "$MAX_BATCHED_TOKENS" ] && ARGS+=(--max-num-batched-tokens "$MAX_BATCHED_TOKENS")
[ -n "$KV_CACHE_MEMORY_BYTES" ] && ARGS+=(--kv-cache-memory-bytes "$KV_CACHE_MEMORY_BYTES")
# shellcheck disable=SC2206  # word-splitting is the interface here
[ -n "$EXTRA_VLLM_ARGS" ] && ARGS+=($EXTRA_VLLM_ARGS)

docker run -d --rm \
  "${GPU_ARGS[@]}" \
  --ipc=host \
  --network host \
  --name vllm-bench \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  ${HF_TOKEN:+-e HF_TOKEN="$HF_TOKEN"} \
  "$IMAGE" \
  vllm serve "$MODEL" \
    --host 0.0.0.0 \
    --port "$PORT" \
    "${ARGS[@]}" >/dev/null

echo "start: engine booting on :$PORT (weights load in minutes; docker logs -f vllm-bench)"
for _ in $(seq 1 $((WAIT_SECS / 5))); do
  curl -sf --max-time 4 "http://localhost:$PORT/v1/models" >/dev/null 2>&1 && break
  docker ps --format '{{.Names}}' | grep -q '^vllm-bench$' || {
    echo "start: engine died during boot — docker logs vllm-bench" >&2; exit 1; }
  sleep 5
done
curl -sf --max-time 4 "http://localhost:$PORT/v1/models" >/dev/null 2>&1 || {
  echo "start: :$PORT not up after ${WAIT_SECS}s" >&2; exit 1; }

bash "$(dirname "$0")/status.sh"
