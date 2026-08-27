# h3 — is `tg128` measuring a transient?

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**LEVER SPENT** — transient bounded: `tg` 127.3 at tg128 against 120.6 at
tg2048, but throughput inside a single generation is flat, so `tg128` is not
measuring a warm-up transient.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | `tg: 128` | the short cell at d0 — the baseline this round needs; runs 7, iqr 3.0%, trace varied, no repetition | pp128 d0 c1 | | 127.3 | | bench (see id.txt) |
| run-0002 | `tg: 2048` | 16x longer: is steady state different? runs 7, iqr 2.4%, trace 4 of 7 degenerate | pp128 d0 c1 | | 120.6 | | bench_02f9548d80da |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

`tg 128` is too short to reach steady-state decode, so the figure the board
scores and every round here optimises is partly a warm-up artifact: steady-state
`tg` at the same cell differs from `tg128` by more than the spread. Mechanism:
MTP acceptance is a running statistic — 0.87 / 0.76 / 0.61 per position, mean
accepted length near 3 — and 128 tokens is only ~41 speculative cycles, so the
first cycles need not average to the long-run rate. A duller mechanism points
the same way: fixed per-request costs are amortised over 128 tokens here and
over 2048 in the arm.

Worth, if right: it does not make us faster, it tells us what we have been
measuring. Memory makes it directional — `tg32` reads faster than `tg128` at
d16384 on this model — so the prediction is that `tg2048` reads BELOW `tg128`.

## Method

### Variables to test

    tg: 128, 2048, 8192      at pp 128, depth 0, concurrency 1

Order: the short cell first, then 16x longer, then 8192 as corroboration.
`depth 0` is on purpose — it removes the KV term, the context-load phase and the
prefill numerator artifact, so `tg` is the only thing varying; `pp 128` keeps
prefill small enough that it cannot dominate the run.

### Constant for this round

Everything in Held, and the full measurement protocol: `exact_tg`,
`extra_body temperature=0`, `no_adapt_prompt`, the per-cell fixed corpus,
`post_run_cmd` resetting between runs. The instrument for this round is not the
summary figure: `run.py` now saves the throughput timeseries, and **the shape of
the first ~2 seconds against the remainder is the answer** — a saw-toothed trace
is acceptance, a flat one is rejection. The generated text is inspected too,
because `ignore_eos` at `temperature 0` invites degeneration, and repetitive
text is easy to draft.

Grid, from the recipe's `benchmark:` block:

    pp 128 · tg 128, 2048 · depth 0 · concurrency 1 · runs 7 (3 at tg8192)

## Decision rule

Stated on the difference between the short cell and the long one, against the
spread of the two, and evaluated on medians.

- **Transient confirmed** if `tg2048`'s median differs from `tg128`'s by more
  than the larger of the two IQRs, and `tg8192` lies on the same side. Then
  `tg128` is a burst measurement, the direction of the bias is recorded, and
  every figure in this experiment carries that caveat from here on.
- **Transient bounded** if the difference is smaller than that. `tg128` is a
  fair proxy for steady state at this cell, the board comparison is not
  measuring warm-up, and this question is closed.
- **Neither** if `tg2048` and `tg8192` disagree in direction. Then generation
  length is not the variable — check the timeseries for a drift that reverses,
  and check whether KV growth during a 8192-token generation is doing it.

Independently of the medians, record what the timeseries shows: whether
throughput within a single 2048-token generation is flat, rising or falling, and
where it settles. A flat trace with a different median would mean the difference
is a fixed per-request cost rather than a transient.

## Conclusion

**Refuted as stated, and the observable it predicted is real for another
reason.** `tg` does change with generation length and past the rule's threshold
— 127.3 at tg128 against 120.6 at tg2048, a gap of 6.7 against a larger IQR of
3.8. But the timeseries refutes the mechanism: recomputed from raw token
timestamps in one-second bins, throughput inside a single 2048-token generation
is flat, no trend and no saw-tooth. There is no warm-up transient to find.

What is left is arithmetic. A 2048-token generation carries its own output as
context, so its average is taken at a larger average context than a 128-token
one — **the same mechanism as depth, sourced from the model's own output**, so
h3 and depth-curve measure one effect, not two. Three caveats: degeneration
*inflates* `tg`, so the honest tg2048 is lower still; run-0003 was abandoned
because at 8192 the run would measure looping; and `exact_tg` did not hold.
The round's reasoning is in the memory store — every record carries
`decode-tg/h3` in its `basis`.
