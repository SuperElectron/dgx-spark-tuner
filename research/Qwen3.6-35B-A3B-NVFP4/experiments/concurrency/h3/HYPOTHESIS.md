# h3 — validation: `max_num_seqs 10` on arena's own unmodified 28-cell grid

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**TARGET MET, guard unresolved** — `d16384 c10` reads 141.5 against the
Objective's floor of 102.31, +38%, and 2.89x our own incumbent 48.9; the guard
`d16384 c1` reads 95.8, inside the pre-registered ±11% band.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | `recipe-new.yaml`: `max_num_seqs` 10, full 28-cell arena-v2 schedule | the only measurement that can close the Objective | d16384 c10 | 677.9 | **141.5** ±0.2% (141.5 140.8 141.7) | 28636.2 | bench_95fdfa8922a3 |
| run-0001 | `recipe-new.yaml`: `max_num_seqs` 10, full 28-cell arena-v2 schedule | the guard cell of the same run | d16384 c1 | 628.0 | **95.8** ±15.0% (95.8 124.2 86.1) | 3281.9 | bench_95fdfa8922a3 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

`recipe-new.yaml` — `max_num_seqs: 10`, every other field identical to
`recipe.yaml` — run once on the unmodified 28-cell arena-v2 schedule, reads `tg`
at `d16384 c10` above 102.31, and reads `d16384 c1` no lower than 103.7.

This is not a new mechanism. h2 established it on a four-cell screen: four slots
admit four of ten offered requests, the other six wait, and llama-benchy's
aggregate counts their waiting in its denominator. What this round adds is the
only thing h2 could not buy, a **board-comparable figure** — Held requires
arena's own order, because cell order decides what is warm and what is hot.

Worth, if right: it closes the Objective. h2 cleared the primary by 34% at a
cell reproducing to 0.2%, so a warm-grid figure would have to fall by a quarter
to miss; if it does, arena's ordering costs a quarter of this cell's throughput,
which is worth as much as the win and is not knowable any other way.

## Method

### Variables to test

    nothing — this is a validation run, not a sweep

    max_num_seqs: 10   (fixed, from h2 run-0002)

Order is arena's, not ours, and is not touched.

### Constant for this round

Everything. `recipe-new.yaml` differs from `recipe.yaml` in exactly one field
(`max_num_seqs` 4 → 10) and from h5 run-0001's recipe in the same one, which is
what makes h5's grid run the incumbent. `max_num_batched_tokens 65536`,
`max_model_len 262144`, `gpu_memory_utilization 0.8`, `kv-cache-dtype fp8`, MTP
depth 3 on triton, the same serve command, the checkpoint's own sampling. The
schedule block is copied byte for byte from the arena-v2 grid and no cell, order
or `runs` value is changed. Prefix cache, acceptance and more slots than 10 are
ruled out in advance and captured only as controls.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0/4096/8192/16384/32768/65535/100000 ·
    concurrency 1, 2, 5, 10 · runs 3 · 28 cells in arena's order

## Decision rule

Read aggregate `tg` medians at `d16384 c10` and `d16384 c1` from this run's
`results.yaml`, against the board's published figures as floors.

- **Target met** — `d16384 c10` above 102.31 **and** `d16384 c1` at or above
  103.7. The Objective closes, `recipe-new.yaml` is that run's recipe, and the
  experiment writes its Conclusion.
- **Target met, guard unresolved** — `d16384 c10` above 102.31 and `d16384 c1`
  within ±11% of 103.7. The primary closes and the guard is recorded as
  unresolvable on the board's own protocol, with the h2 evidence for why: at
  `runs: 3` and an unpinned prompt this cell cannot resolve a change of the size
  the guard was written to catch. This branch is written before the number
  exists because h2 makes it the most likely one.
- **Lever alive** — `d16384 c10` rises materially over h5's incumbent 48.9 but
  lands below 102.31. Then arena's ordering costs part of the screen's gain, the
  size of that cost is the finding, and the round adds arms.
- **Lever spent** — `d16384 c10` lands at or below 102.31 with no route left in
  the slot count, **or** it clears 102.31 while `d16384 c1` falls more than 11%
  below 103.7. In the second case the trade against single-stream is larger than
  the instrument's own noise and is therefore real, the guard governs,
  `max_num_seqs 4` stands, and `recipe-new.yaml` is withdrawn.

Sized against Strategy's scatter for this grid, `d16384 c10` ±0.5% and `d16384
c1` ±5.2% at `runs: 3`. The c1 branches are stated as floors and an 11% band for
the reason h2 recorded, written here before the run. One run means one value per
cell and no iqr at all; every branch reads a single median against a fixed
external number, which is the only rule a validation run can support.

## Conclusion

**Target met, guard unresolved**, the pre-registered branch: `d16384 c10` 141.5
±0.2%, +38% over 102.31 and 2.89x our incumbent 48.9; guard `d16384 c1` 95.8.

**The 2.89x is over our own incumbent, not a board result:** the 2026-08-26
board read puts the #10 cutoff at 236.97 — a same-model same-quant vLLM entry
sits there — voiding the earlier +38.3% margin. The guard's **±15.0% span**
(95.8/124.2/86.1) exceeds its own ±11% band. Every figure is **cold-cache**,
0.0% over 527 samples; *corrected 2026-08-27: the seventh confirmation, not the
eighth — count samples, not runs, and never add it to the `request_end`
double-flush count.* `06-d100000c2` is **SUSPECT**, 13 ends against 12
first-tokens; *corrected 2026-08-27: a double-flush, not h1 run-0003's damage —
full `total_tokens` means the former, short the latter.* Reasoning is in the
store — every record carries `concurrency/h3` in its `basis`.
