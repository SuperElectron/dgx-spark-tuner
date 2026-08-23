# How the instrument works, and where it lies

Read 2026-08-23 from llama-benchy 0.4.0 and sparkrun source, plus our own
run-0008 archive. Everything here is about the measuring apparatus, not the
model.

## The two phases, and the 9x that is not real

With `prefix_caching` on and `depth > 0`, llama-benchy splits each execution:

    phase 1  "Context Load"   system = <depth tokens>, user = "."
    phase 2  "Inference"      the SAME context + a real pp-token user message

Phase 1 is credited `depth` tokens. Phase 2 is credited **`pp` only** — 2048 —
while being timed over the whole prefill, which is `depth + pp`. From run-0008:

    phase          served    est_ppt    credited    reported
    1 (ctx)        16400    2779.7 ms     16384      5900.5
    2 (cell)       18446    3242.4 ms      2048       631.7

    5900.5 / 631.7 = (16384/2048) x (3242.4/2779.7) = 8.00 x 1.166 = 9.34

Both phases prefill at ~5700-5900 t/s. **`pp2048 @ d16384 = 631.7` is 2048
divided by the time to prefill 18446 tokens.** It is a sound monotone proxy at
fixed `(pp, depth)` — so comparisons between runs at the same cell are valid —
and a meaningless rate anywhere else. `run.py` now prints the true rate beside
it as `prefill*`.

`results.py` rejects the server's own count when it disagrees with expectation
by more than 20%, which is why 18446 is discarded in favour of 2048.

## The prefix cache does not hit

`Prefix cache hit rate: 0.0%` on every logger interval of every run so far,
including within a single execution where phase 2 should reuse phase 1's
16400-token context. Phase 2 recomputes in full.

The reset (`post_run_cmd`) is **not** the cause: it fires after each execution,
one per 8.2 s, after both phases. Chased in `decode-tg/h2`.

## Flags we do not use, and what they buy

    --save-total-throughput-timeseries   free; the 1s sliding window already
    --save-all-throughput-timeseries     runs, these only retain the series.
                                         With return_token_ids on, an accepted
                                         speculative step lands several token
                                         timestamps in one chunk — the series
                                         IS MTP acceptance. Now injected.
    --exit-on-first-fail                 unattended runs should fail loudly
    --no-cache                           appends a uuid to the PROMPT only,
                                         leaving context untouched — does not
                                         defeat a prefix cache at depth>0
    --latency-mode {api,generation,none} MEASUREMENT-DEFINITION knob. est_ppt =
                                         ttfr - latency. Changing it silently
                                         rebases the whole pp column. Keep "api"
    --skip-coherence                     do NOT set. The default gate asks the
                                         capital of France and aborts on a wrong
                                         answer — a free per-run check that the
                                         weights still produce sense, which is
                                         exactly what quantization breaks
    --tokenizer                          corpus.py silently falls back to gpt2
                                         if the tokenizer fails to load, making
                                         every token count wrong

Not present at all: no seed, no request-rate/Poisson arrival, no ramp, no
TPOT/ITL percentiles, no per-token latency distribution.

`adapt_prompt` defaults **on** and rewrites the grid at warmup
(`current_depth = depth - delta_context`), which reopens the random prompt
offset the fixed corpus exists to close. We pass `no_adapt_prompt: true`.

## sparkrun's plumbing

    _KNOWN_BENCHMARK_KEYS = {framework, args, metadata, timeout, schedule, category}

Those six are swallowed; **every other key in the `benchmark:` block becomes a
framework arg, with no validation**. A typo becomes `--typod-key VALUE` and
llama-benchy's argparse kills the run — loud, which is the good case.

    _LIST_ARGS   pp, tg, depth, concurrency
    _ARG_ALIASES prefix_caching -> enable_prefix_caching   (the only alias)
    _BOOL_ARGS   omits exact_tg — harmless from YAML, where it is already a
                 bool, but a CLI `-b exact_tg=true` would render `--exact-tg true`

sparkrun silently injects `--served-model-name` (without it every request 404s),
and for SGLANG runtimes injects `return_token_ids=false`, which would degrade
token timestamps to interpolation and destroy the MTP-acceptance signal above.

### Capabilities we are not using

- **`schedule:`** — a list of `{depth, concurrency}` entries, each a separate
  llama-benchy invocation against **one already-running server**, and any other
  key in an entry overrides base args for that task. Warmup and the coherence
  check are paid **once per session**, not per cell. Model load is ~150 s and
  dominates per-run cost, so five separate run dirs burn ~12.5 min of loading
  against ~2.5 min as one schedule. The price is the fixed corpus, which pins
  only the largest cell in a grid.
- **`sparkrun tune vllm --mode moe|fp8|all`** — autotunes fused-MoE tile configs
  and FP8 dense GEMMs inside the recipe's container, written where later runs
  pick them up automatically. Recipe-independent, one-time. Largest untried
  lever on the box. ~1.5 h.
- **tool-eval-bench** (`sparkrun benchmark tools <recipe>`) — 69 scenarios plus
  hard mode, tool-call correctness. This is the one quality axis quantization
  actually breaks, it is completely unmeasured by us, and it bears directly on
  the quant-tradeoff milestone.
- **`sparkrun benchmark resume`**, and `export recipe` / `export running-recipe`.

## The cell menu

Hard constraints first:

1. `max_model_len 32768` — with pp 2048 and tg 128, the deepest legal depth is
   **30592**. The arena's d65535 and d100000 cells cannot run without raising
   it, which is a new epoch.
2. `max_num_seqs 4` — c5 and c10 queue rather than batch. Requests are accepted
   and wait; nothing is rejected.
3. The fixed corpus is sized from the largest cell, so **a multi-cell grid pins
   only the deepest rung**. `run.py` now refuses such a grid.

| cell | isolates | sensitive to |
|---|---|---|
| pure decode — pp128 tg512 d0 | weight-read bandwidth alone, no KV | moe-backend, MARLIN_ATOMIC_ADD, spec config, async-scheduling |
| deep decode — our cell | weights + KV + attention | kv-cache-dtype, attention-backend, gpu-memory-utilization |
| prefill-heavy — pp8192+ tg8 d0 | compute-bound GEMM/MoE | max-num-batched-tokens, chunked prefill, moe-backend. Where `tune vllm` would show up |
| depth ladder | the SLOPE of decode vs KV bytes | kv-cache-dtype, attention-backend |
| concurrency ladder | per-request latency vs aggregate throughput | max-num-seqs, and whether MTP still pays |
| long generation — tg2048+ | MTP acceptance drift; tg128 may measure a transient | num_speculative_tokens, draft moe_backend |

Pairing pure decode with our cell gives the KV term by difference — our cell
alone cannot separate a weight-read regression from a KV-read one.

## Cost model, verified to 0.2%

    T_exec  = depth/5900 + tg/114 + (depth+pp)/5690 + tg/120
    T_bench = (runs + 1) x T_exec + 2 s        # the warmup run is EXTRA

Check on run-0008: 8.21 s x 8 + 2 = 67.7 s predicted, 67.64 s observed.

Model load and server ready is **~150 s per run directory**, and dominates.

    pure decode   pp128 tg512 d0      ~32 s bench   ~3.0 min wall
    our cell      pp2048 tg128 d16384  ~68 s        ~3.6 min
    prefill-heavy pp8192 tg8 d0        ~13 s        ~2.7 min
    depth ladder, 5 separate run dirs  ~4.3 min     ~17 min
    depth ladder, one schedule         ~4.3 min     ~6.8 min
    long gen      pp128 tg2048 d0      ~2.1 min     ~4.6 min
    full arena v2 grid                      —       ~3.5-5 h

Fits in an hour as one schedule: pure decode + prefill-heavy + our cell +
tg2048 + a 5-rung depth ladder ≈ 12 min wall — the whole diagnostic picture of
the serving stack for the cost of two current runs.

**The scheduling trade:** use `schedule:` for prefill/pp-side cells, where
throughput is content-insensitive (our ctx_pp spread is ~1%). Use one run per
cell for anything decode-side, where MTP acceptance is content-dependent and
the fixed corpus is the only reason the tg numbers are readable.

## KV capacity — not the constraint

From our own run-0008 log: KV pool 60.21 GiB, `GPU KV cache size: 2,829,675
tokens`, `Maximum concurrency for 32,768 tokens per request: 86.35x`, and one
d16384 sequence occupies **0.8-1.0%** of the pool.

So ~100 concurrent d16384 sequences fit; c10 uses ~10%. **KV is not the binding
constraint anywhere in a 1->10 sweep**, with ~10x margin. Preemption will not
occur, and `Preemptions:` is logged only when nonzero — its absence is the
assertion of zero.

**The 28 GiB anomaly:** the engine reports 49.83 GiB consumed for weights and
non-torch against ~21.8 GiB of checkpoint tensors. `non_torch_memory` is a
residual (`cuda_memory - torch_memory`), and on GB10 the 121 GiB is unified
CPU+GPU, so `mem_get_info`'s "free" reflects system-wide pressure — page cache
from reading a 21.8 GiB checkpoint, fastsafetensors staging, flashinfer
autotune workspaces all land in it. A Spark-specific tax, unverified as to
cause. It costs KV capacity directly: recovering it would take the pool from 60
to ~88 GiB. Two one-boot tests discriminate: drop the OS page cache before
serve, or boot with a different `--moe-backend`, and compare
`Available KV cache memory`.

## Identical prompts at c>1

`generate_batch` calls `generate()` once per slot, and with the corpus pinned
every slot draws offset 0 — so all c prompts are byte-identical.

vLLM's `BlockPool` shares those by refcount, so the depth-scaling KV term is
held **once**, not c times. Mamba recurrent state is not shared that way and is
paid per sequence.

This makes a c>1 run a real, reproducible **shared-prefix best case** — not
fictitious, but not a general concurrency number either, and it must never be
labelled as one. The proof per cell is free: hit rate reads ~100% in that
regime, against 0.0% today.

## Traps to pre-register before a concurrency sweep

- **c=5 is 20 tokens and pads up to the 24 CUDA-graph bucket** — ~20% wasted
  decode slots. Expect c5 slightly below trend. Not a finding.
- **No eager fallback occurs** in any configuration under consideration. At
  `max_num_seqs 4` the batch never exceeds 16 tokens, which is captured. Raising
  `max_num_seqs` rescales the capture list automatically.
- **`max_num_seqs` is not in the torch.compile hash** — raising it costs a ~5 s
  graph recapture, not the 34 s inductor recompile.
- **`num_speculative_tokens_per_batch_size`** exists (a `--speculative-config`
  key, replacing the removed disable-by-batch-size flag) but enabling it
  downgrades `cudagraph_mode` to PIECEWISE globally — a confound larger than
  the effect being measured.
- Gone in 0.27.x, do not write them: `--num-scheduler-steps`,
  `--preemption-mode` (V1 is recompute-only), `--swap-space`,
  `--speculative-disable-by-batch-size`, `--max-num-partial-prefills`.
