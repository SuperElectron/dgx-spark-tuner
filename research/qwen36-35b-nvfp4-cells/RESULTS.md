# Results — qwen36-35b-nvfp4-cells

Model fixed: nvidia/Qwen3.6-35B-A3B-NVFP4 (de-rayed recipe). The campaign
set out to vary the PROBE, not the config — though from R9 onward its largest
results came from scheduler MUTATIONS, which is why every row below names its
configuration. `recipe.yaml` itself is still untouched.
Targets and incumbents per cell: docs/arena-recipe.md.

**The campaign ran 12 rounds and is closed. The synthesis — what held, what was
retracted, the cost ledger and where to pick up — is the last section of
`journal.md`.** Read this file for the standings and that section for the story.

Nothing is submitted to the arena — there is no login — so this file is the
standings. One row per measured CELL, appended after archiving into
`experiments/<benchId>/`. A single benchmark run measures several cells, so one
benchId spans several rows.

## Standings so far

Every row names its CONFIGURATION. "campaign config" is `recipe.yaml`
unmutated (`--max-num-seqs 4 --max-num-batched-tokens 8192`); a **MUTATION**
row was measured with the named `-o` overrides and is NOT what `recipe.yaml`
does. A tuned row and an untuned row must never look alike here.

### WON — 8 board cells (10 rows: two cells carry both a campaign-config and a mutation figure)

| Cell | Configuration | Ours | Board top | Margin | Note |
|---|---|---:|---:|---:|---|
| tg32 @ d16384 c1 | campaign config, runs=7 | 116.43 | 28.11 | **4.14x** | revised DOWN by R6 from R1's 3-run 129.32 |
| tg32 @ d32768 c1 | campaign config, runs=3 | 115.56 | 23.31 | **4.96x** | ⚠ 3-run figure, provisional — see the runs-budget note |
| tg32 @ d8192 c1 | campaign config, runs=3 | 106.24 | sole entry, no number published | uncontested | ⚠ 3-run figure, provisional |
| tg128 @ d16384 c4 | campaign config, 6 runs pooled | 52.85 | 46.68 | **1.13x** | verified by repeat; worst of 6 runs 51.25 still +9.8% |
| tg128 @ d16384 c4 | **MUTATION mnbt 32768**, runs=7 | **147.25** | 46.68 | **3.15x** | R10; reproduces R9's A1 143.08 to 2.9% from a separate start |
| ctx_tg @ d16384 c4 | campaign config, 6 runs pooled | 56.36 | 27.68 | **2.04x** | |
| ctx_tg @ d16384 c4 | **MUTATION mnbt 32768**, runs=7 | **126.35** | 27.68 | **4.56x** | R10 |
| tg128 @ d65536 c1 | campaign config, runs=7 | 94.10 | 16.48 | **5.71x** | revised DOWN by R8 from R3's 3-run 108.15 |
| ctx_tg @ d65536 c1 | campaign config, runs=7 | 92.98 | 20.70 | **4.49x** | revised by R8 from R3's 89.76 |
| ctx_pp @ d65536 c1 | campaign config, runs=7 | 4013.59 | 1393.35 | **2.88x** | ⚠ mapping caveat — see the prefill section |

### LOST — 12 board cells, and they are recorded as plainly as the wins

| Cell | Configuration | Ours | Board top | Like-for-like | Verdict |
|---|---|---:|---:|---:|---|
| tg128 @ d131072 c1 | campaign config, runs=3 | 77.13 | 81.60 (Nemotron Lightning NVFP4) | — | **0.95x — LOST**, short by 5.5%. ⚠ 3-run |
| tg128 @ d16384 c2 | campaign config | 84.00 | 325.44 (LFM2.5-350M BF16) | 163.27 (board's own Qwen3.6-35B-A3B-NVFP4, vLLM) | **0.51x — LOST** |
| tg128 @ d16384 c2 | **MUTATION mnbt 32768 + mns 5**, runs=7 | 140.77 | 325.44 | 163.27 | **0.86x — still LOST**, was 0.51x |
| tg128 @ d16384 c5 | campaign config + mns 5 | 48.12 | 428.95 (LFM2.5-350M BF16) | 225.46 (Qwen3.6-35B-A3B-NVFP4-Fast, vLLM) | **0.21x — LOST** |
| tg128 @ d16384 c5 | **MUTATION mnbt 32768 + mns 5**, runs=7 | 128.93 | 428.95 | 225.46 | **0.57x — still LOST**, was 0.21x |
| ctx_tg @ d8192 c1 | campaign config (tg32 arm), runs=3 | 126.52 | 207.60 (LFM2.5-350M BF16) | 118.07 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | **0.61x — LOST** to the top; **1.07x** over best vLLM+NVFP4. ⚠ 3-run |
| ctx_tg @ d16384 c1 | campaign config (tg32 arm), runs=7 | 122.97 | 193.09 (LFM2.5-350M BF16) | 153.86 (our own model on Atlas) | **0.64x — LOST**; best vLLM+NVFP4 not in the scrape |
| ctx_tg @ d32768 c1 | campaign config (tg32 arm), runs=3 | 84.03 | 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**) | 116.65 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | **0.72x — LOST** both ways. ⚠ 3-run |
| pp2048 @ d8192, d16384, d32768 c1 (3 cells) | campaign config | 1187.51 / 637.09 / 295.71 | 215894 / 99229 / 63080 (all Atlas) | 4644.54 at d32768 | **LOST, ~0.006x of top and 0.064x of best vLLM** — the size of that gap is itself a warning, see the prefill section |
| ctx_pp @ d8192, d16384, d32768 c1 (3 cells) | campaign config | 6148.56 / 5856.93 / 5086.51 | 775123 / 884765 / 945271 (all Atlas) | not in scrape | **LOST by ~150x** — same warning |

### CANNOT BE SCORED — the board has no figure for these cells

`tg128 @ d16384 c8` (43.51, peak_thr 355) and `c16` (40.47 / peak_thr 440 at
campaign config; 53.45 / peak_thr **515** at mnbt 32768) — the scrape covers
c1, c2, c4 and c5 only. `ctx_tg @ d16384` at c2 (127.09) and c5 (104.75), and
every `pp2048`/`ctx_pp` cell at `c>1` — the board's prefill and context cells
are c1 only. `ctx_tg @ d131072 c1` (76.66) — never scraped. `pp2048 @ d65536
c1` (119.54) — the board has **zero entries** at that depth, so it is an empty
cell rather than a won one, and nothing can be posted to it anyway. All
sixteen R9b rows — three flags from the campaign config, explicitly diagnostic.

`tg128 @ d16384 c1` (112.62 pooled over 14 runs, R6+R8) is the crowded cell and
was never a campaign target: 116.03 best vLLM NVFP4, 188.47 overall, so 0.97x
against like-for-like. It is listed for the reproduction gap (now **-2.9%**),
not as a cell we went after.

⚠️ **Round 8 revised the campaign's second-widest win DOWN by 13%, and killed
the "depth is flat" reading.** `tg128 @ d65536 c1` was claimed at 108.15 on
three runs; seven runs under one engine start put it at **94.10**, so the margin
is **5.71x, not 6.56x**. It is still a large win — the worst of the seven runs,
81.79, is 4.96x — but the figure was overstated. Same cause as R1's tg32: a
3-run median at a noisy cell (σ 9.0% here). See the depth curve below.

✅ **UNITS RESOLVED — R10 read the instrument instead of inferring from it, and it
cost no box time.** llama-benchy 0.4.0's `results.py` settles both open questions
that hung over every `c>1` row:

    run_metric_tg_throughput = self._calculate_metric(
        agg_batch_tg_throughputs if concurrency > 1 else agg_tg_speeds)
    ...
    tg_duration = max_last_token - min_first_token
    batch_tg_throughput = observed_decode_tokens / tg_duration

At `c>1`, **`tg_throughput` is a BATCH AGGREGATE** — every request's decode
tokens over the span from the first request's first token to the last request's
last token. At c1 it is assigned the per-request value *by construction*, so
R2's proof ("they are equal at c1") was a tautology and said nothing about
`c>1`. And sparkrun uploads llama-benchy's own CSV, whose `t_s` column is this
same field (`llama_benchy.py`, `_CSV_HEADERS`), so **the board's figure is the
same aggregate we already record.**

Three consequences, and they run in both directions:

1. **`aggregate = per-request x c` was never right — it double-counts.** That is
   why it kept exceeding `peak_throughput`. The `~350` and `~440` figures this
   table carried for c8 and c16 were `peak_throughput` and remain correct; the
   `per-req` labels on the c2/c5/c8/c16 rows were wrong and are removed.
2. **The c4 win keeps its original margin. 52.85 vs 46.68 = 1.13x, comparing the
   same quantity.** R7's alternative reading — 211.4 vs 46.68 = 4.53x — compared
   our double-counted figure against their aggregate and is **withdrawn**.
3. **c2 and c5 are LOSSES, not "disputed".** 84.00 vs 163.27 and 48.12 vs 225.46,
   against the board's own Qwen3.6-35B-A3B-NVFP4 on vLLM — same model, same
   runtime, same quant, same metric. Their series RISES with concurrency
   (116.03 / 163.27 / 225.46) while ours FALLS (112.62 / 84.00 / 48.12). That is
   a config gap, not a metric gap, and R10 found what most of it is.

⚠️ **AND THE CONFIG GAP IS PARTLY FIXABLE — this is R10's standings headline.**
Because the metric divides by a span that includes admission stagger, a
starved token budget is charged twice: it lowers occupancy AND stretches the
span. Raising `--max-num-batched-tokens` from 8192 to 32768 moves
`tg128 @ d16384 c4` from **52.85 to 147.25** at runs=7 — **1.13x becomes 3.15x**
against the same incumbent — and R9's independent 3-run measurement of the same
change (143.08) agrees to 2.9%. **The mutation is NOT folded into recipe.yaml**;
see the journal's R10 outcome for why, and R11 for the fold decision.

🔬 **Round 12 priced the config gap, and it is almost entirely admission
stagger.** R12 ran c2 and c5 at `max_num_batched_tokens 32768` + `max_num_seqs 5`
under ONE engine start at runs=7. Both cells are **still losses** and are
recorded as such — but c2 goes **84.00 → 140.77** (0.51x → **0.86x** of 163.27)
and c5 goes **48.12 → 128.93** (0.21x → **0.57x** of 225.46), against the board's
own Qwen3.6-35B-A3B-NVFP4 on vLLM.

Because `tg = c × tg_req / stagger`, a zero-stagger run of the same engine is
just `c × tg_req`, and that bound splits the residual gap:

| cell | ours | zero-stagger bound | incumbent | stagger's share of the gap | decode's share |
|---|---:|---:|---:|---:|---:|
| c2 | 140.77 (stagger **1.13**) | **159.46** = 0.98x | 163.27 | **83%** | 17% |
| c5 | 128.93 (stagger **1.70**) | **218.60** = 0.97x | 225.46 | **93%** | 7% |

**Our per-request decode rate is within 3% of what the incumbent's headline
figure requires, at both concurrencies.** The gap is not silicon and it is not
the model — it is how staggered our batch admission is.

And **at c2 the hardware ceiling did not move at all**: `peak_throughput` reads
181 against 182 at `mnbt 8192` (−0.5%) while `tg` rose **+67.6%**. The token
budget bought nothing from the GPU; it bought a shorter denominator. That is the
cleanest demonstration in the campaign that `tg_throughput` is a *scheduling*
measurement wearing a throughput's units.

⚠️ **R12 lost its primary occupancy instrument.** The engine-log capture used
`docker logs -f`, which returns only the container's CUDA banner — vLLM's serve
output does not reach container stdout on this image. **Scheduler
`Running`/`Waiting` and MTP acceptance are UNMEASURED for R12 and no figure is
quoted for either.** Residency from `peak_throughput / peak_req_throughput`
survives as corroboration (1.93 of 2 at c2, 4.92 of 5 at c5). The correct
capture is `docker exec <container> tail -f /tmp/sparkrun_serve.log`.

**Round 10's headline, in five lines.** R10 ran c4 and c16 at
`max_num_batched_tokens 32768` under ONE engine start at runs=7, and read
llama-benchy's source while the grid ran. (1) **The units questions are closed
from the instrument, not by inference**: `tg_throughput` is a batch aggregate at
`c>1`, the board reports the same field, and `per-request x c` double-counts.
(2) **The c4 win keeps 1.13x** and R7's 4.53x alternative is withdrawn; **c2 and
c5 resolve as losses.** (3) **The token budget was worth 2.8x at c4**: 52.85 ->
147.25, i.e. **1.13x -> 3.15x** against the incumbent, reproducing R9's 143.08 to
2.9% from a separate engine start. (4) At c16 the gate is **halved, not
removed** — residency 11.89 -> 14.31 of 16, `peak_throughput` 440 -> **515**, but
the scheduler still reads `Running` 11 / `Waiting` 5. (5) **MTP acceptance did
not move** (3.07 vs R7's 3.10), so the gain is scheduling, not acceptance.

**Round 8's headline, in four lines.** R8 put d16384 and d65536 under ONE engine
start at runs=7 — the control R3's flatness claim always needed. (1) **Depth is
NOT flat: tg128 c1 falls 16.8%** from 113.06 at d16384 to 94.10 at d65536, far
outside the ±6% resolution the round declared before it ran. (2) **R3's 108.15
was a lucky 3-run draw**, the second such figure this campaign has had to retire
(R1's tg32 was the first), and the `tg128 @ d65536 c1` margin drops from 6.56x to
**5.71x**. (3) The depth curve is now **monotone and steepening** — 113.06 /
94.10 / 77.13 — which is what physics required all along; every measured "rise
with depth" this campaign reported is gone. (4) **R3's -17% ctx inversion at
d65536 did not reproduce** (-1.2% here), so open question 4's deep half should be
treated as unmeasured. Controls passed: pp2048 at 628.66 sits inside a series
held across seven invocations, and the d16384 arm reproduced R6 to 1.8%.

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

⚠️ **THE SYNTHESIS PASS SCORED TEN CELLS THAT HAD BEEN SITTING UNSCORED, AND
NINE OF THEM ARE LOSSES.** R5b scraped board figures for the `ctx_tg` c1 depth
cells and the prefill cells back on 2026-08-21 (`docs/arena-recipe.md`), but no
round ever moved them into this table — rows kept saying "not scraped" while the
numbers sat in the scrape. They are now scored above. Nothing about a win
changed; what changed is that `ctx_tg @ d8192/d16384/d32768 c1` are losses
(0.61x / 0.64x / 0.72x, to a 350M BF16 model or to our own model on Atlas), the
six prefill c1 cells are heavy losses, and `ctx_pp @ d65536 c1` is a win at
2.88x. Two of those figures are still 3-run medians, flagged as such.
A scrape is not a standings update, and this one waited a day for one.

Eight cells taken, twelve lost, and **round 5 was the campaign's first LOSS**: tg128 @ d131072 c1
came in at median 77.13 against Nemotron Lightning NVFP4's 81.60 — short by 5.5%.
That cell was queued as a probable loss, run once for the depth curve, and was
deliberately NOT tuned for; the recipe is unchanged. It is recorded here as a
loss and should be read as one. (One of the three runs, 89.39, did clear 81.60 at
1.10x, but the median is the verdict and the median lost.)

Round 4's two cells (c2, c5) were scraped afterwards — 325.44 and 428.95, with
best-vLLM-NVFP4 runners-up at 163.27 and 225.46. They were briefly marked
DISPUTED while R7's units question was open; **R10 closed that question from
llama-benchy's source and they are scored above as LOSSES**, at 0.51x/0.21x on
the campaign config and 0.86x/0.57x on the raised budget. Round 7's two cells
(c8, c16) have no board figures at all and cannot be scored at any units.

The depth curve at tg128 c1 — **rewritten by R8, and it is monotone now:**

| depth | ours | vs previous | per doubling | board top | margin |
|---:|---:|---:|---:|---:|---|
| 16384 | **113.06** (R8, 7 runs) | — | — | 116.03 (best vLLM NVFP4) | 0.97x — gap -2.9% |
| 65536 | **94.10** (R8, 7 runs; was 108.15) | **-16.8%** (4x) | -8.8% | 16.48 | **5.71x** |
| 131072 | 77.13 (R5, 3 runs) | **-18.0%** (2x) | -18.0% | 81.60 | 0.95x — LOST |

**Both R8 points come from ONE engine start and one thermal state**
(`session_count: 1`), which is the whole reason to believe the first leg. The
campaign read this curve as "flat, flat, then a cliff" for five rounds. It is
not: it is a **decline that steepens with depth**, and the flatness was an
artefact of three-run sampling at a cell whose σ is 9.0%. R3's 108.15 sat 13%
above the 7-run median and has been retired.

Physics required this. Per-step decode work is non-decreasing in context
length, so the true curve cannot rise, and every "deeper is faster" reading this
campaign produced was always going to be sampling. What survives is the
*magnitude* argument: a pure-bandwidth model predicts **-44.8%** across
d16384->d65536 (weights ~1.7 GB fixed, FP8 KV 0.62 -> 2.50 GB) and the measured
fall is **-16.8%**, so the architecture — 30 of 40 layers are fixed-state Gated
DeltaNet, only 10 hold KV, and in FP8 — makes the depth term about a third of
naive. Not zero. Never was.

The d131072 point is still a 3-run median from a separate invocation with σ
9.3%, i.e. the same instrument that just failed at d65536. Treat the last leg
as the least trustworthy part of the curve.


## ⚠️ R9b: TWO CORRECTIONS THAT REACH EVERY `ctx_` ROW IN THIS FILE

Both came from reading llama-benchy 0.4.0's source and vLLM's own counters after
R9b's validity gate failed. Neither cost box time. Neither changes a single
claimed win — every standings row is a cold-phase `tg` figure — but both change
what the `ctx_` rows and open question 4 have been talking about.

**1. THE TWO MEASUREMENT PHASES ARE LABELLED BACKWARDS, and have been since R1.**
`llama_benchy/runner.py:127-176` and `223-225`:

    if self.config.enable_prefix_caching and depth > 0:
        # Phase 1: Context Load  -> is_context_phase=True,  expected_ctx (16384)
        # Phase 2: Inference     -> is_context_phase=False, expected_pp  (2048)

The `ctx_` rows are **Phase 1, the context load** — the pass that *establishes*
the cache, i.e. the uncached one. The rows this file calls **"cold" are Phase 2**,
the cache-eligible one. And the two are charged **different token counts**
(16384 vs 2048), so their `pp_throughput` figures were never comparable to one
another. Every "the ctx phase is faster / inverts / is quieter" reading in the
journal and in open question 4 needs re-reading against this. The `tg` figures
are not distorted by the token count, but they are still mislabelled as to which
phase is cached.

**2. PREFIX CACHING HAS NEVER HIT ON THIS BENCHMARK.** vLLM's own counter reads
`Prefix cache hit rate: 0.0%` in all 22 engine samples of R9's A1 and all 92 of
R10 — **with the flag ON**. Independently, total prompt tokens processed by the
engine (summed from vLLM's `Avg prompt throughput` windows) is **1,079,370 with
caching on against 1,060,925 with caching off** — 1.7% apart. **No prefill work
was ever saved.**

Yet the flag is worth **57% of `tg` at c4** (R9 A1 143.08 → R9b A 62.13) while
`peak_throughput` is **identical to the token** (297 vs 297) and `pp2048` is
within 0.8%. The mechanism is **unexplained and R9b does not invent one**; the
leading suspect is that prefix caching off also moves `mamba_block_size` from 16
to 32768, changing the Gated DeltaNet state granularity for 30 of this model's
40 layers by a factor of 2048. Queued as **R9c**.

**Planning consequence:** do not describe this campaign's `c>1` gains as "prefix
caching working". It is not working. Something riding along with the flag is.

## Concurrency curve at tg128 @ d16384 — REBUILT by R10

Every point satisfies `max_num_seqs >= c`, i.e. no request ever waits for a
scheduler *slot*. R9 and R10 showed that is not sufficient: a request can still
wait for token *budget*, so the `mnbt` column now matters as much as `mns` and
both are shown. **The `tg` column is the board's own metric** (llama-benchy
`tg_throughput`, a batch aggregate at `c>1`); `peak_thr` is the sustained
ceiling it must sit under. The old `per-request` and `aggregate` columns were
both wrong and have been deleted — see the units resolution above.

`stagger` is `batch span / single-request decode span`, computed from
`tg_throughput` and `tg_req_throughput`. It is 1.0 only if every request runs in
lockstep; the amount above 1.0 is what admission stagger costs the board metric.

| c | mns | mnbt | tg (board metric) | σ/med | peak_thr | stagger | round |
|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 4 | 8192 | 111.11 | 2.6% | 119 | 1.00 | R6 (runs=7) — see note |
| 2 | 4 | 8192 | 84.00 | 1.4% | 182 | 1.61 | R4 |
| 4 | 4 | 8192 | 52.85 | 0.8% | 291 | 2.54 | R2 (pooled 6 runs) |
| 5 | 4 | 8192 | 45.60 | 0.6% | 282 | 2.46 | R4 — scheduler-limited |
| 5 | **5** | 8192 | 48.12 | 0.15% | 265 | 2.25 | R4 (mutation) |
| 8 | **8** | 8192 | 43.51 | 0.51% | 355 | 2.08 | R7 (mutation) |
| 16 | **16** | 8192 | 40.47 | 0.15% | 440 | 2.06 | R7 (mutation) |
| **2** | **5** | **32768** | **140.77** | 6.28% | 181 | **1.13** | **R12 (mutation, runs=7)** |
| **4** | **16** | **32768** | **147.25** | 3.25% | 284 | **1.57** | **R10 (mutation, runs=7)** |
| **5** | **5** | **32768** | **128.93** | 1.81% | 290 | **1.70** | **R12 (mutation, runs=7)** |
| **16** | **16** | **32768** | **53.45** | 0.52% | **515** | 2.89 | **R10 (mutation, runs=7)** |

**The `mnbt 32768` block now has four points and the stagger column orders them
exactly as prefill arithmetic says it should.** At d16384 a scheduler step admits
`floor(32768 / 16384) = 2` whole prefills, so the whole batch is admitted in 1
step at c2, 2 at c4, 3 at c5 and 8 at c16 — and stagger reads
**1.13 < 1.57 < 1.70 < 2.89** in that order. R12 predicted this ordering before
the run from the integer arithmetic alone. (Its *numeric* floor for c5, >1.80,
missed low at 1.70, because c5's trailing third step admits one prefill rather
than two and therefore costs about half a step — reported as a mixed
discriminator, not forced.)

**Read the table in two halves, because they are two different configurations.**
Down the `mnbt 8192` block the board metric falls monotonically with concurrency
and the stagger climbs — that is the campaign's whole "concurrency hurts" story,
and R10 shows a large part of it was the token budget rather than the hardware.
The two `mnbt 32768` rows sit in a different regime: c4 nearly triples, and c16
posts the campaign's largest sustained aggregate at **515**.

**R7's "the tail is not flat" survives, and its numbers are unchanged.** Per the
board metric, c8 -> c16 at mnbt 8192 is -7.0% across a doubling against -37.1%
across c2 -> c4. Strict time-slicing would put c16 at 111.11/16 = 6.9 by the
per-request measure; `tg_req_throughput` actually reads 5.22 there, so the
time-slicing floor is roughly where per-request lands and it is `peak_throughput`
(440, now 515) that shows batching doing its work.

**Why the c8 and c16 aggregates used to read "~350" and "~440".** They were
`peak_throughput` all along and they were right; what was wrong was the
`per-request x c` figure printed next to them, which double-counted an
already-aggregate metric. At c16 that product read 647.6 against a peak of 440,
which is how the error was caught. Cause of the *occupancy* shortfall was real
and separate: `--max-num-batched-tokens 8192` was not raised alongside
`max_num_seqs`, so at d16384 a scheduler step fit only half of one 16384-token
prefill and the engine held a median of **9 of 16** sequences resident. **R10
raised it to 32768 and the median went to 11 of 16, with residency at peak
11.89 -> 14.31 and `peak_throughput` 440 -> 515 (+17.0%).** The gate is halved,
not removed: 32768 admits two prefills per step, and sixteen would need 262144.

*Note on the c1 anchor.* R8 re-measured this cell at 113.06 (7 more runs), and
the pooled 14-run median is 112.62. The ratio column above is left as computed
against R6's 111.11 so the series stays internally consistent; using 112.62
would move every `vs c1` figure by 1.4% and change nothing about the shape.

*(An earlier copy of R7's tail argument stood here, written in the retired
"per-request" language. It is deleted rather than patched — the surviving,
corrected statement is the "R7's 'the tail is not flat' survives" paragraph
above, and the aggregate story is the paragraph before it. The one figure worth
repeating: `peak_throughput` is still climbing at 16-way, 440 vs 355 = +24%,
above the +15% threshold R7 declared in advance, so the MoE-expert-coverage
mechanism is not binding anywhere below c16.)*

✅ **UNITS DISPUTE CLOSED by R10 — see the units resolution near the top.** The
board's figure and ours are the SAME field (llama-benchy's `tg_throughput`, a
batch aggregate at `c>1`), so the `per-request` column above was a misreading of
our own instrument and the `aggregate` column double-counted it. Both are gone.
c2 is 84.00 vs 163.27 (**0.51x, lost**) and c5 is 48.12 vs 225.46 (**0.21x,
lost**) against the board's own Qwen3.6-35B-A3B-NVFP4 on vLLM. The c4 win keeps
its original 1.13x. **R12 has since re-run both cells at the raised budget:
0.86x and 0.57x. Still losses, and still recorded as losses** — see R12's
standings block near the top of this file.

**WHY OUR SERIES FALLS WHERE THE BOARD'S RISES.** `tg_throughput` divides total
decode tokens by `max(last_token) - min(first_token)`, so it is charged for
admission stagger. Batch span divided by a single request's decode span, over
every archived `c>1` run, is never 1.0 — it is 1.6 to 2.9. A 350M model prefills
d16384 almost instantly, so its stagger is nil and its aggregate rises with `c`;
our 35B model at a starved token budget staggers badly and its aggregate falls.
Same metric, different prefill cost. **R10 confirms the lever: at c4, raising
`--max-num-batched-tokens` 8192 -> 32768 cuts the stagger ratio from 2.54 to
1.57 and takes the cell from 52.85 to 147.25.**

**R12 completes the argument and quantifies it.** At c2 the stagger drops to
**1.13** — near the c1 floor, because at d16384 a 32768-token budget admits both
prefills in ONE scheduler step — and the cell rises +67.6% while
`peak_throughput` moves −0.5%. Removing the stagger is the entire mechanism, and
the residual after removing it is small: the zero-stagger bound `c × tg_req` puts
us at **0.98x** of the c2 incumbent and **0.97x** of the c5 incumbent. **The
board's like-for-like entry is not decoding meaningfully faster than this box; it
is admitting its batch with less stagger.**

Raising `--max-num-seqs` to match the probe is worth +5.5% at c5 — a real effect
(σ 0.07 and 0.26, run ranges disjoint) — and R7 confirms it is a QUEUEING effect
and not a batch-size one: at c16 the batch is 4x larger than R4's and `pp2048`
is undisturbed at 628.74, against the 581.44 R4 measured when the fifth request
queued. NOT folded into recipe.yaml: the campaign recipe stays unmutated at
`--max-num-seqs 4`. The two deep cells are the campaign's widest margins, and
`ctx_tg @ d65536 c1` was the first `ctx_` cell we could claim.

**R5b's scrape has since filled in the other `ctx_` and prefill c1 cells**, and
they are scored in the standings above: `ctx_tg @ d16384 c4` is a win at 2.04x /
4.56x, `ctx_pp @ d65536 c1` is a win at 2.88x, and the `ctx_tg` c1 depth cells
and every prefill c1 cell are losses. What still cannot be scored is the `c>1`
half of the `ctx_`/`pp` families and the c8/c16 cells — the board publishes those
test types at c1 only.

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

**R8 confirms this pricing on an independent sample, and shows what ignoring it
costs.** In ONE engine start, d16384 came in at σ 5.5% and d65536 at σ 9.0%, so
the deep cell really is the noisy one and not merely the unlucky one — the
noise belongs to the depth, not to the session. At 9.0%, a 3-run median at
d65536 has a standard error near 6.5%, and R3's three runs landed **13% high**.
That single shortcut put a wrong number in this table for five rounds.
**Anything at d65536 or deeper gets seven runs, and any 3-run figure at those
depths should be read as provisional until it has been repeated.** R8's shallow
arm also shows the bimodality directly: six of its seven runs span 112.51-114.36
(σ 0.65) and the seventh reads 95.56 — a mode plus one low draw, which is
exactly why the median is the verdict and the mean is not.

**`tg t/s` is a BATCH AGGREGATE at `c>1`, and `per-request x c` is meaningless.**
Settled by reading llama-benchy 0.4.0's `results.py`, not by inference — see the
units resolution at the top of this file. At c1 the aggregate and the
per-request figure are the same number by construction. At `c>1`, `tg_throughput`
is `sum(decode tokens) / (max(last_token) - min(first_token))`: an aggregate
already, so multiplying it by `c` double-counts, which is exactly why the product
kept exceeding `peak_throughput`. **Report `tg_throughput` as the aggregate and
`peak_throughput` as the ceiling it must sit under; never multiply.** The
per-request figure, when you want it, is llama-benchy's own
`tg_req_throughput` — a separate field the campaign never used.

**The span in the denominator is a measurement of the config, not noise.** Because
`tg_duration` runs from the first request's first token to the last request's
last token, anything that staggers admission is charged to this metric twice:
once through lower occupancy and once through a longer span. That makes
`tg_throughput` sensitive to scheduler settings in a way `peak_throughput` is
not — R10 measured `tg` moving +179% at c4 on a token-budget change while
`peak_throughput` moved +4.4% in the same runs. **Both belong in every `c>1`
row, and they answer different questions:** `tg` is what the board ranks,
`peak_throughput` is what the hardware can sustain.

## Generation cells (tg)

| benchId | date | cell / probe | tg med t/s | tg σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d8192 c1 | 106.24 | 22.72 | 1737.93 | sole entry | win — no number published to beat |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d16384 c1 | 129.32 | 18.38 | 3230.01 | 28.11 | win — 4.60x incumbent |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d32768 c1 | 115.56 | 10.40 | 6937.09 | 23.31 | win — 4.96x incumbent |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d8192 c1 | 126.52 | 7.94 | 1345.97 | 207.60 (LFM2.5-350M BF16) | **LOSS — 0.61x** vs the top, but **1.07x** over the best vLLM+NVFP4 entry (118.07, Nemotron-3.5-Lightning-30B-A3B-NVFP4). Board figure came from R5b's scrape and was never carried into the standings until the synthesis pass. ⚠ 3-run figure |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d16384 c1 | 130.16 | 3.01 | 2787.86 | 193.09 (LFM2.5-350M BF16) | **SUPERSEDED by R6's 7-run 122.97** — same cell, same instrument that retired R1's cold tg32 figure. The cell is a **LOSS at 0.64x**; runners-up 153.86 / 152.14 are our own model on Atlas |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d32768 c1 | 84.03 | 10.69 | 6453.91 | 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**) | **LOSS — 0.72x**, and also below the best vLLM entry in the cell (116.65, Nemotron-3.5-Lightning-30B-A3B-NVFP4). ⚠ 3-run figure, and it is the source of the campaign's only surviving deep ctx inversion — see R8c |
| bench_f58c56da6658 | 2026-08-21 | tg128 @ d16384 c4 | 53.56 | 0.43 | 10167.05 | 46.68 | win — 1.15x, verify required at this margin |
| bench_f58c56da6658 | 2026-08-21 | ctx_tg128 @ d16384 c4 | 56.40 | 0.16 | 8554.95 | 27.68 | win — 2.03x; board figure landed later in R5b's scrape, pooled with the verify run below |
| bench_f58c56da6658-verify | 2026-08-21 | tg128 @ d16384 c4 | 52.69 | 0.75 | 10151.35 | 46.68 | win CONFIRMED — pooled median of 6 runs 52.85 = 1.13x; worst single run 51.25 still +9.8% |
| bench_f58c56da6658-verify | 2026-08-21 | ctx_tg128 @ d16384 c4 | 55.92 | 0.62 | 8641.49 | 27.68 | **win — pooled median 56.36 = 2.04x** over the R5b-scraped incumbent |
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
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_tg32 @ d16384 c1 (runs=7) | 122.97 | 8.44 | 2850.87 | 193.09 (LFM2.5-350M BF16) | **LOSS — 0.64x**, and this 7-run figure REPLACES R1's 3-run 130.16 as the campaign's claimed number for the cell. ABOVE cold (+5.62%) and quieter than cold (6.9% vs 9.9%) — but read the phase-label correction: this is the context-LOAD pass, not a cached one |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_tg128 @ d16384 c1 (runs=7) | 104.85 | 9.73 | 2813.42 | not scraped | hold — BELOW cold (-5.63%), opposite sign to the tg32 arm in the SAME invocation; and NOISIER than cold (9.3% vs 2.6%) |
| bench_0954971b5dfa | 2026-08-22 | tg128 @ d16384 c8 (**MUTATION max_num_seqs 8**) | 43.51 | 0.22 | 16554.28 | not scraped | hold — no incumbent. Aggregate ~350 (c x tg 348.1, peak_throughput 355 — estimators AGREE here). σ 0.51% |
| bench_0954971b5dfa | 2026-08-22 | ctx_tg128 @ d16384 c8 (MUTATION max_num_seqs 8) | 47.75 | 0.05 | 13969.54 | not scraped | hold — ABOVE cold (+9.7%), and quieter (σ 0.10%) |
| bench_a769c1142e15 | 2026-08-22 | tg128 @ d16384 c16 (**MUTATION max_num_seqs 16**) | 40.47 | 0.06 | 29751.25 | not scraped | hold — no incumbent. **Only -7.0% below c8 across a DOUBLING** — the tail is not flat. Aggregate **~440** (peak_throughput); ~~c x tg = 647.6~~ INVALID, it exceeds the peak — only 9 of 16 seqs were resident (max_num_batched_tokens 8192 gated admission). σ **0.15%**, the campaign's tightest tg measurement |
| bench_a769c1142e15 | 2026-08-22 | ctx_tg128 @ d16384 c16 (MUTATION max_num_seqs 16) | 45.61 | 0.08 | 25310.86 | not scraped | hold — ABOVE cold (+12.7%); the ctx-vs-cold margin now GROWS monotonically with concurrency: +6.6% (c4), +6.5% (c5), +9.7% (c8), +12.7% (c16) |
| bench_3d8149654d1b | 2026-08-22 | tg128 @ d16384 c1 (**runs=7**, depth control) | 113.06 | 6.20 | 3269.39 | 116.03 best vLLM NVFP4 | hold — reproduces R6's 111.11 to 1.8% from a SEPARATE engine start; pooled 14-run median 112.62, gap now **-2.9%**. Six of seven runs span 112.51-114.36 (σ 0.65); the seventh is 95.56 — a mode plus one low draw. Crowded cell, never a campaign target |
| bench_3d8149654d1b | 2026-08-22 | tg128 @ d65536 c1 (**runs=7**, SAME engine start as the row above) | **94.10** | 8.44 | 17144.32 | 16.48 | **win — 5.71x incumbent; REVISES R3's 3-run 108.15 DOWN 13.0%**; worst of 7 runs 81.79 still 4.96x. **Depth is NOT flat: -16.8% below d16384 in the same invocation**, against a ±6% pre-declared resolution |
| bench_3d8149654d1b | 2026-08-22 | ctx_tg128 @ d16384 c1 (runs=7) | 102.68 | 8.03 | 2809.36 | not scraped | hold — BELOW cold (-9.2%), same sign as R6's -5.63% at this depth and generation length; NOISIER than cold (7.8% vs 5.5%), the third break of the ctx-quietness rule |
| bench_3d8149654d1b | 2026-08-22 | ctx_tg128 @ d65536 c1 (runs=7) | 92.98 | 8.07 | 16340.55 | 20.70 | **win — 4.49x incumbent** (was 4.34x at 89.76); worst of 7 runs 77.33 still 3.74x. **R3's -17% ctx inversion did NOT reproduce: -1.2% vs cold here** — treat the deep inversion as unmeasured |
| bench_5399a85d7aec-a0 | 2026-08-22 | tg128 @ d16384 c4 (**arm A0 — campaign config, UNMUTATED**) | 52.64 | 0.58 | 10205.51 | 46.68 | hold — reproduces R2's pooled 52.85 to 0.4%. Same engine start as the c5 row below (`session_count: 1`). Verdict NOT rewritten: units dispute (R5c) still open. **Engine log shows this cell never reaches full occupancy** — see the R9 occupancy note |
| bench_5399a85d7aec-a0 | 2026-08-22 | tg128 @ d16384 c5 (**arm A0 — campaign config, UNMUTATED**) | 45.05 | 0.28 | 11847.76 | not scraped as per-request | hold — **D0 = -14.4% against the c4 row above, measured in ONE engine start**. R4 computed -13.7% across two invocations; the deficit is real and is not an engine-start artefact |
| bench_5399a85d7aec-a0 | 2026-08-22 | ctx_tg128 @ d16384 c4 (arm A0, campaign config) | 54.98 | 0.19 | 8633.16 | not scraped | hold — ABOVE cold (+4.4%) |
| bench_5399a85d7aec-a0 | 2026-08-22 | ctx_tg128 @ d16384 c5 (arm A0, campaign config) | 48.04 | 0.44 | 9840.74 | not scraped | hold — ABOVE cold (+6.6%); reproduces R4's 48.18 to 0.3% |
| bench_d9fdc68576f2-a1 | 2026-08-22 | tg128 @ d16384 c4 (**arm A1 — MUTATION max_num_batched_tokens 32768**) | 143.08 | 3.97 | 11798.88 | — | hold — **NOT COMPARABLE and NOT CLAIMED**: `tg x c` = 572.3 exceeds `peak_throughput` 297, so the figure is invalid as an aggregate (open question 9). What IS solid: occupancy goes to a clean `Running 4 / Waiting 0`, and `peak_throughput` rises 272 -> 297 (**+9.2%**) |
| bench_d9fdc68576f2-a1 | 2026-08-22 | tg128 @ d16384 c5 (**arm A1 — MUTATION max_num_batched_tokens 32768**) | 81.73 | 8.16 | 11871.93 | — | hold — **NOT COMPARABLE and NOT CLAIMED**: `tg x c` = 408.7 exceeds `peak_throughput` 289. σ **9.98%** (runs 83.06 / 65.12 / 81.73) breaks the round's own error budget. `peak_throughput` 276 -> 289 (+4.7%) |
| bench_d9fdc68576f2-a1 | 2026-08-22 | ctx_tg128 @ d16384 c4 (arm A1, MUTATION mnbt 32768) | 121.42 | 3.28 | 10320.43 | — | hold — not comparable, same estimator break as its cold row |
| bench_d9fdc68576f2-a1 | 2026-08-22 | ctx_tg128 @ d16384 c5 (arm A1, MUTATION mnbt 32768) | 79.53 | 1.14 | 10281.90 | — | hold — not comparable, same estimator break |
| bench_12f458ba7348-crash | 2026-08-22 | tg128 @ d16384 c4+c5 (**arm B — chunked prefill DISABLED**) | — | — | — | — | **CRASH — engine refused to start.** `Chunked prefill is required for mamba cache mode 'align'`, and `align` is the mode vLLM selects whenever prefix caching is on. Disabling chunked prefill on this model would require disabling prefix caching too, i.e. changing the cache strategy of the 30 Gated DeltaNet layers. **R4's mechanism is untestable by this route**; no numbers produced, none invented |
| bench_860b43edd154 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 32768 + mns 16**, runs=7) | **147.25** | 4.78 | 11832.30 | 46.68 | **WIN — 3.15x incumbent**, and it is the campaign's thinnest cell transformed. Aggregate metric (see the units resolution): `peak_throughput` **284** (σ 5.5%). Occupancy a clean **(4,0) in 100% of loaded scheduler samples**. Reproduces R9's arm A1 143.08 to **+2.9%** from a SEPARATE engine start, so the 3-run figure holds at 7 runs. Worst of 7 runs 137.11 still 2.94x. `tg x c` = 589.0 exceeds peak 284 and is NOT the aggregate — see the units resolution |
| bench_860b43edd154 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 32768 + mns 16, runs=7) | 126.35 | 1.64 | 10278.24 | 27.68 | **WIN — 4.56x incumbent** (board figure from the R5b scrape in docs/arena-recipe.md). `peak_throughput` 290. **BELOW cold (-14.2%)**, a SIGN FLIP against the +4.4% the same cell shows at mnbt 8192 — the ctx-vs-cold sign moves with the token budget, a pure scheduler knob |
| bench_860b43edd154 | 2026-08-22 | tg128 @ d16384 c16 (**MUTATION mnbt 32768 + mns 16**, runs=7) | 53.45 | 0.28 | 39389.36 | not scraped | hold — no incumbent. Aggregate `peak_throughput` **515** (σ 3.0%), up **+17.0%** on R7's 440: the largest aggregate the campaign has measured. Residency at peak **14.31 of 16**, up from R7's 11.89. But the scheduler log still reads `Running` median **11**, `Waiting` median **5** — the gate is HALVED, not removed. σ 0.52% |
| bench_860b43edd154 | 2026-08-22 | ctx_tg128 @ d16384 c16 (MUTATION mnbt 32768 + mns 16, runs=7) | 54.54 | 0.10 | 30241.71 | not scraped | hold — `peak_throughput` **566**, the single largest aggregate figure in the campaign. ABOVE cold by only +2.0%, against +12.7% at mnbt 8192: R7's "ctx-vs-cold margin grows monotonically with concurrency" does not survive a budget change |
| bench_ac37f5b64487 | 2026-08-22 | tg128 @ d16384 c2 (**MUTATION mnbt 32768 + mns 5**, runs=7) | **140.77** | 8.84 | 6069.14 | 163.27 best vLLM NVFP4 (325.44 overall) | **LOSS — 0.86x, short by 13.8%**, but was 0.51x on the campaign config (84.00): **+67.6% from a scheduler knob**. `peak_throughput` **181** — UNCHANGED against 182 at mnbt 8192, so the hardware ceiling did not move while the board metric rose two thirds. **Stagger 1.13, the lowest `c>1` figure in the campaign**; zero-stagger bound `2 × tg_req` = **159.46 = 0.98x of the incumbent**, so **83% of the residual gap is admission stagger and 17% is decode rate**. Residency 1.93 of 2. σ **6.28%**, the noisiest `c>1` cell measured (runs span 122.33-151.51, mode-plus-one-low-draw) — runs=7 earned its keep. ttfr ROSE +7.3% on the budget change |
| bench_ac37f5b64487 | 2026-08-22 | ctx_tg128 @ d16384 c2 (MUTATION mnbt 32768 + mns 5, runs=7) | 127.09 | 4.01 | 5269.25 | not scraped | hold — BELOW cold (−9.7%), deepening the −5.4% the same cell shows at mnbt 8192. `peak_throughput` 167. **Stagger 1.17 — HIGHER than cold's 1.13**, and `tg_req` 74.45 is BELOW cold's 79.73, so the cached phase is behind on both terms. See the ctx-stagger contradiction note |
| bench_ac37f5b64487 | 2026-08-22 | tg128 @ d16384 c5 (**MUTATION mnbt 32768 + mns 5**, runs=7) | **128.93** | 2.34 | 14484.92 | 225.46 best vLLM NVFP4 (428.95 overall) | **LOSS — 0.57x, short by 43%**, but was 0.21x on the campaign config (48.12): **+168%**. First run of c5 with BOTH settings raised (R9's arm A1 had mnbt 32768 but `mns 4`, so the fifth request still queued for a slot; it read 81.73). `peak_throughput` **290**, up +9.4% on 265. **Stagger 1.70**; zero-stagger bound `5 × tg_req` = **218.60 = 0.97x of the incumbent**, so **93% of the residual gap is admission stagger and 7% is decode rate**. Residency 4.92 of 5. σ 1.81%. ttfr ROSE +19.8% |
| bench_ac37f5b64487 | 2026-08-22 | ctx_tg128 @ d16384 c5 (MUTATION mnbt 32768 + mns 5, runs=7) | 104.75 | 1.16 | 12731.35 | not scraped | hold — BELOW cold (−18.7%), a **SIGN FLIP** against the +6.5% the same cell shows at mnbt 8192, reproducing what R10 saw at c4 (+4.4% → −14.2%). `peak_throughput` 290. **Stagger 2.12 — HIGHER than cold's 1.70**, which contradicts R10's stated mechanism for the flip |

| bench_9379c15468ec-a-chunk | 2026-08-22 | tg128 @ d16384 c4 (**R9b ARM A — prefix caching OFF, mnbt 32768, mns 4, chunked prefill ON**, runs=3) | 62.13 | 0.70 | 11559.86 | **NOT SCOREABLE** | diagnostic — three flags from the campaign config, not a standings row. `peak_throughput` **297**, IDENTICAL to R9's A1 with caching ON, while `tg` falls **−56.6%** (143.08 → 62.13): the hardware ceiling did not move, the batch span did. Stagger **3.32** vs A1's 1.62. `tg_req` 51.49 (−11.0%) |
| bench_9379c15468ec-a-chunk | 2026-08-22 | tg128 @ d16384 c5 (**R9b ARM A**, runs=3) | 50.28 | 0.81 | 12309.92 | **NOT SCOREABLE** | diagnostic — `peak_throughput` 298, `tg_req` 25.46, stagger 2.53, residency 3.77 of 5. Scheduler `(4,1)` in four samples, reproducing R9's direct observation at this cell |
| bench_9379c15468ec-a-chunk | 2026-08-22 | ctx_tg128 @ d16384 c4 (**R9b ARM A**, runs=3) | 70.90 | 0.56 | 10123 | **NOT SCOREABLE** | diagnostic — **and this row is the CONTEXT-LOAD pass, not a cached pass**: with prefix caching off there is no cache, and llama-benchy's `ctx_` phase was never the cached one anyway (see the phase-label correction above). `peak_throughput` 282 |
| bench_9379c15468ec-a-chunk | 2026-08-22 | ctx_tg128 @ d16384 c5 (**R9b ARM A**, runs=3) | 57.48 | 0.47 | 10760 | **NOT SCOREABLE** | diagnostic — `peak_throughput` 281 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | tg128 @ d16384 c4 (**R9b ARM B — prefix caching OFF, mnbt 32768, mns 4, chunked prefill OFF**, runs=3) | 52.92 | 0.83 | 9575.12 | **NOT SCOREABLE** | diagnostic — **the arm R9 could not start.** vs arm A: `tg` **−14.8%**, `tg_req` **−44.2%** (51.49 → 28.74), stagger IMPROVES 3.32 → **2.17**, ttfr IMPROVES **−17.2%**. Turning chunked prefill off halves per-request decode while tightening admission — it PROTECTS decode, it does not interfere. Scheduler sits at `(2,2)` in three of eight loaded samples and never holds a stable `(4,0)`. `peak_throughput` 285 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | tg128 @ d16384 c5 (**R9b ARM B**, runs=3) | 45.28 | 0.36 | 11115.00 | **NOT SCOREABLE** | diagnostic — vs arm A: `tg` −9.9%, `tg_req` −21.7%, stagger 2.53 → 2.20, ttfr −9.7%. `peak_throughput` 276, `tg_req` 19.92, residency 3.94 of 5 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | ctx_tg128 @ d16384 c4 (**R9b ARM B**, runs=3) | 58.80 | 0.16 | 8280 | **NOT SCOREABLE** | diagnostic — context-load pass. `peak_throughput` 269 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | ctx_tg128 @ d16384 c5 (**R9b ARM B**, runs=3) | 49.54 | 0.60 | 9645 | **NOT SCOREABLE** | diagnostic — `peak_throughput` 288 |

## Prefill cells (pp2048)

pp2048 rides along in every round by default, so these were measured at no extra
cost. They are separate board cells and get their own rows. The cold rows fall
steeply with depth because they prefill the whole context.

### Prefill standings, scored at last — and the scores are a warning

R5b scraped these cells on 2026-08-21 and no round carried them into a verdict.
Doing it now (board figures from `docs/arena-recipe.md`, all c1, single-node):

| Cell | Ours | Board top | Runtime of top | Best vLLM figure | Verdict |
|---|---:|---:|---|---:|---|
| pp2048 @ d8192 c1 | 1187.51 | 215894.21 | Atlas | not in scrape | **LOST, 0.006x** |
| pp2048 @ d16384 c1 | 637.09 (628.66 at runs=7) | 99229.33 | Atlas | not in scrape | **LOST, 0.006x** |
| pp2048 @ d32768 c1 | 295.71 | 63079.61 | Atlas | 4644.54 (Laguna-XS-2.1-NVFP4) | **LOST, 0.005x of top, 0.064x of best vLLM** |
| pp2048 @ d65536 c1 | 119.54 | **no entries** | — | — | empty cell — not a win, and nothing can be posted |
| ctx_pp @ d8192 c1 | 6148.56 | 775122.96 | Atlas | not in scrape | **LOST** |
| ctx_pp @ d16384 c1 | 5856.93 | 884764.53 | Atlas | not in scrape | **LOST** |
| ctx_pp @ d32768 c1 | 5086.51 | 945271.31 | Atlas | not in scrape | **LOST** |
| ctx_pp @ d65536 c1 | 4013.59 | 1393.35 | vLLM | — | **WON, 2.88x** — sole-entry cell, incumbent is three orders below the same test type at d32768, so the holder is probably a slow outlier |

⚠️ **A 15x gap against a LIKE-FOR-LIKE vLLM entry is not a config gap, and this
campaign never checked it.** At d32768 our 295.71 sits 15x under another vLLM
NVFP4 entry in the same cell, while our decode figures sit within 3% of what a
like-for-like incumbent's headline requires (R12). That asymmetry is the
signature of a metric mismatch, not of a slow box — exactly the shape R10 found
when it finally read llama-benchy's source for `tg_throughput`. **These rows are
recorded as the board reads them, and the mismatch is an open question, not a
settled defeat.** The cheapest next move in the whole queue is to read
llama-benchy's `pp_throughput` definition and the board's prefill test-type
mapping. Zero box time; the same move has already paid twice.

Every prefill top except the near-empty `ctx_pp @ d65536` is held by the Atlas
runtime, which is out of scope for this campaign, so these cells were never
targets — but they are cells we entered and lost, and they are recorded as such.

⚠️ **The old sentence here said the `ctx_` rows "reuse the cached prefix and sit
an order of magnitude higher". R9b read llama-benchy's source and BOTH HALVES
ARE WRONG.** The `ctx_` rows are the CONTEXT-LOAD pass — the uncached one — and
they sit higher because they are charged **16384** prompt tokens per request
against the cold rows' **2048**. The ~9x is `16384/2048`. See the phase-label
correction above before comparing any `ctx_pp` figure to any cold one.

| benchId | date | cell / probe | pp med t/s | pp σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d8192 c1 | 1187.51 | 26.39 | 1737.93 | 215894.21 (Atlas) | **LOST, 0.006x** — see the prefill standings block above and its metric-mismatch warning |
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d16384 c1 | 637.09 | 3.76 | 3230.01 | 99229.33 (Atlas) | **LOST, 0.006x** — see the prefill standings block above |
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d32768 c1 | 295.71 | 0.78 | 6937.09 | 63079.61 (Atlas); 4644.54 best vLLM | **LOST both ways, 0.005x / 0.064x** — the 15x like-for-like gap is the metric-mismatch flag |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp2048 @ d8192 c1 | 6148.56 | 15.56 | 1345.97 | 775122.96 (Atlas) | **LOST** |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp2048 @ d16384 c1 | 5910.22 | 36.03 | 2787.86 | 884764.53 (Atlas) | **LOST** |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp2048 @ d32768 c1 | 5086.51 | 23.20 | 6453.91 | 945271.31 (Atlas) | **LOST** |
| bench_f58c56da6658 | 2026-08-21 | pp2048 @ d16384 c4 | 644.01 | 1.12 | 10167.05 | not scraped | hold — board figure unknown |
| bench_f58c56da6658 | 2026-08-21 | ctx_pp2048 @ d16384 c4 | 5967.41 | 22.51 | 8554.95 | not scraped | hold — board figure unknown |
| bench_f58c56da6658-verify | 2026-08-21 | pp2048 @ d16384 c4 | 642.82 | 1.47 | 10151.35 | not scraped | hold — pooled median 643.31 |
| bench_f58c56da6658-verify | 2026-08-21 | ctx_pp2048 @ d16384 c4 | 5924.46 | 30.56 | 8641.49 | not scraped | hold — pooled median 5924.76 |
| bench_dab043abba20 | 2026-08-21 | pp2048 @ d65536 c1 | 118.59 | 0.55 | 17281.66 | **no entries** | empty cell — the board has never carried this depth for pp2048. Not a win, and nothing can be posted |
| bench_dab043abba20 | 2026-08-21 | ctx_pp2048 @ d65536 c1 | 4004.76 | 12.92 | 16377.23 | 1393.35 | **win — 2.88x** at the 7-run figure below (4013.59); sole-entry cell and the incumbent is three orders below the same test type at d32768 |
| bench_0ef7af8997ce | 2026-08-22 | pp2048 @ d16384 c2 | 634.04 | 0.48 | 5657.56 | not scraped | hold — flat against c1's 637.09 and c4's 643.31 |
| bench_0ef7af8997ce | 2026-08-22 | ctx_pp2048 @ d16384 c2 | 5810.28 | 47.04 | 4825.98 | not scraped | hold — board figure unknown |
| bench_0ef7af8997ce | 2026-08-22 | pp2048 @ d16384 c5 (max_num_seqs 4) | 581.44 | 2.22 | 11866.00 | not scraped | hold — the ONLY depressed prefill row at this depth (-9.6%): the queued fifth prefill is what falls |
| bench_0ef7af8997ce | 2026-08-22 | ctx_pp2048 @ d16384 c5 (max_num_seqs 4) | 5236.80 | 38.23 | 9914.85 | not scraped | hold — also depressed vs 5810-5967 elsewhere at this depth |
| bench_858173ba5753-mns5 | 2026-08-22 | pp2048 @ d16384 c5 (MUTATION max_num_seqs 5) | 640.21 | 1.68 | 12088.40 | not scraped | hold — mutation restores prefill to the c2/c4 level |
| bench_858173ba5753-mns5 | 2026-08-22 | ctx_pp2048 @ d16384 c5 (MUTATION max_num_seqs 5) | 5869.43 | 16.83 | 9850.01 | not scraped | hold — likewise restored |
| bench_076db52d341c | 2026-08-22 | pp2048 @ d131072 c1 | 42.59 | 0.02 | 48102.89 | not scraped | hold — 0.359x of d65536, steepening again (0.50x, then 0.40x, now 0.36x per doubling); campaign's tightest measurement, σ 0.05% |
| bench_076db52d341c | 2026-08-22 | ctx_pp2048 @ d131072 c1 | 2803.17 | 2.43 | 46770.69 | not scraped | hold — 0.70x of d65536, the steepest fall in the cached-prefill series |
| bench_dd3afc9e1c94 | 2026-08-22 | pp2048 @ d16384 c1 (tg32 arm, runs=7) | 623.13 | 8.72 | 3298.58 | 99229.33 (Atlas) — LOST | hold — R6 CONTROL: identical prefill work to the tg128 arm below, so the 1.90% gap between them prices the arm-to-arm systematic |
| bench_dd3afc9e1c94 | 2026-08-22 | pp2048 @ d16384 c1 (tg128 arm, runs=7) | 634.99 | 2.77 | 3237.23 | 99229.33 (Atlas) — LOST | hold — control passes (1.90% < 2% threshold), matching the flat d16384 series 637.09 / 634.04 / 643.31 |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_pp2048 @ d16384 c1 (tg32 arm, runs=7) | 5772.30 | 75.83 | 2850.87 | 884764.53 (Atlas) — LOST | hold — in line with the 5810-5967 series at this depth |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_pp2048 @ d16384 c1 (tg128 arm, runs=7) | 5849.11 | 56.10 | 2813.42 | 884764.53 (Atlas) — LOST | hold — 1.33% above the tg32 arm, same direction as the cold control |
| bench_0954971b5dfa | 2026-08-22 | pp2048 @ d16384 c8 (MUTATION max_num_seqs 8) | 631.25 | 0.31 | 16554.28 | not scraped | hold — R7 CONTROL PASSES: inside the flat 623-643 d16384 series, so matching the scheduler width eliminated R4's chunked-prefill interference |
| bench_0954971b5dfa | 2026-08-22 | ctx_pp2048 @ d16384 c8 (MUTATION max_num_seqs 8) | 5796.89 | 1.72 | 13969.54 | not scraped | hold — in line with the 5772-5967 series at this depth |
| bench_a769c1142e15 | 2026-08-22 | pp2048 @ d16384 c16 (MUTATION max_num_seqs 16) | 628.74 | 0.70 | 29751.25 | not scraped | hold — CONTROL PASSES at 4x R4's batch size: the c5 depression to 581.44 was a QUEUEING effect, not a batch-size effect. Strengthens R9's premise |
| bench_a769c1142e15 | 2026-08-22 | ctx_pp2048 @ d16384 c16 (MUTATION max_num_seqs 16) | 5791.30 | 11.10 | 25310.86 | not scraped | hold — flat against the c8 arm (-0.1%) |
| bench_3d8149654d1b | 2026-08-22 | pp2048 @ d16384 c1 (runs=7) | 628.66 | 3.25 | 3269.39 | 99229.33 (Atlas) — LOST | hold — **R8 SESSION CONTROL PASSES**: inside the flat d16384 series across seven invocations (637.09 / 634.04 / 643.31 / 623.13 / 634.99 / 640.21 / 631.25 / 628.74 / 628.66). This is what licenses reading R8's -16.8% as depth and not as a bad session |
| bench_3d8149654d1b | 2026-08-22 | pp2048 @ d65536 c1 (runs=7) | 119.54 | 0.32 | 17144.32 | no entries | hold — reproduces R3's 118.59 to 0.8% from a different engine start |
| bench_3d8149654d1b | 2026-08-22 | ctx_pp2048 @ d16384 c1 (runs=7) | 5856.93 | 28.45 | 2809.36 | 884764.53 (Atlas) — LOST | hold — in line with the 5772-5967 series at this depth |
| bench_3d8149654d1b | 2026-08-22 | ctx_pp2048 @ d65536 c1 (runs=7) | 4013.59 | 14.29 | 16340.55 | 1393.35 | **WIN — 2.88x**, and this is the claimed figure for the cell; reproduces R3's 4004.76 to 0.2% |
| bench_860b43edd154 | 2026-08-22 | pp2048 @ d16384 c4 (MUTATION mnbt 32768 + mns 16) | 672.59 | 0.88 | 11832.30 | not scraped | hold — ABOVE the flat 623-643 campaign-config series, as R9's arm A1 also was (669.28): a d16384 prefill fits in ONE 32768-token batch instead of two 8192 chunks |
| bench_860b43edd154 | 2026-08-22 | ctx_pp2048 @ d16384 c4 (MUTATION mnbt 32768 + mns 16) | 6168.36 | 8.80 | 10278.24 | not scraped | hold — above the 5772-5967 campaign-config series at this depth |
| bench_860b43edd154 | 2026-08-22 | pp2048 @ d16384 c16 (MUTATION mnbt 32768 + mns 16) | 667.00 | 1.75 | 39389.36 | not scraped | hold — +6.1% on R7's 628.74 at the same concurrency and scheduler width, so the lift is the budget and nothing else. Prediction 640-700 HELD |
| bench_860b43edd154 | 2026-08-22 | ctx_pp2048 @ d16384 c16 (MUTATION mnbt 32768 + mns 16) | 6108.27 | 8.82 | 30241.71 | not scraped | hold — +5.5% on R7's 5791.30 |
| bench_ac37f5b64487 | 2026-08-22 | pp2048 @ d16384 c2 (MUTATION mnbt 32768 + mns 5) | 658.93 | 2.76 | 6069.14 | not scraped | hold — above the flat 623-643 campaign-config series, in line with the other raised-budget arms (669.28 / 672.59 / 667.00). Prediction 655-695 HELD |
| bench_ac37f5b64487 | 2026-08-22 | ctx_pp2048 @ d16384 c2 (MUTATION mnbt 32768 + mns 5) | 6065.02 | 53.65 | 5269.25 | not scraped | hold — above the 5772-5967 campaign-config series at this depth |
| bench_ac37f5b64487 | 2026-08-22 | pp2048 @ d16384 c5 (MUTATION mnbt 32768 + mns 5) | 677.44 | 0.94 | 14484.92 | not scraped | hold — **R12 SESSION CONTROL PASSES, and it settles R4's depression**: the highest cold prefill figure at this depth in the campaign, against the 581.44 R4 measured at c5 with `mns 4` and mnbt 8192. Prediction 650-695 HELD. This is what licenses reading the R12 tg figures as scheduler effects |
| bench_ac37f5b64487 | 2026-08-22 | ctx_pp2048 @ d16384 c5 (MUTATION mnbt 32768 + mns 5) | 6158.49 | 20.66 | 12731.35 | not scraped | hold — also restored, against R4's depressed 5236.80 at this cell |
| bench_9379c15468ec-a-chunk | 2026-08-22 | pp2048 @ d16384 c4 (**R9b ARM A — prefix caching OFF, chunk ON, mnbt 32768**) | 663.93 | 0.75 | 11559.86 | **NOT SCOREABLE** | diagnostic — matches R9's A1 (669.28) to **0.8%** with prefix caching OFF, so the flag buys nothing in prefill. Session control passes |
| bench_9379c15468ec-a-chunk | 2026-08-22 | pp2048 @ d16384 c5 (**R9b ARM A**) | 597.78 | 4.26 | 12309.92 | **NOT SCOREABLE** | diagnostic — **`D_pp` = −9.96%** against the c4 row. R4's c5 depression REPRODUCES with prefix caching off |
| bench_9379c15468ec-a-chunk | 2026-08-22 | ctx_pp2048 @ d16384 c4 / c5 (**R9b ARM A**) | 6106.93 / 5379.73 | 16.60 / 16.34 | — | **NOT SCOREABLE** | diagnostic — **these figures broke the round's validity gate and the gate was wrong, not the arm.** They are the CONTEXT-LOAD pass, charged 16384 tokens per request against the cold rows' 2048, so the ~9x is `16384/2048` and not a cache effect. `Prefix cache hit rate: 0.0%` in all 22 engine samples |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | pp2048 @ d16384 c4 (**R9b ARM B — prefix caching OFF, chunk OFF, mnbt 32768**) | 655.82 | 1.48 | 9575.12 | **NOT SCOREABLE** | diagnostic — within 1.2% of arm A, so removing chunked prefill does not move the prefill rate at c4 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | pp2048 @ d16384 c5 (**R9b ARM B**) | 584.04 | 1.24 | 11115.00 | **NOT SCOREABLE** | **THE ROUND'S PRIMARY MEASUREMENT. `D_pp` = −10.95%**, against arm A's −9.96% — so `R_pp` = **1.099**, above the pre-declared 0.60 refutation threshold and pointing the WRONG WAY. **R4's chunked-prefill mechanism is REFUTED**: the c5 prefill deficit survives, slightly enlarged, in an engine that physically cannot chunk a prefill into a decode step |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | ctx_pp2048 @ d16384 c4 / c5 (**R9b ARM B**) | 6008.87 / 5262.09 | 4.74 / 19.00 | — | **NOT SCOREABLE** | diagnostic — context-load pass, within 1.6% / 2.2% of arm A |
