# R06 — the tg32-versus-tg128 control at d16384 c1

objective: decide whether R01's finding that the SHORTER generation is 27% FASTER was ever real, and re-measure the `tg128 @ d16384 c1` baseline the whole reproduction gap rests on. The campaign's first round run purely as a control — no new cell, no new depth, no mutation.
claim: three candidate mechanisms were named and given separate predictions. **H1, undersampling**: both disputed numbers are three-run medians from the campaign's widest distribution, and variance alone cannot move a median, so two medians of the same quantity must converge at runs=7. **H2, acceptance decays along a generation**: a 32-token generation samples only the high-acceptance head while a 128-token one averages it against a slower tail, which shifts the median genuinely. **H3, the tg128 baseline is depressed**: 102.2 was inherited from a different series and never re-measured here.
variables: `tg` set to 32 and 128 at d16384 c1 in ONE invocation, runs=7 each, so both cells see the same engine, the same page-cache state and the same thermal window and the only difference is how many tokens are generated. No mutation, no `max_model_len` override.
confirms / refutes: the gap is the verdict. A gap at or above 20% confirms H2 and makes generation length a real tuning lever; a gap at or below 3% confirms H1 and retires R01's 129.32 as a lucky draw. Predicted 100–115 (centre ~107) for tg128, 108–125 (centre ~116) for tg32, gap +5% to +10%. Two within-round controls on box state were declared in advance with a ~2% contamination threshold: `pp2048` identical in both arms at 630–645, and `ttfr` identical at 3000–3500 ms — the prefill does not know how many tokens will follow it.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_dd3afc9e1c94 | 2026-08-22T06:17:06Z | tg 32 and tg 128 at d16384 c1, one engine start, runs=7 each | tg32 116.43 (σ/med 9.9%), tg128 111.11 (σ/med 2.6%), gap +4.79%; ctx_tg32 122.97, ctx_tg128 104.85; pp2048 623.13 / 634.99, ttfr 3298.58 / 3237.23 |

## conclusion 2026-08-22T06:21:32Z
**H1 wins: the 27% gap was undersampling.** Under one engine start at runs=7 the
comparison reads 116.43 against 111.11, +4.79% — four fifths of the effect was never
there. tg32 fell 10.0% from its three-run figure and tg128 rose 8.7% from its
inherited one, converging exactly as the sampling argument required. And the residual
is smaller than it looks, because the round's own controls priced the systematic:
both identical-work controls came in offset the same way by the same amount —
`pp2048` −1.90% and `ttfr` +1.90% — which is pure systematic, presumably the tg32
arm running first into a marginally colder box. Subtract it and the residual
generation-length advantage is ~2.9%, landing precisely on the round's own H1
threshold. **H2 is not supported at any useful magnitude**, so generation length is
not a tuning lever, and R01's 129.32 is retired. Writing the controls down in advance
is what made 4.79% readable as 2.9%; without them the round would have reported a 5%
effect that is mostly a warm-up artefact.

The reproduction gap comes free and is two-thirds gone: 111.11 against the board's
best vLLM NVFP4 entry of 116.03 is −4.24%, not −12%, and two of the seven runs clear
116.03 outright, so the board's figure sits at the top of our own distribution rather
than outside it. What got better: two open questions largely closed, a board cell
re-claimed at a corrected figure, for 124 s of grid time — the campaign's best cost
ratio, and evidence that control rounds were being under-scheduled. What got worse:
the standings figure moved **down**. `tg32 @ d16384 c1` stays a win but is revised
from 4.60x to **4.14x**, and a revision that lowers our own number is the correct
outcome of a control round.

The noise prediction got the direction emphatically right and both magnitudes wrong
(9.9% and 2.6% against 12%+ and 8–12%), and the Phase-1 result is the cleanest
unconfounded evidence the campaign produced on the ctx-versus-cold sign: it flips
with GENERATION LENGTH alone — +5.62% at tg32 and −5.63% at tg128, same invocation,
same depth, same concurrency, same thermal window. R03's version was confounded
across depths and invocations and R04's across concurrencies; this one is not
confounded by anything. "Removing prefill removes the variance" failed a second time
here, for a different reason than at d131072, and was retired rather than patched.

⚠ Superseded on its methodology rule, which the campaign then priced rounds on for
eight rounds. "`runs=3` is adequate for `tg128 @ d16384`" was generalised from this
round's σ/med of 2.6% and **refuted by R11**: measured at three engine starts the
same cell reads 2.6% / 5.5% / 8.01%, so σ is itself a draw, and R23 later added
8.26 / 10.95 / 12.22 / 10.90% for seven starts total. At 8%+ a three-run median has a
standard error near 5.8%, larger than most effects the campaign chased. The `c>=8`
half of the rule survives; the c1 half does not — **runs=7 at c1, always**, and this
cell is not the quiet regime. The `ctx_` phase labels are also inverted throughout;
the `tg` comparison and its sign are untouched, but the open question they fed was
withdrawn by the phase-label correction. Implication for the next hypothesis: the
concurrency curve's tail (c8, c16) is next, with `--max-num-seqs` matched at every
point.
