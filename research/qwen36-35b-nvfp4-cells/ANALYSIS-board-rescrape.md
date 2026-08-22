# ANALYSIS-board-rescrape — the per-entry cache-hit discriminator

Desk analysis, 2026-08-22. **Zero box time consumed.** No benchmark run, no ssh,
no GPU touched, no git command, nothing written inside the repo. No arena login;
none was offered and none was used. The board's data was read from the public
Firebase endpoint the leaderboard SPA itself reads.

Primary input: `ANALYSIS-r23.md` (sections 2.2–2.6). This file closes its
experiment **B** and settles its section-2.6 secondary claim, with per-entry data.

---

## 0. Method and provenance

`spark-arena.com/leaderboard` is a Next.js SPA; WebFetch is 403'd by the edge, but
the page's own JS chunks name a Firebase Realtime Database,
`https://spark-arena-default-rtdb.firebaseio.com`. The `/leaderboard` subtree is
world-readable (`/benchmarks`, `/submissions`, `/results` and the root are all
`Permission denied` — only `/leaderboard` opens). No credentials were presented
at any point.

    GET https://spark-arena-default-rtdb.firebaseio.com/leaderboard/byTest/<cell>.json

390 cells. Each returns `{metadata:{entryCount,lastUpdated}, snapshot:[...]}` and
each snapshot element is a **per-entry record**:

    {benchmarkId, clusterSize, modelName, modelFullPath, quantization, runtime,
     recipeType, rank, tokensPerSec, ttfr, estPpt, e2eTtft, submittedAt, userId, ...}

Two things make this far stronger than a rendered-table scrape:

1. **`benchmarkId` is stable across cells.** The same submission appears in
   `pp2048 @ dN (c1)` and `ctx_pp @ dN (c1)`, so the two figures can be joined
   **per entry** rather than per cell. The join is essentially total: 214/214 at
   d8192, 211 of 211/213 at d16384, 202 of 202/204 at d32768.
2. **`estPpt` and `e2eTtft` are published per entry.** `estPpt` is the metric's
   own denominator in ms; `e2eTtft` is time to the first *content-bearing* token
   (`results.py:304`, `progress.py:92`), while `ttfr` is time to the first chunk
   carrying a `choices` key (`results.py:299`, `client.py:351-353`). Having both
   turns section 2.6 from an inference into a direct measurement.

Snapshot timestamp `2026-08-22T19:00:32Z`. **Scrape verified against the
2026-08-21 record before use**: filtering `clusterSize == 1` reproduces
`docs/arena-recipe.md`'s single-node entry counts exactly — 129 / 131 / 125 at
d8192 / d16384 / d32768 — and every board top quoted in `RESULTS.md`
(215894.21, 99229.33, 63079.61, 775122.96, 884764.53, 945271.31, 1393.35)
reappears to the cent. All figures below are `clusterSize == 1`.

Every board figure, like every figure of ours, is a **median** over that
submission's runs. Our own figures are the medians already recorded in
`RESULTS.md`.

---

## 1. The discriminator, restated in the form the data supports

`ANALYSIS-r23` proposed `ctx_pp / pp2048` per entry. With `estPpt` published, the
same question is answerable more directly and with the depth factor divided out.

Write `T1 = estPpt` on the `ctx_pp` record (Phase 1 wall time) and `T2 = estPpt`
on the `pp2048` record (Phase 2 wall time), same `benchmarkId`, same depth.

- **COLD** (cache misses, Phase 2 re-prefills `depth + 2048`):
  `T2/T1 = (depth+2048)/depth` — 1.250 / 1.125 / 1.0625 at d8192 / d16384 / d32768.
- **WARM** (cache hits, Phase 2 prefills only the 2048 new tokens):
  `T2/T1 ≈ 2048/depth` — 0.250 / 0.125 / 0.0625, plus per-request overhead.

The published ratio is the same statement scaled: `ctx_pp/pp2048 = (depth/2048) × T2/T1`.
`T2/T1` is preferred here because its cold expectation is ~1 at every depth, so
the two classes do not slide past each other as depth changes.

Threshold used throughout: **COLD if `T2/T1 > 0.8`**. The gap in the data is far
wider than that threshold is delicate — see the histograms.

---

## 2. Result: the board is mixed, and it is mostly WARM

`T2/T1` histograms, single-node, joined entries only:

**d32768** (n = 125; cold expects 1.0625, warm expects 0.0625)

    0.1: 48   0.2: 39   0.3: 10   0.4: 4   0.5: 1   0.6: 2   0.7: 2   0.9: 1
    1.1: 17   1.2: 1
    -> COLD 19 (15.2%)   WARM 106 (84.8%)

**d16384** (n = 131; cold 1.125, warm 0.125)

    0.1: 4   0.2: 37   0.3: 27   0.4: 17   0.5: 8   0.6: 5   0.7: 8   0.8: 1
    0.9: 1   1.0: 1   1.1: 11   1.2: 11
    -> COLD 24 (18.3%)   WARM 107 (81.7%)

**d8192** (n = 129; cold 1.250, warm 0.250)

    0.2: 4   0.3: 15   0.4: 19   0.5: 12   0.6: 20   0.7: 2   0.8: 17   0.9: 4
    1.0: 2   1.1: 4   1.2: 14   1.3: 15   1.5: 1
    -> COLD 50 (38.8%)   WARM 79 (61.2%)

The distribution is **bimodal at d32768 and d16384**, with the cold mode sitting
exactly on its predicted value (1.1 against 1.0625; 1.1–1.2 against 1.125) and
the warm mode piled at 0.1–0.3. That is a clean confirmation that the
discriminator works and that both populations exist on this board. At d8192 the
two modes are only 5x apart and per-request overhead smears them together, so
d8192 classifications should be treated as indicative, not decisive.

**We are in the cold minority.** Our own archived `T2/T1` is 1.294 / 1.159 /
1.075 / 1.049 at the four depths, and our prefix-cache hit rate is 0.0% across
220+ engine samples.

### 2.1 The entries `RESULTS.md` actually scores against

| Depth | Entry | Runtime / quant | `pp2048` | `ctx_pp` | `ctx_pp/pp2048` | `T2/T1` | **Verdict** |
|---|---|---|---:|---:|---:|---:|---|
| d32768 | **Laguna-XS-2.1-NVFP4** | vLLM NVFP4 | 4644.54 | 8002.87 | 1.723 | **0.108** | **WARM** |
| d16384 | Laguna-XS-2.1-NVFP4 | vLLM NVFP4 | 5878.08 | 8747.25 | 1.488 | **0.186** | **WARM** |
| d8192 | Laguna-XS-2.1-NVFP4 | vLLM NVFP4 | 6944.70 | 8764.73 | 1.262 | **0.316** | **WARM** |
| d32768 | Qwen3.5-0.8B (cell pp2048 top ex-Atlas) | vLLM BF16 | 9778.34 | 21636.54 | 2.213 | **0.138** | **WARM** |
| d16384 | gemma-3-1b-it | vLLM BF16 | 17162.78 | 31447.28 | 1.832 | **0.230** | **WARM** |
| d8192 | LFM2.5-350M | vLLM BF16 | 32034.06 | 59634.42 | 1.862 | **0.465** | **WARM** |
| d32768 | best same-model Qwen3.6-35B-A3B-NVFP4 vLLM | vLLM NVFP4 | 2099.16 | 5732.74 | 2.731 | **0.190** | **WARM** |
| d16384 | best same-model Qwen3.6-35B-A3B-NVFP4 vLLM | vLLM NVFP4 | 2662.97 | 6163.87 | 2.315 | **0.322** | **WARM** |
| d8192 | best same-model Qwen3.6-35B-A3B-NVFP4 vLLM | vLLM NVFP4 | 2668.71 | 6022.92 | 2.257 | **0.621** | WARM (d8192 caveat) |
| d32768 | Qwen3.6-35B-A3B-NVFP4 | vLLM FP4 | 341.73 | 5939.56 | 17.381 | **1.086** | **COLD** — same failure as ours |
| d32768 | Qwen3.6-35B-A3B-FP8 | vLLM FP8 | 334.29 | 5806.88 | 17.371 | **1.086** | **COLD** |
| d32768 | Qwen3.6-35B-A3B-int4-AutoRound | vLLM INT4 | 313.37 | 5447.25 | 17.383 | **1.086** | **COLD** |
| d65536 | DeepSeek-V4-Flash-0731-REAP | vLLM FP8 | *(cell empty)* | 1393.35 | — | — | n/a, honest (`ttfr == e2eTtft == 42155.78`) |

**Every single entry `RESULTS.md` compares our `pp2048` figures against is WARM.**
That includes the like-for-like Laguna-XS-2.1-NVFP4 at all three depths, the
non-Atlas cell tops, and the best same-model vLLM NVFP4 entry at every depth.

### 2.2 Answer to the question `RESULTS.md` lines 96–101 assert

> "the board's prefill figures come through the same llama-benchy CSV and carry
> the identical understatement, so the artefact cancels"

**Refuted.** The competitors we score against carry no understatement at all.
`ANALYSIS-r23` section 2.5 called this "probably wrong"; it is wrong, and by a
factor of `(depth+2048)/2048` — 5x, 9x, 17x by depth.

The board is not homogeneous: 15–19% of entries at d16384/d32768 are cold like
us, and against *those* the artefact does cancel exactly (three of them are
listed above at `T2/T1 = 1.086`, and their `pp2048` figures — 341.73, 334.29,
313.37 — are the same order as our 295.71, which is the tell). But none of them
is the entry any scored row is measured against, because a cold entry's
`pp2048` is depressed 17x and it therefore ranks near the bottom of the cell.
**The scoring rule "compare against the cell top" systematically selects a warm
opponent.** That is the structural reason the artefact cannot cancel on a
standings row, and it will not cancel on any future one either.

---

## 3. Corrected margins, per affected `RESULTS.md` row

Two corrections are available and they answer different questions. Both are
stated, because quoting only one would repeat the campaign's habit of picking a
reading and calling it settled.

**(a) `ctx_pp` vs `ctx_pp` — the honest column.** Phase 1 is the uncached context
load for *every* entry, warm or cold: its numerator is `depth`, which is what was
actually prefilled. This comparison needs no correction at all and is valid
against the entire field. Cross-check that Phase 1 is genuinely cold board-wide:
all 113–118 vLLM `ctx_pp` figures per depth sit in a physical 0.6k–22k tok/s
band. A Phase 1 that was itself cache-warmed would read in the hundreds of
thousands, as the Atlas rows do for a different reason (section 4).

**(b) `pp2048` vs `pp2048` — needs our warm-equivalent.** A warm entry's `pp2048`
is the *marginal* rate for 2048 tokens appended to a resident `depth`-token
prefix. Our comparable is `2048 / (T2 − T1)` from our archives, which is the
incremental cost of extending a cold prefill by 2048 tokens at the same depth —
the same attention work against the same number of keys:

| Depth | our T1 (ms) | our T2 (ms) | ΔT (ms) | **our warm-equivalent** | our `ctx_pp` (avg cold rate) |
|---|---:|---:|---:|---:|---:|
| d8192 | 1332.7 | 1724.6 | 391.9 | **5225.8** | 6148.56 |
| d16384 | 2797.7 | 3257.7 | 460.0 | **4452.2** | 5856.93 |
| d32768 | 6442.5 | 6925.7 | 483.2 | **4238.4** | 5086.51 |
| d65536 | 16328.8 | 17132.5 | 803.7 | **2548.2** | 4013.59 |

⚠ **Caveat that must travel with (b).** `T1` and `T2` are medians of two separate
distributions, so `T2 − T1` is a difference of medians, not the median of a
paired per-run difference. At d8192 the difference is 29% of `T1` and robust; at
d65536 it is 4.9% of `T1`, comparable to the campaign's own ±7% position-bias
floor, so the d65536 warm-equivalent (2548) is an estimate with roughly ±100%
uncertainty and should not be quoted as a measurement. Closing that properly
needs the per-run `est_ppt` arrays paired by run index from
`experiments/*/consolidated.json` — which are on disk and cost zero box time, but
were not re-derived here because no scored row depends on the d65536 `pp2048`
number (that cell is empty on the board).

Note also that our warm-equivalent is **higher** than `RESULTS.md`'s implied
rescaling. `ANALYSIS-r23` proposed 5027.06 at d32768 (= `2048/T2 × 17`, i.e. the
average rate over the whole cold pass). The marginal rate 4238.4 is the more
conservative and more nearly like-for-like figure, and it is the one used below.

### Row-by-row

| `RESULTS.md` row | As recorded | Opponent's status | **Corrected** |
|---|---|---|---|
| `pp2048 @ d8192 c1` — ours 1187.51 vs 215894.21 (Atlas) | **0.006x — LOST** | Atlas top is non-physical (§4); best real vLLM top 32034.06 (LFM2.5-350M, WARM); like-for-like Laguna 6944.70 (WARM); same-model best 2668.71 (WARM) | **NOT SCORED as recorded.** Against Laguna **0.752x — LOST**; against the best same-model vLLM NVFP4 entry **1.958x — WON**. On the honest `ctx_pp` column: 6148.56 vs same-model 7288.95 = **0.844x**, vs best vLLM NVFP4 (Nemotron-3-Nano) 10708.31 = **0.574x** |
| `pp2048 @ d16384 c1` — ours 628.66 vs 99229.33 (Atlas) | **0.006x — LOST** | Atlas non-physical; best real vLLM 17162.78 (gemma-3-1b-it, WARM); Laguna 5878.08 (WARM); same-model best 2662.97 (WARM) | **NOT SCORED as recorded.** vs Laguna **0.757x — LOST**; vs same-model **1.672x — WON**. `ctx_pp`: 5856.93 vs same-model 6929.26 = **0.845x**, vs best vLLM NVFP4 10631.13 = **0.551x** |
| `pp2048 @ d32768 c1` — ours 295.71 vs 63079.61 (Atlas), like-for-like 4644.54 | **0.005x / 0.064x — LOST** | Atlas non-physical; **Laguna-XS-2.1-NVFP4 is WARM (`T2/T1` = 0.108)**; same-model best 2099.16 (WARM) | **The headline change. NOT SCORED as recorded.** vs Laguna **0.913x — still LOST, by 8.7%, not by 15.6x**; vs same-model **2.019x — WON**. `ctx_pp`: 5086.51 vs same-model 5939.56 = **0.856x**, vs best vLLM NVFP4 9475.96 = **0.537x**. ⚠ `ANALYSIS-r23`'s projected "1.082x — a WIN" does **not** survive the marginal-rate correction; the honest answer is a narrow loss |
| `ctx_pp @ d8192 c1` — ours 6148.56 vs 775122.96 | **LOST by ~126x** | Atlas holder, `ttfr` 12.66 ms vs `e2eTtft` 2753.04 ms | **Restate.** Real like-for-like exists and was missed by the 2026-08-21 scrape: **0.844x** vs same-model vLLM NVFP4, **0.574x** vs best vLLM NVFP4. Rank 32 of 116 vLLM entries. Not 126x |
| `ctx_pp @ d16384 c1` — ours 5856.93 vs 884764.53 | **LOST by ~151x** | Atlas, `ttfr` 20.38 vs `e2eTtft` 10635.57 | **Restate: 0.845x / 0.551x.** Rank 35 of 118 |
| `ctx_pp @ d32768 c1` — ours 5086.51 vs 945271.31 | **LOST by ~186x** | Atlas, `ttfr` 37.27 vs `e2eTtft` 24064.87 | **Restate: 0.856x / 0.537x.** Rank 40 of 113 |
| `ctx_pp @ d65536 c1` — ours 4013.59 vs 1393.35 | **WON 2.88x** | DeepSeek-V4-Flash-0731-REAP, vLLM FP8, `ttfr == e2eTtft == 42155.78 ms` — **honest**, and not a "slow outlier": it is a much larger model | **UNCHANGED — the win stands, and it is the only prefill row in the file that needed no correction.** `ANALYSIS-r23` was right to promote it |
| `pp2048 @ d65536 c1` — NOT SCORED | empty cell | confirmed: 0 entries in the live snapshot | **UNCHANGED** |

**Net effect on the standings.** Six recorded losses of 15x–186x are not losses
of that size. Three of them (`ctx_pp` d8192–d32768) become ordinary 0.54x–0.86x
losses to entries that were never in the scrape. Three (`pp2048` d8192–d32768)
split by which opponent is chosen: losses of 0.75x–0.91x against the best vLLM
NVFP4 entry in the cell, wins of 1.67x–2.02x against the best entry of our own
model. No prefill row is a 100x-class loss and none is a clean win except
`ctx_pp @ d65536`.

**Recommended scoring rule going forward: score prefill on `ctx_pp` only.** It is
the one prefill column whose numerator matches what the engine did, for every
entry on the board, warm or cold, and it needs no correction, no opponent
classification, and no marginal-rate reconstruction. `pp2048` is uninterpretable
without knowing the opponent's cache state, and now that we know the board is
84% warm at d32768, our own `pp2048` figures should simply not be published as
comparisons at all until prefix caching works here.

**The `RESULTS.md` note this replaces.** Lines 96–101 should be rewritten from
"the artefact cancels" to: *the artefact cancels only against a cold opponent;
84% of the d32768 field and 82% of the d16384 field is warm, and the
compare-against-the-top rule selects a warm opponent by construction, so the
artefact never cancels on a scored row.*

---

## 4. The Atlas `ttfr` claim — settled, twice over

`ANALYSIS-r23` §2.6 argued from FLOPs that every Atlas prefill top exceeds the
GB10's FP4 peak by >5x and must be an artefact of `ttfr` firing on the first
content-free `choices` chunk (`client.py:351-353`).

**The arithmetic holds.** `ctx_pp @ d32768 c1 = 945271.31` implies
`est_ppt = 32768/945271.31 = 34.66 ms` (the board's own published `estPpt` for
that entry is 35.96 ms — agreement to 3.6%, so the reconstruction was right).
Prefill of 32768 tokens on a ~3B-active model is `2 × 3e9 × 32768 = 1.97e14`
FLOPs before attention, so 34.66 ms implies **5.67 PFLOPS**. NVIDIA's published
GB10 figure is **1 PFLOP FP4 (sparse)**, i.e. ~0.5 PFLOPS dense. That is
**5.7x the sparse peak and ~11.3x the dense rate**, on a workload with no
sparsity to exploit. Not a measurement. The claim stands as written.

**And the per-entry data proves it directly, which is better than an inequality.**
The board publishes both `ttfr` and `e2eTtft` per entry:

| Depth | Atlas entry | published `ctx_pp` | `ttfr` (ms) | `e2eTtft` (ms) | true rate from `e2eTtft` | inflation |
|---|---|---:|---:|---:|---:|---:|
| d8192 | Qwen3.6-35B-A3B-NVFP4 | 775122.96 | 12.66 | 2753.04 | 2975.6 | **260x** |
| d8192 | Qwen3.6-35B-A3B-FP8 | 765488.95 | 12.42 | 5150.72 | 1590.5 | **481x** |
| d16384 | Qwen3.6-35B-A3B-FP8 | 884764.53 | 20.38 | 10635.57 | 1540.5 | **574x** |
| d16384 | Qwen3.6-35B-A3B-NVFP4 | 770513.14 | 24.50 | 6155.21 | 2661.8 | **289x** |
| d32768 | Qwen3.6-35B-A3B-FP8 | 945271.31 | 37.27 | 24064.87 | 1361.7 | **694x** |
| d32768 | Qwen3.6-35B-A3B-NVFP4 | 771423.29 | 46.70 | 14549.78 | 2252.1 | **343x** |

And the artefact is **runtime-specific, not universal**:

| Depth | max abs(`ttfr` − `e2eTtft`), vLLM entries | max abs(`ttfr` − `e2eTtft`), Atlas entries |
|---|---:|---:|
| d8192 | 382.80 ms (n=116) | 5138.30 ms (n=4) |
| d16384 | 388.91 ms (n=118) | 10615.19 ms (n=4) |
| d32768 | 402.82 ms (n=113) | 24027.60 ms (n=3) |

Our own runs read `ttfr == e2e_ttft` to the last decimal at every depth
(`bench_25a0e7f36ab0`: 1344.13/1344.13, 2789.31/2789.31, 6441.66/6441.66), so we
are not affected and neither is any vLLM entry to more than ~0.4 s.

**Verdict: the claim holds, and it is now measured rather than bounded.** Atlas
streams a content-free `choices` chunk within ~12–47 ms of the request and only
emits the first real token 2.7–24.1 s later; `est_ppt = ttfr − latency`
(`results.py:306`) collapses onto the empty chunk, inflating published prefill
by 260x–694x. Atlas's *true* prefill rate is 1362–2976 tok/s, i.e. **below ours**
(4014–6149) at every depth. The one thing to correct in `ANALYSIS-r23` §2.6: it
also read the rising `ctx_pp`-with-depth shape (775k → 885k → 945k) as
upload-time-dominated. The `e2eTtft` column shows the true rate falls
monotonically with depth (2976 → 2662 → 2252 tok/s) exactly as attention cost
requires; the *rise* in the published figure is `ttfr` drifting up sub-linearly
while the depth numerator doubles, which is the same explanation but should be
stated about `ttfr`, not about the physical prefill.

Consequence for the record: every prefill "board top" in `RESULTS.md` is an
Atlas artefact, so the six rows scored against those tops were scored against
numbers that measure nothing. This is independent of, and additional to, the
warm/cold finding in section 2 — either one alone invalidates those six margins.

---

## 5. What this does and does not settle

**Settled.**

- The board carries both populations, and the split is measurable per entry.
- Every opponent on every scored prefill row is WARM. The artefact does not cancel.
- The corrected prefill margins are 0.54x–0.91x, not 0.005x/186x.
- `ctx_pp @ d65536 c1` (2.88x) stands unchanged and is the only prefill row that
  ever needed no correction.
- The Atlas `ttfr` artefact is real, is 260x–694x, and is Atlas-specific.
- Prefix caching works for ~84% of the d32768 field on this hardware. It is not
  an architectural impossibility for hybrid-mamba models on GB10 — it is a
  property of *our* configuration. That materially raises the prior on
  `ANALYSIS-r23`'s experiment **A**, which is now the only open item.

**Not settled, and what would settle it.**

- *Which flag breaks our cache.* The board does not publish server flags, only
  `recipeType` and `recipeCopyCount`. The three cold Qwen3.6-35B-A3B entries at
  d32768 (`T2/T1` = 1.086) are the natural comparison set, but their recipes are
  under `/benchmarks` and `/submissions`, both of which return
  `Permission denied`. **Only experiment A settles this** — 13 minutes of box
  time for a binary hit-rate readout.
- *The exact size of our warm-equivalent `pp2048`.* Needs per-run paired
  `est_ppt` deltas from `experiments/*/consolidated.json` rather than a
  difference of medians. Zero box time; not done here because no scored row
  turns on it. It would firm up the d32768 `0.913x` and is the only way to quote
  the d65536 figure at all.
- *Whether a warm entry's Phase 1 is truly cold.* Argued here from the physical
  banding of all vLLM `ctx_pp` figures, not proven. It would be proven by a
  single entry publishing per-run `ctx_pp` values (run 1 vs runs 2+); the board
  publishes only the median. If Phase 1 *were* warm for warm entries, the
  section-3(a) `ctx_pp` comparisons would flatter them and our 0.54x–0.86x
  losses would be smaller still — so this uncertainty runs in our favour, and
  the corrected margins above are the conservative end.
- *Anything about the decode rows.* Not examined. The same per-entry endpoint
  would support the identical treatment of the `tg` and `ctx_tg` cells for zero
  box time, and given that `ANALYSIS-r23` §2.7 attributes our c2/c5 deficit to
  the same cache failure, checking whether the entries beating us at c2/c5 are
  the warm ones is the obvious free follow-up.
