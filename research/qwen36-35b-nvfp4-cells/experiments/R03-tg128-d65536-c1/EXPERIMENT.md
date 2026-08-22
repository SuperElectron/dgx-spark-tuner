# R03 — `tg128 @ d65536 c1`, the deepest contested cell

objective: take the deepest contested cell and its Phase-1 partner in one invocation — the only round where both board figures were known in advance (16.48 for `tg128 @ d65536 c1`, 20.70 for `ctx_tg @ d65536 c1`).
claim: the decode step at c1 is memory-bound on two reads. The weight read is fixed at ~1.7 GB per step regardless of depth and dominates; the KV read grows with depth but is suppressed twice over — only 10 of 40 layers carry a KV cache (the other 30 are fixed-state Gated DeltaNet) and those 10 are FP8. Doubling context doubles a quarter-width, half-precision term against a fixed dominant one, so expect a gentle decline: median 70–85, centre ~78, a 24% fall from the d16384 figure of 102.2. Second, sharper claim: Phase 1 should come in 55–75, BELOW Phase 2, deepening R01's d32768 inversion — if the inversion is a depth effect it grows at 65536; if it was a three-run artefact it does not reappear.
variables: `depth` raised 16384 → 65536 at c1, runs=3. No recipe mutation; `-o max_model_len=73728` is a probe-driven override to fit depth + pp + tg in one sequence, as R01 did at 40960.
confirms / refutes: the verify repeat becomes mandatory only if the median lands under ~33 (2x incumbent). Two further falsifiable claims declared: `pp2048 @ d65536` lands near 140–150, and σ is above 8% of the median. Named config risk: an engine OOM at startup if the KV arithmetic is wrong.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_dab043abba20 | 2026-08-22T04:55:28Z | depth 65536 at c1, max_model_len 73728 | tg 108.15 (σ 10.41) = 6.56x; ctx_tg 89.76 (σ 1.80) = 4.34x; pp2048 118.59; ctx_pp2048 4004.76 |

## conclusion 2026-08-22T05:00:40Z
Both board cells taken, by the campaign's widest margins to date — 108.15 against
16.48 (6.56x) and 89.76 against 20.70 (4.34x) — and the worst single run of the
Phase-2 cell, 89.23, still clears its incumbent by 5.41x, so no repeat was needed.
The named config risk never materialised and was never close: sparkrun's own VRAM
estimate put the KV cache at 2.81 GB against 75.0 GB available, a 26.7x context
multiplier. Deep cells on this model are not memory-constrained anywhere near
d65536.

The headline prediction was refuted, and refuted **upward**, for the third time in
three rounds. Against a predicted 24% decline the cell read a 5.8% rise at four
times the depth. The honest synthesis is not that deeper is faster — it is that the
depth-dependent term in this model's decode cost is smaller than the run-to-run
noise across the whole measured range. σ here is 10.41 at c1, and R01 saw 22.72 at
the same concurrency; a 5.8% gap between two three-run medians drawn from that
distribution is noise. The claim this round supports is flatness *within noise*, and
separating that from a real rise needs both depths under one engine start at runs=7.
The prefill claim was refuted downward: `pp2048` read 118.59 against a predicted
140–150, a 0.40x ratio from d32768 rather than 0.50x — cold prefill degrades
slightly worse than inverse-linear out here, which is attention's quadratic term
finally becoming visible, and at σ 0.55 the miss is real rather than a draw.

⚠ Superseded, and the two headline findings both fell. "Depth is flat from d16384 to
d65536" was retired by R8, which measured both depths inside one engine start at
runs=7 and read a 16.8% fall (113.06 → 94.10). Physics required monotonicity — per-step
decode work cannot fall as context grows — so every "deeper is faster" reading the
campaign published was always going to be sampling. The −17% Phase-1 inversion was
likewise refuted by R8 at −1.2%, and the claim that "the ctx inversion deepens with
depth" is fully retired: no deep Phase-1 inversion exists anywhere in the campaign's
data and none ever did. The phase labels here are inverted — this is Phase 1, the
*uncached* context load, against Phase 2 — so "removing prefill work hurts decode at
depth" was never a coherent reading, and the round's closing claim that the `ctx_`
cells are "the cheapest place in this campaign to measure a real effect" is
withdrawn with it. What survives from the corrected reading is the campaign's only
honest prefill-rate curve: Phase 1 is charged the tokens it actually processes, so
6148.56 / 5910.22 / 5086.51 / 4004.76 / 2803.17 is the real prefill rate against
depth. Implication for the next hypothesis: stop inferring depth effects across
invocations — put two depths under one engine start at runs=7, which is what R08 was
queued to do.
