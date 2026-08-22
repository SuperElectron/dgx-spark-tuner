# R11 — the fold decision: is `max_num_batched_tokens` inert at c1?

objective: decide whether `max_num_batched_tokens: 65536` can be folded into `recipe.yaml`. The flag is the largest effect the campaign found — the difference between 1.13x and 3.71x on the only contested cell it holds — and ten of the eighteen win rows depend on mutations the recipe does not carry.
claim: the fold was never free. At d16384 a Phase-2 prefill is 18432 tokens, three scheduler steps at 8192 and one at 65536, so the flag is not obviously inert at c1 either — and the c1 anchor every depth and concurrency comparison hangs from (112.62, pooled over R06's seven runs and R08's seven, both at the old budget) was measured at 8192. **Folding without re-measuring that anchor would silently create a new epoch and quietly invalidate the depth curve.** ⚠ **H_inert**: the budget has moved this metric by exactly two routes in thirteen rounds and both are structurally absent at c1 — occupancy (there is one request, residency is 1 of 1 at every budget) and the span denominator (at c1 `tg_throughput` is *assigned* the per-request value, so there is no span to shorten). What the budget does change at c1 is prefill chunking; decode is untouched, since 128 tokens emitted ~3.1 at a time are orders of magnitude below any budget. ⚠ **H_decode**, and it is real: R13 found `tg_req` rose exactly +15.5% at BOTH c4 and c5, and R13c's c4 `tg_req` curve runs +98% across the sweep. That is a per-request quantity moving with the budget, and **every measurement of it was taken at `c>1`**. At c1 the two are cleanly separated for the first and only time.
variables: `max_num_batched_tokens` 8192 → 65536 at `tg128 @ d16384 c1`, runs=7, one engine start, Phase-1 partner riding along.
confirms / refutes: `M` = the 7-run median. Anchor 112.62, band ±5% = **107.0 – 118.3**, pricing the −1.88% systematic plus a 7-run median's sampling spread with room to spare. `M` inside → H_inert → **FOLD**. `M` > 118.3 → H_decode → do not fold; the flag is a genuine per-request decode lever and folding it re-anchors everything, making the fold a re-measurement project rather than a one-line edit. `M` < 107.0 → the budget costs something at c1 → do not fold. ⚠ Declared in advance: the expected result is the one that licenses changing the campaign's only tuned artifact, so **a marginal reading must be resolved against folding, not for it** — a caution zone of 117.2–118.3 was named. A conjunction rule was also declared: a split verdict, one phase moving and the other not, leaves inertness unestablished whatever the fold band says.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_c9518e3e96a3-r11 | 2026-08-22T12:59:00Z | mnbt 65536 at tg128 @ d16384 c1, runs=7 | tg 112.92 (+0.27% on the 112.62 anchor, 0.07 SE), σ/med 8.01%; ctx_tg 98.72 (−4.15%, 0.89 SE); scheduler (1,0) in 4 of 4; prefix cache 0.0% in 7 of 7 |

## conclusion 2026-08-22T13:03:47Z
**The flag is inert at c1, the fold rule is satisfied, and `recipe.yaml` has been
changed** — `max_num_batched_tokens: 65536` is now in its defaults. `tg128 @ d16384
c1` reads 112.92 against the pooled 14-run anchor of 112.62, +0.27%, which is 0.07
standard errors; the caution zone at the top of the band was not entered. Both phases
are inert, which is the conjunction the round required: Phase 1's −4.15% is 0.89 SE
on the noisiest reading of this cell in the campaign and is inside its own
pre-declared band. The two figures are NOT pooled — they are different
configurations, and pooling across a configuration difference is the thing the
campaign forbids.

The result generalises because the round predicted *why* before it ran: both routes
by which the budget has ever moved this metric are structurally absent at c1. That
also settles H_decode — the +98% per-request rise across R13c's curve is a sharing
artefact of `c>1`, not an intrinsic per-request effect, and this is the only place
that separation could be made. What got better: ten win rows now rest on the config
the recipe actually ships, and the depth curve and every c1 comparison stay valid
with no new epoch. What got worse: nothing measurable at c1 — but the round records
two small costs on the same side. `ttfr` **rose** 2.06% against R06 and 1.06% against
R08, which was the round's sharpest non-obvious call and it **missed on sign**: the
campaign's explanation for six consecutive worse-ttfr readings is a `c>1` neighbour
effect, and this is the seventh, at a concurrency where that explanation cannot
apply. The round got the magnitude right (+1.6% here against +7.3% to +32.4% at
`c>1`, an order of magnitude) and the sign wrong. A candidate cause sits in the data
— at 65536 the whole 18432-token prefill runs in one scheduler step instead of three,
and a single large forward pass appears marginally less efficient per token than
three chunked ones, with `pp2048` agreeing at −0.8% — but it is stated as a
candidate on two small same-signed moves, not a finding.

**The σ miss is the round's most useful side result and it retires a rule the
campaign priced eight rounds on.** R06 read σ/med 2.6% at this cell and generalised
"runs=3 is adequate for `tg128 @ d16384`". Measured at three engine starts it reads
2.6% / 5.5% / **8.01%**: σ is itself a draw, and at 8.01% a 3-run median has a
standard error near 5.8%, larger than most effects the campaign chased. The `c>=8`
half of R06's rule survives; the c1 half does not. **runs=7 at c1, always.** Eleven
of fifteen predictions held, including four that reproduce earlier sessions to two
decimal places or better, and the widened `ctx_pp` gate R13d recommended proved to be
the right instrument. One miss was a bookkeeping error in the hypothesis rather than
a surprise on the box: R06's "124 s" bought 28 runs, not 14, so the correct rate
anchor for this cell is ~4.4 s per run.

⚠ Superseded and then re-licensed. R22's order-reversal control raised the
possibility that the +0.27% anchor reading was a position artefact — the arm running
second read higher in 4 comparisons of 4, mean +6.5% — which would have put this fold
on an ordering artefact rather than a measurement. **R23 tested it under an A-B-B-A
design built to catch exactly that and refuted the position bias** (four
same-configuration contrasts, mean −0.44%, p = 1.0), then measured the configuration
effect drift-free at **C = −1.76%**, inside the ±5% band. R11's fold stands, now on a
contrast that ordering cannot fake. R13c separately established that 65536 rather
than 98304 is the right value: it is the knee, with the same throughput to within
noise and a much cheaper engine start. Implication for the next hypothesis: with the
recipe folded, the remaining work is auditing the standings rows that still rest on
three runs.
