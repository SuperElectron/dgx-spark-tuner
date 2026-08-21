# Arena recipe — Qwen/Qwen3.5-0.8B

Source: https://spark-arena.com/benchmark/9ff9728a-ff81-44cd-8ce9-03393b349158
Author: Raphael Amorim. Benchmarked ~2026-05-23 (page ts 1779481175).
Tool: llama-benchy. Stack: spark-vllm-docker (`vllm-node` container,
https://github.com/eugr/spark-vllm-docker). Scraped 2026-08-21.

## Recipe (verbatim)

```yaml
command: |
  vllm serve Qwen/Qwen3.5-0.8B \
    --host {host} \
    --port {port} \
    --language-model-only \
    --max-model-len {max_model_len} \
    --max-num-batched-tokens {max_num_batched_tokens} \
    --max-num-seqs {max_num_seqs} \
    --gpu-memory-utilization {gpu_memory_utilization} \
    --load-format fastsafetensors \
    --attention-backend flash_attn \
    --enable-prefix-caching \
    --enable-chunked-prefill \
    --trust-remote-code \
    --dtype auto \
    --reasoning-parser qwen3 \
    --enable-auto-tool-choice \
    --tool-call-parser qwen3_coder
recipe_version: '1'
model: Qwen/Qwen3.5-0.8B
container: vllm-node
mods:
  - mods/fix-qwen3.5-chat-template
env:
  VLLM_MARLIN_USE_ATOMIC_ADD: '1'
defaults:
  port: 8000
  max_num_batched_tokens: 8192
  max_model_len: 262144
  gpu_memory_utilization: 0.8
  max_num_seqs: 4
  host: 0.0.0.0
```

## Leaderboard numbers (as of scrape)

| cell | tok/s |
|---|---|
| **tg128 (c1)** — our target | **121.19 ± 0.23** |
| pp2048 (c1) | 23284.60 ± 897.95 |
| tg128 @ d4096 (c2) | 241.95 ± 0.37 (121.03/req) |
| pp2048 @ d4096 (c2) | 18940.40 ± 207.47 |

## Mapping notes (recipe → our best.env)

- Dropped as decode-irrelevant serving plumbing: `--reasoning-parser`,
  `--enable-auto-tool-choice`, `--tool-call-parser` (tool-call parsing of
  outputs, not kernel work), and the chat-template mod (our probe hits
  /v1/completions, not chat).
- `VLLM_MARLIN_USE_ATOMIC_ADD=1` not carried: marlin kernels serve quantized
  weights; this checkpoint runs BF16. Also our start.sh cannot yet pass env
  vars into the container — known gap, revisit if a quantized model needs it.
- `--attention-backend flash_attn` kept verbatim DESPITE our box lore saying
  flash-attn is shaky on GB10 — their stack proves some flash path works.
  Round 0 will confirm or crash; either is information.

## Reproduction gap

(fill after round 0)
