# h1 — measure the tg32/pp4096 grid; no field moves

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

**TARGET MET** — 16 of 16 scorable `tg32` points rank **1** board-wide, not
merely ≤3; narrowest margin 122.76 vs 24.99 at `d16384 c10`.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | none — the slots winner unchanged; only the measured grid differs | coverage round: the official arena profile measures only tg128 and pp2048, leaving 27 tg32 cells at a field of 1 and 9 pp4096 cells at a field of 2 | d16384 c10 | 15308.41 | 125.60 | 1615.68 | bench_88df45c73f9b |
| run-0002 | none — same recipe; grid supplied by --profile profiles/arena-tg32-pp4096.yaml instead of the recipe's inline benchmark block | run-0001 archived profile: null — it ran the inline block, so its figures carry no profile provenance; re-run under the profile to produce a submittable, correctly-stamped grid | d16384 c10 | 15273.22 | 122.76 | 1622.05 | bench_18c53808be50 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

**The `slots` winner, run unchanged over `profiles/arena-tg32-pp4096.yaml`,
produces a `tg32` figure that would rank ≤3 board-wide at every one of the 16
scorable grid points.** No recipe field moves; depth and concurrency are cells,
not levers.

The mechanism is the board's coverage, not the machine's. The official
`@official/spark-arena-v2` profile measures `tg128` and `pp2048`, so `tg32` is
populated only by whoever went looking — 27 of its 28 cells held exactly one
entry on 2026-08-30. A cell with a field of one cannot rank a valid third
figure below 2.

Worth, if right: **16 top-3 placements from one grid**, at zero tuning cost, on
a config already validated and already published. The arithmetic is field size,
not speed: 15 of the 16 are decided by counting alone. The sixteenth,
`tg32 (c1) @ d0`, has a rank-3 bar of **50.09**; our `tg128 (c10)` reads
2044.66 on the board and 2197.7 locally, and c1 applies no division across
streams — a margin of roughly 4x at the one cell anybody contests.

The falsifier is not "someone beat us". It is a grid point that produces no
figure, or one that collapses — depth against `max_num_batched_tokens 8192`, or
early-EOS short returns eating the token count.

## Method

### Variables to test

    depth:       0, 4096, 8192, 16384
    concurrency: 1, 2, 4, 5, 10

Order: the profile's `schedule:` block — depth-major (8192, 4096, 16384, 0),
each depth sweeping concurrency 5, 2, 10, 1, 4. Held by `EXPERIMENT.md`.

### Constant for this round

Every field of `recipe.yaml`, unchanged from `slots/recipe-new.yaml`:
`max_num_seqs 16`, `mnbt 8192`, `max_model_len 32768`, `gpu_mem_util 0.8`,
`--quantization fp8`, `--kv-cache-dtype fp8`, `--attention-backend FLASHINFER`.

Grid, from `profiles/arena-tg32-pp4096.yaml`:

    pp 4096 · tg 32 · depth 0/4096/8192/16384 · concurrency 1/2/4/5/10 · runs 3

`runs 3` is a coverage grid, not a discriminating one, on a model whose
scatter runs 7-15% (`cadfb796`) — correct here, because the margins read are
4x and ~50x. Screened **without `--arena`**; nothing is submitted. Read the
short-return distribution in `progress.jsonl` before trusting a depth figure
(`b540500c`).

## Decision rule

Frozen before any figure exists. Scored on `tg32`, one figure per grid point,
against a live board read taken within 24 hours of the run. The four c4 points
are **not scorable** — the board has no `tg32` cell at c4 — so the denominator
is the 16 points at c1/c2/c5/c10.

- **Target met** — **16 of 16** scorable points rank ≤3. The Objective, and
  the expected outcome: fifteen are decided by field size.
- **Lever alive** — **8-15 of 16**. Coverage holds, but some region produced no
  competitive figure. Next action is to name that region and re-measure it,
  not to tune.
- **Lever spent** — **≤7 of 16**. The 2026-08-30 near-vacancy is not what a
  submitted grid competes against and the coverage premise is wrong. Close as
  measurement-only and record what the sweep misread.

No branch turns on a difference smaller than the cell spread; the rule counts
placements decided by 4x-50x ratios. At `runs 3` there is no interquartile
range, so no rule stated on spread could be evaluated here — this one is
stated on placement instead, deliberately.

## Conclusion

TARGET MET. Two 20/20 runs of the unchanged `slots` winner over the grid —
`bench_88df45c73f9b`, and `bench_18c53808be50` under `--profile` — agree at the
rule's cell to 2.3% (125.60 / 122.76). Against a live board read of 2026-08-31
01:56 UTC our `tg32` ranks **1** in every existing cell, by +234% to +1562%;
narrowest `d16384 c10`, 122.76 against 24.99. The 6 existing `pp4096` cells
also rank 1, by +697% to +5529%.

**The denominator.** The Objective said "16 of 20 grid points"; the live read
found only **16 `tg32` cells exist** — the whole `c4` column absent at every
depth, `Leaderboard test not found` on two fetches. The rule as frozen already
anticipated this and named the denominator 16, so it resolved directly, 16 of
16; the wrong count was the Objective's "of 20". Both readings give the same
verdict, no branch turned on it, and nothing is edited to fix it.

Falsifier never fired — no grid point failed or collapsed. Only the cell varied;
no recipe field moved. `run-0002` was submitted as `sub1788141670208`.

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here.
