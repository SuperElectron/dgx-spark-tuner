# h1 — baseline sweep against the eight like-for-like board entries

## Verdict

LEVER SPENT — 11.22 t/s median at `tg128 @ d16384 c10`, against a floor of 55.0.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | none — baseline recipe unchanged | baseline | d16384 c10 | 142.84 | 11.22 | 108120.9 | bench_3691c02e8f1d |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Our untuned recipe over the board's 28-cell grid reads **≥ 55.0 t/s at
`tg128 @ d16384 c10`** — within 15% of the best like-for-like entry's 63.05.

Mechanism: `sub1786821875313` scores 63.05 at that cell on our checkpoint, our
runtime, MTP k=3, `kv fp8`, `flashinfer`, `instanttensor`, gmu 0.8 and no
`max_num_seqs`. We match all of it and differ in three fields only —
`max_model_len` 262144 vs 131072, `max_num_batched_tokens` 16384 vs 32768, and
its `VLLM_MARLIN_USE_ATOMIC_ADD=1`. The claim is that those three are worth
less than 15% here.

Worth, if right: 28 board-comparable cells and our own per-cell scatter, for one
grid's box time. If wrong, h1 has located a large lever by exclusion.

## Method

**Variables to test: none.** This round moves no field. The three candidates
above are named so h1 is not tempted to test them — it measures, it does not
tune.

Constant: everything in `recipe.yaml`. `max_num_seqs` stays unset, as the two
fastest like-for-like entries leave it.

Grid: depth [0, 4096, 8192, 16384, 32768, 65535, 100000] x concurrency
[1, 2, 5, 10], pp 2048, tg 128, runs 3, as one `schedule:` against one server.

Recorded, not scored: the engine's resolved `max_num_seqs` and
`cudagraph_capture_sizes`; `SpecDecoding` acceptance lines (the only number that
would explain MTP buying 1.44-1.65x here against the MoE's much larger gain);
`ttfr` per cell; peak host memory and swap; short-return counts if sampling
cannot be pinned.

## Decision rule

Read on the **median** at `tg128 @ d16384 c10`, never the mean `run.py` prints.

- **Target met** — ≥ 72.5 t/s. The Objective falls out of the baseline.
- **Lever alive** — 55.0 to 72.5 t/s. Inside the like-for-like band; h2 opens on
  the three recipe deltas.
- **Lever spent** — under 55.0 t/s. More than 15% below a twin we match in every
  field but three, so one of those three, or something unrecorded, dominates;
  h2 locates it by exclusion instead.

Sizing: 15% is the imported `d16384 c1` band from `Qwen3.6-35B-A3B-NVFP4`, used
because our own c10 scatter does not exist until this round. The board's c10
entries are far tighter (±0.55, ±0.49 on 61-63), so it is expected to be
conservative. If our measured band comes in under 5%, say so at conclusion and
re-size later rounds — do not edit this rule.

## Conclusion

LEVER SPENT. The median at `tg128 @ d16384 c10` is **11.22 t/s**, under the
rule's 55.0 floor by a factor of five and 5.6x below the twin's 63.05. No field
varied — this round measured the baseline over 28 cells against one server.

The rule resolved cleanly and was the right rule. `d16384 c1` reads 16.96,
inside the board's like-for-like MTP band of 16.13-18.52, so the recipe is sound
and only concurrency collapses: c1 is flat with depth while c10 falls
monotonically 74.94 / 57.45 / 23.45 / 11.22 / 5.15 / 2.22 / 1.30.

Why: the engine held max running 10 / max waiting 9 with `max_num_seqs`
resolved to 256, so seats were never the constraint and
`max_num_batched_tokens` 16384 was — one request's prefill at this cell is
depth+pp = 18432, so not even a single request fits the budget.

The grid was interrupted after `d16384 c10` and resumed against the same server
boot; the objective cell ran mid-first-leg, so the resume does not qualify it.

Scatter, as the rule asked: our c10 band is 0.9% of median, not the imported
15% — re-size later rounds on ours. c1 is much looser at 14%.
