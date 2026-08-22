# Arena targets — nvidia/Qwen3.6-35B-A3B-NVFP4, thin-cell campaign

Board scraped live from spark-arena.com/leaderboard on 2026-08-21 (21:00 UTC
snapshot, 211 benchmarks). Scrape verified: the tg128 @ d16384 c1 read
reproduces our existing milestone snapshot exactly (188.47 / 152.76 / 149.07 /
131.44 / 116.03).

## Recipe

Ours, carried over from the qwen36-35b-quant series (de-rayed from
@eugr/qwen3.6-35b-a3b-nvfp4 — Ray OOM-kills the worker on solo GB10):

    vllm serve nvidia/Qwen3.6-35B-A3B-NVFP4
      --kv-cache-dtype fp8 --attention-backend flashinfer --moe-backend marlin
      --gpu-memory-utilization 0.8 --max-model-len 32768 --max-num-seqs 4
      --max-num-batched-tokens 8192 --enable-chunked-prefill
      --async-scheduling --enable-prefix-caching
      --speculative-config '{"method":"mtp","num_speculative_tokens":3,"moe_backend":"triton"}'
      --load-format fastsafetensors
    env VLLM_MARLIN_USE_ATOMIC_ADD=1, container vllm-node, TP=1

## Target cells and the numbers to beat

| Cell | Entries | Top | Holder | Our estimate |
|---|---:|---:|---|---|
| tg32 @ d8192 c1 | 1 | — | Qwen3.6-27B-PrismaSCOUT-NVFP4 | 90-105 |
| tg32 @ d16384 c1 | 1 | 28.11 | Qwen3.6-27B-PrismaSCOUT-NVFP4 | 85-100 |
| tg32 @ d32768 c1 | 1 | 23.31 | Qwen3.6-27B-PrismaSCOUT-NVFP4 | 80-95 |
| tg128 @ d16384 c4 | 8 | 46.68 | Gemma-4-26B-A4B-NVFP4 | 180-260 (aggregate) |
| tg128 @ d65536 c1 | 2 | 16.48 | DeepSeek-V4-Flash-REAP MXFP4 | 70-85 |
| ctx_tg @ d65536 c1 | 1 | 20.70 | DeepSeek-V4-Flash-REAP FP8 | 70-85 |

Reference points in the crowded cells, for context only (not this campaign's
targets): tg128 @ d16384 c1 top 188.47 (LFM2.5-350M BF16), best vLLM NVFP4
116.03; tg128 @ d32768 c1 top 115.53 (Nemotron Lightning NVFP4);
tg128 @ d131072 c1 top 81.60 (Nemotron Lightning NVFP4).

## Reproduction gap

qwen36-35b-quant round 0 measured tg128 @ d16384 c1 median 102.2 against the
board's 116.03 for the same model+runtime+quant: -12%. Previously attributed
to this box's 2405/3003 MHz SM clock, but memory later corrected that ceiling
to be fleet-wide power policy rather than a local misconfiguration — so the
gap is currently UNEXPLAINED and is not assumed to apply to the thin cells.
