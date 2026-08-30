# The board entries this model is measured against

Read live 2026-08-29 18:18 local, one snapshot generation,
`generatedAt: 2026-08-30T01:00:28Z`. All 28 `tg128` cells cached in one sweep.
Read-only — nothing was submitted. Every figure below is inline; the raw scan is
local scratch at `.cache/results/2026-08-29-1818-qwen38-27b-scan.md`, which is
gitignored and will not exist in a fresh clone.

**These are date-stamped observations, never current standings.** Re-read the
cell with `spark-board` before any claim of a margin.

## The peer set

    modelName    Qwen3.8-27B-NVFP4  (also -FP8 and -NVFP4-BF16-LMHead)
    runtime      vLLM
    clusterSize  1

The board mixes every model, so rank-all is meaningless here: both the `d16384`
c1 and c10 cells are topped by LFM2.5-350M. Rank inside the peer set.

**This is a live peer set, not a reference.** We serve
`unsloth/Qwen3.8-27B-NVFP4` on vLLM at clusterSize 1, and the board carries
about nine clusterSize-1 vLLM entries under the `Qwen3.8-27B-NVFP4` display
name. Same architecture, same runtime family, same box class.

The one caveat is the checkpoint behind that display name. `modelName` is a
display string, not an HF repo: the leaders' recipes name
`RadixArk/Qwen3.8-27B-NVFP4`, whose `lm_head` is FP4 at 0.67 GiB against our
FP8 1.185 GiB. That is a 7% difference in the speculative cycle before any flag
is set, and it is held by the checkpoint. Which repo each cs=1 vLLM entry
actually serves is being read from the embedded `benchmarkData` rather than
assumed — see the entry table below.

## The field

25 distinct submissions from 15 user ids, 2026-08-14 to 2026-08-28, in three
board spellings — `Qwen3.8-27B-NVFP4` (21), `-FP8` (3),
`-NVFP4-BF16-LMHead` (1). This is a contested cell, not an empty one.

**Every leader is SGLang with the DFlash2 block-diffusion drafter**, cs=1 and
cs=2 alike, serving `RadixArk/Qwen3.8-27B-NVFP4` at rev `52d1adc5f38aa5eb`. That
drafter is the one mechanism separating this model's top from its bulk, and it
is not a vLLM path. vLLM entries top out lower everywhere except the deep c10
cells — where every SGLang single-box entry collapses and the vLLM ones do not.

The board's `quantization` column disagrees with the model name on several rows
(`Qwen3.8-27B-NVFP4` tagged `FP8`). It is filled from the KV/activation dtype,
not the weights. Do not read it as weights.

## Best cs=1 entry per cell — the numbers we are judged against

`tg` only. Our runs are cold-cache, so our `pp` and `ttfr` read ~4x low and are
comparable to nothing here.

| cell | runtime | quant | tg128 | rank-all | benchmarkId |
|---|---|---|---:|---:|---|
| tg128 c1 | vLLM | NVFP4 | 37.51 | 141 | sub1787467674993 |
| tg128 c2 | vLLM | NVFP4 | 59.21 | 131 | sub1787208001459 |
| tg128 c5 | SGLang | FP8 | 91.16 | 117 | sub1787625705494 |
| tg128 c10 | SGLang | FP8 | 116.88 | 107 | sub1787625705494 |
| d4096 c1 | vLLM | NVFP4 | 30.30 | 164 | sub1787208001459 |
| d4096 c10 | vLLM | NVFP4 | 78.76 | 124 | sub1786821875313 |
| d8192 c5 | vLLM | NVFP4 | 78.11 | 100 | sub1786821875313 |
| d8192 c10 | vLLM | NVFP4 | 71.55 | 118 | sub1786754097881 |
| **d16384 c1** | vLLM | NVFP4 | **29.15** | 153 | sub1787208001459 |
| d16384 c2 | SGLang | FP8 | 42.69 | 147 | sub1787625705494 |
| d16384 c5 | vLLM | NVFP4 | 51.87 | 136 | sub1786821875313 |
| **d16384 c10** | vLLM | NVFP4 | **63.05** | 103 | sub1786821875313 |
| d32768 c1 | SGLang | FP8 | 28.31 | 145 | sub1787625705494 |
| d32768 c10 | vLLM | NVFP4 | 63.05 | 79 | sub1786754097881 |
| d65535 c10 | vLLM | NVFP4 | 49.10 | 74 | sub1786754097881 |
| d100000 c10 | vLLM | NVFP4 | 39.58 | 63 | sub1786754097881 |

The whole cs=1 field sits between rank 63 and 172. Nobody has won this model.

## The single-box SGLang reference, and where it breaks

    https://spark-arena.com/benchmark/sub1787625705494
    https://spark-arena.com/api/benchmarks/sub1787625705494/raw
    SGLang, cs=1, RadixArk NVFP4 + incoai DFlash2 drafter, @Ege

Its own raw table, `tg128` mean ± sd:

    cell        c1              c2              c5              c10
    d0     28.43 ± 1.97    52.61 ± 5.72    91.16 ± 6.58   116.88 ± 0.78
    d4096  25.64 ± 0.83    46.50 ± 2.56    49.91 ± 3.06    53.87 ± 1.07
    d8192  27.87 ± 2.03    44.16 ± 3.81    74.41 ± 18.15   65.91 ± 6.27
    d16384 26.80 ± 2.24    42.69 ± 1.72    42.71 ± 7.11    45.09 ± 8.11
    d32768 28.31 ± 4.12    43.74 ± 5.87    37.85 ± 4.82    17.07 ± 2.14
    d65535 22.61 ± 2.23    38.30 ± 3.66    17.70 ± 0.33     2.86 ± 0.16
    d100k  19.99 ± 0.78    38.77 ± 1.63    37.50 ± 7.48     1.55 ± 0.00

Note what the deep c10 column does. 45.09 at d16384, 17.07 at d32768, 2.86 at
d65535, 1.55 at d100000 — a collapse, not a decline. Its `max_running_requests`
is 12 and `max_mamba_cache_size` is 64, so the GDN recurrent state and the
mamba radix cache are the suspects, not KV. The cs=2 DFlash2 entries collapse
the same way (3.70 at d100000 c10). **The vLLM cs=1 entries do not** — 49.10 at
d65535 c10 and 39.58 at d100000 c10, from `sub1786754097881`.

## The cs=2 leaders, for context only

We run one node, so these are out of our peer set. They are here because they
set the model's board ceiling.

    https://spark-arena.com/benchmark/sub1787730993310    153.30 c5, r46
    https://spark-arena.com/benchmark/sub1787656709068    same figures, same user
    https://spark-arena.com/benchmark/sub1787545115725    145.29 c5, r55
    https://spark-arena.com/benchmark/sub1787257846901    135.00 d8192 c10, r37

All SGLang TP=2 over CX-7, `RadixArk/Qwen3.8-27B-NVFP4` + `z-lab` DFlash2,
`--speculative-algorithm DFLASH --speculative-num-draft-tokens 8`,
`mem-fraction-static 0.5`, `max-running-requests 8`, `cuda-graph-max-bs 8`,
`kv-cache-dtype fp8_e4m3`, `mamba-radix-cache-strategy extra_buffer`.

Their scatter is wide: `sub1787730993310` reads sd 33.37 on a 127.71 mean at
d8192 c5. Margins under ~25% in that cell are inside their own noise.

## What nobody on this board appears to have moved

Every published recipe caps concurrency low — SGLang `max_running_requests` 8
and 12, `cuda_graph_max_bs` 8, `torch_compile_max_bs` 4 and 10. No vLLM entry
publishes a `--max-num-seqs` above the default 4.

That is the lever with a 2.89x behind it in this tree, measured at exactly the
`tg128 @ d16384 c10` cell on Qwen3.6-35B-A3B-NVFP4 (49.0 to 141.5,
`bench_95fdfa8922a3`, 2026-08-24, reproduced four days later and submitted).
Whether it transfers is not settled: on LFM2.5-350M `max_num_seqs` 16 beat 10
by 15% at c10 even with only 9 requests ever running, while on the MoE 10 was
the smallest sufficient value. **The two models in this tree gave opposite
answers above the offered concurrency, so this must be measured here, not
assumed.**
