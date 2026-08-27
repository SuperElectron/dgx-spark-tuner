# h5 — our recipe, measured on the board's own grid

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

LEVER SPENT, by the rule as written — `tg` median at `d16384 c1` is 103.7,
below the rule's 110 floor. But the round's mechanism never engaged: prefix
cache hit rate read 0.0%, so the hypothesis was not refuted, it was never
tested.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | arena-v2 grid, `max_model_len` 262144 | the board-comparable figure; tg is the median of 115.1, 103.7, 101.1, ±5.2% at n=3; pp ±0.8% | d16384 c1 | 636.7 | 103.7 | 3242.6 ms | bench_e86574ff0e1e |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Our tuned recipe, run on `@official/spark-arena-v2` unmodified, reads above
116.03 `tg` at `d16384 c1` — the best vLLM entry on the board. The grid is not
the recipe: arena-v2 fixes depths, concurrencies, `runs: 3`, prefix caching on
with no reset, and a heat-aware cell order, and says nothing about any field we
have tuned. So this round changes *how we measure*, not what we serve.

Mechanism, and it points two ways. **Cache warm:** no reset between runs, and
`d16384 c1` sits at index 13 of 28, so twelve cells of cache precede it — h2
measured that at 4.1x on `pp` and +2.3% `tg`. **Thermally warm:** index 13 is
mid-sweep on a loaded box, which depresses their number, not ours.

Worth, if right: the Objective's second figure. This is the only measurement
that can be set beside the board without an asterisk, and it settles the
question either way.

## Method

### Variables to test

    benchmark grid: @official/spark-arena-v2, unmodified

Order: nothing else varies, so there is no order. One run.

### Constant for this round

The whole served recipe — every flag decode-tg has settled, including whatever
h4 concludes about the draft's `moe_backend`. **h4 closes before this runs.**
Exactly one field changes, and it is capacity rather than tuning:

    max_model_len   32768 -> 262144

The grid reaches d65535 and d100000, which 32768 cannot serve at all.
`max_model_len` is a recipe field and therefore an **epoch break**: everything
here sits on the far side of it from h1-h4.

Grid, from the recipe's `benchmark:` block — arena-v2 unmodified, its 28-entry
`schedule:` transcribed verbatim so `d16384 c1` stays at index 13:

    pp 2048 · tg 128 · depth 0/4096/8192/16384/32768/65535/100000
    concurrency 1/2/5/10 · runs 3 · prefix_caching true

## Decision rule

Read our own `d16384 c1` row out of the result and set it beside 116.03.

- **Target met** if our `tg` at `d16384 c1` exceeds 116.03. The board comparison
  is then settled in our favour on the board's own terms, and the Objective's
  second figure exists.
- **Lever alive** if it lands between 110 and 116.03 — behind, but close enough
  that the warm-cache and thermal effects are worth separating before conceding.
- **Lever spent** if it lands below 110. Then our cold 119.6 was an artifact of
  measuring alone on a cool box, the board comparison goes against us, and what
  we learned is that our protocol flatters us.

Their `±` is a population standard deviation over three requests inside one
invocation; ours across invocations. The rule is stated on the median and does
not depend on comparing the two spreads. `runs: 3` gives three values at c1 and
an interquartile range needs four, so this cell prints no stability verdict.

## Conclusion

**Lever spent, by the rule as written** — median 103.7, below the 110 floor and
10.6% below 116.03 — **but the mechanism never engaged, so the hypothesis was
not refuted; it was never tested.** Prefix cache hit rate read 0.0% on all 544
engine samples, `enable_prefix_caching=True` confirmed, and `pp`, `ctx_pp` and
`ttfr` all land within 0.5% of h2's cold arm. So the Lever-spent branch's stated
reasoning — that our protocol flatters us — does not follow.

Four caveats. The figure is the **median** 103.7; run.py's table prints a
106.7 mean of rates, and both are below 110. `max_model_len 262144` is an
**epoch break**: nothing here may be set beside h1-h4 without saying so. **c5
and c10 at depth >= 8192 are unreadable** under `max_num_seqs 4`, measuring
queue position rather than decode. And the 0.0% residue is an **open question**,
with `no_adapt_prompt` and the fixed corpus the better-supported candidate.
Reasoning in the store, under `decode-tg/h5` in the `basis`.
