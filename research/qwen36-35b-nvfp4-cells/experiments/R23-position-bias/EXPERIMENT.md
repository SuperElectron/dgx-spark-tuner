# R23 — whether the campaign's arm-to-arm comparisons carry a position bias

objective: decide whether "the setting that runs later reads higher" is a real effect, and with it whether R11's fold of `max_num_batched_tokens: 65536` rests on a real measurement; cell `tg128 @ d16384 c1`, runs=7 per invocation.
claim: R22 observed that in 4 arm-to-arm comparisons of 4, across two rounds and four engine starts, the later-running setting read higher (+6.36, +0.37, +12.24, +6.89%, mean +6.5%, p = 0.25 on a sign test). An A-B-B-A ordering cancels linear drift, so the configuration effect and the position effect can be read independently from the same four invocations.
variables: `max_num_batched_tokens` alternated 8192 / 65536 / 65536 / 8192 across four sequential engine starts, `max_num_seqs 4` throughout; a fifth invocation ran the shipped recipe unchanged at c4.
confirms / refutes: `P3` (arm4 − arm1, same configuration, 3 positions apart) was the primary reading. `P3` ≥ +6.0% confirms the position effect; +2.0% to +6.0% is a declared dead zone the round cannot call; `P3` ≤ +2.0% refutes it, and ≤ −2.0% is additionally recorded as sign-flipped. Separately, |`C`| < 5% on the drift-free configuration contrast leaves R11's fold standing.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_b20062a3c5c5-r23-arm1-A8192 | 2026-08-22T18:49:40Z | mnbt 8192, position 1 | tg 107.42 (σ/med 8.26%), ctx_tg 100.93 |
| bench_c9518e3e96a3-r23-arm2-B65536 | 2026-08-22T18:53:58Z | mnbt 65536, position 2 | tg 102.03 (σ/med 10.95%), ctx_tg 104.78 |
| bench_c9518e3e96a3-r23-arm3-B65536 | 2026-08-22T18:58:38Z | mnbt 65536, position 3 | tg 101.10 (σ/med 12.22%), ctx_tg 107.75 |
| bench_b20062a3c5c5-r23-arm4-A8192 | 2026-08-22T19:03:40Z | mnbt 8192, position 4 | tg 102.69 (σ/med 10.90%), ctx_tg 101.66 |
| bench_b56686c32206-r23-arm5-c4-mns4 | 2026-08-22T19:07:55Z | shipped recipe (mnbt 65536 / mns 4) at c4, no override | tg 179.34 = 3.84x board top, ctx_tg 169.45 = 6.12x |

## conclusion 2026-08-22T19:14:34Z
The position bias does not reproduce. `P3` = −4.40% and `P1` = −0.91%, both inside
the pre-declared refute band and both sign-flipped: the later-running setting read
*lower*. Across four same-configuration contrasts the mean is −0.44% with p = 1.0 on
a sign test, against R22's 4-of-4 up at mean +6.5%. Thermal and clock explanations
were checked rather than assumed — the box genuinely warmed (39 → 53 °C idle) and
later arms were slower, and under-load SM clocks spread only 0.25% with no
correlation to throughput. The drift-free configuration contrast `C` = −1.76%
(pooled 101.89 at mnbt 65536 against 103.72 at mnbt 8192) is inside the ±5% band, so
**R11's fold of `max_num_batched_tokens: 65536` stands** on a contrast that ordering
cannot fake.

What got better: every small cross-invocation delta in the campaign — R13c's budget
curve above all — is restored to a symmetric noise reading rather than an
order-suspect one, and the shipped recipe was measured at c>1 for the first time,
discharging the campaign's last "never been measured" caveat. What got worse: the
noise floor is now known to be wider than believed. R9c's ±2.5% reproduction floor
is an underestimate; identical configurations spread about ±5% here, and R6's
"tg128 at d16384 is the quiet regime" rule is dead at seven engine starts (σ/med
2.6 / 5.5 / 8.01 / 8.26 / 10.95 / 12.22 / 10.90%). No future round should budget
runs at this cell as if it were quiet. The engine log was not captured, an execution
miss against the round's own instrument plan, so the round contributes no residency,
acceptance or prefix-cache samples.

This round supersedes R22's position-bias observation: R22's +6.5% is best read as
four draws from a distribution whose σ/med at this cell runs 8–12%, which is what
R22 itself allowed at p = 0.25. R8c's "+6.36% from the folded budget on Phase 1"
stays refuted, but the explanation changes from an ordering artefact to a draw.
Implication for the next hypothesis: the ordering caveat is closed, and the open
question that outranks everything else is the prefix cache, which has read 0.0% in
220+ engine samples across 17 rounds.
