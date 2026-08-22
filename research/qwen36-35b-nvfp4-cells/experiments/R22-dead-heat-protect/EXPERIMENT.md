# R22 — protecting the 125-entry dead heat at `ctx_tg32` / `tg32 @ d32768 c1`

objective: decide whether R08c's 117.65 against a 117.37 incumbent — 1.002x, the closest the campaign ever came to an unclaimed win, on a 125-entry crowded cell — reproduces, and separately halve the error bar on R08c's Phase-1 budget effect. runs=14, both budgets.
claim: ⚠ **The round is honest about its ceiling up front: it CANNOT resolve +0.24%.** At σ/med 9.44% the SE of a median is 3.2% at n=14 and 2.6% pooled at n=21, so a 0.24% margin is ~0.09 SE either way, and no affordable number of runs on this box resolves it. What it CAN do is distinguish 117 from 108 — the two candidate readings differ by ~8%, which is ~2.5 SE at n=14 — halve the error bar on R08c's +6.36% Phase-1 budget effect (from 1.0 SE to ~1.4 SE, still not decisive, said before running rather than after), and settle whether budget inertness at c1 holds on Phase 1. ⚠ **H_draw** is the prediction: 117.65 has crossed from an unaudited row into a *defended* one, and R21's rule says defended rows correct downward. Predicted 112, band 103–122. There is no mechanism on offer for a budget effect at c1 and that is the point — both routes by which the budget has ever moved a number are absent there (residency is 1 of 1 at every budget; `tg == tg_req` exactly, so span is 1.0000 by assignment), and R11 and R08c measured inertness at c1 to within a tenth of a percent of each other.
variables: `max_num_batched_tokens` at 65536 (the shipped recipe) and at 8192 (the pre-fold budget), `-o max_model_len=40960` in both as a probe-driven override, `max_num_seqs` left at 4. runs=14 at **both** budgets, not just one, because the SE of the budget comparison is set by the noisier side. ⚠ **THE ONE DESIGN CHANGE FROM R08c, DELIBERATE: the invocations run in the REVERSE order** — 65536 first, then 8192, where R08c ran 8192 then 65536. The two budgets cannot share an engine start, so the comparison is unavoidably cross-invocation; reversing the order costs nothing and buys one real thing — if the same sign reproduces with the order flipped, thermal drift and start-order cannot be the explanation.
confirms / refutes: the claim rule, declared before the run — **the pooled mnbt-65536 median over all 21 runs must exceed 117.37 by more than 1 SE**, i.e. clear 120.53. Contingency declared: if the args echo does not read `runs: 14`, abort before the grid.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_bb4b8ef8a193-r22-armH | 2026-08-22T16:03:56Z | mnbt 65536 (shipped recipe), position 1 | ctx_tg32 109.41 (−7.00% against R08c), σ/med 11.39%; pooled 21-run 113.37 = 0.966x |
| bench_8707c27ce1a4-r22-armG | 2026-08-22T16:10:58Z | mnbt 8192 (pre-fold budget), position 2 | ctx_tg32 122.80 = 1.046x on this invocation alone; pooled 24-run 115.86 = 0.987x |

## conclusion 2026-08-22T16:16:23Z
**The cell is not claimed and the 1.002x dead heat was a high draw.** The pooled
21-run median at the shipped budget is 113.37 against a threshold of 120.53 — not met
and not close, 6.1% below the bar — so `ctx_tg @ d32768 c1` remains a LOSS and the
counts stay 8 won / 12 lost. H_draw is confirmed and the prediction was right on the
number: 109.41 against a predicted 112 in a 103–122 band, with the direction called
in advance. **R08c's 117.65 was the best single measurement of a cell measured once,
and it behaved exactly as the campaign's rule says such figures behave. R08c was
right not to claim it.**

⚠ Note what would have happened without the pre-declared rule. The 8192 invocation's
14-run median is **122.80 = 1.046x**, comfortably above the incumbent and the largest
sample ever taken at this cell. **It is not claimed either**, by the same rule: it is
one invocation at one position in one session, the pooled 24-run figure at that budget
is 115.86 = 0.987x, and promoting the best arm of a round is the error this round
exists to avoid repeating. **A rule that only binds when it is convenient is not a
rule.** The honest summary after 45 runs across four engine starts is that the cell is
a loss of between 1.3% and 3.4% depending on budget — another dead heat we are on the
wrong side of, and a real correction to both the carried 0.72x and the 1.002x, in
opposite directions. ⚠ Do not go back: 0.987x is 0.34 SE on the 24-run figure, the
same unresolvable position R21 priced out at d131072.

**The round's real finding is not the one it was queued for. The order-reversal
control was put in to rule out a nuisance variable and instead found one.** In four
arm-to-arm comparisons of four, across two rounds and four engine starts, **the arm
that ran SECOND read higher** — +6.36, +0.37, +12.24, +6.89%, mean +6.5%. The budgets
are swapped between the two rounds, so a budget effect cannot produce that pattern and
a position effect produces exactly it. Consequently R08c's "+6.36% on Phase 1 from the
folded budget" is refuted as a budget effect: the quantity R08c measured was not the
one it named. Comparing first invocation against first invocation — where the warm-up
state is matched — the budget reads −1.08% on Phase 1 and +0.86% on Phase 2, inert on
both, satisfying the conjunction rule R11 and R08c both declared. With R11's +0.27% at
d16384, **budget inertness at c1 is CLOSED and Phase 1's exception is withdrawn.**

The trade-off is methodological rather than performance: the round spent box time and
returned no new cell, and what it bought is that the campaign's largest-sample cell is
correctly scored and that every small cross-invocation delta in the file became
suspect. ⚠ The position effect was itself reported as NOT ESTABLISHED — 4 comparisons
from 2 sessions is p = 0.25 on a sign test — and was stated as a suspicion everywhere
it was used. The round also retired one of its own prior figures: R08c's "σ/med 24.20%
is the noisiest cell the campaign has measured" re-measured at 11.39% here, a factor
of 2.1, so a σ estimate from 7 runs is a draw like any other and carries roughly ±50%
of itself.

⚠ Superseded on the position bias, and this is the important one. **R23 tested it
under an A-B-B-A design built to catch it and REFUTED it at this cell**: four
same-configuration contrasts read −4.40%, −0.91%, +0.71%, +2.84% — two up, two down,
mean −0.44%, p = 1.0 on a sign test, against R22's 4-of-4 up at +6.5%. The pattern
does not reproduce even in the exact adjacent-different-configuration form that
produced it. Thermal and clock explanations were checked and excluded. So R22's +6.5%
is best read as four draws from a distribution whose σ/med at that cell runs 8–12%,
exactly as R22 itself allowed at p = 0.25. **The refutation of R08c's +6.36% stands —
what changes is the explanation, from an ordering artefact to a draw** — and R23's
drift-free contrast re-licensed R11's fold. Implication for the next hypothesis: the
ordering question is the highest-value item left, and it must be settled before any
small delta in the file can be trusted.
