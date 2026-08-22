# R01 — tg32 across three depths at c1

objective: score the two published `tg32` board cells (28.11 at d16384, 23.31 at d32768) and get a first reading of how decode throughput bends with context depth.
claim: `tg32` measures the same decode loop over 32 tokens instead of 128, so fixed per-request overhead — prefill handoff, first-token latency, MTP warm-up — is amortised over 4x fewer tokens and the figure should land *somewhat below* the `tg128 @ d16384 c1` baseline of 102.2; expect 85–100 at d16384, less at d32768 as the KV read grows. Depth should cost little: only 10 of 40 layers carry a KV cache (the other 30 are fixed-state Gated DeltaNet) and it is stored FP8, so d8192 → d32768 should bend gently rather than cliff.
variables: no recipe mutation — the incumbent recipe with a new probe. `depth` swept 8192 / 16384 / 32768 at `tg 32`, `pp 2048`, c1, runs=3. `max_model_len` raised 32768 → 40960 so the deepest point fits depth + pp + tg in one sequence.
confirms / refutes: none declared. This round predates the campaign's practice of fixing bands before the run.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_25a0e7f36ab0 | 2026-08-22T04:31:36Z | tg32 at depth 8192 / 16384 / 32768, c1, runs=3 | tg32 medians 106.24 / 129.32 / 115.56; ctx_tg32 medians 126.52 / 130.16 / 84.03. d16384 4.60x, d32768 4.96x over the board |

## conclusion 2026-08-22T04:35:15Z
The two published `tg32` cells fall by a wide margin — 129.32 against 28.11 at
d16384 (4.60x) and 115.56 against 23.31 at d32768 (4.96x) — and the worst single
run of any cell (73.07) still clears every incumbent by 2.6x, so the margins do not
need a verify repeat. The *hypothesis*, though, is refuted in the direction that
matters: the prediction was 85–100 at d16384, below the `tg128` baseline of 102.2,
and it came in above that baseline at every depth. Whatever `tg32` costs in
amortisation is smaller than something running the other way.

What got better: two board cells scored on the first round. What got worse: the
round bought no depth curve at all. Medians did not restore monotonicity —
106.24 < 129.32 > 115.56, with the shallowest and cheapest point the slowest — and
three runs cannot rank these depths. d8192 spans 73.07 to 128.35 inside one cell, a
1.76x spread whose σ of 22.72 is larger than the entire spread between the three
cell medians. Means and medians disagree in *direction* here, which is exactly why
the campaign reports medians. The curve needs runs=7+ at fixed depth, not more
depths. An instrument fault was fixed mid-round: `parse-round.py` labelled all six
benchmarks with an identical header and the cells had to be matched by hand.

⚠ Superseded, extensively. "tg32 is 26.5% faster than tg128" was retired by R6 —
it is ~2.9%. The `ctx_` readings in this round were described as prefix-caching
phases with the prefill work removed; the phase-label correction retired that
wholesale — Phase 1 is the *uncached* context load and prefills `depth` tokens.
The −27.3% Phase-1 inversion at d32768 (the 84.03) was fully retired by R8c, which
re-measured at runs=7 and read +0.9%, and R22 confirmed it at runs=14 across both
budgets. The `tg32 @ d8192` figure of 106.24 failed R21's ±10% reproduction band at
+16.54% and was retired outright, replaced by 123.81. The `tg32 @ d32768` 115.56 /
4.96x is likewise retired in favour of a 24-run pooled 115.85 / 4.97x. Implication
for the next hypothesis: measure fewer cells with more runs, and get the `tg128`
baseline under a controlled comparison before reading anything into the tg32-vs-tg128
gap.
