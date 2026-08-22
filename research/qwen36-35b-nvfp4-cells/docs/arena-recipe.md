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

## R5b board scrape — cells RESULTS.md was missing

Scraped live from spark-arena.com/leaderboard on 2026-08-21, filters
`Cluster = Single Node` throughout, concurrency as stated per row. Scrape
verified before recording: `tg128 @ d16384 c1` reproduced the known top five
exactly (188.47 / 152.76 / 149.07 / 131.44 / 116.03).

`Entries` is the board's own "Showing N results" count for that cell after the
single-node filter. `Ours` is the measured figure the row is scored against.

### Decode cells

| Cell (test @ depth, conc, cluster) | Entries | Board top | Holder | Runtime | Quant | Ours | Ours/top |
|---|---:|---:|---|---|---|---:|---:|
| ctx_tg @ d8192, c1, single | 128 | 207.60 | LFM2.5-350M | vLLM | BF16 | 126.52 | 0.61x |
| ctx_tg @ d16384, c1, single | 130 | 193.09 | LFM2.5-350M | vLLM | BF16 | 130.16 | 0.67x |
| ctx_tg @ d32768, c1, single | 125 | 117.37 | Qwen3.6-35B-A3B-NVFP4 | Atlas | NVFP4 | 84.03 | 0.72x |
| ctx_tg @ d16384, c4, single | 7 | 27.68 | Gemma-4-26B-A4B-NVFP4 | vLLM | NVFP4 | 56.36 | 2.04x |
| tg128 @ d16384, c2, single | 130 | 325.44 | LFM2.5-350M | vLLM | BF16 | 84.00 | 0.26x |
| tg128 @ d16384, c5, single | 120 | 428.95 | LFM2.5-350M | vLLM | BF16 | 48.12 | 0.11x |

Runners-up worth keeping, same cells:

- ctx_tg @ d8192 c1: 177.50 / 177.42 / 176.47, all Qwen3.6-35B-A3B-NVFP4 on
  Atlas; best vLLM+NVFP4 is 118.07 (Nemotron-3.5-Lightning-30B-A3B-NVFP4).
- ctx_tg @ d16384 c1: 153.86 / 152.14, Qwen3.6-35B-A3B-NVFP4 on Atlas.
- ctx_tg @ d32768 c1: 116.65 / 115.56, Nemotron-3.5-Lightning-30B-A3B-NVFP4
  on vLLM — the whole top three sits inside 1.6% of each other.
- ctx_tg @ d16384 c4: 25.17 (Gemma-4-26B-A4B-NVFP4, vLLM), then 21.44
  (Qwen3.5-122B-A10B-int4-fp8-hybrid, vLLM). Thin cell, and we are above all of it.
- tg128 @ d16384 c2: 179.48 Qwen3.5-0.8B BF16, 178.85 gemma-3-1b-it BF16,
  163.27 Qwen3.6-35B-A3B-NVFP4 on vLLM — the last is the like-for-like number.
- tg128 @ d16384 c5: 230.47 Qwen3.5-0.8B BF16, then 225.46
  Qwen3.6-35B-A3B-NVFP4-Fast on vLLM — best vLLM+NVFP4 in the cell.

The c2 and c5 cells are NOT empty: the board carries 130 and 120 single-node
entries respectively, topped by a 350M BF16 model. Correct the earlier
"no incumbent" assumption.

### Prefill cells

The board has no `ctx_pp2048` test type. The prefill families it publishes are
`pp2048 @ dN`, `pp4096 @ dN`, and `ctx_pp @ dN`, so `ctx_pp @ dN` is recorded
below as the context-prefill counterpart.

| Cell (test @ depth, conc, cluster) | Entries | Board top | Holder | Runtime | Quant |
|---|---:|---:|---|---|---|
| pp2048 @ d8192, c1, single | 129 | 215894.21 | Qwen3.6-35B-A3B-FP8 | Atlas | FP8 |
| pp2048 @ d16384, c1, single | 131 | 99229.33 | Qwen3.6-35B-A3B-FP8 | Atlas | FP8 |
| pp2048 @ d32768, c1, single | 125 | 63079.61 | Qwen3.6-35B-A3B-NVFP4 | Atlas | NVFP4 |
| pp2048 @ d65536, c1, single | 0 | no entries | — | — | — |
| ctx_pp @ d8192, c1, single | 129 | 775122.96 | Qwen3.6-35B-A3B-NVFP4 | Atlas | NVFP4 |
| ctx_pp @ d16384, c1, single | 132 | 884764.53 | Qwen3.6-35B-A3B-FP8 | Atlas | FP8 |
| ctx_pp @ d32768, c1, single | 126 | 945271.31 | Qwen3.6-35B-A3B-FP8 | Atlas | FP8 |
| ctx_pp @ d65536, c1, single | 1 | 1393.35 | DeepSeek-V4-Flash-0731-REAP | vLLM | FP8 |

`pp2048 @ d65536` is a genuine empty cell — the depth is absent from the
board's test-type list entirely, so nobody has ever posted it. The adjacent
depth `pp2048 @ d65535` does exist and is crowded: 123 entries, top 30697.95
(Qwen3.6-35B-A3B-FP8, Atlas, FP8), runner-up 29991.76
(Qwen3.6-35B-A3B-NVFP4, Atlas). Posting d65536 claims a rank-1 outright, but
it will be read against the d65535 column by anyone who looks.

`ctx_pp @ d65536 c1` is near-empty at one entry and the incumbent is
1393.35 — three orders of magnitude below the same test type at d32768,
which suggests the single holder is a slow outlier rather than a real ceiling.

Two structural notes on the prefill cells: every prefill top is held by Atlas,
which is out of scope for this campaign, and the best vLLM figures trail the
Atlas tops by roughly an order of magnitude (e.g. pp2048 @ d32768 c1: Atlas
63079.61 vs best vLLM+NVFP4 4644.54, Laguna-XS-2.1-NVFP4). Beating a prefill
top means beating Atlas, so these cells are recorded for completeness rather
than as reachable targets.

## Reproduction gap

qwen36-35b-quant round 0 measured tg128 @ d16384 c1 median 102.2 against the
board's 116.03 for the same model+runtime+quant: -12%. Previously attributed
to this box's 2405/3003 MHz SM clock, but memory later corrected that ceiling
to be fleet-wide power policy rather than a local misconfiguration — so the
gap is currently UNEXPLAINED and is not assumed to apply to the thin cells.
