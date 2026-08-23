# kv-cache-dtype — is fp8 KV costing decode throughput at c1?

## Claim

Moving `--kv-cache-dtype` off `fp8` raises `tg` at `tg128 @ d16384 c1`.

The reason to expect it is a measurement nobody chased: R24 arm 2 changed
exactly this field, `fp8 → auto`, and `tg` went 169.89 → 179.15 (+5.5%) at c4.
That round was investigating why the prefix cache never fires, concluded on the
cache, and never returned to the throughput number.

The reason to doubt it is arithmetic, and it points the other way. Decode at
depth is memory-bandwidth-bound. At d16384 the KV read per step is roughly
0.6 GB at fp8 and 1.2 GB at bf16; against GB10's bandwidth that is about 2.3 ms
against 4.6 ms of a ~10 ms step. On bytes alone `auto` should *lose* by a wide
margin.

So this measures which effect dominates: the bytes fp8 saves, or the
dequantisation it adds on every access.

## Method

### Variables to test

    kv_cache_dtype: fp8, auto

Order: `fp8` first as the control — it is the shipped value, and its figure at
this cell must be re-established on this epoch rather than read from R25.
Then `auto`.

`fp8_e5m2` is held in reserve: run it only if `fp8` and `auto` separate, to say
whether the effect is fp8 as such or this particular exponent split.

### Held

The probe grid, the container image, the box, and every other recipe field —
`max_num_batched_tokens 65536`, `max_num_seqs 4`, `max_model_len 32768`,
`gpu_memory_utilization 0.8`, `--moe-backend marlin`,
`--attention-backend flashinfer`, `num_speculative_tokens 3`, prefix caching on.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

`runs: 7`, not the model baseline's 3. R25 measured σ/median of 7.64% at this
exact cell, and the effect under test is +5.5% — smaller than the noise. Three
runs cannot separate them.

`concurrency: 1` only. R10 established that at c>1 the reported `tg` is a batch
aggregate, not a per-request rate, so c1 and c10 are different metrics and
mixing them in one hypothesis muddles the rule.

## Decision rule

Stated as non-overlap rather than a percentage, because the expected effect is
smaller than the within-run spread and a bare ±% threshold would not be
evaluable at n=7.

- The claim survives if the `auto` run's seven `tg` values and the `fp8` run's
  seven `tg` values do not overlap — `min(auto) > max(fp8)` — and `auto`'s
  median is the higher of the two.
- The claim fails if the two ranges overlap at all, or if `auto`'s median is
  lower.

An overlap is a real answer: it says the R24 reading was inside the noise and
this lever is not worth carrying. It is not an indeterminate result.

## Runs

One row per run, appended when the run returns.

- **changed** — this run's recipe against `recipe.yaml`, as `field: old → new`;
  comma-separated when a run moves more than one.
- **why** — the prior result that prompted it. `baseline` for the first run.
- **figures** — from the run's `out/results.yaml`.

| run | changed | why | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|--------|--------|---------|-------|

A crashed run keeps its row: `—` for the figures, the failure in **why**.

## Conclusion

Pending — written once every run is in, against the decision rule as written.
If the rule was wrong, say so here; do not edit it.

## Memory

One line, written with `remember.sh` when the conclusion is. Recall prints the
line and nothing else, so anything not in it cannot be weighed later.

    [OBSERVATION] <date> <hypothesis>: <what varied> over <values> — <what held or did not>, <evidence>

    [OBSERVATION] 2026-08-22 test-runtime: max_num_seqs 4→64 at d0 c1 — tg flat within ±3% across all five, so single-stream decode does not use the extra slots (runs=5, bench_2ebcb63db398..bench_9f1)

Entity: the widest scope it is actually true for — `experiment:<name>`,
`model:<hf-id>`, `family:<name>`, `stack:<runtime>`, `box:<alias>`,
`flag:<vllm-flag>`.
