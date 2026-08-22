# R08c — the last surviving deep inversion, and a protection point on a three-run win

objective: two things at once at `ctx_tg32` / `tg32 @ d32768 c1`, runs=7. Retire or confirm the campaign's last surviving deep Phase-1 inversion (R01's −27.3%), and protect a standings row that still rested on three runs.
claim: the queued framing was half obsolete and the round says so — the phase-label correction retired "cached versus cold", R09b established prefix caching never engages at all, and R09c plus R13b closed the mechanism chain. **The chain is definitionally silent at c1**, so it cannot already have explained this inversion: at c1 there is no batch, no span and no admission term for a depth effect to ride on. The pre-run position is that the gap does not need a mechanism, it needs a bigger sample — the d65536 precedent contracted −17.0% at 3 runs to −1.2% at 7, and applying the same contraction to −27.3% gives about −2%.
variables: `max_num_batched_tokens` at 8192 in one invocation (replicating R01's condition bit for bit) and at 65536 in the other (the folded recipe), with `-o max_model_len=40960` in both and `max_num_seqs` left at the recipe's 4 — at c1 scheduler width does nothing and changing it would make this a two-mutation round for no reason. runs=7 in both, non-negotiable at c1 and at tg32.
confirms / refutes: gap ≤ **−20%** → H_real, the −27% survives in substance and the campaign owns a c1 effect its mechanism chain cannot explain. Gap > −20% → H_sampling, the −27% is retired as a three-run draw. −20% to −18% is not established either way. Predicted −4%, band −18% to +8%. ⚠ **Honest power statement, made in advance:** at σ/med ~10% the SE on the change from R01's ratio is ~11%, so a shift from −27% to −4% is ~2 SE. This round can retire a 27-point effect; it could not resolve a 10-point one. Protection band ±10% on both archived rows, and the round predicted a **split** verdict in advance — Phase 2 stands and comes in low, Phase 1 does not stand and comes in high. ⚠ Named weakness: the two budgets cannot share an engine start, so that one comparison is cross-invocation and must be read against R09c's ±2.5% floor; the primary and protection readings are both intra-invocation and are not exposed to it.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_2b0f7bc8fb7b-mnbt8192 | 2026-08-22T14:54:26Z | mnbt 8192 — R01's condition replicated | ctx_tg32 110.61, tg32 109.62 → Phase 1 vs Phase 2 **+0.9%**; residency (1,0) in 9 of 9 |
| bench_964a188f3d16-mnbt65536 | 2026-08-22T14:59:54Z | mnbt 65536 — the folded recipe | ctx_tg32 117.65, tg32 110.03 → **+6.9%** |

## conclusion 2026-08-22T15:04:49Z
**The −27% inversion is retired. It was a three-run draw.** Both invocations land far
on the H_sampling side and agree in sign: +0.9% at R01's own condition and +6.9% at
the folded budget, both inside the predicted −18% to +8% band, with the pooled 10-run
figure at the original condition reading −4.3% — the predicted centre to a tenth of a
point. "The ctx inversion deepens with depth" has lost its last evidence: it was
already unreproduced at d65536 (−17.0% → −1.2%) and at d131072 (−0.6%), and d32768 was
the only surviving piece. **No deep Phase-1-versus-Phase-2 inversion exists anywhere
in this campaign's data, and none ever did.** Note what did not have to be invoked: no
mechanism was needed and none is offered, which matters because at c1 the campaign's
one surviving mechanism is silent by construction — `tg == tg_req` exactly in all four
phase-arms, so the span ratio is 1.0000 by assignment.

**The protection verdict is split, exactly as pre-declared, and both predictions
landed inside their bands.** Phase 2 STANDS at −5.14%, the ninth same-sign low
reproduction — though on a cell whose σ/med is 15.82% that is 0.8 SE, so it should be
read as noise with a sign rather than a correction to apply. Phase 1 DOES NOT STAND
and is the campaign's largest single-figure retraction by percentage: 84.03 was 28.5%
below what seven runs at its own condition say. ⚠ Note the shape, because it is the
reusable half of this round. The campaign's four-for-four rule says *promoted*
three-run medians came in too high; this is a three-run median that came in too
**low**, and it was never promoted because it was a loss. **The one-sided survival is
a property of what gets defended, not of the sampling** — a flattering draw becomes a
claim and gets defended, an unflattering one becomes a recorded loss and nobody
re-measures it for eleven rounds. Both directions were live all along and only one was
being audited.

The consequence nobody queued: `ctx_tg @ d32768 c1` had been carried as a hopeless
0.72x loss since R01 and it is not. The pooled 10-run figure at the pre-fold budget
reads 0.918x and the folded-recipe invocation reads 1.002x. **This is NOT claimed as a
win and must not be** — the margin is +0.24% on a cell whose σ/med is 9.44%, which is
0.06 standard errors, and it is the first and only measurement of the cell at that
budget. Recording it as a win would repeat the precise error this round was built to
correct, in the same document that corrects it. What IS established is that the cell
was mis-scored and by a lot: the loss stands, the margin does not.

The trade-off across the two budgets is small and split. Phase 2's +0.37% is a
striking reproduction of R11's +0.27% at d16384 — same flag, same concurrency, a
second depth, an 8x budget change, agreeing to a tenth of a percent — so budget
inertness at c1 extends to d32768 on Phase 2. Phase 1's +6.36% sits above the 5%
inertness line at ~1 SE and was reported as NOT ESTABLISHED under the round's own
conjunction rule, with instructions that the protection round measure both budgets.

⚠ Superseded on two figures, and the first is the one that matters. **R22 did measure
both budgets and REFUTED the +6.36%: the quantity R08c measured was not the one it
named.** R08c ran 8192 first and 65536 second; R22 ran 65536 first and 8192 second,
and in 4 comparisons of 4 the arm that ran SECOND read higher. Comparing first arm
against first arm the budget reads −1.08% and +0.86%, inert on both. R22 then
re-measured the dead heat at runs=14 and it did not survive — **the 1.002x is
RETIRED**, the cell closes as a LOSS at 0.987x on a pooled 24 runs, and R08c's 117.65
reads 109.41. ⚠ R23 then refuted R22's position bias in turn, so the *explanation*
changes from an ordering artefact to a draw while the refutation of the +6.36% stands.
R08c's "σ/med 24.20% is the noisiest cell the campaign has measured" was also retired
by R22, which read 11.39% at runs=14 — a factor of 2.1, and a reminder that a σ
estimate from 7 runs carries roughly ±50% of itself. Implication for the next
hypothesis: the surviving three-run standings rows need the same audit this round just
gave one of them.
