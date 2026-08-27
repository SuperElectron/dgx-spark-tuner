# h2 — four slots serve ten requests, and the c10 aggregate pays for the queue

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**TARGET MET** on the screen, which the screen cannot close — `max_num_seqs`
4 → 10 takes `d16384 c10` from 49.0 to 137.5, clearing 102.31 by 34%; the
round's own outcome token is `target-met-pending-validation`.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | baseline, `max_num_seqs` 4 | the control, on this round's schedule and session; pp t/s, tg t/s, ttfr ms | d16384 c10, guard d16384 c1 | 583.9 | 49.0 ±0.2% | 21430 | bench_270c9926d658 |
| run-0002 | `max_num_seqs` 4 → 10 | the queue disappears at exactly the primary cell's concurrency; pp t/s, tg t/s, ttfr ms | d16384 c10, guard d16384 c1 | 577.6 | **137.5 ±1.8%** | 8127 | bench_8ced4b0ea3c2 |
| run-0003 | `max_num_seqs` 4 → 16 | separates "the queue was the cost" from "more slots always help"; pp t/s, tg t/s, ttfr ms | d16384 c10, guard d16384 c1 | 668.6 | **139.8 ±0.4%** | 29047 | bench_4363a52d9d21 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Raising `max_num_seqs` from 4 to 10 raises `tg` at `d16384 c10` above h1's
control of 49.0, and does not lower `tg` at `d16384 c1`. Mechanism: admission,
not batching efficiency. h1 measured `running max 4` — pinned at the field —
with `waiting max 6`, at a cell that presents ten requests, and llama-benchy's
aggregate divides generated tokens by a wall-clock window that counts a queued
request's waiting. Four slots serve ten in roughly three waves, and two waves of
waiting dilute the mean.

Worth, if right: the Objective needs 49.0 to clear 102.31, a 2.1x, and h1's
control put the mean-to-peak gap at this cell at 6.4x. Recovering a third of it
clears the target, and no other open field has arithmetic that size.

## Method

### Variables to test

    max_num_seqs: 4 (control) -> 10 -> 16

Order: 4 first, as the control on this round's own schedule; then 10, the
primary cell's own concurrency, where the queue disappears; then 16 to separate
"the queue was the cost" from "more slots always help".

### Constant for this round

Everything else in `recipe.yaml`, byte for byte, and in particular
**`max_num_batched_tokens` stays at 65536** — h1 measured it as the best of
three values at this cell, and moving two scheduler fields at once confounds
both. `max_model_len 262144`, `gpu_memory_utilization 0.8`, `kv-cache-dtype
fp8`, MTP depth 3 on triton, the same serve command and the checkpoint's own
sampling. Acceptance, prefix cache and KV capacity are ruled out in advance and
captured only as controls.

Grid, from the recipe's `benchmark:` block — the same reduced schedule h1 ran,
in the same order, and **not board-comparable**:

    pp 2048 · tg 128 · depth 16384 · concurrency 1, 10, 5, 2 · runs 7/3/3/3

## Decision rule

Read `d16384 c10` and `d16384 c1`, aggregate `tg` medians, from each arm,
against **this round's own control arm** — not against h5's cross-schedule
figures.

- **Target met** — c10 exceeds 102.31 *and* c1 holds at or above 0.959 × the
  control's c1. Then go straight to one full 28-cell arena-v2 run of that arm's
  recipe, which is the only thing that can close the Objective.
- **Lever alive** — c10 rises more than 5% over the control and c1 holds at or
  above 0.959 × the control's c1, but c10 is still below 102.31. Add arms to this
  round: the slot count has more to give and its best value carries forward.
- **Lever spent** — c10 moves less than 5% either way, or it rises while c1 falls
  below 0.959 × the control's c1. In the second case admission is a genuine trade
  against single-stream rather than a free win, the guard governs, and
  `max_num_seqs 4` stands.

Sized against h1's scatter on this exact schedule, ±0.3-0.6% at c10 and
±2.9-4.1% at c1, the c1 floor one scatter width below the control. The rule
reads **aggregate** `tg`, what the board scores; `tg/req` spans 11.8x inside one
c10 cell and no branch may be read on it. Three values per arm means no iqr,
hence medians and a 5% threshold.

## Conclusion

**Target met on the screen, and the screen cannot close it. Outcome:
`target-met-pending-validation`.** `max_num_seqs` 4 → 10 → 16 took `d16384 c10`
49.0 → 137.5 → 139.8 and c5 84.2 → 171.5, clearing 102.31 by 34%; `running max`
went 4 → 10 and `waiting max` 6 → 4, the mechanism check, passed first.

Four caveats, without which this misleads. These are **screen figures**, not
board-comparable, and Held forbids setting them beside 102.31 — 137.5 is a
candidate, not the number. **c1 is unresolvable** on this protocol at better
than ±11%, so the rule's 0.959 floor is mis-specified rather than failed, and is
left as written. The round **bought throughput partly with latency**, c10 ttft
median 19.12 → 28.08 s. And **10 is the smallest sufficient value**; 16 is inert,
the grid never offering an eleventh request. The round's reasoning is in the
memory store — every record carries `concurrency/h2` in its `basis`.
