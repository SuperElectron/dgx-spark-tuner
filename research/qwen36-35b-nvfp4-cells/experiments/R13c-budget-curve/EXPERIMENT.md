# R13c — the `max_num_batched_tokens` curve at one concurrency

objective: sweep the token budget across its whole range at a single cell to find the knee, and separately re-measure six archived headline figures from fresh engine starts. `tg128 @ d16384 c4`, `max_num_seqs 5`, runs=7, six invocations.
claim: a Phase-2 request prefills `depth + pp` = 18432 tokens (prefix caching never hits, so none of the 16384 is free), and four requests are 73728, so admission takes `ceil(73728 / B)` steps — 9 / 5 / 3 / 2 / 1 / 1 at the six budgets. **98304 and 131072 are the same admission configuration**, both admitting the whole batch in one step and leaving `Waiting: 0`, and that pair is the discriminator. R13 left an unexplained fact — the budget lifts per-request decode — and two accounts differ only past the point where admission is already a single step.
variables: `max_num_batched_tokens` swept 8192 / 16384 / 32768 / 65536 / 98304 / 131072, one invocation per budget. ⚠ One invocation for all six is impossible here (each new budget forces a torch.compile rebuild) and the round says so instead of pretending.
confirms / refutes: **H_admission_decode** — decode is depressed only while prefill is chunked across steps, so the effect is exhausted once `B >= 73728`: `tg_req(131072) ≤ 1.03 x tg_req(98304)`, with `tg_req(65536)` already within 5%. **H_budget_decode** — the budget itself buys decode independent of admission steps: `tg_req(131072) ≥ 1.05 x tg_req(98304)`. Between 1.03 and 1.05 is mixed and not forced. **HEADLINE PROTECTION, written before the numbers exist:** six archived rows are re-measured against a ±10% band — about 2.5x the expected combined spread, wide enough that a true reproduction clears it and tight enough that a real regression fails it.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_0f4c34c12223-mnbt8192 | 2026-08-22T11:37:35Z | mnbt 8192 (9 admission steps) | tg 52.07, tg_req 33.00, span 2.535, peak 271; scheduler partial residency |
| bench_fa5630a4ac79-mnbt16384 | 2026-08-22T11:44:02Z | mnbt 16384 (5 steps) | tg 85.90, tg_req 43.99, span 2.048, peak 277; partial residency |
| bench_10bd1b5f24ea-mnbt32768 | 2026-08-22T11:30:30Z | mnbt 32768 (3 steps) | tg 143.83, tg_req 59.48, span 1.654, peak 288; (4,0) in 13 of 13 |
| bench_0bd1f20dca74-mnbt65536 | 2026-08-22T11:50:43Z | mnbt 65536 (2 steps) | tg 173.34, tg_req 65.24, span 1.505, peak 308; (4,0) in 10 of 10 |
| bench_d6cec044441c-mnbt98304 | 2026-08-22T11:22:19Z | mnbt 98304 (1 step) | tg 169.69, tg_req 64.02, span 1.509, peak 302; (4,0) in 11 of 11 |
| bench_0509b2a740f6-mnbt131072 | 2026-08-22T11:58:08Z | mnbt 131072 (1 step) | tg 170.89, tg_req 64.14, span 1.501, peak 304; engine start 310.0 s |

## conclusion 2026-08-22T12:07:15Z
**All six protected rows stand**, every one inside its pre-declared ±10% band from a
separate engine start at runs=7 against runs=7, at −1.48% / −2.32% / −2.86% / −1.30%
and two more. That is the round's first and cheapest result: the campaign's headline
`c4` margins are reproducible, not single draws.

**The discriminator lands decisively on H_admission_decode**: `tg_req(131072) /
tg_req(98304) = 1.0019` against a 1.03 line, and `tg_req(65536)` is within 1.9% of
`tg_req(98304)` against a 5% threshold. The budget does not buy decode past the point
where admission stops being split — **there is nothing above the knee.** ⚠ But the
mechanism is only half right, and the wrong half is R13's. H_admission_decode implied
the ceiling arrives at one-step admission; it does not. **The ceiling arrives at
65536, a TWO-step configuration**, which has the highest `tg_req` of the six. The
three budgets at or above 65536 read 173.34 / 169.69 / 170.89 — a 2.1% spread against
a per-arm σ/med of ~4%, statistically one point. **So `max_num_batched_tokens 98304`,
the value R13 derived from careful one-step arithmetic and paid a torch.compile
rebuild for, buys NOTHING over 65536.** R13's pre-flight was right that 98304 removes
the trailing step and wrong that removing it is what the gain was made of. Two steps
is already enough — the same shape as R13's own outcome, which got its numbers from
the term it treated as secondary.

The knee is at **65536**, exactly where the round predicted, and the curve is flat
above it: 8192 → 65536 is **+233%**, and 65536 → 131072 is **−1.4%**, i.e. nothing.
The trade-off is what makes 65536 the right value rather than merely an equal one:
same throughput to within noise, a smaller activation budget, and a much cheaper
engine start — 185.2 s against 310.0 s at 131072. **R11's fold decision now has a
value, and it is 65536, not 98304.**

The curve also separates two thresholds the campaign had been conflating. Residency
saturates at 32768, where the scheduler first reads a clean (4,0); but the span ratio
keeps falling past it, 1.654 → 1.505 between 32768 and 65536, **with `Waiting: 0` at
both** — then hits a floor of ~1.50 that no budget touches. Full residency is not the
same thing as a full span. That is the measured half of the campaign's mechanism
chain: token budget → residency → prefill-completion stagger → batch span → every
`c>1` number. What got worse across the sweep: variance rises with the budget (σ/med
1.03% at 8192 against 4.39% at 65536), ttfr rises monotonically (10217 → 12167 ms),
and the engine start cost tracks the SIZE of the budget — which corrects R13's cost
note that each new value costs a full rebuild, and means sweeping the flag is
affordable.

⚠ Two things this round declined to promote, deliberately. A new widest margin was
measured and is NOT promoted, on the round's own rule. And the round measured a
systematic: six of six protected rows reproduced LOW, mean −1.94%, which on a coin is
p ≈ 3% — so every figure in the campaign taken exactly once carries a ~2% downward
correction of unknown origin. ⚠ Superseded: R09c had already weakened that systematic
to a ±2.5% noise floor, and R23 widened the floor again to about ±5% on identical
configurations while refuting any directional bias — so the inter-point differences in
this curve (98304 against 131072 at −1.4%) remain noise, which is what they were
already called, and the knee at +233% was never at risk. Implication for the next
hypothesis: repeat the promotion candidate at 131072 to see whether the widest margin
reproduces, and take the fold anchor at 65536 to c1.
