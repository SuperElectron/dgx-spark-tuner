# Results — qwen36-35b-nvfp4-cells

**This file is the standings and nothing else: one row per measured cell, with
the configuration it was measured under, the board incumbent, our margin and the
verdict.** Model fixed: `nvidia/Qwen3.6-35B-A3B-NVFP4` (de-rayed recipe). Nothing
was ever submitted to the arena — there is no login — so these rows are the
standings. Board incumbents come from the 2026-08-21 scrape in
`docs/arena-recipe.md`; **every prefill row was re-scored on 2026-08-22 from the
per-entry re-scrape in `ANALYSIS-board-rescrape.md`**, which is authoritative for
those rows. Raw runs, σ and ttfr for every row live in
`experiments/<benchId>/consolidated.json`.

**Every figure is a MEDIAN of the runs**, never a mean (MTP acceptance is
bimodal). `SE` where quoted is the median standard error, `1.253 σ/√n`.

**Reading the columns that are easy to get wrong:**

- **benchId / date.** The archive under `experiments/` that produced the row, and
  the date of the run. A pooled row lists **every** contributing benchId and the
  date of the **latest** one. `r13b-perreq-probe` is a directory name, not a
  sparkrun benchId — that round has none. A blank cell means the row has no single
  archive behind it (see the row's own text); it never means the archive is unknown.
- **Configuration.** `recipe.yaml` changed once, at R11 on 2026-08-22, which
  folded `max_num_batched_tokens: 65536` (it was 8192). **`mnbt 8192 — pre-fold
  recipe` rows are no longer reproducible from `recipe.yaml`** and need an
  explicit `-o max_num_batched_tokens=8192`. `MUTATION` names `-o` overrides on
  top of the pre-fold recipe. What the recipe ships today is `mns 4 + mnbt
  65536`, measured at **c1 and (since R23) at c4** — the two
  `mnbt 65536 + mns 4 — folded recipe as shipped` rows at `d16384 c4` are the
  only rows in this file that state what `recipe.yaml` produces at `c>1`.
- **Phase.** A `ctx_` row is llama-benchy **Phase 1, the context load** — the
  *uncached* pass, charged `depth` prompt tokens. A row without `ctx_` is
  **Phase 2**, charged 2048 while processing `depth + 2048`. The campaign had
  these backwards for thirteen rounds. **Board margins DO move** — see the
  prefill caution under LOST. Never compare a `ctx_pp` figure to a `pp` figure;
  the ratio is `(depth+2048)/2048`.

**Standings: 8 board cells WON, 12 LOST**, plus a tail the board publishes no
figure for. **The 2026-08-22 prefill re-scoring changed six margins and moved no
cell from lost to won or won to lost, so the counts are unchanged.**

**For the narrative — every round's hypothesis and outcome, the campaign
synthesis, the `ctx_` phase-label correction, R5c's metric closure, the
three-run audit, R22's position-bias finding and R23's refutation of it — read
the `CAMPAIGN SYNTHESIS` section of `journal.md` together with the `Round 23
outcome` block. It is the one authoritative handoff.**

---

## WON — 8 cells, 21 rows

The two `c4` cells each carry a pre-fold figure, five token-budget points from
R13c's curve and (since R23) the shipped-recipe figure, and `tg32 @ d32768 c1`
carries both budgets.

| benchId | date | Cell | Configuration | Ours | Runs | Board top | Margin | Note |
|---|---|---|---|---:|---:|---:|---:|---|
| bench_dd3afc9e1c94 | 2026-08-22 | tg32 @ d16384 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 116.43 | 7 | 28.11 | **4.14x** | R6. Worst of 7 (108.96) still 3.88x |
| bench_25a0e7f36ab0, bench_2b0f7bc8fb7b-mnbt8192, bench_8707c27ce1a4-r22-armG | 2026-08-22 | tg32 @ d32768 c1 | mnbt 8192 — pre-fold recipe, mns 4 | **115.85** | 24 pooled (R1 3 + R8c E 7 + R22 G 14) | 23.31 | **4.97x** | The campaign's largest sample at any cell. σ/med 13.51%, SE 3.46%. Worst of 24 (93.54) still 4.01x |
| bench_964a188f3d16-mnbt65536, bench_bb4b8ef8a193-r22-armH | 2026-08-22 | tg32 @ d32768 c1 | **mnbt 65536 — folded recipe**, mns 4 | **110.16** | 21 pooled (R8c F 7 + R22 H 14) | 23.31 | **4.72x** | The current-epoch row for this cell — the only one quotable as what `recipe.yaml` produces here. Budget is inert at c1 (position-controlled, R22) |
| bench_6921c874daee-r21-armB | 2026-08-22 | tg32 @ d8192 c1 | mnbt 8192 — pre-fold recipe, mns 4 | **123.81** | 7 | sole entry, no number published | uncontested | R21. σ/med 13.18%. No margin moves either way |
| bench_f58c56da6658, bench_f58c56da6658-verify | 2026-08-21 | tg128 @ d16384 c4 | mnbt 8192 — pre-fold recipe, mns 4 | 52.85 | 6 pooled (R2 + verify) | 46.68 | **1.13x** | The only contested cell we hold (8 entries). Worst of 6 (51.25) still +9.8% |
| bench_860b43edd154 | 2026-08-22 | tg128 @ d16384 c4 | **MUTATION mnbt 32768 + mns 16** | **147.25** | 7 | 46.68 | **3.15x** | R10 |
| bench_0bd1f20dca74-mnbt65536 | 2026-08-22 | tg128 @ d16384 c4 | **MUTATION mnbt 65536 + mns 5** | **173.34** | 7 | 46.68 | **3.71x** | R13c — **the knee of the budget curve**. `mns 5` is NOT in the recipe; the shipped-recipe row is directly below |
| bench_b56686c32206-r23-arm5-c4-mns4 | 2026-08-22 | tg128 @ d16384 c4 | **mnbt 65536 + mns 4 — folded recipe as shipped** | **179.34** | 7 | 46.68 | **3.84x** | R23. **The only row in this file that states what `recipe.yaml` produces at `c>1`.** `peak_throughput` 317.0, `tg_req` 67.17, σ/med 5.63%, worst of 7 (154.92) still 3.32x. ⚠ +3.46% on the `mns 5` row above is a cross-session delta inside the ±5% arm-to-arm spread R23 measured on identical configs — the two are indistinguishable; do NOT read it as `mns 4` beating `mns 5` |
| bench_433eeaf9827e, bench_d6cec044441c-mnbt98304 | 2026-08-22 | tg128 @ d16384 c4 | **MUTATION mnbt 98304 + mns 5** | 171.31 | 14 pooled (R13 + R13c) | 46.68 | **3.67x** | Two engine starts, 174.68 and 169.69 |
| bench_0509b2a740f6-mnbt131072, bench_0509b2a740f6-r13d | 2026-08-22 | tg128 @ d16384 c4 | **MUTATION mnbt 131072 + mns 5** | 170.84 | 14 pooled (R13c + R13d) | 46.68 | **3.66x** | Above the knee — buys nothing over 65536 |
| bench_fa5630a4ac79-mnbt16384 | 2026-08-22 | tg128 @ d16384 c4 | **MUTATION mnbt 16384 + mns 5** | 85.90 | 7 | 46.68 | **1.84x** | R13c — below the knee, partial occupancy |
| bench_f58c56da6658, bench_f58c56da6658-verify | 2026-08-21 | ctx_tg @ d16384 c4 | mnbt 8192 — pre-fold recipe, mns 4 | 56.36 | 6 pooled (R2 + verify) | 27.68 | **2.04x** | |
| bench_860b43edd154 | 2026-08-22 | ctx_tg @ d16384 c4 | **MUTATION mnbt 32768 + mns 16** | 126.35 | 7 | 27.68 | **4.56x** | R10 |
| bench_0bd1f20dca74-mnbt65536 | 2026-08-22 | ctx_tg @ d16384 c4 | **MUTATION mnbt 65536 + mns 5** | 164.95 | 7 | 27.68 | **5.96x** | R13c — the knee. Same `mns 5` caveat as the Phase-2 row |
| bench_b56686c32206-r23-arm5-c4-mns4 | 2026-08-22 | ctx_tg @ d16384 c4 | **mnbt 65536 + mns 4 — folded recipe as shipped** | **169.45** | 7 | 27.68 | **6.12x** | R23. The Phase-1 partner of the shipped-recipe row. `peak_throughput` 305.0, `tg_req` 61.80, σ/med 2.45%, worst of 7 (162.81) still 5.88x |
| bench_433eeaf9827e, bench_d6cec044441c-mnbt98304 | 2026-08-22 | ctx_tg @ d16384 c4 | **MUTATION mnbt 98304 + mns 5** | 170.36 | 14 pooled (R13 + R13c) | 27.68 | **6.15x** | |
| bench_0509b2a740f6-mnbt131072, bench_0509b2a740f6-r13d | 2026-08-22 | ctx_tg @ d16384 c4 | **MUTATION mnbt 131072 + mns 5** | **171.77** | 14 pooled (R13c + R13d) | 27.68 | **6.21x** | **The campaign's widest margin.** Took the title from the 98304 row by 0.83% — a bookkeeping change, not a discovery |
| bench_fa5630a4ac79-mnbt16384 | 2026-08-22 | ctx_tg @ d16384 c4 | **MUTATION mnbt 16384 + mns 5** | 68.79 | 7 | 27.68 | **2.49x** | R13c — below the knee |
| bench_3d8149654d1b | 2026-08-22 | tg128 @ d65536 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 94.10 | 7 | 16.48 | **5.71x** | **The widest campaign-config win.** Worst of 7 (81.79) still 4.96x |
| bench_3d8149654d1b | 2026-08-22 | ctx_tg @ d65536 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 92.98 | 7 | 20.70 | **4.49x** | Worst of 7 (77.33) still 3.74x |
| bench_3d8149654d1b | 2026-08-22 | ctx_pp @ d65536 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 4013.59 | 7 | 1393.35 | **2.88x** | Sole-entry cell (1 board entry). **The only prefill row that needed no correction**: the incumbent (DeepSeek-V4-Flash-0731-REAP, vLLM FP8) is honest — `ttfr == e2eTtft == 42155.78 ms` — and is not a slow outlier but a much larger model |

## LOST — 12 cells, 16 rows

`Like-for-like` is the best board entry at the same model/runtime/quant where
the scrape carries one; the verdict is scored against `Board top` — **except on
the six prefill rows, where the board top is an Atlas `ttfr` artefact and the
verdict is scored against `Like-for-like` instead** (see the caution below).

| benchId | date | Cell | Configuration | Ours | Runs | Board top | Like-for-like | Verdict |
|---|---|---|---|---:|---:|---:|---:|---|
| bench_076db52d341c, bench_deb3090b9a29-r21-armA | 2026-08-22 | tg128 @ d131072 c1 | mnbt 8192 — pre-fold recipe, mns 4 | **81.22** | 10 pooled (R5 3 + R21 7) | 81.60 (Nemotron Lightning NVFP4) | — | **0.995x — LOST by 0.47%**, which is **0.11 SE** at σ/med 10.56%. A dead heat we are on the wrong side of; **not claimed**. ⚠ Do not re-run — unresolvable at any affordable budget, and this is the campaign's most expensive depth |
| bench_0ef7af8997ce | 2026-08-22 | tg128 @ d16384 c2 | mnbt 8192 — pre-fold recipe, mns 4 | 84.00 | ⚠ **3 — PROVISIONAL** | 325.44 (LFM2.5-350M BF16) | 163.27 (Qwen3.6-35B-A3B-NVFP4, vLLM) | **0.51x — LOST.** ⚠ Three runs, deliberately not re-measured (R21): the gap is >2x and no observed sampling error closes it. Kept as the pre-fold baseline for the row below; **not to be quoted as a measurement** |
| bench_ac37f5b64487 | 2026-08-22 | tg128 @ d16384 c2 | **MUTATION mnbt 32768 + mns 5** | 140.77 | 7 | 325.44 | 163.27 | **0.86x — still LOST** |
| bench_858173ba5753-mns5 | 2026-08-22 | tg128 @ d16384 c5 | mnbt 8192 — pre-fold recipe + **MUTATION mns 5** | 48.12 | ⚠ **3 — PROVISIONAL** | 428.95 (LFM2.5-350M BF16) | 225.46 (Qwen3.6-35B-A3B-NVFP4-Fast, vLLM) | **0.21x — LOST.** ⚠ Same status as the c2 row above |
| bench_ac37f5b64487 | 2026-08-22 | tg128 @ d16384 c5 | **MUTATION mnbt 32768 + mns 5** | 128.93 | 7 | 428.95 | 225.46 | **0.57x — still LOST** |
| bench_433eeaf9827e | 2026-08-22 | tg128 @ d16384 c5 | **MUTATION mnbt 98304 + mns 5** | 164.27 | 7 | 428.95 | 225.46 | **0.73x — still LOST.** R13 aimed at this cell and did not take it; **0.38x against the cell top**. The only loss that ever had a live route to a win |
| bench_25a0e7f36ab0, bench_6921c874daee-r21-armB | 2026-08-22 | ctx_tg @ d8192 c1 | mnbt 8192 — pre-fold recipe, mns 4 (tg32 arm) | **127.64** | 10 pooled (R1 3 + R21 7) | 207.60 (LFM2.5-350M BF16) | 118.07 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | **0.615x — LOST** to the top; **1.08x over best vLLM+NVFP4**, the campaign's thinnest surviving claim, protected by R21 |
| bench_dd3afc9e1c94 | 2026-08-22 | ctx_tg @ d16384 c1 | mnbt 8192 — pre-fold recipe, mns 4 (tg32 arm) | 122.97 | 7 | 193.09 (LFM2.5-350M BF16) | 153.86 (our own model on **Atlas**) | **0.64x — LOST**; best vLLM+NVFP4 not in the scrape |
| bench_25a0e7f36ab0, bench_2b0f7bc8fb7b-mnbt8192, bench_8707c27ce1a4-r22-armG | 2026-08-22 | ctx_tg @ d32768 c1 | mnbt 8192 — pre-fold recipe, mns 4 (tg32 arm) | **115.86** | 24 pooled (R1 3 + R8c E 7 + R22 G 14) | 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**) | 116.65 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | **0.987x — LOST** by **0.34 SE**. ⚠ The R8c→R22 change of +11.02% **failed the ±10% protection band by 1.0 point**; the sets were pooled rather than replaced because the failing arm ran second and matches R22's position bias in sign and size. Recorded as a departure from procedure, not buried. ⚠ Do not go back |
| bench_964a188f3d16-mnbt65536, bench_bb4b8ef8a193-r22-armH | 2026-08-22 | ctx_tg @ d32768 c1 | **mnbt 65536 — folded recipe**, mns 4 | **113.37** | 21 pooled (R8c F 7 + R22 H 14) | 117.37 (Atlas) | 116.65 | **0.966x — LOST.** R22's pre-declared claim rule (pooled must clear 120.53) missed by 6.1%. One 14-run arm read 122.80 = 1.046x and was **not promoted** |
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d8192 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 1187.51 (warm-equivalent **5225.8**) | 3 | 215894.21 (Atlas — ⚠ `ttfr` artefact, not a prefill rate) | 6944.70 (Laguna-XS-2.1-NVFP4, vLLM NVFP4, WARM) | **0.752x — LOST.** ⚠ Not scored: prefill is scored on `ctx_pp` only |
| bench_3d8149654d1b | 2026-08-22 | pp2048 @ d16384 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 628.66 (warm-equivalent **4452.2**) | 7 (R1's 3-run figure was 637.09) | 99229.33 (Atlas — ⚠ artefact) | 5878.08 (Laguna, WARM) | **0.757x — LOST.** ⚠ Not scored, same reason |
| bench_25a0e7f36ab0 | 2026-08-21 | pp2048 @ d32768 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 295.71 (warm-equivalent **4238.4**) | 3 | 63079.61 (Atlas — ⚠ artefact) | 4644.54 (Laguna, WARM) | **0.913x — LOST by 8.7%**, not by 15.6x. ⚠ Not scored, same reason. The warm-equivalent is the MARGINAL `2048/(T2−T1)`, a difference of medians. ⚠ `ANALYSIS-prefill-metric.md`'s projected 5027 = "1.082x WIN" never held — do not quote it |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp @ d8192 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 6148.56 | 3 | 775122.96 (Atlas — ⚠ artefact; true rate from its own `e2eTtft` is 2975.6) | 7288.95 same-model / 10708.31 best vLLM NVFP4 (Nemotron-3-Nano) | **0.844x / 0.574x — LOST.** Rank 32 of 116 vLLM entries |
| bench_3d8149654d1b | 2026-08-22 | ctx_pp @ d16384 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 5856.93 | 7 (R1's 3-run figure was 5910.22) | 884764.53 (Atlas — ⚠ artefact; true rate 1540.5) | 6929.26 same-model / 10631.13 best vLLM NVFP4 | **0.845x / 0.551x — LOST.** Rank 35 of 118 |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_pp @ d32768 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 5086.51 | 3 | 945271.31 (Atlas — ⚠ artefact; true rate 1361.7) | 5939.56 same-model / 9475.96 best vLLM NVFP4 | **0.856x / 0.537x — LOST.** Rank 40 of 113 |

⚠ **The artefact does NOT cancel, and prefill is scored on `ctx_pp` ONLY.**
llama-benchy passes 2048 as the `pp_throughput` numerator (`runner.py:225`) while
the engine prefills `depth + 2048`, so a **cold** entry's `pp2048` understates by
`(depth+2048)/2048`; a **warm** entry really did prefill 2048 and its figure is
correct. The 2026-08-22 per-entry re-scrape classified the board by
`estPpt(pp2048)/estPpt(ctx_pp)`: it is mostly warm (106 of 125 at d32768, 107 of
131 at d16384), we are cold at every depth (0.0% prefix-cache hits in 220+ engine
samples — ⚠ **R24 found the cause: MTP speculative decoding. Removing it restores
the cache, but `ctx_pp` is Phase 1, the pass that POPULATES the cache, so it moves
+4.8% and NOT ONE OF THESE SIX ROWS CHANGES**), and ranking by cell top selects a
warm opponent by construction — so
the artefact never cancels on a scored row. **`ctx_pp`'s numerator is what the
engine actually did for every entry, warm or cold**, so the `ctx_pp` rows carry
the verdicts and the `pp2048` rows are kept as recorded losses on our marginal
warm-equivalent, not quotable as board comparisons. Every prefill `Board top`
except `ctx_pp @ d65536` is an Atlas `ttfr` artefact (fires on a content-free
`choices` chunk, 260x–694x early; Atlas's true prefill is 1362–2976 tok/s,
**below ours**) and is shown only to honor the column contract.

## NOT SCORED — no board figure, or never a campaign target

| benchId | date | Cell | Configuration | Ours | Runs | Why it is not scored |
|---|---|---|---|---:|---:|---|
| bench_dd3afc9e1c94, bench_3d8149654d1b, bench_b20062a3c5c5-r23-arm1-A8192, bench_b20062a3c5c5-r23-arm4-A8192 | 2026-08-22 | tg128 @ d16384 c1 | mnbt 8192 — pre-fold recipe, mns 4 | **110.60** | 28 pooled (R6 7 + R8 7 + R23 arm1 7 + R23 arm4 7) | The crowded cell (188.47 top, 116.03 best vLLM NVFP4 → **0.953x**), **never a campaign target**. Listed for the reproduction gap, now −4.7%. σ/med 7.84%. R23's two `mnbt 8192` arms read 103.72 pooled, −7.90% on the prior 112.62 — inside the file's ±10% convention, so pooled rather than retired. ⚠ R23 did not pre-declare this as a protection reading |
| bench_c9518e3e96a3-r11, bench_c9518e3e96a3-r23-arm2-B65536, bench_c9518e3e96a3-r23-arm3-B65536 | 2026-08-22 | tg128 @ d16384 c1 | **mnbt 65536 — folded recipe**, mns 4 | **103.97** | 21 pooled (R11 7 + R23 arm2 7 + R23 arm3 7) | R11's fold anchor, re-measured by R23. NOT pooled with the row above — different configuration. ⚠ **The licensed budget comparison is R23's drift-free A-B-B-A contrast, −1.76%** (14 runs at each budget in one session), NOT the ratio of these two pooled cross-session rows. R11's single-arm +0.27% is superseded by it and agrees in verdict: **inert at c1** |
| bench_dd3afc9e1c94, bench_3d8149654d1b, bench_b20062a3c5c5-r23-arm1-A8192, bench_b20062a3c5c5-r23-arm4-A8192 / bench_c9518e3e96a3-r11, bench_c9518e3e96a3-r23-arm2-B65536, bench_c9518e3e96a3-r23-arm3-B65536 | 2026-08-22 | ctx_tg @ d16384 c1 | mnbt 8192 pre-fold / mnbt 65536 folded | **102.60** pooled / **101.87** pooled | 28 / 21 | Never scraped. R23's drift-free Phase-1 budget contrast is **+4.91%**, inside R11's ±5% band by 0.09 points and ~0.9 SE — inert, and reported at the band edge rather than rounded |
| bench_076db52d341c, bench_deb3090b9a29-r21-armA | 2026-08-22 | ctx_tg @ d131072 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 77.52 | 10 pooled (R5 3 + R21 7) | Never scraped, so held rather than claimed |
| bench_3d8149654d1b | 2026-08-22 | pp2048 @ d65536 c1 | mnbt 8192 — pre-fold recipe, mns 4 | 119.54 | 7 | The board has **zero entries** at that depth — an empty cell, not a won one, and nothing can be posted to it |
| bench_0954971b5dfa | 2026-08-22 | tg128 @ d16384 c8 | **MUTATION mns 8**, mnbt 8192 | 43.51 | 3 | The scrape covers c1, c2, c4 and c5 only |
| bench_a769c1142e15 | 2026-08-22 | tg128 @ d16384 c16 | **MUTATION mns 16**, mnbt 8192 | 40.47 | 3 | Same |
| bench_860b43edd154 | 2026-08-22 | tg128 @ d16384 c16 | **MUTATION mnbt 32768 + mns 16** | 53.45 | 7 | Same. `peak_throughput` **515**, the campaign's largest sustained aggregate |
| bench_0ef7af8997ce / bench_ac37f5b64487 | 2026-08-22 | ctx_tg @ d16384 c2 | pre-fold / **MUTATION mnbt 32768 + mns 5** | 79.44 / 127.09 | 3 / 7 | The board publishes `ctx_` cells at c1 only |
| bench_858173ba5753-mns5 / bench_ac37f5b64487 / bench_433eeaf9827e | 2026-08-22 | ctx_tg @ d16384 c5 | pre-fold + mns 5 / mnbt 32768 + mns 5 / mnbt 98304 + mns 5 | 51.25 / 104.75 / 160.67 | 3 / 7 / 7 | Same |
| bench_0954971b5dfa / bench_a769c1142e15 / bench_860b43edd154 | 2026-08-22 | ctx_tg @ d16384 c8, c16 | **MUTATION mns 8 / mns 16** at mnbt 8192; c16 also at mnbt 32768 | 47.75 / 45.61 / 54.54 | 3 / 3 / 7 | Same |
| | | every `pp2048` / `ctx_pp` cell at `c>1` | various | see archives | — | The board's prefill and context cells are c1 only |
| bench_9379c15468ec-a-chunk, bench_10496035f7fd-b-nochunk (R9b); bench_30d6586cc70a-p-pc-on, bench_76bccce3d8b3-g-block32768, bench_76bccce3d8b3-g-block32768-repeat, bench_107f95223a60-n-pc-off (R9c) | 2026-08-22 | every R9b and R9c row | prefix caching OFF, `--block-size 32768`, chunked prefill OFF, all at `mnbt 32768` | see archives | 3 / 7 | Deliberately diagnostic: they mutate a flag the recipe ships and sit at a budget it does not. **No standings row was ever measured with prefix caching off** |
| bench_647b25c13d9f-r24-arm1-control, bench_064550e26525-r24-arm2-kvauto, bench_064fc6128314-r24-arm3-specoff, bench_f6e4a4c51f71-r24-arm4-spec1 | 2026-08-22 | every R24 row, `tg128` and `ctx_tg @ d16384 c4` | shipped recipe / `kv-cache-dtype auto` / `--speculative-config` removed / `num_speculative_tokens 1`, all at `mnbt 65536 + mns 4` | 169.89 / 179.15 / 143.24 / 148.12 (Phase 2); 175.59 / 194.14 / 144.62 / 152.81 (`ctx_`) | 3 each | Deliberately diagnostic: three of four mutate a flag the recipe ships, and the round pre-declared it was **not quoting a throughput** — the readout is the engine's `Prefix cache hit rate`, **0.0% / 0.0% / 42.1% / 0.0%**. ⚠ **MTP speculative decoding is what kept the cache at 0.0%**; removing it restores the cache to its 42.14% structural ceiling and costs −15.7% `tg`, −39% `peak_throughput`, buying 4.17x Phase-2 `pp` and 4.19x `ttfr`. The control is **not pooled** into the shipped-recipe win row above (3-run diagnostic; it read −5.27% on R23's 179.34) |
| r13b-perreq-probe | 2026-08-22 | R13b probe rows | `mnbt 98304 + mns 5` + `--per-request-spec-decode-metrics detailed` | 167.14 / 161.68 | 7 batches | Not measured by llama-benchy and there is no benchId; a reproduction check for a mechanism round. The instrument recipe must never be folded |

## RETIRED FIGURES — published here once, do not quote

`Source archive` / `date` are the archive and date the **retired** figure came
from, not the round that retired it — that is the `Retired by` column, and not
the archive the `Replacement` came from either. The column is deliberately NOT
called `benchId`: `memory-backfill.sh` reads a `benchId` header as a standings
schema and would emit each row as an observation asserting the replacement
figure against the retired run's archive. Renaming it makes the backfill skip
this table, which is correct — nothing here is quotable.

| Source archive | date | Figure | Cell | Retired by | Replacement |
|---|---|---|---|---|---|
| bench_25a0e7f36ab0 | 2026-08-21 | 129.32 (4.60x) | tg32 @ d16384 c1 | R6 | 116.43 = 4.14x |
| bench_25a0e7f36ab0, bench_2b0f7bc8fb7b-mnbt8192 | 2026-08-22 | 115.56 (4.96x), then pooled 112.59 (4.83x) | tg32 @ d32768 c1 | R8c, then R22 | 115.85 = 4.97x, pooled 24 |
| bench_25a0e7f36ab0 | 2026-08-21 | 106.24 | tg32 @ d8192 c1 | R21 (band failure, +16.54%) | 123.81 |
| bench_25a0e7f36ab0, bench_2b0f7bc8fb7b-mnbt8192 | 2026-08-22 | 84.03 (0.72x), then 0.92x | ctx_tg @ d32768 c1 | R8c, then R22 | 0.987x / 0.966x |
| bench_964a188f3d16-mnbt65536 | 2026-08-22 | 117.65 = **1.002x dead heat** | ctx_tg @ d32768 c1, mnbt 65536 | R22 (re-measures 109.41, −7.00%) | 113.37 = 0.966x, pooled 21 |
| bench_dab043abba20 | 2026-08-21 | 108.15 (6.56x) | tg128 @ d65536 c1 | R8 | 94.10 = 5.71x |
| bench_dab043abba20 | 2026-08-21 | 89.76 (4.34x) | ctx_tg @ d65536 c1 | R8 | 92.98 = 4.49x |
| bench_076db52d341c | 2026-08-22 | 77.13 (0.95x, "short by 5.5%") | tg128 @ d131072 c1 | R21 | 81.22 = 0.995x, short by 0.47% |
| bench_076db52d341c | 2026-08-22 | 76.66 | ctx_tg @ d131072 c1 | R21 | 77.52, pooled 10 |
| bench_433eeaf9827e | 2026-08-22 | 174.68 (3.74x) | tg128 @ d16384 c4, mnbt 98304 | R13c | 171.31 = 3.67x, pooled 14 |
| bench_433eeaf9827e | 2026-08-22 | 170.59 (6.16x) | ctx_tg @ d16384 c4, mnbt 98304 | R13c | 170.36 = 6.15x, pooled 14 |
| bench_0509b2a740f6-mnbt131072 | 2026-08-22 | 175.40 (**6.34x**, never promoted) | ctx_tg @ d16384 c4, mnbt 131072 | R13d | 171.77 = 6.21x, pooled 14 |
| bench_964a188f3d16-mnbt65536 | 2026-08-22 | σ/med **24.20%**, "the noisiest cell in the campaign" | tg32 @ d32768 c1, mnbt 65536 | R22 (11.39% at the identical config) | none — stop naming σ records from a single arm; σ from 7 runs carries ~±50% of itself |
| bench_2b0f7bc8fb7b-mnbt8192, bench_964a188f3d16-mnbt65536 | 2026-08-22 | "+6.36% from the folded budget on Phase 1" | ctx_tg @ d32768 c1 | R22 | It was **arm position**, not budget. Position-controlled the budget reads −1.08% / +0.86% — inert at c1 on both phases |
| bench_dd3afc9e1c94, bench_3d8149654d1b | 2026-08-22 | 112.62 (0.97x reproduction gap) | tg128 @ d16384 c1, mnbt 8192 | R23 | 110.60 = 0.953x, pooled 28 |
| bench_c9518e3e96a3-r11 | 2026-08-22 | 112.92, and the **+0.27%** single-arm fold anchor | tg128 @ d16384 c1, mnbt 65536 | R23 | 103.97, pooled 21; the fold now rests on R23's drift-free **−1.76%** |
| bench_dd3afc9e1c94, bench_3d8149654d1b / bench_c9518e3e96a3-r11 | 2026-08-22 | 102.99 pooled / 98.72 | ctx_tg @ d16384 c1, both budgets | R23 | 102.60 pooled 28 / 101.87 pooled 21 |
| bench_2b0f7bc8fb7b-mnbt8192, bench_964a188f3d16-mnbt65536, bench_8707c27ce1a4-r22-armG, bench_bb4b8ef8a193-r22-armH | 2026-08-22 | "the arm that runs SECOND reads higher, 4 of 4, mean **+6.5%**" | every arm-to-arm comparison in this file | R23 (A-B-B-A, 4 same-config position contrasts: −4.40, −0.91, +0.71, +2.84%, mean **−0.44%**, p = 1.0) | **REFUTED as a directional effect.** What remains is a **symmetric** arm-to-arm spread of ~±5% on identical configurations, which does not re-sign any past delta |
| bench_dd3afc9e1c94 | 2026-08-22 | R6's "runs=3 is adequate at d16384 — the quiet regime", σ/med 2.6% | tg128 @ d16384 c1 | R23 (seven engine starts now read 2.6 / 5.5 / 8.01 / 8.26 / 10.95 / 12.22 / 10.90%) | none — this cell is not quiet; do not budget runs as if it were |
| | | `tg` aggregate = per-request × c (168.0, 228.0, 647.6, 4.53x at c4) | every `c>1` row | R10 from llama-benchy's source, corroborated by R5c over 34 records | `tg_throughput` is already a batch aggregate; `peak_throughput` is the ceiling it must sit under. Never multiply |
| bench_25a0e7f36ab0 | 2026-08-21 | 0.006x against 215894.21 (Atlas) | pp2048 @ d8192 c1 | `ANALYSIS-board-rescrape.md` (2026-08-22) | 0.752x against Laguna-XS-2.1-NVFP4 6944.70, on warm-equivalent 5225.8 |
| bench_3d8149654d1b | 2026-08-22 | 0.006x against 99229.33 (Atlas) | pp2048 @ d16384 c1 | same | 0.757x against Laguna 5878.08, on warm-equivalent 4452.2 |
| bench_25a0e7f36ab0 | 2026-08-21 | 0.005x of top / 0.064x of best vLLM, "a 15x gap … an open question" | pp2048 @ d32768 c1 | same | 0.913x against Laguna 4644.54, on warm-equivalent 4238.4. ⚠ `ANALYSIS-prefill-metric.md`'s projected 5027 = "1.082x WIN" is retired with it and was never true |
| bench_25a0e7f36ab0 | 2026-08-21 | LOST by ~126x (775122.96, "not in scrape") | ctx_pp @ d8192 c1 | same | 0.844x same-model / 0.574x best vLLM NVFP4 — the like-for-like entries the 2026-08-21 scrape missed |
| bench_3d8149654d1b | 2026-08-22 | LOST by ~151x (884764.53, "not in scrape") | ctx_pp @ d16384 c1 | same | 0.845x / 0.551x |
| bench_25a0e7f36ab0 | 2026-08-21 | LOST by ~186x (945271.31, "not in scrape") | ctx_pp @ d32768 c1 | same | 0.856x / 0.537x |
| | | "the board's prefill figures … carry the identical understatement, so the artefact cancels" | every prefill row | same | **REFUTED per entry.** The board is 82–85% warm at d16384/d32768, we are cold at every depth, and cell-top ranking selects a warm opponent by construction. Prefill is scored on `ctx_pp` only |
| | | every prefill "board top" read as a prefill rate (215894.21, 99229.33, 63079.61, 775122.96, 884764.53, 945271.31) | every prefill row | same | **Atlas `ttfr` artefact, measured not suspected**: `ttfr` fires on a content-free `choices` chunk, inflating by 260x–694x. Atlas's true prefill from its own `e2eTtft` is 1362–2976 tok/s, below ours. Kept in the `Board top` column for the contract only |
| | 2026-08-22 | `ANALYSIS-prefill-metric.md` §2.7's "fix the prefix cache → **+42% at c4, `tg` ~247**", and the c2/c5 flips built on the same arithmetic | tg128 @ d16384 c4, c2, c5 | R24 | **REFUTED at c4, measured.** The fix is removing MTP, and it reads **143.24 = −15.7%**, not +247. The projection assumed the cache could be restored at no cost; it costs 33.4% of per-request decode and buys 26.6% of batch span. The c2/c5 flips rest on the same refuted arithmetic and are not a live prospect |
| | | "the `ctx_` phase is prefill-free, so it is ~9x faster at prefill" and the five claims built on it | every `ctx_pp`-vs-`pp` comparison | the `ctx_` phase-label correction | **Withdrawn, not adjusted.** The ratio is `(depth+2048)/2048` to within 4% in 45 of 46 archived phase pairs. Prefix caching **never hit once** in 220+ engine samples |

## Two cautions that reach every row above

1. ⚠ **Small cross-invocation deltas are noise, in either direction.** R22's
   order-reversal control found the arm that ran **second** reading higher in 4
   comparisons of 4, mean **+6.5%**, and this file carried it as a suspected
   position bias. **R23's A-B-B-A round REFUTED it**: four same-configuration
   position contrasts read −4.40, −0.91, +0.71, +2.84% (mean **−0.44%**,
   p = 1.0), and the six adjacent different-config pairs in the same session
   split 3 up / 3 down. Clocks were identical across the five starts
   (2392–2398 MHz under load) and the box warmed 16 °C without throttling. What
   survives is a **symmetric** arm-to-arm spread of about **±5%** on identical
   configurations — so **R9c's ±2.5% reproduction floor is still an
   underestimate**, but it is a floor, not a bias, and no past delta needs
   re-signing. Do not quote a cross-invocation delta at or below ~5% as an
   effect. **The knee at 65536 was never at risk** (+233%).
2. ⚠ **A figure measured exactly once carries a ~2% downward correction of
   unknown origin** (8 of 8 same-sign low reproductions, mean −1.88%), and an
   unaudited 3-run row is wrong by ~1 SE in an unknown direction. The direction
   is set by **audit selection, not sampling**: rows somebody was defending
   corrected DOWN five times, rows nobody had a motive to check corrected UP five
   times. **The campaign's recorded losses and thin margins are the rows most
   likely to be wrong, and most likely to be wrong in our favour.**
