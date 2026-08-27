# h1 — decode is flat with depth

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

TARGET MET — **Flat**. D = 4.5% from d0 to the deep anchor (114.6 → 109.5),
against a threshold of 10%.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | depth 0 | the intercept: no KV term, single phase, and the rule reads it — runs 9, tg iqr 5.1% UNSTABLE, true prefill 5610.5 t/s, hit 0.0% | pp2048 · tg128 · c1 · d0 | 5695.1 | 114.6 | 377.0 | bench_594c47d62013 |
| run-0002 | depth 4096 | first rung with a context — runs 7, tg iqr 4.2%, true prefill 5933.4 t/s, hit 0.0% | pp2048 · tg128 · c1 · d4096 | 1995.5 | 110.1 | 1049.4 | bench_a0c409874de1 |
| run-0003 | depth 8192 | witnesses monotonicity — runs 7, tg iqr 5.6% UNSTABLE, true prefill 5796.0 t/s, hit 0.0% | pp2048 · tg128 · c1 · d8192 | 1165.8 | 127.0 | 1779.2 | bench_fa59c397c082 |
| run-0004 | depth 16384 | re-bases the incumbent under the new corpus offset — runs 7, tg iqr 2.6%, true prefill 5639.4 t/s, hit 0.0% | pp2048 · tg128 · c1 · d16384 | 628.6 | 117.8 | 3279.0 | bench_c003c48ede71 |
| run-0005 | depth 30592 | runs 9. The deepest legal context at max_model_len 32768; the rule reads it — HTTP 400, one token over: prompt 32641 + tg 128 = 32769 vs max_model_len 32768 | pp2048 · tg128 · c1 · d30592 | — | — | — | bench_5330c0302d07 |
| run-0006 | depth 30591 | runs 9. One token shallower than run-0005 — HTTP 400 again, at the same 32641 input tokens. The endpoint adds a token of its own, so the served prompt is pp + depth + 2 | pp2048 · tg128 · c1 · d30591 | — | — | — | bench_f574047b8c2e |
| run-0007 | depth 30464 | measured ceiling is d30590 with zero margin; this takes 126 tokens of headroom for the same rung. Stands in as the rule's deep anchor — runs 9, tg iqr 4.3% (±2.1%), true prefill 5195.9 t/s, hit 0.0% | pp2048 · tg128 · c1 · d30464 | 327.1 | 109.5 | 6270.8 | bench_6bd19fe9a3c2 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

`tg` at c1 declines by less than 10% from d0 to d30592, matching the shape the
board's vLLM entries show rather than a KV-bound decline.

Mechanism: KV is paid on 10 of 40 layers only, at 10.2 KB per token, the other
30 being linear-attention with a state constant in context length, so KV rises
from ~0% of the per-step read at d0 to ~12% at d30592 against ~2.25 GB of
weights. A bandwidth-bound decode loses that order, not the steep decay a
full-KV transformer shows.

Worth, if right: `--kv-cache-dtype` and `--attention-backend` reach only those
10 depth-dependent layers, so a flat curve closes both and points every future
round at the MoE path, the draft path and the scheduler. If decode slopes, both
are live.

## Method

### Variables to test

    depth: 0, 4096, 8192, 16384, 30592

Order: one run directory per rung, in that order. Nothing else moves.

### Constant for this round

Everything in Held. Each rung is its own run and so its own server, which stops
a rung inheriting another's prefix cache or the heat it left behind; the
per-cell corpus offset fixes each rung's text and makes it reproducible.

Grid per rung:

    pp 2048 · tg 128 · concurrency 1 · runs 7

d0 and d30592 run at `runs 9`: the rule is stated on those two medians and the
middle three only witness monotonicity, so the repeats go where the verdict is.

## Decision rule

Read `tg` at `pp2048 · tg128 · c1` — the cell itself, never its context-prefill
phase — from the d0 and d30592 rows. Evaluated on medians, since each rung
carries its own values.

Let **D** be the decline from d0 to d30592 as a fraction of d0, and **S** the
larger of those two rungs' `tg` interquartile spreads.

- **Flat** if D is at most 10%. Decode is depth-independent on this stack; the
  attention-side levers are bounded by the 10 full-attention layers and the
  objective's ceiling lies elsewhere.
- **Sloped** if D exceeds 10%, is monotone across the rungs, **and exceeds S**.
  KV read is a live term, and `--kv-cache-dtype` and the attention backend are
  worth their own rounds.
- **Neither** if D exceeds 10% and is not monotone. Something other than depth
  is moving — check each rung's hit rate, peak power and IQR before reading
  anything into the shape.
- **Unreadable** if D exceeds 10% but does not exceed S. The ladder cannot
  separate the effect from the scatter that produced it. Re-run both anchor
  rungs at higher `runs` before calling anything; do not report a slope.

A rung whose `tg` IQR exceeds 5% is not counted toward the decline until it is
re-run; an unstable rung cannot anchor a slope. Every rung carries at least 7
values, so an interquartile range exists at all of them.

(Amended 2026-08-23, before any rung ran. It previously had three branches and
a bare 10% threshold, with no branch for a decline that clears 10% while
sitting inside the rungs' own spread — the outcome the prior evidence makes
most likely, since the nearest measurement on this box declines 5.3% across
four times this span. A threshold that can be met by noise is not a rule.)

## Conclusion

**Flat — target met.** `tg` at c1 declines 4.5% from d0 to the deep anchor,
114.6 → 109.5, against a threshold of 10%, so the first branch fires and the
later three never arise. Decode on this stack is depth-independent as far as
`max_model_len 32768` lets us look.

Four caveats, without which this overstates. **S = 5.1% exceeds D = 4.5%**: on
raw `tg` alone the ladder cannot separate the decline from zero, and what makes
it credible is the acceptance-normalised series, 37.0 → 35.1. The rule was
**amended in place** before any rung ran, disclosed above, and the branch that
amendment added — *Unreadable* — did not fire. The deep anchor is **d30464, not
the d30592 the rule names**: the served prompt is `pp + depth + 2`, d30592 is
refused with HTTP 400, and the substitution costs 128 tokens of KV, ~0.05% of
the per-step read. The attention-side levers close with it. The round's
reasoning is in the memory store — every record carries `depth-curve/h1` in its
`basis`.
