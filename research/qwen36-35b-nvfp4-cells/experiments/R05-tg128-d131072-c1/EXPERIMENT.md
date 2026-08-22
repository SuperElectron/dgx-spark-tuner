# R05 — `tg128 @ d131072 c1`, the stretch point

objective: extend the depth curve to the deepest cell the campaign will attempt, queued in advance as a probable LOSS and explicitly not to be tuned for. The incumbent is 81.60 (Nemotron Lightning NVFP4), a competitor that scales its own depth curve well rather than a weak sole entry.
claim: two competing models were named before the run so the measurement could choose between them. **Hypothesis A**, the naive weights-plus-KV bandwidth model behind the queue's 55–70 estimate: at 40 KB/token the depth-dependent read is 5.00 GB against a fixed ~1.7 GB weight read, giving 35. It was already refuted once — it predicted 56 at d65536 where R03 measured 108.15. **Hypothesis B**, extrapolating our own flat d16384–d65536 response, gives 100–110. The round's declared prediction was 85–105, centre ~95: hypothesis B with a small downward tilt, because d131072 is the first depth at which the KV read clearly exceeds the weight read.
variables: `depth` raised 65536 → 131072 at c1, runs=3. No recipe mutation — the recipe stays exactly as it has been for five rounds and only the probe moves.
confirms / refutes: 85–105 wins the cell against 81.60 by 1.04x–1.29x, a margin under 2x, which triggers the mandatory verify repeat. 55–70 means the queue's estimate was right and hypothesis A survives. Three further falsifiable claims declared: Phase 1 comes in 12–22% below Phase 2 (70–88), `pp2048` lands at 40–48, and Phase 1 is quieter at σ under 3% of its median.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_076db52d341c | 2026-08-22T05:49:52Z | depth 131072 at c1, runs=3 | tg 77.13 (σ 7.17) = 0.95x, a LOSS; ctx_tg 76.66 (σ 10.16); pp2048 42.59; ctx_pp2048 2803.17. MTP acceptance fell live from 3.81 / 93.6% to 2.43 / 47.7% |

## conclusion 2026-08-22T05:59:00Z
The campaign's first LOSS, and it is recorded as one: 77.13 against 81.60, short by
5.5%. The narrowness invites exactly the wrong follow-up and the round says so — one
of the three runs, 89.39, would have beaten the incumbent on its own, but that is
the top of a bimodal draw in the noisiest regime the campaign measures. At σ 9.3% of
the median, three runs cannot resolve 5.5%, so the honest statement is "we lost this
cell by about 5%, with a run-to-run spread wider than the margin" — not "we nearly
won it". `recipe.yaml` is untouched.

Both competing hypotheses were refuted, from opposite sides: 77.13 sits between
them, about 10% above the top of hypothesis A's band and 9% below the bottom of
hypothesis B's. It is the first time the campaign was refuted **downward** — R01,
R02 and R03 all predicted a slowdown and measured the opposite, and R04's one
accurate prediction came from interpolating measured points. R05 interpolated
measured points too, and this time the extrapolation was too optimistic, because it
extrapolated a flatness that was about to end. The depth term finally bites and the
round locates where: flat within noise across the first 4x, then a 29% fall across
the next 2x. The naive bandwidth model is still not coming good — it is wrong by a
factor of 2.2 here after being wrong by 2x at d65536 — so whatever amortises the KV
read is still amortising it.

The trade-off, and the round's best mechanism, was watched directly rather than
inferred: MTP acceptance degrades badly at this depth. The engine's own
`SpecDecoding` metrics went from mean acceptance length 3.81 at 93.6% draft
acceptance early in the round to 2.43 at 47.7% once the deep contexts were in play,
with per-position acceptance falling 1.000 / 0.962 / 0.846 → 0.608 / 0.451 / 0.373.
Halving acceptance roughly halves tokens per verify step, a decode cost with nothing
to do with KV bandwidth, and it is a better candidate for the 29% fall than the
memory argument. It also explains why σ stays wide at c1: the acceptance draw is
what is bimodal. The Phase-1 prediction was refuted on magnitude and broke a
five-round regularity — the gap read −0.6%, so the inversion did not deepen with
depth, it disappeared; and Phase 1 came in NOISIER than Phase 2 (13.3% against
9.3%) for the first time in the campaign, killing the "removing prefill removes the
variance" explanation.

⚠ Superseded and corrected. R05 was righter than it knew about the quietness: the
phase-label correction shows the premise was false outright — Phase 1 is the
*uncached* context load and prefills `depth` tokens, so no prefill is removed in
either phase, here or anywhere. "Removing prefill removes the run-to-run variance"
is retired as a claim, having broken three times for two different reasons. The
headline figure itself was **revised by R21**: R05's 77.13 was a three-run draw,
R21 ran seven runs at R05's own invocation and read 81.32 (+5.43%), and the pooled
10-run median is 81.22 — which moves the recorded loss from 0.95x to **0.995x**. The
published 5.5% deficit was overstated by a factor of ten; the real gap is 0.47%,
which is 0.11 SE. ⚠ It did not flip, it is not claimed, and the round is explicitly
priced out for re-measurement: 0.11 SE is unresolvable at any affordable run budget
at the most expensive depth on the box. Implication for the next hypothesis: the
`tg32`-versus-`tg128` gap and the reproduction gap both still rest on three-run
medians at c1, and R06 should settle them with a controlled runs=7 comparison inside
one engine start.
