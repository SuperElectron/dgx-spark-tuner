# Results — qwen36-35b-nvfp4-cells

Model fixed: nvidia/Qwen3.6-35B-A3B-NVFP4 (de-rayed recipe). The campaign
varies the PROBE, not the config: each round measures a different board cell.
Targets and incumbents per cell: docs/arena-recipe.md.

Nothing is submitted to the arena — there is no login — so this file is the
standings. One row per measured CELL, appended after archiving into
`experiments/<benchId>/`. A single benchmark run measures several cells, so one
benchId spans several rows.

## Standings so far

Cells taken, best figure we have, against the board:

| Cell | Ours | Board top | Margin |
|---|---:|---:|---:|
| tg32 @ d16384 c1 | 116.43 | 28.11 | **4.14x** (revised down by R6, 7 runs) |
| tg32 @ d32768 c1 | 115.56 | 23.31 | **4.96x** |
| tg32 @ d8192 c1 | 106.24 | sole entry, no number | uncontested |
| tg128 @ d16384 c4 | 52.85 | 46.68 | **1.13x**, verified |
| tg128 @ d65536 c1 | 108.15 | 16.48 | **6.56x** |
| ctx_tg128 @ d65536 c1 | 89.76 | 20.70 | **4.34x** |
| tg128 @ d16384 c2 | 84.00 per-req / 168.0 agg | 325.44 (163.27 best vLLM NVFP4) | **UNITS DISPUTED — see below** |
| tg128 @ d16384 c5 | 48.12 per-req / 240.6 agg | 428.95 (225.46 best vLLM NVFP4) | **UNITS DISPUTED — see below** |
| tg128 @ d16384 c8 | 43.51 per-req / ~350 agg | not scraped | cannot be scored |
| tg128 @ d16384 c16 | 40.47 per-req / ~440 agg | not scraped | cannot be scored |
| **tg128 @ d131072 c1** | **77.13** | **81.60** | **0.95x — LOST** |
| tg128 @ d16384 c1 (the crowded cell) | 111.11 | 116.03 best vLLM NVFP4 (188.47 overall) | 0.96x — not a target, see below |

⚠️ **The c4 win's MARGIN is now in question — its direction is not.** R7 found
evidence that the board's c>1 tg figures are AGGREGATE, not per-request. Under
that reading `tg128 @ d16384 c4` is 211.4 vs 46.68 = **4.53x**, not 1.13x. Either
way it is a win. The units are queued for a zero-box-time board check (R5c) and
nothing has been rewritten until that lands.

**Round 7's headline, in three lines.** (1) The concurrency tail is NOT flat —
per-request falls only 7.0% from c8 to c16, against 37% across the single c2->c4
step, and the aggregate is still climbing at 16-way. (2) The campaign's
`aggregate = per-request x c` convention BREAKS at c16 and the correct figure is
~440, not 647.6 — see the concurrency section. (3) The board's c>1 figures look
like aggregates, which would make our c4 win 4.53x rather than 1.13x; queued for
a zero-cost check, not rewritten. No new cell can be scored: c8 and c16 have no
board figures.

**Round 6's headline, and it is a correction to our own numbers.** R6 was a
control round: tg=32 and tg=128 at d16384 c1 in ONE engine start at runs=7. Two
things came out of it that change what is written above.

1. **tg32 @ d16384 c1 is revised DOWN, from 129.32 to 116.43** — still a clear
   win at 4.14x over the incumbent 28.11 (worst of seven runs, 108.96, is still
   3.88x), but R1's 3-run median was a lucky draw and the 7-run figure is what
   this campaign now claims.
2. **The -12% reproduction gap was mostly undersampling.** The inherited tg128 @
   d16384 c1 baseline of 102.2 re-measures at **111.11** over seven runs, so the
   gap against the board's best vLLM NVFP4 entry (116.03) is **-4.2%, not -12%**
   — and two of our seven runs (116.58, 116.66) clear 116.03 outright. That cell
   is the crowded one and was never a campaign target; it is listed above for the
   gap, not as a loss we went after.

The tg32-vs-tg128 puzzle is also settled: shorter generations are NOT faster in
any useful sense. The 26.5% advantage R1 appeared to show is +4.79% under one
engine start, and the round's own prefill controls (pp2048 and ttfr both offset
1.90% between the arms, on work that is identical in both) price the residual
generation-length effect at **~2.9%**.

Six cells taken, and **round 5 is the campaign's first LOSS**: tg128 @ d131072 c1
came in at median 77.13 against Nemotron Lightning NVFP4's 81.60 — short by 5.5%.
That cell was queued as a probable loss, run once for the depth curve, and was
deliberately NOT tuned for; the recipe is unchanged. It is recorded here as a
loss and should be read as one. (One of the three runs, 89.39, did clear 81.60 at
1.10x, but the median is the verdict and the median lost.)

Round 4's two cells (c2, c5) HAVE been scraped since — 325.44 and 428.95, with
best-vLLM-NVFP4 runners-up at 163.27 and 225.46 — but scoring them ran straight
into R7's units dispute above, so they are marked DISPUTED rather than scored.
Round 7's two cells (c8, c16) have no board figures at all and cannot be scored
at any units.

The depth curve at tg128 c1, which is what R5 actually bought:

| depth | ours | board top | margin |
|---:|---:|---:|---|
| 16384 | **111.11** (R6, 7 runs; was 102.2) | 116.03 (best vLLM NVFP4) | 0.96x — gap now -4.2%, was -12% |
| 65536 | 108.15 | 16.48 | **6.56x** |
| 131072 | 77.13 | 81.60 | 0.95x — LOST |

R6 replaced the d16384 point with a 7-run median from this campaign's own engine.
The curve is now 111.11 / 108.15 / 77.13, so the flatness across the first 4x is
*tighter* than it looked (2.7% apart rather than 5.8%) and the fall to d131072 is
31%. Flat from d16384 to d65536, then a 31% fall to d131072. The depth term finally
bites, and it bites between d65536 and d131072 — the first genuine decline the
campaign has measured on any axis.

## Concurrency curve at tg128 @ d16384 — COMPLETE (R4 c1-c5, R7 c8+c16)

Every point satisfies `max_num_seqs >= c`, i.e. **no request ever waits for a
scheduler slot**. That, not a single engine config, is what makes the rows
comparable — the `mns` column is here so you can check it.

| c | mns | per-request | σ/med | aggregate | peak_thr | vs c1 | round |
|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 4 | 111.11 | 2.6% | 111.1 | 119 | 1.00x | R6 (runs=7) |
| 2 | 4 | 84.00 | 1.4% | 168.0 | 182 | 1.51x | R4 |
| 4 | 4 | 52.85 | 0.8% | 211.4 | 291 | 1.90x | R2 (pooled 6 runs) |
| 5 | 4 | 45.60 | 0.6% | 228.0 | 282 | 2.05x | R4 — **queued, superseded** |
| 5 | **5** | 48.12 | 0.15% | 240.6 | 265 | 2.17x | R4 (mutation) |
| 8 | **8** | **43.51** | 0.51% | **~350** | 355 | ~3.2x | **R7 (mutation)** |
| 16 | **16** | **40.47** | **0.15%** | **~440** | 440 | ~4.0x | **R7 (mutation)** |

**THE TAIL IS NOT FLAT — this is R7's headline and it refutes R7's own
prediction.** Per-request fell only **-7.0%** across the c8 -> c16 doubling,
against **-37.1%** across the single c2 -> c4 doubling. The c2-c4 region is
better read as a one-time STEP than as the start of a decline, and everything
past it is a shallow slope. R7 predicted 16-22 per-request at c16 and measured
40.47 — a miss of 84%, the campaign's fourth upward refutation.

Strict time-slicing with no batching benefit would put c16 at 111.11/16 = 6.9.
Measured 40.47 is **5.9x above that line**: batching is still doing most of the
work at 16-way that it does at 1-way.

**Why the c8 and c16 aggregates read "~350" and "~440" rather than exact.** This
campaign computed aggregate as `per-request x c`. That identity **breaks between
c8 and c16**: at c16 it gives 647.6 while `peak_throughput` — which is a PEAK and
therefore an upper bound on the sustained figure — reads only 440. A sustained
number cannot exceed a peak, so ~~647.6~~ is invalid and is not claimed. Cause:
`--max-num-batched-tokens 8192` was not raised alongside `max_num_seqs`, so at
d16384 the token budget gated admission and the engine held a median of **9 of 16
sequences resident** (Waiting median 6, from 42 scheduler samples in the archived
engine log). `peak_throughput / peak_req_throughput` corroborates it: 7.0 of 8 at
c8, 11.9 of 16 at c16. Matching `max_num_seqs` was necessary and **not
sufficient**; the completed mutation is queued as R10.

The aggregate is nonetheless **still climbing at 16-way**: ~440 vs ~350 is +24%,
above the +15% threshold R7 wrote down in advance. The MoE-expert-coverage
mechanism — the reason to expect this A3B model's tail to flatten harder than a
dense model's — is not binding anywhere below c16.

⚠️ **UNITS DISPUTE, and it reaches the campaign's only marginal win.** The board's
c>1 tg figures RISE with concurrency for a fixed model — LFM2.5-350M reads
188.47 / 325.44 / 428.95 at c1/c2/c5, and our like-for-like
Qwen3.6-35B-A3B-NVFP4 on vLLM reads 116.03 / 163.27 / 225.46. Per-request
throughput cannot rise with concurrency. Those shapes (1.00/1.41/1.94) track
**our aggregate** series (1.00/1.51/2.17) and look nothing like **our
per-request** series (1.00/0.76/0.43). So the board figure is probably an
aggregate, and every c>1 comparison this campaign has made compared the wrong
two quantities. Under the aggregate reading c2 is 168.0 vs 163.27 (1.03x), c5 is
240.6 vs 225.46 (1.07x), and **c4 is 211.4 vs 46.68 = 4.53x rather than 1.13x**.
Counter-evidence, unresolved: 46.68 as an aggregate at c4 implies 11.7 tok/s per
request for Gemma-4-26B-A4B-NVFP4, which is very slow — though the c4 cell is
thin (8 entries, large models) while c2/c5 are crowded (130/120, topped by a
350M), so the magnitude gap may be population rather than metric. **Queued as
R5c, a zero-box-time board check. Nothing has been rewritten until it lands.**

Raising `--max-num-seqs` to match the probe is worth +5.5% at c5 — a real effect
(σ 0.07 and 0.26, run ranges disjoint) — and R7 confirms it is a QUEUEING effect
and not a batch-size one: at c16 the batch is 4x larger than R4's and `pp2048`
is undisturbed at 628.74, against the 581.44 R4 measured when the fifth request
queued. NOT folded into recipe.yaml: the campaign recipe stays unmutated at
`--max-num-seqs 4`. The two deep cells are the campaign's widest margins, and
`ctx_tg @ d65536 c1` is the FIRST prefix-caching cell we can actually claim —
it is the only `ctx_` cell whose board figure was ever scraped.

Cells measured but NOT claimed, because docs/arena-recipe.md never scraped their
board figures: every other `ctx_` prefix-caching cell and every `pp2048` cell
below. Scraping those six-plus figures is the cheapest standings gain available —
the numbers are already measured and sitting in the tables.

## Reading these tables

tg/pp columns are MEDIANS of the runs — means are not verdicts (MTP acceptance
is bimodal). σ is the run standard deviation, kept as the noise flag.
`ctx_` rows are the prefix-caching phase of the same run (a separate board cell).

**How many runs a cell needs (revised by R6).** "c1 is the noisy regime" is not
right: what drives σ is how many MTP verify steps a measurement averages over and
how good acceptance is in that regime. Long generations at shallow depth are
quiet even at c1 — tg128 @ d16384 c1 came in at σ 2.6%, the campaign's quietest
c1 cell — while short generations (tg32: 9.9-21.4%) and deep contexts (tg128 @
d65536: 9.6%, @ d131072: 9.3%) are not. Three runs are enough for tg128 at
d16384; anything tg32, and anything at d65536 or deeper, needs seven. R7 extends
this to the top of the concurrency range: c8 and c16 gave σ 0.51% and **0.15%**,
the quietest cells the campaign has measured, because raising c multiplies the
sequences averaged per verify step — the same lever as lengthening the
generation. Three runs is generous there.

**tg t/s is PER-REQUEST, not aggregate — and `per-request x c` is not always the
aggregate either.** At c1 the two coincide. Through c8, `per-request x c` and
`peak_throughput` agree within 2-8% and either serves. At c16 they diverge by
47% and `per-request x c` is simply wrong: `tg t/s` is a request's decode rate
*while it is running*, so multiplying by nominal concurrency counts requests that
are queued. Whenever `mns >= c` is satisfied and the numbers still disagree,
suspect the `--max-num-batched-tokens` budget and trust `peak_throughput`, which
at least bounds the sustained figure from above. **And see the units dispute
above before comparing any c>1 row against a board figure.**

## Generation cells (tg)

| benchId | date | cell / probe | tg med t/s | tg σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d8192 c1 | 106.24 | 22.72 | 1737.93 | sole entry | win — no number published to beat |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d16384 c1 | 129.32 | 18.38 | 3230.01 | 28.11 | win — 4.60x incumbent |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d32768 c1 | 115.56 | 10.40 | 6937.09 | 23.31 | win — 4.96x incumbent |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d8192 c1 | 126.52 | 7.94 | 1345.97 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d16384 c1 | 130.16 | 3.01 | 2787.86 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d32768 c1 | 84.03 | 10.69 | 6453.91 | not scraped | hold — board figure unknown |
| bench_f58c56da6658 | 2026-08-21 | tg128 @ d16384 c4 | 53.56 | 0.43 | 10167.05 | 46.68 | win — 1.15x, verify required at this margin |
| bench_f58c56da6658 | 2026-08-21 | ctx_tg128 @ d16384 c4 | 56.40 | 0.16 | 8554.95 | not scraped | hold — board figure unknown |
| bench_f58c56da6658-verify | 2026-08-21 | tg128 @ d16384 c4 | 52.69 | 0.75 | 10151.35 | 46.68 | win CONFIRMED — pooled median of 6 runs 52.85 = 1.13x; worst single run 51.25 still +9.8% |
| bench_f58c56da6658-verify | 2026-08-21 | ctx_tg128 @ d16384 c4 | 55.92 | 0.62 | 8641.49 | not scraped | hold — pooled median 56.36 |
| bench_dab043abba20 | 2026-08-21 | tg128 @ d65536 c1 | 108.15 | 10.41 | 17281.66 | 16.48 | win — 6.56x incumbent; worst of 3 runs 89.23 still 5.41x |
| bench_dab043abba20 | 2026-08-21 | ctx_tg128 @ d65536 c1 | 89.76 | 1.80 | 16377.23 | 20.70 | win — 4.34x incumbent; first ctx_ cell with a known board figure |
| bench_0ef7af8997ce | 2026-08-22 | tg128 @ d16384 c2 | 84.00 | 1.18 | 5657.56 | not scraped | hold — no incumbent; aggregate 168.0, 82% scaling efficiency vs c1 |
| bench_0ef7af8997ce | 2026-08-22 | ctx_tg128 @ d16384 c2 | 79.44 | 1.06 | 4825.98 | not scraped | hold — BELOW cold (-5.4%), first below-cold ctx_ at this depth |
| bench_0ef7af8997ce | 2026-08-22 | tg128 @ d16384 c5 (max_num_seqs 4, unmutated) | 45.60 | 0.26 | 11866.00 | not scraped | hold — scheduler-limited: fifth request queues; aggregate 228.0 |
| bench_0ef7af8997ce | 2026-08-22 | ctx_tg128 @ d16384 c5 (max_num_seqs 4) | 48.18 | 0.31 | 9914.85 | not scraped | hold — above cold (+5.7%) |
| bench_858173ba5753-mns5 | 2026-08-22 | tg128 @ d16384 c5 (MUTATION max_num_seqs 5) | 48.12 | 0.07 | 12088.40 | not scraped | hold — best c5 figure; +5.5% over the unmutated arm; mutation NOT kept in recipe.yaml |
| bench_858173ba5753-mns5 | 2026-08-22 | ctx_tg128 @ d16384 c5 (MUTATION max_num_seqs 5) | 51.25 | 0.26 | 9850.01 | not scraped | hold — above cold (+6.5%) |
| bench_076db52d341c | 2026-08-22 | tg128 @ d131072 c1 | 77.13 | 7.17 | 48102.89 | 81.60 | **LOSS — 0.95x, short by 5.5%**; runs 72.37 / 89.39 / 77.13, best run alone would have won at 1.10x. Not tuned for, by design |
| bench_076db52d341c | 2026-08-22 | ctx_tg128 @ d131072 c1 | 76.66 | 10.16 | 46770.69 | not scraped | hold — level with cold (-0.6%), and NOISIER than cold (σ 13.3% vs 9.3%): first round where the ctx_ phase is the noisy one |
| bench_dd3afc9e1c94 | 2026-08-22 | tg32 @ d16384 c1 (**runs=7**) | 116.43 | 11.55 | 3298.58 | 28.11 | **win — 4.14x incumbent**; REVISES R1's 3-run 129.32 down 10.0%; worst of 7 runs 108.96 still 3.88x |
| bench_dd3afc9e1c94 | 2026-08-22 | tg128 @ d16384 c1 (**runs=7**) | 111.11 | 2.91 | 3237.23 | 116.03 best vLLM NVFP4 (188.47 overall) | **reproduction gap now -4.2%, was -12%** — replaces the inherited 102.2 baseline (+8.7%); 2 of 7 runs (116.58, 116.66) clear 116.03. Crowded cell, never a campaign target, not tuned for. σ 2.6% is the QUIETEST c1 cell in the campaign |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_tg32 @ d16384 c1 (runs=7) | 122.97 | 8.44 | 2850.87 | not scraped | hold — ABOVE cold (+5.62%), and quieter than cold (6.9% vs 9.9%) |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_tg128 @ d16384 c1 (runs=7) | 104.85 | 9.73 | 2813.42 | not scraped | hold — BELOW cold (-5.63%), opposite sign to the tg32 arm in the SAME invocation; and NOISIER than cold (9.3% vs 2.6%) |
| bench_0954971b5dfa | 2026-08-22 | tg128 @ d16384 c8 (**MUTATION max_num_seqs 8**) | 43.51 | 0.22 | 16554.28 | not scraped | hold — no incumbent. Aggregate ~350 (c x tg 348.1, peak_throughput 355 — estimators AGREE here). σ 0.51% |
| bench_0954971b5dfa | 2026-08-22 | ctx_tg128 @ d16384 c8 (MUTATION max_num_seqs 8) | 47.75 | 0.05 | 13969.54 | not scraped | hold — ABOVE cold (+9.7%), and quieter (σ 0.10%) |
| bench_a769c1142e15 | 2026-08-22 | tg128 @ d16384 c16 (**MUTATION max_num_seqs 16**) | 40.47 | 0.06 | 29751.25 | not scraped | hold — no incumbent. **Only -7.0% below c8 across a DOUBLING** — the tail is not flat. Aggregate **~440** (peak_throughput); ~~c x tg = 647.6~~ INVALID, it exceeds the peak — only 9 of 16 seqs were resident (max_num_batched_tokens 8192 gated admission). σ **0.15%**, the campaign's tightest tg measurement |
| bench_a769c1142e15 | 2026-08-22 | ctx_tg128 @ d16384 c16 (MUTATION max_num_seqs 16) | 45.61 | 0.08 | 25310.86 | not scraped | hold — ABOVE cold (+12.7%); the ctx-vs-cold margin now GROWS monotonically with concurrency: +6.6% (c4), +6.5% (c5), +9.7% (c8), +12.7% (c16) |

## Prefill cells (pp2048)

pp2048 rides along in every round by default, so these were measured at no extra
cost. They are separate board cells and get their own rows. The cold rows fall
steeply with depth because they prefill the whole context; the `ctx_` rows reuse
the cached prefix and sit an order of magnitude higher.

| benchId | date | cell / probe | pp med t/s | pp σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d8192 c1 | 1187.51 | 26.39 | 1737.93 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d16384 c1 | 637.09 | 3.76 | 3230.01 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d32768 c1 | 295.71 | 0.78 | 6937.09 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp2048 @ d8192 c1 | 6148.56 | 15.56 | 1345.97 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp2048 @ d16384 c1 | 5910.22 | 36.03 | 2787.86 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp2048 @ d32768 c1 | 5086.51 | 23.20 | 6453.91 | not scraped | hold — board figure unknown |
| bench_f58c56da6658 | 2026-08-21 | pp2048 @ d16384 c4 | 644.01 | 1.12 | 10167.05 | not scraped | hold — board figure unknown |
| bench_f58c56da6658 | 2026-08-21 | ctx_pp2048 @ d16384 c4 | 5967.41 | 22.51 | 8554.95 | not scraped | hold — board figure unknown |
| bench_f58c56da6658-verify | 2026-08-21 | pp2048 @ d16384 c4 | 642.82 | 1.47 | 10151.35 | not scraped | hold — pooled median 643.31 |
| bench_f58c56da6658-verify | 2026-08-21 | ctx_pp2048 @ d16384 c4 | 5924.46 | 30.56 | 8641.49 | not scraped | hold — pooled median 5924.76 |
| bench_dab043abba20 | 2026-08-21 | pp2048 @ d65536 c1 | 118.59 | 0.55 | 17281.66 | not scraped | hold — board figure unknown |
| bench_dab043abba20 | 2026-08-21 | ctx_pp2048 @ d65536 c1 | 4004.76 | 12.92 | 16377.23 | not scraped | hold — board figure unknown |
| bench_0ef7af8997ce | 2026-08-22 | pp2048 @ d16384 c2 | 634.04 | 0.48 | 5657.56 | not scraped | hold — flat against c1's 637.09 and c4's 643.31 |
| bench_0ef7af8997ce | 2026-08-22 | ctx_pp2048 @ d16384 c2 | 5810.28 | 47.04 | 4825.98 | not scraped | hold — board figure unknown |
| bench_0ef7af8997ce | 2026-08-22 | pp2048 @ d16384 c5 (max_num_seqs 4) | 581.44 | 2.22 | 11866.00 | not scraped | hold — the ONLY depressed prefill row at this depth (-9.6%): the queued fifth prefill is what falls |
| bench_0ef7af8997ce | 2026-08-22 | ctx_pp2048 @ d16384 c5 (max_num_seqs 4) | 5236.80 | 38.23 | 9914.85 | not scraped | hold — also depressed vs 5810-5967 elsewhere at this depth |
| bench_858173ba5753-mns5 | 2026-08-22 | pp2048 @ d16384 c5 (MUTATION max_num_seqs 5) | 640.21 | 1.68 | 12088.40 | not scraped | hold — mutation restores prefill to the c2/c4 level |
| bench_858173ba5753-mns5 | 2026-08-22 | ctx_pp2048 @ d16384 c5 (MUTATION max_num_seqs 5) | 5869.43 | 16.83 | 9850.01 | not scraped | hold — likewise restored |
| bench_076db52d341c | 2026-08-22 | pp2048 @ d131072 c1 | 42.59 | 0.02 | 48102.89 | not scraped | hold — 0.359x of d65536, steepening again (0.50x, then 0.40x, now 0.36x per doubling); campaign's tightest measurement, σ 0.05% |
| bench_076db52d341c | 2026-08-22 | ctx_pp2048 @ d131072 c1 | 2803.17 | 2.43 | 46770.69 | not scraped | hold — 0.70x of d65536, the steepest fall in the cached-prefill series |
| bench_dd3afc9e1c94 | 2026-08-22 | pp2048 @ d16384 c1 (tg32 arm, runs=7) | 623.13 | 8.72 | 3298.58 | not scraped | hold — R6 CONTROL: identical prefill work to the tg128 arm below, so the 1.90% gap between them prices the arm-to-arm systematic |
| bench_dd3afc9e1c94 | 2026-08-22 | pp2048 @ d16384 c1 (tg128 arm, runs=7) | 634.99 | 2.77 | 3237.23 | not scraped | hold — control passes (1.90% < 2% threshold), matching the flat d16384 series 637.09 / 634.04 / 643.31 |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_pp2048 @ d16384 c1 (tg32 arm, runs=7) | 5772.30 | 75.83 | 2850.87 | not scraped | hold — in line with the 5810-5967 series at this depth |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_pp2048 @ d16384 c1 (tg128 arm, runs=7) | 5849.11 | 56.10 | 2813.42 | not scraped | hold — 1.33% above the tg32 arm, same direction as the cold control |
| bench_0954971b5dfa | 2026-08-22 | pp2048 @ d16384 c8 (MUTATION max_num_seqs 8) | 631.25 | 0.31 | 16554.28 | not scraped | hold — R7 CONTROL PASSES: inside the flat 623-643 d16384 series, so matching the scheduler width eliminated R4's chunked-prefill interference |
| bench_0954971b5dfa | 2026-08-22 | ctx_pp2048 @ d16384 c8 (MUTATION max_num_seqs 8) | 5796.89 | 1.72 | 13969.54 | not scraped | hold — in line with the 5772-5967 series at this depth |
| bench_a769c1142e15 | 2026-08-22 | pp2048 @ d16384 c16 (MUTATION max_num_seqs 16) | 628.74 | 0.70 | 29751.25 | not scraped | hold — CONTROL PASSES at 4x R4's batch size: the c5 depression to 581.44 was a QUEUEING effect, not a batch-size effect. Strengthens R9's premise |
| bench_a769c1142e15 | 2026-08-22 | ctx_pp2048 @ d16384 c16 (MUTATION max_num_seqs 16) | 5791.30 | 11.10 | 25310.86 | not scraped | hold — flat against the c8 arm (-0.1%) |
