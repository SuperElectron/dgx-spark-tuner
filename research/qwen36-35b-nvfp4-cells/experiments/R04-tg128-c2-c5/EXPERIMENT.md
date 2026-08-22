# R04 — the concurrency curve at c2 and c5, and the first recipe mutation

objective: put a shape on the concurrency scaling curve at `tg128 @ d16384`, not to take a headline — neither c2 nor c5 has a scraped board figure, so the verdict is a curve and both rows carry "not scraped".
claim: a 35B-A3B MoE is memory-bound on a fixed ~1.7 GB weight read per decode step which every sequence in the step shares, so adding sequences buys aggregate throughput until something saturates. If the c1→c4 curve is roughly logarithmic, c2 sits nearer the top — predict 75–88, centre ~81. At c5 the recipe's `--max-num-seqs 4` means only four sequences decode and the fifth queues, so its wait should land in TTFT rather than in decode rate: predict c5 unchanged from c4 at 48–54 with ttfr up 20–30%. Raising the scheduler width to 5 should LOWER per-request throughput to 44–49, because five sequences would genuinely share every step.
variables: `concurrency` set to 2 and 5 against the shipped `max_num_seqs 4` in one invocation; then `max_num_seqs` raised 4 → 5 at c5 alone, the campaign's first recipe mutation, journaled and deliberately not folded. runs=3. No `max_model_len` override — the first round in three that needed none.
confirms / refutes: if c5 instead comes in near 42 (= aggregate/5), the per-request metric is being computed over wall time including queue wait, and every `c>1` figure in the campaign needs re-reading. Noise declared in advance: σ ~1–3% at c2 and under 1.5% at c5; if c2 comes back as noisy as c1, the "averaging sequences kills the variance" story needs a threshold nobody has posited.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_0ef7af8997ce | 2026-08-22T05:31:23Z | c2 and c5 at the shipped max_num_seqs 4 | c2 84.00 (σ 1.18), ctx 79.44; c5 45.60 (σ 0.26), ctx 48.18; pp2048 falls to 581.44 at c5 |
| bench_858173ba5753-mns5 | 2026-08-22T05:37:05Z | max_num_seqs raised 4 → 5, c5 only | c5 48.12 (σ 0.07) = +5.5% over the same point at mns 4; ctx 51.25; pp2048 back to 640.21 |

## conclusion 2026-08-22T05:42:03Z
No win and no loss, by construction — the round was run for the curve. The c2
prediction was the campaign's first accurate one: predicted 75–88 centre ~81,
measured 84.00, at 82% scaling efficiency against a predicted 79%. That contrast is
the round's methodological lesson: interpolating between our own measured cells
works, and reasoning forward from the model card does not. The knee sits between c2
and c4, not above it — c1→c2 costs 18% of per-request throughput to buy 64% more
aggregate, while c2→c4 costs another 37% to buy 26% more.

Both c5 predictions were refuted, in opposite directions, and both refutations are
informative. At `max_num_seqs 4`, c5 read 45.60 — below the predicted band and 13.7%
under c4 — so the four decoding sequences are *not* running at c4 speed; the named
alternative signature of a wall-time metric (~42) did not happen either, so R02's
units reading survives. Raising the scheduler width to 5 was predicted to cost
per-request throughput and instead bought +5.5% on both per-request and aggregate:
the queueing penalty is larger than the wider-batch penalty. The prefill rows show
the mechanism and are the round's real instrument — `pp2048 @ d16384` is flat to
within 1.5% at c1/c2/c4 (637.09 / 634.04 / 643.31), falls 9.6% to 581.44 at c5 under
`mns 4`, and goes straight back to 640.21 once the width matches. The trade-off is
therefore: matching scheduler width to concurrency buys throughput at both ends and
costs nothing measurable here, but the honest reading is narrower than "5 beats 4" —
it is "the scheduler width should match the concurrency the probe asks for". The
mutation was NOT folded; folding it would silently change every future round's
meaning. Noise held on both counts, and c2's 1.4% against c1's 14% is the first
evidence about the *shape* of the suppression: most of the variance is gone by the
second sequence.

⚠ Superseded on its mechanism, though not on its numbers. This round named
**chunked-prefill interference** as the cause of the c5 deficit; R09b refuted that —
the cause is queueing at `c > max_num_seqs`, and chunked prefill in fact *protects*
decode, since turning it off cuts `tg_req` 44% at c4 while improving stagger and
ttfr. The per-request framing throughout is retired by R10: at `c>1` the headline
field is a batch aggregate, so the "aggregate = per-request x c" column in the curve
table double-counts. The `ctx_` phase labels are inverted throughout — read Phase 1,
the uncached context load — and the round's observation that the ctx-vs-cold sign
varies with concurrency was dissolved by the phase-label correction rather than
explained. The c2 (84.00) and c5 (48.12) figures are three-run pre-fold baselines,
still provisional, deliberately declined for re-measurement by R21 because both lose
by more than 2x; they must not be quoted as measurements. Telemetry was sampled
alongside a round for the first time — 339 samples, SM clock pinned at 2392 MHz
median, 72 °C peak, 95 W peak — which rules out thermal throttling and clock
instability, and contradicts R01's 2554 MHz reading, so the clock figure is not
stable across sessions. Implication for the next hypothesis: R07 should measure one
concurrency per round with `--max-num-seqs` matched at every point.
