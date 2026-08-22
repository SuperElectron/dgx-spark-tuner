# R08 — the depth-flatness control: d16384 and d65536 under ONE engine start

objective: decide whether the campaign's "depth is flat" reading survives when both depths are measured inside one engine start and one thermal state, removing engine-start variation and thermal drift as explanations. Everything the campaign knew about depth at `tg128 c1` rested on three separate invocations.
claim: three architectural facts make the depth term small over this range — 30 of 40 layers are fixed-state Gated DeltaNet whose per-step work does not grow with context, only 10 hold KV, and those hold it in FP8, with ~2.81 GB of cache against ~75 GB reserved so nothing is evicted. Against that, the naive bandwidth arithmetic says total read goes 2.40 → 4.51 GB, a 1.88x rise a pure-bandwidth model turns into −47%. That model was already wrong by ~2x at d65536 and 2.2x at d131072, so it is not the estimator — but if the true fall is even a quarter of it, seven runs at each depth will see it. ⚠ The round explicitly refuses one reading in advance: per-step decode work is non-decreasing in context length, so the true curve is monotone non-increasing and any measured rise is a sampling artefact by definition. The round may say "flat", "falling" or "cannot resolve" — never "deeper is faster".
variables: `depth` 16384 and 65536 at c1 in ONE invocation, runs=7 each. No mutation.
confirms / refutes: the resolution budget was priced before the run — SE of a median ≈1.2% at d16384 and ≈4.5% at d65536, so the gap carries ≈±4.7% at one sigma and **the round cannot resolve the 2.7% gap it is chasing and does not claim it will**. |gap| ≤ 6% reports FLAT regardless of sign. More than 6% below means the depth term bites earlier than R05 placed it. More than 6% above violates monotonicity under one engine start, which cannot be physics, and the engine log is being captured to check the MTP acceptance draw.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_3d8149654d1b | 2026-08-22T06:58:26Z | depth 16384 and 65536, c1, one engine start (`session_count: 1`), runs=7 each | tg 113.06 (σ/med 5.5%) at d16384 against 94.10 (σ/med 9.0%) at d65536 = −16.8%; ctx_tg 102.68 and 92.98; pp2048 628.66 and 119.54 |

## conclusion 2026-08-22T07:05:42Z
**The hypothesis is refuted and so is R03. Depth is NOT flat across d16384–d65536 —
it falls 16.8%**, 113.06 → 94.10 on medians and 110.68 → 94.30 on means, far outside
the ±6% band declared in advance and roughly 3.5σ on the pre-declared error budget.
The round was built to be able to say "cannot resolve" and instead says "falling",
unambiguously, and the pre-declared threshold is what makes that statement worth
anything.

The cost is stated plainly: R03's 108.15 was a lucky three-run draw, exactly as
R01's 129.32 turned out to be, and this is the second time a three-run median in
this campaign has been retired by a seven-run one — both times too high. So the
campaign's headline reading of R03, "the depth-dependent term is smaller than c1
noise across d8192–d65536", is retired. What was actually true is narrower and less
interesting: three runs at c1 could not resolve the depth term, and the campaign
mistook that for the term being absent. The curve is monotone after all, which is
what physics required; the five-round "flat, flat, then a cliff" story is retired,
and there was never a knee. The naive bandwidth model keeps its sign and stays wrong
by 2.7x in magnitude, which is an open problem rather than a solved one.

R03's deep Phase-1 inversion did not reproduce either: under one engine start
d65536 reads −1.2% against R03's −17%, and the magnitude ordering is backwards from
the prediction — the shallower arm is the more negative one, at −9.2%. Across five
depths the sequence is +, +, −27%, −1.2%, −0.6%, with both figures that built the
"inversion deepens with depth" story being three-run readings from separate
invocations and the one properly re-measured having collapsed to nothing. The
quietness rule broke for the third time and stays retired.

What got better: eight side-predictions were declared and seven held, including both
identical-work session controls — `pp2048` at 628.66 sits inside a flat series
spanning seven invocations, and `pp2048 @ d65536` reproduced R03's figure from a
different engine start to 0.8%. That is what licenses reading the −16.8% as a depth
effect rather than a bad night. What got worse: two claimed figures were revised,
one down hard — `tg128 @ d65536 c1` goes 108.15 → 94.10, so the margin falls from
6.56x to 5.71x, though the worst of seven runs is still 4.96x and the verdict is
nowhere near flipping.

⚠ PROCESS FAILURE, recorded rather than buried. The hypothesis promised MTP
acceptance at both depths from the engine log and it was not captured — sparkrun tore
the container down at Step 3/3 and `/tmp/sparkrun_serve.log` went with it. Nothing
was invented to fill the gap, but the one unconfounded acceptance-versus-depth
reading the round was in a position to take is lost, and acceptance is the leading
candidate for a depth term that steepens. The fix is procedural: capture the engine
log DURING the grid, not after. ⚠ Superseded: the d131072 leg of this round's depth
curve (77.13, −18.0%) was revised by R21 to a pooled 81.22 at −13.7%, which makes the
steepening milder; the curve stays monotone and steepening. The `ctx_` phase labels
are inverted throughout — read Phase 1 against Phase 2 — but the measurement and its
verdict are untouched. Implication for the next hypothesis: the chunked-prefill
interference R04 named as the cause of the c5 deficit has never been measured inside
one invocation, and chunked prefill has never actually been turned off.
