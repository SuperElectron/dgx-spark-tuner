# ANALYSIS-r23 — leaderboard reading, the prefill metric, and what is worth measuring next

Desk analysis, 2026-08-22. **Zero box time consumed.** No benchmark run, no ssh
workload, no GPU touched. Every number below comes from the archives already on
disk, the 2026-08-21 board scrape in `docs/arena-recipe.md`, and the
`llama-benchy` 0.4.0 source in
`~/.cache/uv/archive-v0/Tgb_tyGTzStQEu4j/llama_benchy/`.

This file is a report. It does not edit `RESULTS.md` or `journal.md`.

> **PARTLY SUPERSEDED 2026-08-22 by `ANALYSIS-board-rescrape.md`. Read that file
> before quoting any margin from this one.** The `pp_throughput` numerator
> finding below (`runner.py:225` passes 2048 while the engine prefills
> `depth+2048`) was independently confirmed. Two conclusions built on it were
> not, and are wrong here:
>
> 1. **The "1.082x WIN at 5027 tok/s" for `pp2048 @ d32768 c1` is WRONG.** The
>    warm-equivalent rate is the *marginal* `2048/(T2−T1)` = **4238 tok/s**, so
>    that row is **0.913x — a narrow loss**.
> 2. **§2.6's claim that the rising `ctx_pp`-with-depth shape is upload time is
>    WRONG** — it is `ttfr` drift. The true rate falls monotonically with depth
>    (2976 → 2662 → 2252 tok/s).
>
> The re-scrape also settled the question this file left open: the artefact does
> **not** cancel. Every opponent on every scored prefill row ran with a warm
> prefix cache, because ranking by cell top selects a warm entry by construction.
>
> Kept unedited rather than rewritten: the reasoning is sound and the source
> reads are correct, and seeing where a careful analysis went wrong is worth more
> than a tidied file. The corrected figures live in `RESULTS.md`.

Framing note that governs every recommendation: **there is no arena login and
nothing was ever submitted or ever can be.** "Winning a cell" has no external
payoff. The only two things this campaign produces with value are a correctly
tuned `recipe.yaml` and a record of what is actually true. Sections 1 and 2 are
graded against the record; section 3 is graded against the recipe.

---

## 1. Leaderboard analysis — what the standings actually say

### 1.1 The headline: at c1 this box is at parity with like-for-like, and the campaign never noticed

The standings are organised around board cells, which buries the single most
informative pattern in the data. Pull out every cell where the scrape carries a
**like-for-like** entry (same model class, vLLM runtime, NVFP4 quant) and the
picture is flat:

| Cell | Ours | Best like-for-like vLLM+NVFP4 | Ratio |
|---|---:|---:|---:|
| ctx_tg @ d8192 c1 | 127.64 | 118.07 (Nemotron-3.5-Lightning-30B-A3B-NVFP4) | **1.081x** |
| tg128 @ d16384 c1 | 112.62 | 116.03 (Qwen3.6-35B-A3B-NVFP4) | **0.971x** |
| ctx_tg @ d32768 c1 | 115.86 | 116.65 (Nemotron-3.5-Lightning-30B-A3B-NVFP4) | **0.993x** |
| tg128 @ d131072 c1 | 81.22 | 81.60 (Nemotron Lightning NVFP4) | **0.995x** |
| — | | | |
| tg128 @ d16384 **c2** | 140.77 | 163.27 (Qwen3.6-35B-A3B-NVFP4) | **0.862x** |
| tg128 @ d16384 **c5** | 164.27 | 225.46 (Qwen3.6-35B-A3B-NVFP4-Fast) | **0.729x** |

At **c1**, across four depths spanning 16x, we sit at **0.971x–1.081x**, mean
1.010x. That entire spread is inside the campaign's own ~7% position-bias floor
(R22). **There is no c1 deficit to find.** The box is a normally-configured
vLLM+NVFP4 GB10 and the recipe is, at c1, already correct.

At **c>1** the same box drops to 0.862x and 0.729x. The deficit is *entirely* a
concurrency deficit, and it is the exact size the span/stagger mechanism
predicts. This reframes the campaign: the 17 rounds of budget tuning were
chasing a real defect, but the defect is one specific thing (section 2.7), not a
general slowness.

It also retires the "reproduction gap" worry in `docs/arena-recipe.md` lines
112–118. That −12% was measured once at `tg128 @ d16384 c1` in the quant series
(102.2). This campaign's pooled 14-run figure for the same cell is 112.62, i.e.
**0.97x of the board's like-for-like 116.03**. The gap is −2.9%, not −12%, and
−2.9% is a fraction of the position-bias floor. There is no unexplained
reproduction gap.

### 1.2 The 8 wins, graded

Entry counts are the board's own single-node "Showing N results".

| # | Cell | Entries | Ours | Board top | Margin | Grade |
|---|---|---:|---:|---:|---:|---|
| 1 | tg32 @ d8192 c1 | 1 | 123.81 | **no number published** | — | **NOT A WIN.** Empty. Nothing to beat, nothing to post to |
| 2 | tg32 @ d16384 c1 | 1 | 116.43 | 28.11 | 4.14x | Uncontested; measures the incumbent's brokenness |
| 3 | tg32 @ d32768 c1 | 1 | 115.85 | 23.31 | 4.97x | Same. Best-sampled row in the campaign (24 runs) |
| 4 | tg128 @ d16384 c4 | **8** | 52.85 / 173.34 | 46.68 | 1.13x / 3.71x | Most meaningful win — but see 1.3 |
| 5 | ctx_tg @ d16384 c4 | **7** | 56.36 / 171.77 | 27.68 | 2.04x / 6.21x | Same operating point, Phase 1. Not an independent win |
| 6 | tg128 @ d65536 c1 | 2 | 94.10 | 16.48 | 5.71x | Thin cell |
| 7 | ctx_tg @ d65536 c1 | 1 | 92.98 | 20.70 | 4.49x | Uncontested |
| 8 | ctx_pp @ d65536 c1 | 1 | 4013.59 | 1393.35 | 2.88x | Uncontested — **but the only honest prefill number in the file.** See 2.5 |

**Not one of the eight is in a crowded cell.** The busiest cell we won has 8
entries. Every cell on this board with 120–132 entries, we lost or drew. The
board's c4 column is effectively abandoned — 7–8 entries against 120–130 at c2
and c5 — so even win #4, the one RESULTS.md calls "the only contested cell we
hold", is contested by a near-empty field.

**Wins 2, 3, 6, 7 measure the incumbent, not us.** The tg32 cells are held by a
single Qwen3.6-27B-PrismaSCOUT-NVFP4 entry posting 23–28 tok/s decode. Our own
tg128 decode at the same depths is 112–116, and the board's like-for-like tg128
figures are 116. A 27B NVFP4 model posting 28 tok/s on a GB10 is roughly 4x
below what the hardware plainly does. That entry is a misconfigured or throttled
run. Beating it 4.97x is arithmetic, not a discovery, and the 24-run sample
behind win #3 buys precision on a number whose margin was never in doubt.

**Robustness summary.** Of the eight: one is empty (#1), four are uncontested
single-entry cells against an apparently broken incumbent (#2, #3, #7, and #8's
incumbent is explicitly flagged as a probable slow outlier), one is a duplicate
operating point (#5), one is a thin 2-entry cell (#6). **The campaign's real
result at c4 is a single operating point, and #4 at the shipping-ish config is
1.13x — thin enough that it sits only ~6 points above the position-bias floor.**
The 3.15x–3.71x figures in that cell are all at `mns 5`, which the recipe does
not ship.

### 1.3 The one number in the wins table that is genuinely load-bearing

`tg128 @ d16384 c4` at `mnbt 65536 + mns 5` reads **173.34** with `tg_req 65.24`
and `span 1.505`. That is not a board result — the board cell is abandoned — it
is a *mechanism* result: it says four concurrent requests on this box produce
4 × 65.24 = 260.96 tok/s of decode work, and the metric only reports 173.34
because the batch span is 1.505x the decode window. **The 87.6 tok/s difference
is the whole prize**, and section 2.7 identifies what is spending it.

### 1.4 Record integrity — one thing checked and clear

`recipe.yaml` defaults `max_model_len: 32768`, yet the campaign has rows at
d65536 and d131072 whose Phase-2 requests are 67584 and 133120 tokens. Those
would be rejected outright at a 32768 limit, which would invalidate wins #6, #7
and #8. **Checked: sparkrun scales it.** `bench_3d8149654d1b/sparkrun-stdout.log`
line 9 records `max_model_len=73,728` for the d65536 invocation, and the run log
carries zero errors. No truncation. Those rows stand.

---

## 2. The prefill metric check — resolved, with source lines

This was the highest-value item and it cost nothing. It resolves cleanly, and
the answer is not the one `RESULTS.md` currently records.

### 2.1 What `pp_throughput` is computed from

At concurrency 1 (all six prefill cells are c1), `results.py:191` selects
`agg_pp_speeds`:

```
results.py:191   run_metric_pp_throughput = self._calculate_metric(
                     agg_batch_pp_throughputs if concurrency > 1 else agg_pp_speeds)
```

and `agg_pp_speeds` is filled at `results.py:313-315`:

```
results.py:306   est_ppt = max(0, ttfr - latency)
results.py:313   if est_ppt > 0:
results.py:314       pp_speed = prompt_tokens / est_ppt
results.py:315       agg_pp_speeds.append(pp_speed)
```

- **Denominator**: `est_ppt = ttfr − latency`, where `ttfr = first_response_ts −
  start_ts` (`results.py:299`) and `latency` is the mean of **three HTTP GET
  round trips to `/models`** (`client.py:155-188`, mode `api`; measured at
  13.39 ms in the archived runs).
- **Numerator**: `prompt_tokens`, which is `expected_pp_tokens` as passed by the
  runner (`results.py:283-289`), and the runner passes **different things to the
  two phases**:

```
runner.py:224   ...run_ctx_results, latency, expected_ctx,  is_context_phase=True     # = depth
runner.py:225   ...run_std_results, latency, expected_pp,   is_context_phase=False    # = 2048
```

So for a Phase-2 `pp2048 @ dN` row the numerator is **2048** while the request
actually presented to the engine is `depth + 2048` tokens (`runner.py:187`,
`expected_tokens = current_pp + current_depth`).

### 2.2 That numerator is only correct when the prefix cache hits

The two-phase structure exists *only* because prefix caching was requested —
`runner.py:127` and `runner.py:223` both gate it on
`if self.config.enable_prefix_caching and depth > 0`. The design intent is
explicit: Phase 1 loads the context, Phase 2 reuses it, so Phase 2 really does
prefill only 2048 new tokens and 2048 is the right numerator.

**For us the cache never hits — 220+ consecutive engine samples at 0.0% — so
the numerator is wrong by exactly `(depth+2048)/2048`.**

### 2.3 Direct proof from the archives, at 4 depths, with no free parameters

`est_ppt` is exported per run, so this is measurable rather than inferred.
Computed from `bench_25a0e7f36ab0` and `bench_3d8149654d1b`:

| Cell | est_ppt (median) | reported | tokens charged | tokens actually prefilled | **true rate** | understated |
|---|---:|---:|---:|---:|---:|---:|
| ctx_pp @ d8192 | 1332.7 ms | 6148.56 | 8192 | 8192 | 6147.06 | 1.00x |
| pp2048 @ d8192 | 1724.6 ms | 1187.51 | 2048 | 10240 | **5937.53** | **5.00x** |
| ctx_pp @ d16384 | 2797.7 ms | 5856.93 | 16384 | 16384 | 5856.22 | 1.00x |
| pp2048 @ d16384 | 3257.7 ms | 628.66 | 2048 | 18432 | **5657.91** | **9.00x** |
| ctx_pp @ d32768 | 6442.5 ms | 5086.51 | 32768 | 32768 | 5086.20 | 1.00x |
| pp2048 @ d32768 | 6925.7 ms | 295.71 | 2048 | 34816 | **5027.06** | **17.00x** |
| ctx_pp @ d65536 | 16328.8 ms | 4013.59 | 65536 | 65536 | 4013.53 | 1.00x |
| pp2048 @ d65536 | 17132.5 ms | 119.54 | 2048 | 67584 | **3944.77** | **33.00x** |

Two independent confirmations fall out of the `est_ppt` column:

1. **The Phase-2 wall time is the cold-prefill time.** `T2/T1` measures
   1.294 / 1.159 / 1.075 / 1.049 at the four depths. A **cold** Phase 2 predicts
   `(depth+2048)/depth` = 1.250 / 1.125 / 1.0625 / 1.031 — every one within
   1.8–3.5%. A **cache hit** predicts 0.25 / 0.125 / 0.0625 / 0.031, which is
   off by a factor of 5 to 33. Phase 2 re-prefills the entire context, every
   time. Prefix caching contributes literally nothing.
2. **Both phases prefill at the same rate.** True rate Phase 1 vs Phase 2:
   6147/5938, 5856/5658, 5086/5027, 4014/3945 — agreement to 1–3% at every
   depth, and the rate falls monotonically with depth exactly as attention cost
   requires. These are physical, sane numbers.

### 2.4 Conclusion 1 — our `pp2048` figures are not prefill measurements

**Stated plainly: `pp2048 @ dN` for this campaign does not measure prefill
throughput. It measures `2048 / (time to prefill depth+2048 tokens)`, a quantity
with no physical meaning, and it is depressed by exactly `(depth+2048)/2048`.**
The 15x gap against Laguna-XS-2.1-NVFP4 at `pp2048 @ d32768 c1` (295.71 vs
4644.54) is **numerically indistinguishable from the 17.00x instrument
artefact** — which is precisely why the asymmetry against a 3% decode gap looked
like a definition mismatch. It was one.

Our true prefill throughput is **5027 tok/s at d32768**, and 6147 / 5856 / 4014
at d8192 / d16384 / d65536.

### 2.5 Conclusion 2 — `RESULTS.md`'s "the artefact cancels" is not established, and is probably wrong

`RESULTS.md` lines 96–101 disarm the rescaling trap by asserting that the
board's figures come through the same CSV and carry the identical
understatement, so the artefact cancels. **That is true only for a competitor
whose prefix cache also missed.** A competitor whose cache *hit* has an honest
2048-token numerator, and against them the artefact does not cancel at all.

Physical check on the like-for-like entry. If Laguna-XS-2.1-NVFP4 were also
cold, its true prefill rate at d32768 would be 4644.54 × 17 = **78,957 tok/s** —
15.5x our 3B-active model's rate on the same class of hardware. Prefill at 32k
depth is heavily attention-dominated, and attention cost does not shrink with
parameter count, so a 15.5x prefill advantage is not available to any model,
however small. The cache-hit reading (4644.54 as an honest 2048-token
measurement against a warm 32k prefix) is the only physically comfortable one.

**If Laguna's cache hit, the corrected like-for-like comparison at
`pp2048 @ d32768 c1` is 5027.06 vs 4644.54 = 1.082x — a WIN, not a 0.064x
loss.** That is a 17x swing on a standings row.

I cannot close this from the archives alone. It is closable for **zero box
time** — see experiment **B** in section 3, which is why it is ranked second.

### 2.6 Conclusion 3 — every Atlas prefill "top" is an artefact, not a target

`est_ppt = max(0, ttfr − latency)` is a pathologically unstable estimator: it is
unbounded above, floored at zero, and `ttfr` fires on the **first streamed chunk
that carries a `choices` key, regardless of whether that chunk contains any
content**:

```
client.py:351   if 'choices' in chunk and len(chunk['choices']) > 0:
client.py:352       if result.first_response_ts is None:
client.py:353           result.first_response_ts = chunk_time
```

whereas the first *token* is tracked separately and does require content
(`client.py:367-370`). Any runtime that flushes an empty role-delta chunk before
prefill completes collapses `est_ppt` toward zero and reports unbounded prefill
throughput.

The Atlas figures are in that regime, and they are impossible on their face.
`ctx_pp @ d32768 c1 = 945,271` implies `est_ppt = 32768/945271 = 34.7 ms`. For
Qwen3.6-35B-A3B (~3B active), prefilling 32768 tokens is ~ 2 x 3e9 x 32768 =
2.0e14 FLOPs, so 34.7 ms implies **5.7 PFLOPS — over 5x the GB10's headline
sparse FP4 peak and roughly 11x its dense FP4 rate.** Not a measurement.

Two further tells. The implied `est_ppt` values (10.6 / 18.5 / 34.7 ms at d8192 /
d16384 / d32768) scale as roughly `depth^0.87` — sub-linear, which is the
signature of **request-body upload time** (~130 KB of JSON at d32768, ~3.5 MB/s)
plus fixed overhead, not of prefill compute, which must scale super-linearly.
And the archived `latency` subtraction is 13.39 ms, the *same order as the entire
Atlas measurement* — so those figures are dominated by the error in a 3-sample
HTTP GET estimate. Finally, the shape disagreement the synthesis flagged as
suspicious — our Phase-1 rate falls with depth while board `ctx_pp` incumbents
*rise* (775k → 885k → 945k) — is now explained: a real prefill rate cannot rise
with depth; an upload-time-dominated one drifts up as fixed overheads amortise.

**Recommended record change**: the six prefill rows should be restated from
"LOST by 15x–200x" to **"NOT SCORED — the instrument does not measure prefill
under a cold prefix cache, and the incumbent figures are non-physical."** They
are not losses. Keeping them as losses overstates the campaign's deficit by up
to two orders of magnitude, and it is the same class of error the audit-selection
ledger already caught the campaign making in its own disfavour.

Note the inversion this produces: **`ctx_pp` is honest** — its numerator is the
token count actually prefilled — so win #8 (`ctx_pp @ d65536 c1`, 4013.59 vs
1393.35 = 2.88x, both vLLM) is a **genuine like-for-like prefill win**, and it is
the only trustworthy prefill comparison in the entire file. The campaign was
treating its one real prefill result as its least interesting.

### 2.7 The thing this makes urgent: prefix caching has never hit, and it is not the benchmark's fault

The synthesis carries this as a curiosity. The metric analysis makes it the
campaign's central open defect, and I can narrow the cause substantially without
box time.

**The access pattern does NOT defeat caching.** Phase 1 sends
`system: <context>` + `user: CONTEXT_LOAD_USER_MESSAGE` (`runner.py:137-139`);
Phase 2 sends `system: <same context>` + `user: <2048-token prompt>`
(`runner.py:163-166`), and `client.py:298-300` places the system message first
in both. Under the Qwen chat template the two requests share an identical token
prefix of 16384+ tokens. `prompt_batch` is generated once per run
(`runner.py:120-125`) and both phases index the same element, so the context
text is byte-identical. The instrument is doing exactly what a prefix cache
needs.

**Capacity and eviction are ruled out.** From
`bench_30d6586cc70a-p-pc-on/engine-serve.log`:

```
line 100  GPU KV cache size: 3,071,735 tokens, Maximum concurrency for 32,768 tokens per request: 93.74x
line 196  ... GPU KV cache usage: 3.6%, Prefix cache hit rate: 0.0%
```

Peak KV usage across the whole run is **3.6% of a 3.07M-token pool** — roughly
28x more capacity than the 4 x 16384 = 65,536 tokens Phase 1 needs to retain.
Nothing is being evicted for space.

**Block granularity is ruled out.** `interface.py:911` forces the attention block
size to **2144 tokens** to match the mamba page size. A 16384-token shared prefix
is 7.64 blocks, so 7 full blocks (15,008 tokens, 81% of an 18,432-token Phase-2
request) are block-aligned and eligible. There is a large, well-aligned,
resident, identical prefix — and the hit rate is exactly 0.0%.

So: **prefix caching is silently inoperative in this configuration for
engine-side reasons.** The model is a hybrid — `config.py:605` logs *"Mamba cache
mode is set to 'align' for Qwen3_5MoeForConditionalGeneration by default when
prefix caching is enabled"* — and the recipe simultaneously carries three things
known to interact badly with prefix reuse: `--kv-cache-dtype fp8`,
`--attention-backend flashinfer`, and MTP speculative decoding. Each is a
single-flag mutation with a **binary** readout. That is experiment **A**.

The prize is large and follows from the campaign's own established chain. Using
R13b's zero-parameter identity `span ~ 1 + spread / decode_duration` at the c4
knee (`tg` 173.34, `tg_req` 65.24, `span` 1.505, `decode_duration = 127/65.24 =
1.947 s` → implied spread ~ 0.983 s): if Phase-2 prefill work drops 9x at
d16384, the prefill-completion spread drops with it to ~0.109 s, span → ~1.056,
and `tg = 4 x 65.24 / 1.056 ~ **247**` — a **+42%** move at c4 from a flag that
is already switched on. The same mechanism projects c5 from 164.27 to ~230
(vs like-for-like 225.46, a flip) and c2 from 140.77 to ~176 (vs 163.27, a flip).

**This single defect is the common cause of the c2 loss, the c5 loss, and all six
prefill "losses".** It is also the most plausible explanation for how the board's
like-for-like vLLM entries beat us at c2 and c5 while tying us at c1: their cache
hits and ours does not.

---

## 3. Proposed next experiments, ranked

Excluded as instructed: anything at d131072; budgets above 65536 at c4; any
repeat of `ctx_tg @ d32768 c1`; and the two rounds in flight (the A-B-B-A
position-bias round, and `mnbt 65536 + mns 4` at tg128 d16384 c4).

Every proposal below is a single mutation with pre-declared thresholds, and every
comparison is inside one session with arm order recorded, per the campaign's
carried rules.

### A — Prefix-cache root cause ladder. **Rank 1 by a wide margin.**

- **Cell / config**: `tg128 @ d16384 c4`, `mnbt 65536`, `mns 4` (shipping
  recipe), `runs=3`. Three arms, one flag each, one session, order recorded:
  **A0** recipe as shipped (control) - **A1** `-o kv_cache_dtype=auto` -
  **A2** recipe with `--speculative-config` removed.
- **Hypothesis**: prefix caching is inoperative because of fp8 KV cache or MTP
  speculative decoding on a hybrid mamba model. Instrument, access pattern,
  capacity, eviction and block alignment are all ruled out in section 2.7.
- **Readout**: `Prefix cache hit rate` from the engine log. **Free, and binary.**
  This is the round's key virtue — a 0.0%-vs-nonzero readout is completely immune
  to the +/-7% position bias, to MTP acceptance bimodality, and to the 3-run
  problem. `runs=3` is sufficient; we are not quoting a throughput.
- **Confirm**: any arm reports hit rate > 50% on the Phase-2 pass (the alignment
  ceiling is ~81%).
- **Refute**: all three read exactly 0.0% → prefix reuse is unavailable for this
  architecture in this build. Stop. Record that `--enable-prefix-caching` is a
  mamba-scheduling flag on this model and nothing more.
- **Box time**: 3 engine starts (~150 s each) + 3 short grids (~90 s each) ~
  **12–13 min**. The cheapest high-value round available.
- **If it confirms**: run one follow-up throughput arm at the fixed config, then
  fold. Projected +42% at c4, and flips of the c2 and c5 like-for-like
  comparisons (section 2.7). It would also make `pp2048` a valid metric for us
  for the first time, retiring the whole of section 2.4.
- **If it refutes**: costs 13 minutes and closes the campaign's oldest open
  question with a definite answer, which is worth having on its own.

### B — Per-entry board re-scrape to settle whether the prefill artefact cancels. **Rank 2. Zero box time.**

- **What**: re-scrape the leaderboard capturing, **for individual entries**,
  both `ctx_pp @ dN` and `pp2048 @ dN`. The board is public; no login is needed
  and nothing is submitted. Compute `ctx_pp / pp2048` per entry.
- **Hypothesis**: that ratio is a clean cache-hit discriminator. A **cold** entry
  reads `(depth+2048)/2048` = **17.0** at d32768 (as ours does, 45 of 46 archived
  pairs). A **warm** entry reads **~1–2**, because a cache hit collapses the
  Phase-2 denominator while the numerator stays 2048.
- **Confirm cold** (ratio ~17 for the vLLM like-for-like entries): the artefact
  cancels, `RESULTS.md` lines 96–101 are right, the six prefill rows stand as
  recorded. Cheap vindication.
- **Confirm warm** (ratio ~1–2): the artefact does **not** cancel; our corrected
  5027.06 vs Laguna's 4644.54 = **1.082x**, and up to six standings rows are
  wrong by up to 17x in our disfavour.
- **Box time**: **zero.** Harness tokens only.
- **What it changes**: it is the only thing that can close section 2.5, and it is
  free. Note the Atlas ratio already computable from the existing scrape is
  945271/63079 = 15.0 ~ 17, i.e. Atlas looks cold — but Atlas is separately
  non-physical (section 2.6), so it settles nothing about the vLLM entries.

### C — `num_speculative_tokens` 3 → 4 → 5. **Rank 3. The only untried lever that can move c1.**

- **Cell / config**: `tg128 @ d16384 c1` (crowded cell, like-for-like 116.03,
  ours 112.62 = 0.97x), shipping recipe, `runs=7`. Arms `nst=3` (control) / 4 / 5,
  one session, order reversed and recorded.
- **Hypothesis**: **the speculative budget, not acceptance quality, is the
  binding constraint.** The campaign's own telemetry measures accepted length
  **3.56–3.71 at 85.4–90.2% acceptance** across four independent engine starts at
  d32768. With `num_speculative_tokens=3` the ceiling is 4.0, so we are running at
  89–93% of the maximum the budget allows. That is a saturated knob, and
  `research/docs/vllm-parameters.md:70` flags it as a classic hill-climb that this
  campaign never touched — spec decode was fixed at `mtp/3` for all 17 rounds.
- **Confirm**: `nst=4` or `5` raises the median `tg` by **>7%** (clear of the
  position-bias floor) **and** raises accepted length above 3.71.
- **Refute**: <7% change, or accepted length flat → the budget is not binding.
  Fold nothing.
- **Box time**: 3 engine starts (~150 s) + 3 grids (~180 s) ~ **17 min**.
- **What it changes**: c1 is where the recipe is quotable and where we currently
  sit at 0.97x–1.08x of like-for-like across four depths. A 7–10% gain moves
  `tg128 @ d16384 c1` from 0.97x to ~1.05x, improves *every* c1 row including the
  0.995x dead heat at d131072, and compounds with any c>1 fix from **A**. This is
  the only proposal that improves the recipe at c1 rather than at c4.
- **Caveat**: a longer speculative chain costs more verify work per step, so
  there is a real chance of a *regression* at 5. That is a valid outcome — it
  bounds the knob and is worth recording either way.

### D — `--moe-backend` alternative to `marlin`. **Rank 4. Speculative but genuinely untried.**

- **Cell / config**: `tg128 @ d16384 c1`, shipping recipe, one alternative MoE
  backend, `runs=7`, arm order reversed. Ride along with **C**'s session if the
  engine starts allow.
- **Hypothesis**: on a 35B-A3B MoE, the expert GEMM is the decode bottleneck, and
  the backend was inherited from the de-rayed @eugr recipe and never tested.
  `marlin` + `VLLM_MARLIN_USE_ATOMIC_ADD=1` is a plausible-but-unverified default.
- **Confirm**: >7% median `tg` improvement. **Refute**: <=7%, or a crash (crashes
  are data — record the incompatibility and revert).
- **Box time**: ~6 min if it rides along; ~12 min standalone. Higher crash risk
  than **C**, which is why it is ranked below it.
- **What it changes**: potentially every row in the campaign, since it is a
  decode-path change that applies at all concurrencies. But it has no supporting
  evidence behind it — this is an honest shot in the dark, ranked accordingly.

### Explicitly NOT worth the box time

I am deliberately keeping this list short and the "no" list long.

- **Budget knee at c2 and c5.** Superficially attractive — the knee was taken at
  c4 only — but it is already effectively done. The predicted knee is
  `c x 18432`: 36,864 at c2 and 92,160 at c5. c2 was measured at 32,768 (140.77,
  0.86x) and c5 at 98,304 (164.27, 0.73x). **Both were already run at or above
  their own knee** and neither reached like-for-like. The budget lever is
  exhausted at c2 and c5 as well as at c4. Skip.
- **`--kv-cache-memory-bytes`** (flagged in `vllm-parameters.md` as the primary
  memory knob, never tried). Peak KV usage is **3.6% of 3.07M tokens**. There is
  no KV pressure anywhere in this campaign, so neither enlarging nor pinning the
  pool can move throughput. Worth one line in the record — `gpu-memory-utilization
  0.8` is over-provisioned by ~28x for these cells — but not worth an engine start.
- **`--async-scheduling` off.** Untried, but it is already at the setting that
  overlaps CPU scheduling with GPU execution. Turning it off can only cost. No
  headroom.
- **`--max-num-seqs` sweeps.** Exhausted: mns 4/5/16 at c4 span <=2.9%.
- **More MTP acceptance telemetry.** Retired claim 22 — it explains 17% of the
  span excess and more of it will not change that. (Note this is *not* the same
  as proposal **C**, which changes the spec budget rather than measuring
  acceptance.)
- **Re-running any of the four uncontested tg32 cells for precision.** Win #3
  already has 24 runs on a margin that was never in doubt against an incumbent
  that is plainly broken. Precision there buys nothing.
- **Anything premised on `--enable-prefix-caching` being separable from mamba
  cache mode.** Provably validator-refused; the synthesis is right that this must
  be answered by reading the mamba2 chunking path, not by benchmarking.

### Recommended order

**B** first — it is free and can run right now while the box is busy. **A** the
moment the box frees, because it is 13 minutes for a binary answer to the
campaign's central defect. **C** next, as the only c1 lever. **D** only if **C**
leaves an engine start spare.

---

## 4. Summary of proposed record corrections

None of these are applied here; `RESULTS.md` and `journal.md` are being written
by another agent.

1. The six `pp2048` / `ctx_pp @ d8192–d32768` rows are **not losses**. Restate as
   NOT SCORED with the true prefill rates (6147 / 5856 / 5086 / 4014 tok/s by
   depth) and the instrument reason. See 2.4, 2.6.
2. `RESULTS.md` lines 96–101, "the artefact cancels", is **not established** and
   is probably wrong for warm-cache competitors. Pending experiment **B**. See 2.5.
3. Add: every Atlas prefill top exceeds the GB10's FP4 peak by >5x and is an
   artefact of `est_ppt = ttfr - latency`. Out of scope for a stronger reason
   than "different runtime". See 2.6.
4. `ctx_pp @ d65536 c1` (2.88x) is the campaign's **only honest prefill
   comparison** and is like-for-like vLLM. Promote it in the narrative. See 2.5.
5. `tg32 @ d8192 c1` should not be counted among the 8 — the cell publishes no
   number. The honest standing is **7 cells won, of which 5 are uncontested and 2
   are the same c4 operating point in two phases.** See 1.2.
6. The "reproduction gap" in `docs/arena-recipe.md` lines 112–118 is **-2.9%, not
   -12%**, using this campaign's pooled 14-run figure. It is inside the
   position-bias floor and needs no explanation. See 1.1.
7. Add the c1-parity finding as a headline: **0.971x-1.081x of like-for-like
   across four depths at c1; 0.862x and 0.729x at c2 and c5.** The deficit is
   purely a concurrency deficit. See 1.1.
