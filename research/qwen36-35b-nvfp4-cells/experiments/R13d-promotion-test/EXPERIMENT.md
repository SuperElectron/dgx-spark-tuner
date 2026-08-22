# R13d — the promotion test: does the widest margin reproduce?

objective: decide whether R13c's `ctx_tg @ d16384 c4` = 175.40 at `mnbt 131072` should take the campaign's widest-margin title from the pooled 14-run 170.36 (6.15x) at `mnbt 98304`. R13c deliberately declined to promote it.
claim: 175.40 is a single 7-run median at a configuration measured exactly once, and its two neighbours above the budget knee (168.37 at 98304, 164.95 at 65536) make the top three statistically one point at σ/med ~4%. R01's 129.32 and R03's 108.15 were both retired for being high draws. This one is 7-run rather than 3-run, but it is still one draw of the configuration, and one repeat settles it.
variables: nothing changes — the identical configuration is run a second time. `pp 2048`, `depth 16384`, `tg 128`, c4, runs=7, `max_num_batched_tokens 131072` and `max_num_seqs 5`, both journaled mutations, neither folded. One invocation, one engine start, with the Phase-2 partner riding along free.
confirms / refutes: let `M14` be the median of the 14 pooled runs (R13c's seven plus this round's seven) — pooling is legitimate here and only here, same recipe, same probe, same mutations, same values. **`M14 > 170.36` → the title MOVES. `M14 ≤ 170.36` → the title STAYS and R13c's 175.40 is recorded as the high draw it looks like, and the question is closed for good — no third measurement, whatever the gap.** No other outcome is available; in particular a repeat median above 175.40 does not by itself move anything.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_0509b2a740f6-r13d | 2026-08-22T12:31:15Z | mnbt 131072 + mns 5 at c4, identical repeat of R13c's 131072 invocation | ctx_tg 170.16 (σ/med 2.11%), tg128 168.97 (σ/med 5.86%); pooled 14-run ctx_tg 171.77 = 6.21x; scheduler (4,0) in 13 of 13; prefix cache 0.0% in all 24 samples |

## conclusion 2026-08-22T12:40:05Z
**The title moves, by 0.83%, and the round said so before it ran.** The pooled
14-run median is 171.77 against the incumbent 27.68 — **6.21x** — clearing the
declared 170.36 threshold. The hypothesis had named this exact outcome in advance as
"a title move by a margin too small to mean anything physically", so the right
reading is not that a better configuration was found. It is that the campaign's
widest-margin claim now rests on 14 runs at a re-measured configuration instead of
one 7-run draw, and it landed almost exactly where the pre-run arithmetic put it.
**R13c's 175.40 = 6.34x is retired as the high draw it looked like** — the repeat came
in 2.99% below it and the pooled figure 2.07% below it, and 6.34x should not appear
in any standings claim again.

Sixteen predictions were declared and **14 held, 2 missed**, both small and both in
the same direction as everything else. The primary ones were the tight ones: the
repeat median landed 0.7% from its centre and `M14` 0.45% from its centre. The
trade-off here is a methodological one rather than a performance one — nothing about
the box changed, and what the round bought was confidence at the price of one engine
start. ⚠ The `ctx_pp` miss is worth naming because R13c had declared `ctx_pp` the
*replacement* session gate after `pp2048` broke its own gate on one low draw, and on
its first outing the new gate missed too, by 2.0%. It is a narrow band built from one
prior invocation rather than a broken instrument — 5781.15 against 6163.69 is a −6.2%
move whose σ collapsed from 416.60 to 136.29, so the two disagree about dispersion as
much as about level. **Widen the `ctx_pp` gate to ±10%, the same band the protection
points use, or stop calling it a gate.**

The round's second finding is the systematic. R13c reported six reproductions, all
low, mean −1.94%; this round adds two more from an independent engine start (−2.99%
and −1.12%), making **eight of eight the same sign, mean −1.88%**, which on a fair
coin is p ≈ 0.8%. It cannot separate the two candidate causes — a decode-side session
effect or first-measurement bias — but it narrows one thing R13c could not: R13c's
six reproductions were all of figures that had motivated their own promotion, which
is exactly the shape first-measurement bias takes, while **this round's Phase-2
partner was not a promoted figure — nothing hung on it, it rode along free — and it
came in low anyway.** That is mild evidence for the session-effect half, though one
unpromoted point against seven promoted ones is not conclusive.

⚠ Superseded on the size of that systematic, though not on its existence. R09c had
already weakened it to a ±2.5% noise floor, and R23 then measured the arm-to-arm
spread on *identical* configurations at about ±5% while refuting any directional bias
— so the honest working figure is a symmetric floor rather than a downward
correction, and no past delta needs re-signing. The `ctx_tg @ d16384 c4` title itself
stands at 6.21x. Implication for the next hypothesis: R11's fold decision is the only
thing left blocking a recipe change, it needs the c1 anchor, and R13c said which
budget to take there — 65536.
