# R21 — the three-run audit: re-measure the surviving `runs=3` standings rows

objective: audit the standings rows nobody had a motive to check. This is a standings-protection round, not a new-cell hunt — no cells are added.
claim: for eleven rounds the campaign published a rule that every three-run median it re-measured came in too high, four for four, and used it to treat unrepeated wins as inflated. **R08c broke it in the expensive direction**: a cell carried as a 0.72x loss since R01 on a three-run 84.03 read +31.64% at runs=7, and the campaign spent eleven rounds not looking at a cell it had written off on a bad draw. The revised reading this round acts on is that the four-for-four pattern was an artefact of **which rows got audited, not of sampling** — sampling error is symmetric, and the error that survives in a results file is whichever direction nobody was auditing.
variables: no vLLM setting is under test. Two invocations reproduce archived conditions bit for bit — R05's d131072 leg (`max_model_len 139264`, `mnbt 8192`) and R01's d8192 leg (`max_model_len 40960`, `mnbt 8192`) — at runs=7 instead of runs=3. ⚠ A fourth row (`tg128 @ d16384` c2 and c5) was **deliberately not measured**: both lose by more than 2x, no sampling error of that size closes the gap, and both already have runs=7 tuned successors.
confirms / refutes: a ±10% band around each archived median, declared in advance. Inside → the row STANDS and the two sets are POOLED. Outside → the archived figure is RETIRED and REPLACED outright, not pooled. Cheapest control declared in advance: the two near-zero-σ `pp` figures — if either moves more than a percent, the invocation differed from the archived one and the whole reading is suspect.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_deb3090b9a29-r21-armA | 2026-08-22T15:24:39Z | R05's d131072 c1 condition at runs=7 | tg128 81.32 (σ/med 10.56%, +5.43%) → pooled 81.22; ctx_tg 78.38 (+2.24%) → pooled 77.52; pp2048 +0.35%, ctx_pp2048 +0.30% |
| bench_6921c874daee-r21-armB | 2026-08-22T15:41:29Z | R01's d8192 c1 tg32 condition at runs=7 | ctx_tg 128.76 (+1.77%) → pooled 127.64; tg32 123.81 (σ/med 13.18%, **+16.54%**, outside band); pp2048 −2.44% |

## conclusion 2026-08-22T15:43:48Z
Four rows re-measured, four rows moved, and **all four moved upward**. No cell changed
hands and the counts stay 8 won / 12 lost. The product is that three standings figures
are no longer three-run medians and one recorded margin was overstated by a factor of
ten.

**The headline: `tg128 @ d131072 c1` had been carried as 0.95x, "short by 5.5%",
since R05. The pooled 10-run median is 81.22 against 81.60 — 0.995x, short by
0.47%**, which at σ/med 10.56% is **0.11 SE**. The cell is a dead heat and we are on
the wrong side of it. ⚠ It did not flip and it is NOT claimed as a win — the same
discipline R08c applied to its own 1.002x: a figure that cannot be distinguished from
the incumbent is not a win, in either direction. The row stays in the LOST table.
What changed is that the campaign was publishing a deficit it did not have. ⚠ And it
should not be re-run: 0.11 SE is not resolvable at any budget this campaign can
afford, since halving the SE needs 4x the runs at the most expensive depth on the box
— 784 s of grid for seven runs, with a 47.9 s time to first response. R05's standing
advice not to return to d131072 was right; this round is the exception that audits it,
not the start of a campaign there.

Three of four rows stood and pooled. `ctx_tg @ d8192 c1` moved +1.77% and **the
campaign's thinnest surviving claim survived** — 1.07x over the best vLLM+NVFP4 entry
firms to 1.08x, against roughly a 35% pre-run risk of withdrawal. One row failed its
band: `tg32 @ d8192 c1` moved **+16.54%**, so R01's 106.24 is RETIRED and 123.81
replaces it outright, not pooled, per the rule. That was the campaign's worst-sampled
standings row — σ/med 21.4%, a 1.76x spread inside one cell — and **no margin moves**,
because the board publishes no figure for the cell, which is why it ranked third in
priority rather than first.

The trade-off here is not a performance one; it is that the audit costs box time and
returns no new cells. What it buys is that the depth curve's weakest leg is no longer
a three-run median, which flattens its last segment from −18.0% to −13.7% and makes
the curve's steepening milder — still monotone, still steepening, with the naive
bandwidth model's miss factor at the deep end shrinking accordingly. ⚠ Note the
direction: the one point on that curve which stood on three runs came in **high**,
like every other unaudited row.

The instrument check passed and it is what makes the deep invocation trustworthy —
both near-zero-σ `pp` figures moved under half a percent, on σ of 0.01 and 1.76, so
the invocation reproduces R05's. The shallower invocation's `pp2048` moved −2.44%,
larger but sitting exactly on the campaign's known ~2% reproduction floor. ⚠ A
methodological correction is recorded against something asserted mid-round: a matching
`intent_id` was read as proof the engine configuration was reproduced exactly, and it
is not proof.

⚠ Superseded on the reproduction floor it was read against, not on any of its figures.
R09c had weakened the campaign's "~2% downward systematic" to a symmetric ±2.5% noise
floor, and R23 later measured the arm-to-arm spread on identical configurations at
about ±5% while refuting any directional position bias — so the ±10% bands used here
were, if anything, generous, and the three pooled rows are unaffected. Implication for
the next hypothesis: R08c's dead heat at `ctx_tg32 @ d32768 c1` is the closest
unclaimed cell in the campaign and it is a 125-entry crowded cell — it needs the same
audit at both budgets, at more runs.
