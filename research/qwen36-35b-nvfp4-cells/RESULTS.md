# Results — qwen36-35b-nvfp4-cells

## READ THIS FIRST — the standings in ten lines (2026-08-22, after R21)

> ### ✅ R21 RAN LAST — THE THREE-RUN AUDIT. NO CELL CHANGED HANDS; FOUR NUMBERS DID.
>
> **Counts are unchanged at 8 won / 12 lost.** R21 was a standings-protection
> round, not a cell hunt: it re-measured at `runs=7` the rows that still stood on
> 3-run medians, each arm reproducing its row's original pre-fold configuration.
> **Four rows moved and every one moved UPWARD:**
> `tg32 @ d8192 c1` **+16.54%** (106.24 → **123.81**, R1's figure RETIRED —
> outside the ±10% band), `tg128 @ d131072 c1` **+5.43%** (pooled → **81.22**),
> `ctx_tg128 @ d131072 c1` **+2.24%** (pooled → **77.52**), `ctx_tg @ d8192 c1`
> **+1.77%** (pooled → **127.64**).
>
> **The headline correction: `tg128 @ d131072 c1` was NOT lost by 5.5%. It is
> lost by 0.47%** — 0.11 SE, a dead heat we are on the wrong side of. It did not
> flip and is **not** claimed, but the campaign had been overstating that deficit
> by a factor of ten. **`ctx_tg @ d8192 c1`'s thin 1.07x over best vLLM+NVFP4
> survived** and firms to 1.08x, so no published claim was withdrawn.
>
> ⚠ **One row is still on three runs and is labelled provisional, not hidden:**
> `tg128 @ d16384` c2 (84.00) and c5 (48.12). Both are losses by **>2x**, which
> no sampling error closes, and both already have 7-run tuned successors. See
> *the rows still on three runs* below.
>
> **Five up, five down — and the sign is predicted by whether anyone was
> defending the row.** See the same section for what that means.

> ### ⚠️ `recipe.yaml` CHANGED TODAY — THIS IS A CONFIG EPOCH BOUNDARY
>
> **R11 folded `max_num_batched_tokens: 65536` into `recipe.yaml`** (it was
> 8192). That is the **first change to the recipe in the campaign's history** —
> R1 through R13d all ran on the recipe exactly as inherited.
>
> **Consequence you must not miss:** every row in this file that used to say
> "campaign config" was measured at **mnbt 8192** and is **no longer reproducible
> from `recipe.yaml`**. Those rows now say **"mnbt 8192 — PRE-FOLD recipe"**.
> Nothing in the archives is invalidated and **no margin moved**; what changed is
> what "unmutated" means after today. **The next round that runs `./recipe.yaml`
> without `-o` flags gets a different engine from every round before R11, and at
> `c>1` it gets dramatically different numbers.**
>
> **Why the fold was allowed:** R11 measured the c1 anchor at the new value
> first, because that anchor is what every depth and concurrency comparison in
> the campaign hangs from. `tg128 @ d16384 c1` reads **112.92** at mnbt 65536
> against **112.62** at mnbt 8192 — **+0.27%, i.e. nothing** — so no baseline
> moves and no depth-curve point is invalidated. The fold rule and its band were
> declared in `journal.md` before the run.

- **WON 8 board cells, LOST 12**, and a long tail the board publishes no figure
  for and which therefore cannot be scored either way. **R11 moved no cell** —
  it measured a crowded cell that was never a campaign target, and its product is
  the fold, not a standing. **R8c moved no cell either, but it moved a
  number — see the next bullet, which is the newest thing in this file.**
- ⚠️ **A RECORDED LOSS WAS WRONG BY 28%, AND IT WAS WRONG IN OUR FAVOUR.**
  `ctx_tg @ d32768 c1` has been carried as a **0.72x** loss since R1. R8c
  re-measured R1's own condition at runs=7 and read **110.61 against R1's
  84.03 — +31.64%**, far outside the ±10% protection band. **The cell is
  0.92x, not 0.72x**, and on the folded recipe (`mnbt 65536`) it reads
  **117.65 against a 117.37 incumbent — 1.002x, a dead heat.** ⚠ **That dead
  heat is NOT claimed as a win** (+0.24% is 0.06 SE, and it is the only
  measurement of the cell at that budget), so the counts stay **8 won / 12
  lost** — but a **125-entry crowded cell** the campaign had written off is now
  the closest unclaimed cell it has, and it is queued for a protection round at
  both budgets. **This is the single most likely place for the standings to
  change.**
- **R8c also retired the campaign's last deep `ctx_` inversion.** R1's −27.3%
  Phase-1 deficit at d32768 read **+0.9%** at runs=7 on the identical config and
  **+6.9%** on the folded recipe. All three deep inversions the campaign ever
  published are now gone, and no mechanism was needed for any of them.
- ⚠️ **AND THE SAMPLING RULE THIS FILE PUBLISHED IS REVISED: 3-run medians are
  unreliable in BOTH directions.** The campaign carried a warning that every
  3-run median it re-measured came in too high — four for four. That pattern was
  an artefact of **which** figures got re-measured: flattering ones become claims
  and claims get audited, while a disappointing figure sits in the standings
  unexamined, which is exactly what 84.03 did for eleven rounds. **Audit the
  unflattering rows too.** ✅ **R21 DID, AND IT WAS RIGHT FIVE TIMES OUT OF
  FIVE** — three of the four listed rows are now on 7 runs and every one came in
  HIGH (+16.54%, +5.43%, +1.77%, plus +2.24% on a free rider). The fourth is
  declined on the record. See *the rows still on three runs* below.
- **Widest margin: `ctx_tg @ d16384 c4` at 6.21x** (171.77 vs 27.68), on a
  **mutation** — `max_num_batched_tokens 131072 + max_num_seqs 5`, pooled over 14
  runs from two engine starts (R13c + **R13d**). It took the title from the
  mnbt 98304 row's 6.15x **by 0.83%** — a bookkeeping change, not a discovery.
  The best *campaign-config* win is `tg128 @ d65536 c1` at **5.71x**.
- **The one contested cell we hold** is `tg128 @ d16384 c4`: **1.13x** on the
  untouched recipe, **3.67x** on the raised token budget.
- **The token budget is the campaign's largest lever and its curve KNEES AT
  65536** (R13c). 8192 → 65536 is +233% at c4; 65536 → 131072 is −1.4%, i.e.
  nothing. R13's 98304 buys nothing over 65536. **R11's fold value is 65536.**
- **c5 was never taken.** It is the only loss with a live route to a win and it
  ends the campaign at 0.73x. It is recorded as a loss.
- **R13d closed the queue's last scoreable cell.** It repeated
  `ctx_tg @ d16384 c4` at mnbt 131072 and **moved the widest-margin title to
  6.21x on 14 pooled runs**, retiring R13c's unpromoted 6.34x as a high draw
  (repeat came in −2.99%). **No standing changed sign; the counts are still
  8 won / 12 lost.** Everything below still applies.
- **R11 ran last and settled the fold.** It is the round the synthesis called the
  highest-value item outstanding, and it did what it was queued to do: the token
  budget is **inert at c1** (+0.27% on the anchor, and the Phase-1 partner is
  inside its own noise), so the flag went into the recipe. **Eight of the
  eighteen win rows are now the config the recipe ships rather than a per-round
  `-o` flag.**
- **R11 also answered open question 13 for free.** R13 found `tg_req` rising
  +15.5% at both c4 and c5 on a budget change and nobody could say whether that
  was sharing or an intrinsic per-request effect, because every measurement was
  at `c>1`. At c1, `tg` **is** `tg_req` by assignment — and it moved **+0.27%**.
  **The per-request rise at `c>1` is a sharing artefact, not a property of the
  request.**
- ⚠️ **`runs=3` is no longer safe at `tg128 @ d16384`, and R6's rule saying it is
  should not be quoted again.** The same cell has now read σ/med **2.6% (R6) /
  5.5% (R8) / 8.01% (R11)** across three engine starts. At 8.01% a 3-run median
  carries a standard error near 5.8%. **runs=7 is the only budget that has been
  safe at all three.**

**What changed overnight, in four items — all four are corrections, and two of
them retired figures this file had published:**

1. **R13** took `tg128 @ d16384 c4` to a claimed 3.74x and set a record 6.16x —
   and **refuted the campaign's own "admission stagger" model**: with
   `Waiting: 0` in 100% of samples the span ratio barely moved. Whatever the
   denominator is charging for, it is not admission. ⚠️ **R13b then named what it
   IS — prefill-completion stagger — and refuted the replacement candidate (MTP
   acceptance dispersion) on the way.** See the R13b section.
2. **The `ctx_` PHASE-LABEL CORRECTION.** llama-benchy labels its two phases
   backwards. `ctx_` is the **uncached** Phase-1 context load; the rows this file
   called "cold" are the cache-*eligible* Phase 2 — and the two are charged
   **different token counts** (16384 vs 2048). The ~9x `ctx_pp` advantage read
   for twelve rounds was a **denominator artefact**. **Prefix caching never once
   engaged in this campaign's config.** Six claims withdrawn; **no board margin
   moves**, because both sides of every comparison are the same instrument.
   ⚠ **R9c later priced the flag at 2.414x anyway, 83% of it batch span — the
   cache never hitting and the flag being worth 2.4x are both true, for the
   reason set out in the prefix-caching section below.**
3. **R5c** verified against all 34 archived `c>1` records that the board's `c>1`
   `tg` figure is a **batch aggregate** (`tg_throughput`, `results.py:352`):
   `tg > tg_req` in 34/34. **Never multiply a per-request figure by concurrency.**
   The stagger proxy is valid only at full residency.
4. **R13c** put all six `c4` headline rows back on the box from separate engine
   starts. **All six stood** — but all six came in low (mean −1.94%, six of six
   the same sign), so **every figure here measured exactly once carries a ~2%
   downward correction of unknown origin**. Two same-config figures were pooled
   to 14-run medians: **3.74x → 3.67x** and **6.16x → 6.15x**.

**If you are picking this up:** ✅ **R21 is DONE — the 3-run audit is closed** and
the standings' remaining provisional row is named above. The best scoreable
prospect left is **R8c-PROTECT**: `ctx_tg @ d32768 c1` at both budgets, the
125-entry cell now sitting at a 1.002x dead heat. Then ✅ **R11 is DONE and the
flag is folded** — see
the epoch warning above before you compare anything to a pre-fold row. The next
items are the zero-box-time prefill metric check, then **`mnbt 65536 + mns 4` at
c4**, which is the config the recipe now actually ships and which has never been
measured (the 3.71x row was taken at `mns 5`). See the handoff at the end of
`journal.md`.

---

Model fixed: nvidia/Qwen3.6-35B-A3B-NVFP4 (de-rayed recipe). The campaign
set out to vary the PROBE, not the config — though from R9 onward its largest
results came from scheduler MUTATIONS, which is why every row below names its
configuration. `recipe.yaml` itself is still untouched.
Targets and incumbents per cell: docs/arena-recipe.md.

**The campaign ran 13 rounds and is closed. The synthesis — what held, what was
retracted, the cost ledger and where to pick up — is the `CAMPAIGN SYNTHESIS`
section of `journal.md`, revised 2026-08-22 to cover R13, the `ctx_` correction,
R5c, R13c and **R13d**. It is the ONE authoritative handoff; read it rather than the
individual round blocks.** Read this file for the standings.

Nothing is submitted to the arena — there is no login, and none was ever
attempted — so this file is the standings. One row per measured CELL, appended
after archiving into `experiments/<benchId>/`. A single benchmark run measures
several cells, so one benchId spans several rows.

## Standings so far

Every row names its CONFIGURATION. **"mnbt 8192 — PRE-FOLD recipe"** means
`--max-num-seqs 4 --max-num-batched-tokens 8192`, which is what `recipe.yaml`
did for rounds R1 through R13d and **is no longer what it does** — R11 folded
`max_num_batched_tokens: 65536` on 2026-08-22, so those rows must be reproduced
with an explicit `-o max_num_batched_tokens=8192`. A **MUTATION** row was
measured with the named `-o` overrides on top of the pre-fold recipe. A tuned row
and an untuned row must never look alike here, and after the fold **neither may
be confused with what the recipe now ships** — which is `mns 4 + mnbt 65536`, a
combination that has been measured at **c1 only** (R11).

**Every row also names its PHASE, and the labels are not what they look like.**
A `ctx_` row is llama-benchy **Phase 1, the CONTEXT LOAD** — the *uncached* pass
that establishes the cache, charged `depth` prompt tokens. A row without `ctx_`
is **Phase 2, the inference pass** — the cache-*eligible* one, charged 2048
prompt tokens while actually processing `depth + 2048`. The campaign called
Phase 2 "cold" for thirteen rounds and had the two exactly backwards. **No
board margin in either table changes**, because the board publishes the same two
test types and the incumbents are the same instrument on the same side of the
comparison — see the phase-label correction section below for the full audit of
what changes and what does not.

### WON — 8 board cells, 18 rows

Eight cells, eighteen rows: the two `c4` cells each carry a pre-fold figure plus
FIVE token-budget points, because R13c curved the budget.

**⚠️ R11 SETTLED THIS AND THE ARITHMETIC BELOW IS NOW BACKWARDS FROM WHAT IT
SAID.** This paragraph used to read "ten of the eighteen rows are MUTATIONS that
are not in `recipe.yaml`". After the fold, **`max_num_batched_tokens 65536` IS
the recipe**, so the rows at that budget are no longer mutations — and the eight
rows measured at **mnbt 8192** are the ones the recipe no longer produces. Read
the CONFIGURATION column, not the word "MUTATION", which is retained on the rows
where it was true at the time of measurement. Rows still carrying a genuine
mutation on top of the current recipe are those naming `mns 5`, `mns 16` or a
budget other than 65536.

| Cell | Configuration | Ours | Board top | Margin | Note |
|---|---|---:|---:|---:|---|
| tg32 @ d16384 c1 | mnbt 8192 — PRE-FOLD recipe, runs=7 | 116.43 | 28.11 | **4.14x** | revised DOWN by R6 from R1's 3-run 129.32 |
| tg32 @ d32768 c1 | mnbt 8192 — PRE-FOLD recipe, **10 runs pooled** (R1 3 + R8c arm E 7) | **112.59** | 23.31 | **4.83x** | **PROTECTED BY R8c and STANDS.** ⚠ R1's 3-run 115.56 = 4.96x is RETIRED as the single draw it was; arm E re-measured the identical condition at runs=7 and read **109.62, −5.14%**, inside the ±10% protection band. σ/med 13.91% pooled. Worst of 10 runs 93.54 is still 4.01x |
| tg32 @ d32768 c1 | **mnbt 65536 — the FOLDED recipe** (`mns 4`), runs=7 | **110.03** | 23.31 | **4.72x** | **R8c arm F — the current-epoch row for this cell**, and the only one quotable as what `recipe.yaml` produces here. Against arm E's 109.62 at mnbt 8192 the budget moves it **+0.37%**, reproducing R11's **+0.27%** at d16384: the token budget is inert at c1 at a second depth. ⚠ **σ/med 24.20% — the noisiest cell in the campaign** (runs 75.36–144.99); at 32 tokens this averages only ~9 MTP verify steps, which is R6's variance mechanism at its extreme |
| tg32 @ d8192 c1 | mnbt 8192 — PRE-FOLD recipe, runs=7 | **123.81** | sole entry, no number published | uncontested | ⚠ **CORRECTED BY R21 — R1's 3-run 106.24 is RETIRED, and it was 16.54% LOW.** R21 re-measured R1's own condition at runs=7 and read 123.81 (runs 99.04–152.31, σ/med 13.18%). +16.54% is **outside the ±10% protection band**, so the figures are NOT pooled and the 7-run median replaces the 3-run one outright. This was the campaign's **worst-sampled standings row** (R1's σ/med 21.4%, runs 73.07–128.35, a 1.76x spread inside one cell). **No margin moves either way** — the board publishes no figure for this cell — which is exactly why it was re-measured last of the three |
| tg128 @ d16384 c4 | mnbt 8192 — PRE-FOLD recipe, 6 runs pooled | 52.85 | 46.68 | **1.13x** | verified by repeat; worst of 6 runs 51.25 still +9.8% |
| tg128 @ d16384 c4 | **MUTATION mnbt 32768**, runs=7 | **147.25** | 46.68 | **3.15x** | R10; reproduces R9's A1 143.08 to 2.9% from a separate start |
| tg128 @ d16384 c4 | **MUTATION mnbt 98304 + mns 5**, **14 runs pooled** | **171.31** | 46.68 | **3.67x** | **R13 + R13c**, two engine starts (174.68 and 169.69, gap −2.86%). Was claimed at 3.74x on R13's 7 runs alone; **R13c reproduced it and the pooled median is now the claimed figure** |
| tg128 @ d16384 c4 | **mnbt 65536** (the FOLDED budget) **+ mns 5**, runs=7 | **173.34** | 46.68 | **3.71x** | **R13c — THE KNEE, and the budget half of this row is now `recipe.yaml`.** peak_thr 308, span 1.505, σ 4.39%. Statistically identical to mnbt 98304 and 131072; the cheapest budget that reaches the ceiling. ⚠ **`mns 5` was NOT folded** — the recipe ships `mns 4`. At c4 the width is worth ≤2.9% (mnbt 32768 measured at mns 4/5/16 reads 143.08/143.83/147.25) and mns 4 holds full `(4,0)` residency at c4 from 32768 up, so the recipe should land within a few percent — but **`mnbt 65536 + mns 4` has never been measured** and this row must not be quoted as what the recipe produces |
| tg128 @ d16384 c4 | **MUTATION mnbt 131072 + mns 5**, **14 runs pooled** | 170.84 | 46.68 | **3.66x** | R13c + R13d, two engine starts (170.89 and 168.97, gap −1.12%) — above the knee, buys nothing over 65536. Not the claimed c4 figure: **the claimed one is the 65536 knee at 3.71x** |
| tg128 @ d16384 c4 | **MUTATION mnbt 16384 + mns 5**, runs=7 | 85.90 | 46.68 | **1.84x** | R13c — below the knee, scheduler never holds full occupancy |
| ctx_tg @ d16384 c4 | mnbt 8192 — PRE-FOLD recipe, 6 runs pooled | 56.36 | 27.68 | **2.04x** | |
| ctx_tg @ d16384 c4 | **MUTATION mnbt 32768**, runs=7 | **126.35** | 27.68 | **4.56x** | R10 |
| ctx_tg @ d16384 c4 | **MUTATION mnbt 131072 + mns 5**, **14 runs pooled** | **171.77** | 27.68 | **6.21x** | **R13c + R13d — the campaign's WIDEST margin**, past tg128 @ d65536 c1's 5.71x. Two engine starts (175.40 and 170.16, gap −2.99%). **R13d's repeat settled the cell R13c would not promote**: the pooled figure clears the previous title (170.36) by **0.83%**, so the title moves by a margin too small to mean anything physically — what changed is that it now rests on 14 runs at a re-measured config. **R13c's 175.40 = 6.34x is RETIRED as the high draw it looked like.** No third measurement of this cell — the question is closed |
| ctx_tg @ d16384 c4 | **MUTATION mnbt 98304 + mns 5**, **14 runs pooled** | 170.36 | 27.68 | **6.15x** | **SUPERSEDED as the widest margin by the mnbt 131072 row above (6.21x), by 0.83%.** Still a win at 6.15x and still the best value below 131072. R13 + R13c, two engine starts (170.59 and 168.37, gap −1.30%); was claimed at 6.16x on R13's 7 runs alone |
| ctx_tg @ d16384 c4 | **mnbt 65536** (the FOLDED budget) **+ mns 5**, runs=7 | 164.95 | 27.68 | **5.96x** | R13c — the knee. peak_thr 289, span 1.505. ⚠ Same caveat as the Phase-2 row above: `mns 5` is not in the recipe and `mnbt 65536 + mns 4` is unmeasured |
| ctx_tg @ d16384 c4 | **MUTATION mnbt 16384 + mns 5**, runs=7 | 68.79 | 27.68 | **2.49x** | R13c — below the knee |
| tg128 @ d65536 c1 | mnbt 8192 — PRE-FOLD recipe, runs=7 | 94.10 | 16.48 | **5.71x** | revised DOWN by R8 from R3's 3-run 108.15 |
| ctx_tg @ d65536 c1 | mnbt 8192 — PRE-FOLD recipe, runs=7 | 92.98 | 20.70 | **4.49x** | revised by R8 from R3's 89.76 |
| ctx_pp @ d65536 c1 | mnbt 8192 — PRE-FOLD recipe, runs=7 | 4013.59 | 1393.35 | **2.88x** | ⚠ mapping caveat — see the prefill section |

### LOST — 12 board cells, and they are recorded as plainly as the wins

| Cell | Configuration | Ours | Board top | Like-for-like | Verdict |
|---|---|---:|---:|---:|---|
| tg128 @ d131072 c1 | mnbt 8192 — PRE-FOLD recipe, **10 runs pooled** (R5 3 + R21 7) | **81.22** | 81.60 (Nemotron Lightning NVFP4) | — | ⚠ **STILL LOST, BUT THE 0.95x IS RETIRED — R21 CORRECTED IT UPWARD AND THE LOSS IS NOW 0.47%, NOT 5.5%.** R21 re-measured R5's identical condition at runs=7 and read **81.32, +5.43%** — inside the ±10% band, so the row STANDS and the two sets are pooled to a 10-run median of **81.22 = 0.995x**. **The cell is a DEAD HEAT that we lose:** −0.47% against σ/med 10.56% is **0.11 SE**. It is NOT claimed as a win and it is NOT scored as one — but the campaign's most-cited narrow loss was overstated by a factor of ten. ⚠ Do not re-run to chase it: this is the campaign's most expensive depth (784 s of grid for seven runs) and 0.11 SE is not resolvable at any run budget this campaign can afford |
| tg128 @ d16384 c2 | mnbt 8192 — PRE-FOLD recipe | 84.00 | 325.44 (LFM2.5-350M BF16) | 163.27 (board's own Qwen3.6-35B-A3B-NVFP4, vLLM) | **0.51x — LOST** |
| tg128 @ d16384 c2 | **MUTATION mnbt 32768 + mns 5**, runs=7 | 140.77 | 325.44 | 163.27 | **0.86x — still LOST**, was 0.51x |
| tg128 @ d16384 c5 | mnbt 8192 — PRE-FOLD recipe + mns 5 | 48.12 | 428.95 (LFM2.5-350M BF16) | 225.46 (Qwen3.6-35B-A3B-NVFP4-Fast, vLLM) | **0.21x — LOST** |
| tg128 @ d16384 c5 | **MUTATION mnbt 32768 + mns 5**, runs=7 | 128.93 | 428.95 | 225.46 | **0.57x — still LOST**, was 0.21x |
| tg128 @ d16384 c5 | **MUTATION mnbt 98304 + mns 5**, runs=7 | 164.27 | 428.95 | 225.46 | **0.73x — still LOST**, was 0.57x. **R13**, the round aimed at this cell and did not take it. peak_thr **303**, stagger 1.54, σ 3.29%. Against the CELL TOP 428.95 it is 0.38x |
| ctx_tg @ d8192 c1 | mnbt 8192 — PRE-FOLD recipe (tg32 arm), **10 runs pooled** (R1 3 + R21 7) | **127.64** | 207.60 (LFM2.5-350M BF16) | 118.07 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | **0.61x — LOST** to the top (0.615x); **1.08x** over best vLLM+NVFP4. ✅ **PROTECTED BY R21 AND STANDS.** R21 re-measured R1's condition at runs=7 and read **128.76, +1.77%** — comfortably inside the ±10% band and the smallest correction of the round, so the sets are pooled. **The thin 1.07x claim over best vLLM+NVFP4 survives and firms to 1.08x.** The 0.61x loss to the cell top was never in play — 207.60 is 63% away and no sampling reaches it |
| ctx_tg @ d16384 c1 | mnbt 8192 — PRE-FOLD recipe (tg32 arm), runs=7 | 122.97 | 193.09 (LFM2.5-350M BF16) | 153.86 (our own model on Atlas) | **0.64x — LOST**; best vLLM+NVFP4 not in the scrape |
| ctx_tg @ d32768 c1 | mnbt 8192 — PRE-FOLD recipe (tg32 arm), **10 runs pooled** (R1 3 + R8c arm E 7) | **107.73** | 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**) | 116.65 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | **0.92x — still LOST**, but ⚠ **the recorded 0.72x is RETIRED and was wrong by 28%.** R1's 84.03 was a 3-run low draw; arm E re-measured the identical condition at runs=7 and read **110.61, +31.64%**, far outside the ±10% band. **This is the campaign's largest single-figure retraction, and it went UPWARD** — see the note on one-sided auditing below |
| ctx_tg @ d32768 c1 | **mnbt 65536 — the FOLDED recipe** (`mns 4`), runs=7 | **117.65** | 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**) | 116.65 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM) | ⚠ **1.002x — A DEAD HEAT, AND EXPLICITLY NOT CLAIMED AS A WIN.** +0.24% on a cell with σ/med 9.44% is **0.06 standard errors**, and this is the FIRST and ONLY measurement of the cell at this budget. The campaign's rule (R13c) is that a single 7-run median at a configuration measured once is not a claim, and promoting the best first measurement is exactly what retired R1's and R3's figures. **The cell is scored a LOSS and queued for a protection round** — it is a 125-entry crowded cell and now the closest unclaimed cell in the campaign. ⚠ The +6.36% over arm E is 1.0 SE, so whether the folded budget genuinely helps Phase 1 here is NOT established; the protection round must measure BOTH budgets |
| pp2048 @ d8192, d16384, d32768 c1 (3 cells) | mnbt 8192 — PRE-FOLD recipe | 1187.51 / 637.09 / 295.71 | 215894 / 99229 / 63080 (all Atlas) | 4644.54 at d32768 | **LOST, ~0.006x of top and 0.064x of best vLLM** — the size of that gap is itself a warning, see the prefill section |
| ctx_pp @ d8192, d16384, d32768 c1 (3 cells) | mnbt 8192 — PRE-FOLD recipe | 6148.56 / 5856.93 / 5086.51 | 775123 / 884765 / 945271 (all Atlas) | not in scrape | **LOST by ~150x** — same warning |

### ⚠️ THE ROWS STILL ON THREE RUNS — and the one-sided auditing that hid an error for eleven rounds

**Why this note exists.** R8c re-measured `ctx_tg32 @ d32768 c1` and found R1's
3-run 84.03 was **28.5% below** what seven runs at its own condition say. It is
the campaign's largest single-figure retraction and **it went upward**, which
breaks the rule this file used to publish — that a 3-run median always comes in
high. It never was a property of sampling. A high draw becomes a claimed win and
gets defended, and defended figures get re-measured; **a low draw becomes a
recorded loss and nobody looks at it again.** The four figures the campaign had
audited were all figures somebody had a motive to check. **Sampling error is
symmetric; the error that survives in a results file is whichever direction
nobody was auditing.**

**The practical rule: treat any unrepeated figure as wrong by ~1 standard error
in an unknown direction, and re-measure the unflattering rows first.**

✅ **R21 WORKED THIS LIST AND THREE OF THE FOUR ROWS ARE OFF IT. ALL THREE MOVED,
AND ALL THREE MOVED UP.** Two engine starts, `runs=7`, each arm reproducing its
row's original pre-fold configuration with an explicit
`-o max_num_batched_tokens=8192`.

| # | row | was (runs=3) | R21 (runs=7) | change | now | verdict |
|---:|---|---:|---:|---:|---:|---|
| 1 | `ctx_tg @ d8192 c1` | 126.52 | 128.76 | **+1.77%** | **127.64** pooled(10) | ✅ **STANDS.** The 1.07x over best vLLM+NVFP4 survives and firms to **1.08x** |
| 2 | `tg128 @ d131072 c1` | 77.13 | 81.32 | **+5.43%** | **81.22** pooled(10) | ⚠ **STANDS but the margin was wrong by 10x.** 0.95x → **0.995x**. Still a loss — by **0.47%, i.e. 0.11 SE.** Did not flip |
| 3 | `tg32 @ d8192 c1` | 106.24 | **123.81** | **+16.54%** | **123.81** | ⚠ **OUTSIDE the band — R1's figure RETIRED**, not pooled. Uncontested cell, so no margin moves |
| 4 | `tg128 @ d16384` c2 (84.00) and c5 (48.12), R4 pre-fold | — | **NOT MEASURED** | — | — | ⚠ **STILL ON THREE RUNS AND STILL PROVISIONAL** — see below |

⚠️ **ROW 4 REMAINS ON THREE RUNS AND IS LABELLED PROVISIONAL RATHER THAN
QUIETLY LEFT.** `tg128 @ d16384` at c2 (84.00) and c5 (48.12) were **deliberately
not re-measured** by R21: both are losses by **more than 2x**, and no sampling
error of that size closes a 2x gap — R21's largest correction was 16.5%. Both
also already have 7-run tuned successors at raised budgets (c2 → 140.77, c5 →
128.93/164.27) which are what the standings actually rest on. **The two 3-run
figures are provisional and should not be quoted as measurements**; they are kept
because they are the pre-fold baselines those successors are measured against.

**AND THE DIRECTION IS NOW THE STORY. Five consecutive upward corrections.**
Counting R8c's `ctx_tg32 @ d32768` (+31.64%), every 3-run row this campaign
re-measured **because nobody had audited it** has come in **HIGH**: +31.64%,
+16.54%, +5.43%, +2.24%, +1.77%. Every 3-run row it re-measured **because
somebody was defending it as a claim** came in **LOW**: −10.0%, −13.0%, −5.14%,
−2.86%, −1.30%. **Five down, five up, and the sign is predicted entirely by
whether the row was flattering — not by anything about sampling.** This is
regression to the mean seen from both ends at once, and it is the cleanest
vindication the campaign has of the rule it wrote after R8c. **A results file's
surviving errors point in whichever direction nobody had a motive to look.**

### CANNOT BE SCORED — the board has no figure for these cells

`tg128 @ d16384 c8` (43.51, peak_thr 355) and `c16` (40.47 / peak_thr 440 at
mnbt 8192 — pre-fold recipe; 53.45 / peak_thr **515** at mnbt 32768) — the scrape covers
c1, c2, c4 and c5 only. `ctx_tg @ d16384` at c2 (127.09) and c5 (104.75 at mnbt
32768; **160.67 at mnbt 98304 + mns 5, R13**), and
every `pp2048`/`ctx_pp` cell at `c>1` — the board's prefill and context cells
are c1 only. `ctx_tg @ d131072 c1` (**77.52 pooled over 10 runs, R5 3 + R21 7** —
R21 read 78.38 at runs=7 against R5's 76.66, **+2.24%**, inside the band; the
retired 3-run figure was 76.66) — never scraped, so held rather than claimed.
`pp2048 @ d65536
c1` (119.54) — the board has **zero entries** at that depth, so it is an empty
cell rather than a won one, and nothing can be posted to it anyway. All
sixteen R9b rows — three flags off the pre-fold campaign config (mnbt 8192),
explicitly diagnostic.

`tg128 @ d16384 c1` (112.62 pooled over 14 runs, R6+R8, at mnbt 8192) is the
crowded cell and was never a campaign target: 116.03 best vLLM NVFP4, 188.47
overall, so 0.97x against like-for-like. It is listed for the reproduction gap
(now **-2.9%**), not as a cell we went after.

**R11 re-measured it at the folded budget and this is the anchor the fold rests
on: 112.92 at mnbt 65536, +0.27% on the 112.62 anchor** (runs=7, σ 9.05,
σ/med 8.01%). The two figures are **NOT pooled** — different configurations, and
pooling across a config difference is the thing this file says must never happen.
Against 116.03 the new figure is **0.97x**, unchanged. **This is the cell that
licenses every cross-fold comparison in this file:** because it did not move, no
depth-curve point and no c1 baseline is invalidated by the recipe change.

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

⚠️ **ROUND 13 CORRECTS THE SENTENCE ABOVE — read this before using that table.**
R13 raised the budget to `max_num_batched_tokens 98304`, which is enough to admit
a whole 5-request batch in one scheduler step (a Phase-2 prefill is `depth + pp` =
**18432** tokens, not 16384 — see the journal's R13 pre-flight). The engine log
confirms it worked: **`Waiting: 0 reqs` in 100% of loaded samples**, `Running: 4`
and `Running: 5` at the two arms. **And the stagger ratio only fell from 1.70 to
1.54 at c5, and from 1.57 to 1.53 at c4.** With literally nothing queueing, the
ratio barely moved. **So most of what this file has been calling "admission
stagger" since R10 is NOT admission**, and R12's "93% stagger" split above is a
description of the metric's arithmetic rather than of the physical cause. The
leading candidate for the residual span is MTP acceptance dispersion across the
batch (acceptance samples span 2.77-4.00, a 1.44x spread against a measured
1.54); it is **not established** — see the journal for what would settle it.

⚠️ **ANSWERED BY R13b, AND THAT CANDIDATE IS REFUTED TOO.** Measured per request,
acceptance dispersion acting alone gives a span ratio of **1.085** against
**1.499** observed — 17% of the excess. Within one batch, per-request acceptance
max/min is **1.167**; the 2.77–4.00 range was between-sample, and max/**min** is
not the statistic that enters the span (max/**harmonic-mean** is, and it reaches
only 1.19 even on that range). **The residual is prefill-completion stagger**:
the first request to finish prefill decodes at **88.5 ms/verify-step** against
55–58 ms for the other four, because its verify steps are co-scheduled with the
batch's remaining chunked prefill — and the batch span is measured from its first
token. `corr(start stagger, ms/step) = −0.980`; `corr(verify steps, decode
duration) = +0.142`. **`Waiting: 0` was never evidence against this, because
`Running` counts a prefilling request the same as a decoding one.** See the R13b
section below.

📊 **What Round 13 actually bought, at `mnbt 98304 + mns 5`, runs=7, one engine
start.** The gain came from per-request decode, not from the span:

| cell | tg was | tg now | tg_req was | tg_req now | stagger was | stagger now |
|---|---:|---:|---:|---:|---:|---:|
| c4 | 147.25 | **174.68** | 57.80 | 66.76 (**+15.5%**) | 1.57 | 1.53 |
| c5 | 128.93 | **164.27** | 43.72 | 50.50 (**+15.5%**) | 1.70 | 1.54 |

**A win widened and a record set:** `tg128 @ d16384 c4` goes 3.15x → **3.74x**,
and `ctx_tg @ d16384 c4` goes 4.56x → **6.16x, the widest margin the campaign
held at the time** (the title has since moved to the mnbt 131072 row at 6.21x —
R13d).
⚠️ **BOTH OF THOSE FIGURES WERE SUPERSEDED THE SAME NIGHT.** R13c re-ran the
identical configuration from a separate engine start and the two 7-run sets are
pooled to 14-run medians: **3.74x → 3.67x** and **6.16x → 6.15x**. The claimed
figures are the pooled ones and they are what the standings table carries; 3.74x
and 6.16x appear here only as R13's own reading. The margins survive, the
decimals do not.

**A loss stayed a loss:** c5 was the round's target and the only cell with a live
route to a win. It reads **164.27 against 225.46 — 0.73x, short by 27%.** It is
recorded as a loss. Against the c5 cell's actual top (428.95, LFM2.5-350M BF16)
it is 0.38x, so even clearing 225.46 would have beaten the board's own
Qwen3.6-35B-A3B-NVFP4 entry without taking the cell.

**The latency trade got worse again.** ttfr rises for the sixth consecutive
budget increase — 15126 ms at c5, 12102 ms at c4. These rows are a throughput
ranking bought with response latency, and `peak_throughput` (303 and 310) moved
only +4.5% and +9.2% while the board metric moved +27% and +19%.

✅ **ROUND 13c PUT ALL SIX c4 HEADLINE FIGURES BACK ON THE BOX, AND ALL SIX
STOOD.** R13c re-measured every protected `tg128 @ d16384 c4` and
`ctx_tg @ d16384 c4` figure at runs=7 from a separate engine start, against a
±10% band declared before the run, and then curved `max_num_batched_tokens`
across six values at that one concurrency. Nothing came down.

| protected row | archived | R13c | gap | verdict |
|---|---:|---:|---:|---|
| tg128 @ d16384 c4, mnbt 8192 | 52.85 | 52.07 | −1.48% | **STANDS** |
| tg128 @ d16384 c4, mnbt 32768 | 147.25 | 143.83 | −2.32% | **STANDS** |
| tg128 @ d16384 c4, mnbt 98304 | 174.68 | 169.69 | −2.86% | **STANDS** |
| ctx_tg @ d16384 c4, mnbt 8192 | 56.36 | 54.57 | −3.18% | **STANDS** |
| ctx_tg @ d16384 c4, mnbt 32768 | 126.35 | 125.74 | −0.48% | **STANDS** |
| ctx_tg @ d16384 c4, mnbt 98304 | 170.59 | 168.37 | −1.30% | **STANDS** |

The mnbt 32768 point is the strongest of the six: 143.83 at `mns 5` sits between
R9's arm A1 (143.08 at `mns 4`, runs=3) and R10's 147.25 (at `mns 16`, runs=7) —
**three independent measurements, three scheduler widths from 4 to 16, inside a
2.9% band.**

⚠️ **BUT ALL SIX REPRODUCTIONS CAME IN LOW — mean −1.94%, six of six the same
sign.** On a coin that is p ≈ 3%, so it is a systematic and it is recorded as
one. Two candidates, and R13c **cannot separate them**: a small decode-side
session effect on the night, or a first-measurement bias in a campaign that
promotes the figure from the run that motivated the round. The `pp2048` session
control passed at five of six arms, so no night-wide slowdown is visible — but
`pp` measures prefill and `tg` measures decode, so a decode-only session effect
would not show there. **Treat every figure in this file that was measured exactly
once as carrying a ~2% downward correction of unknown origin.** No verdict,
margin or standing changes sign at that size.

**Two figures are consequently tightened**, because R13 and R13c ran the *same*
configuration (mnbt 98304 + mns 5) at runs=7 each and there is no basis for
preferring either draw. The claimed figures become pooled 14-run medians, exactly
as R2's verify run did for c4 and as R6 and R8 did when they retired 3-run
medians: `tg128 @ d16384 c4` **174.68 → 171.31 (3.74x → 3.67x)** and
`ctx_tg @ d16384 c4` **170.59 → 170.36 (6.16x → 6.15x — the campaign's widest
margin as of this pass; R13d later moved the title to the mnbt 131072 row at
6.21x, by 0.83%)**. The mnbt 8192 and mnbt 32768 rows are **not** pooled — those
were measured at `mns 4` and `mns 16` and R13c ran `mns 5`, and pooling across a
configuration difference is the one thing this file has said must never happen.

📈 **AND THE BUDGET CURVE HAS A KNEE AT 65536 — so R13's 98304 buys nothing.**
Six budgets, c4, d16384, tg128, `mns 5`, runs=7 each, one invocation per budget:

| mnbt | admission steps | `tg` | σ/med | `tg_req` | span ratio | `peak_thr` | scheduler |
|---:|---:|---:|---:|---:|---:|---:|---|
| 8192 | 9 | 52.07 | 1.03% | 33.00 | 2.535 | 271 | **partial occupancy** |
| 16384 | 5 | 85.90 | 2.08% | 43.99 | 2.048 | 277 | **partial occupancy** |
| 32768 | 3 | 143.83 | 3.87% | 59.48 | 1.654 | 288 | `(4,0)` 13/13 |
| **65536** | 2 | **173.34** | 4.39% | **65.24** | **1.505** | 308 | `(4,0)` 10/10 |
| 98304 | 1 | 169.69 | 4.01% | 64.02 | 1.509 | 302 | `(4,0)` 11/11 |
| 131072 | 1 | 170.89 | 3.89% | 64.14 | 1.501 | 304 | `(4,0)` 12/13 |

8192 → 65536 is **+233%**. 65536 → 131072 is **−1.4%**, i.e. nothing: the top
three budgets span 2.1% against a per-arm σ/med of ~4% and are one point.
**`max_num_batched_tokens 98304` — the value R13 derived from one-step-admission
arithmetic and paid a torch.compile rebuild for — is not needed.** The ceiling is
reached at 65536, which is a TWO-step configuration, so removing the last
admission step is not what the gain was made of. **R11's fold value is 65536.**

🔬 **The curve also separates two thresholds this file had been conflating.**
*Residency* saturates at 32768 — the scheduler reads a clean `Running: 4,
Waiting: 0` there and above, while at 16384 it carries `(2,2)` and `(3,1)` in 9
of 16 loaded samples and at 8192 in 10 of 19 (reproducing R9's observation at
this cell from a fourth engine start). *The span ratio* does not: it keeps
falling from 1.654 to **1.505** between 32768 and 65536 with nothing waiting at
either, then stops dead. **That is R13's `Waiting: 0` finding seen from the other
side, and the second independent confirmation that the ratio this file called
"admission stagger" for four rounds is not admission.** Its floor is ~1.50.
⚠️ **R13b identified that floor: prefill-completion stagger.** More budget means
fewer prefill chunks and a tighter first-token spread, which is why the ratio
keeps falling with nothing waiting — and it floors because the prefill *work*
cannot be made simultaneous across the batch by any budget.

✅ **ROUND 13d SETTLED THE MARGIN R13c REFUSED TO PROMOTE — the title moves, by
0.83%.** R13c measured `ctx_tg @ d16384 c4` at mnbt 131072 as **175.40 = 6.34x**
and would not claim it: a single 7-run median at a config measured once, with two
above-knee neighbours (168.37, 164.95) making the three one point. R13d repeated
the identical configuration, runs=7, one engine start.

| | R13c | **R13d** | **pooled 14** | vs the 170.36 title |
|---|---:|---:|---:|---|
| `ctx_tg @ d16384 c4`, mnbt 131072 | 175.40 | **170.16** | **171.77** | **+0.83% — TITLE MOVES, 6.21x** |
| `tg128 @ d16384 c4`, mnbt 131072 | 170.89 | 168.97 | 170.84 | — |

**Read this as a bookkeeping change, not a discovery.** The campaign's widest
margin is now **6.21x** and rests on 14 runs at a re-measured configuration
instead of one draw — but 6.21x against 6.15x is 0.83%, well inside the ~2%
correction this file carries on once-measured figures. **R13c was right not to
promote 6.34x: it was an overstatement of 2.1%, and it is retired.** The rule
declared before R13d ran was that the pooled median decides and no third
measurement would be taken either way. **The cell is closed.**

📉 **AND THE −1.94% SYSTEMATIC NOW HAS EIGHT SAME-SIGN REPRODUCTIONS.** R13d's
two came in at **−2.99%** (ctx) and **−1.12%** (Phase 2); with R13c's six that is
**8 of 8 low, mean −1.88%**, p ≈ 0.8% on a fair coin. One thing narrowed: R13c's
six were all figures that had motivated their own promotion, which is the shape
first-measurement bias takes — **R13d's Phase-2 partner was not a promoted figure
and came in low anyway**, which is mild evidence for the session-effect half.
Mild, not conclusive: one unpromoted point against seven promoted ones. **The ~2%
downward correction on every once-measured figure in this file stands.**

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
(0.61x / 0.64x / ⚠ **0.92x — REVISED BY R8c from the 0.72x this paragraph used
to carry**, to a 350M BF16 model or to our own model on Atlas), the
six prefill c1 cells are heavy losses, and `ctx_pp @ d65536 c1` is a win at
2.88x. ⚠ The d8192 figure is still a 3-run median from the same invocation whose
d32768 figure R8c found 28.5% low — see *the rows still on three runs* above; it
is the campaign's first priority re-measure.
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
the pre-fold campaign config (mnbt 8192) and 0.86x/0.57x on the raised budget. Round 7's two cells
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


## ⚠️ THE PHASE-LABEL CORRECTION — the full audit, and what it costs

R9b found two instrument errors that reach every `ctx_` row this campaign ever
wrote. A dedicated correction pass (2026-08-22, no box time) then audited every
such row and every claim resting on one, and put a number on the second error.
**This section is the authority. Read it before using any `ctx_` figure.**

**THE BOTTOM LINE, so nobody has to hunt for it.** No win is withdrawn, no loss
becomes a win, and no board margin moves — because the board publishes the same
two test types (`ctx_tg @ dN`, `ctx_pp @ dN`, per `docs/arena-recipe.md`) and
the incumbents are the same instrument measured the same way. What is withdrawn
is a family of **internal** readings: every comparison this campaign made
between a `ctx_` figure and its non-`ctx_` counterpart, plus every mechanism
built on the belief that the `ctx_` phase does less prefill work. Six such
claims are retired below. **The standings are unchanged and are correct as
written.**

**1. THE TWO MEASUREMENT PHASES ARE LABELLED BACKWARDS, and have been since R1.**
`llama_benchy/runner.py:127-176` and `223-225`:

    if self.config.enable_prefix_caching and depth > 0:
        # Phase 1: Context Load  -> is_context_phase=True,  expected_ctx (16384)
        # Phase 2: Inference     -> is_context_phase=False, expected_pp  (2048)

The `ctx_` rows are **Phase 1, the context load** — the pass that *establishes*
the cache, i.e. the uncached one. The rows this file calls **"cold" are Phase 2**,
the cache-eligible one. And the two are charged **different token counts**
(`depth` vs 2048), so their `pp_throughput` figures were never comparable to one
another. The archived exports say so directly and independently of the source
read: every benchmark record in `experiments/` carries
`"is_context_prefill_phase": true` on the `ctx_` rows, alongside
`"context_size": 16384, "prompt_size": 2048` on **both** phases.

**AND PHASE 1 IS NOT THE PHASE WITH LESS PREFILL WORK — IT IS THE ONE WITH
MORE OF IT CHARGED AND LESS OF IT DONE.** Phase 1 processes `depth` prompt
tokens and is charged all of them. Phase 2 processes `depth + 2048` (R13's
pre-flight established this, and prefix caching never hits so none of the
`depth` is free) and is charged **2048**. So the campaign's recurring phrase
"the `ctx_` phase removes the prefill work" is false in both directions: the
`ctx_` phase does 89% as much prefill as the phase it was being compared
against, not none of it.

**1b. THE `ctx_pp`-VS-`pp` RATIO IS THE TOKEN COUNT AND NOTHING ELSE — MEASURED,
NOT ASSERTED.** R9b said the ~9x was `16384/2048`; the correction pass tested
that against every archived pair in `experiments/` where both phases were
measured in the same record. If the ratio is pure denominator it must equal
`(depth + 2048) / 2048` — Phase 1's charged tokens over Phase 2's, times the
12.5% extra real work Phase 2 does — with no free parameters:

Run over **every** `(depth, concurrency, response_size)` cell in the 18 archived
`consolidated.json` files where both phases were measured — 30 pairs, not a
sample:

| depth | pairs | observed `ctx_pp / pp` | predicted `(depth+2048)/2048` | residual |
|---:|---:|---:|---:|---:|
| 8192 | 1 | 5.18 | 5.00 | +3.6% |
| 16384 | 24 | 8.93 – 9.32 | 9.00 | −0.7% to +3.5% |
| 32768 | 1 | 17.20 | 17.00 | +1.2% |
| 65536 | 2 | 33.58, 33.77 | 33.00 | +1.7%, +2.3% |
| 131072 | 1 | 65.82 | 65.00 | +1.3% |

**29 of 30 pairs, five depths, every configuration the campaign ever ran, every
residual inside −0.7% to +3.6%.**

> **R13c EXTENDS THIS TO 35 OF 36 PAIRS, and adds the one dimension the audit
> lacked — the token budget.** Its six arms give six new `d16384` pairs at
> `mnbt` 8192 / 16384 / 32768 / 65536 / 98304 / 131072: `ctx_pp / pp` reads
> **9.21 / 9.11 / 9.12 / 9.23 / 9.58 / 9.20** against the same zero-free-parameter
> prediction of **9.00**, residuals **+1.2% to +6.4%**. The ratio is unmoved by a
> **16x** change in the scheduler's token budget, which is what a pure denominator
> artefact must do and what a real prefill effect could not. The 9.58 outlier is
> the arm whose `pp2048` carried one low draw, not a new phenomenon. The two phases prefill at the same rate to
within 4%; the small, almost always positive residual is Phase 1 being
marginally faster per token, which is the direction a pass with no decode setup
should go. **There is no prefill speedup anywhere in this campaign's data, at
any depth, and there never was.** The single exception is R13's c5 `ctx_pp`
(7.65, −15%), and it is a broken measurement rather than a counter-example: its
own σ is 817 on a median of 5175, sixteen times the dispersion of the c4 arm
beside it in the same invocation.

**This is also a second, independent instrument for finding 2 below.** Two of
the 30 pairs are R9b's **prefix-caching-OFF** arms, and they read 9.20 and
9.16 — indistinguishable from the caching-ON arms. Had the cache ever hit,
Phase 2 would have skipped 16384 of its 18432 tokens and the ratio would have
collapsed toward 1. It does not move at all. **The archives were carrying proof
that prefix caching never hits, in a column the campaign had been reading as
proof that it did.**

**2. PREFIX CACHING HAS NEVER HIT ON THIS BENCHMARK.** vLLM's own counter reads
`Prefix cache hit rate: 0.0%` in all 22 engine samples of R9's A1 and all 92 of
R10 — **with the flag ON**. Independently, total prompt tokens processed by the
engine (summed from vLLM's `Avg prompt throughput` windows) is **1,079,370 with
caching on against 1,060,925 with caching off** — 1.7% apart. **No prefill work
was ever saved.**

⚠ **R9c CORRECTED THE TWO FIGURES THIS PARAGRAPH USED TO CARRY — the "57%" and
the "2048x". Read this version.** The flag is worth **2.414x of `tg` at c4**
(146.32 ON vs 60.60 OFF, 14 runs re-measured inside **one** session; the 57% was
two 3-run medians four hours and one engine start apart), while
`peak_throughput` moves **0.7%** (287 vs 289) and `pp2048` moves 2.9%. The
decomposition closes exactly on `tg = c x tg_req / span`:

    tg ratio 2.415  =  tg_req ratio 1.160  x  span ratio 2.082
    log-share:  batch span 83%   per-request decode 17%

and the span was measured directly as within-batch ttfr dispersion: **1516 ms ON
vs 6269 ms OFF, 4.13x**.

**HOW THAT SITS WITH "THE CACHE NEVER HITS" — it is not a contradiction.** The
flag is not buying cache hits and is not buying hardware throughput; it is
buying a **shorter measurement window**, and the window is `tg_throughput`'s
denominator (R10, from the source). A flag can be worth 2.414x of a scheduling
measurement while saving zero prefill work, and this one does.

**The suspect was also wrong:** `mamba_block_size` goes **2144 → 32768 (15.3x)**,
not 16 → 32768 (2048x) — `platforms/interface.py:911-918` overwrites the 16, and
every archived engine log had been printing the real value. Moved from the only
legal side (`--block-size 32768`, caching ON), it explains **at most 42%** of the
span gap and brings a 2.03x decode penalty the caching-OFF arm does not have.
**The remainder is UNEXPLAINED**, and prefix caching, `mamba_cache_mode` and
`mamba_block_size` are **provably inseparable in this engine**, so it is a
source-reading task and not a benchmark. R9c is **DONE — do not re-queue it.**

**Planning consequence:** do not describe this campaign's `c>1` gains as "prefix
caching working". It is not working. What rides along with the flag is worth
**2.414x at c4, and 83% of that is the batch span** — so any margin restated in
terms of what produced it belongs to the span denominator, not to caching and
not to the hardware.

### WHAT IS WITHDRAWN — six claims, and none of them is a standing

Withdrawn, not adjusted. A comparison the denominator invalidates cannot be
rescued by rescaling it, and a mechanism whose premise is false does not get
patched into a smaller version of itself.

1. **"The `ctx_` phase is prefill-free, so it is ~9x faster at prefill."** — R1
   through R9b. **Withdrawn entirely.** The ratio is `(depth+2048)/2048`,
   measured to within 4% in 29 of 30 archived phase pairs. No `ctx_pp`-versus-`pp`
   comparison anywhere in this file or the journal is valid, at any depth or
   concurrency, and none is retained.
2. **"Removing the prefill removes the run-to-run variance."** — R1-R4. The
   campaign had already retired the *regularity* after it broke three times
   (R5, R6, R8). The *premise* is now gone too: no prefill is removed. The
   observation that some `ctx_` cells are quieter stands as an unexplained
   observation; the explanation is withdrawn.
3. **"The `ctx_` phase does no prefill, so it never staggers much"** — R10's
   mechanism for the ctx-vs-cold sign flip. **Withdrawn at the premise.** R12
   had already contradicted it with the instrument; it was false before it was
   contradicted.
4. **"Why does removing prefill work make the batch stagger WORSE?"** — R12's
   sharpened form of open question 4, inherited by the synthesis and by R13.
   **The question is dissolved, not answered.** It presupposes a removal that
   never happens. R13 refuted the regularity underneath it empirically at a
   third budget; the premise means there was never anything there to explain.
5. **"The ctx_ prefix-caching phases are the cheapest place in this campaign to
   measure a real effect."** — R3, quoted in this file for six rounds. Built on
   claims 1 and 2. **Withdrawn.**
6. **Open question 4 as posed — "do the ctx_ prefix-caching phases deserve
   their own tuning?"** They are not prefix-caching phases and there is no
   cached phase to tune: the cache never hits. The `ctx_` cells remain real,
   separately-ranked board cells worth winning; the question's framing is dead.

### WHAT SURVIVES, and why it survives

- **Every board margin, win and loss alike.** The board publishes `ctx_tg @ dN`
  and `ctx_pp @ dN` as their own test types and its entries come through the
  same llama-benchy CSV that ours do (R10 established the upload path). Both
  sides of every `ctx_` comparison are Phase 1 against Phase 1. A shared
  convention that is strange is still shared. **8 cells won, 12 lost, unchanged.**
- **Every `tg` comparison between the two phases.** Both phases decode the same
  128 tokens per request; the token-count error is confined to `pp_throughput`.
  Those figures keep their values and their signs — what changes is which one
  gets called cached, and the answer is neither.
- **R9b's broken validity gate, and it is now explained rather than merely
  confessed.** The gate demanded `ctx_pp2048 < 1200` with caching off and
  measured ~6100. Under the corrected reading the gate could never have passed
  at any setting: Phase 1 is charged 16384 tokens whether a cache exists or
  not, so its `pp` figure has an 8x floor built into the denominator. **The arm
  was right, the gate was arithmetically impossible, and overriding it on the
  engine's own counters was the correct call.**

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
| 4 | 5 | 8192 | 52.07 | 1.03% | 271 | 2.535 ⚠ | **R13c** (mutation, runs=7) — partial occupancy, span is a proxy only |
| 4 | 5 | 16384 | 85.90 | 2.08% | 277 | 2.048 ⚠ | **R13c** — partial occupancy, span is a proxy only |
| 4 | 5 | 32768 | 143.83 | 3.87% | 288 | 1.654 | **R13c** — full residency starts here |
| **4** | **5** | **65536** | **173.34** | 4.39% | **308** | **1.505** | **R13c — THE KNEE** |
| 4 | 5 | 98304 | 169.69 | 4.01% | 302 | 1.509 | **R13c** (R13 read 174.68; pooled 14-run **171.31**) |
| 4 | 5 | 131072 | 170.89 | 3.89% | 304 | 1.501 | **R13c** — nothing above the knee |

**R13c's six rows are the same cell at six token budgets and they are the only
place in this table where one variable moves alone.** Read down them: `tg` rises
+233% from 8192 to 65536 and then stops (−1.4% over the next two doublings). The
span ratio falls 2.535 → 1.505 and settles on a floor of ~1.50 that no further
budget touches. And the two thresholds separate: **residency** is full from 32768
up (`Running: 4, Waiting: 0` in every loaded sample), while the **span** keeps
tightening to 65536 with nothing waiting at either — so the last 9% of the ratio
is not admission, which is R13's `Waiting: 0` result confirmed from a second
direction.

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

> **⚠️ "CAMPAIGN CONFIG" AND "UNMUTATED" ARE PRE-FOLD TERMS EVERYWHERE BELOW
> THIS LINE.** They were written when `recipe.yaml` carried
> `max_num_batched_tokens: 8192`, and every archive row that uses them was
> measured at **mnbt 8192 + mns 4**. Since R11 folded `mnbt 65536` on
> 2026-08-22, `recipe.yaml` unmutated means **mns 4 + mnbt 65536** instead —
> a different engine. **No row below describes what the recipe now ships**
> unless it names `mnbt 65536` explicitly (only R11's own rows do). Reproducing
> any of them requires `-o max_num_batched_tokens=8192`.
>
> **The same holds for a row that names no configuration at all.** Most archive
> rows from R1–R9 name only the cell and the run count, because at the time
> there was one recipe and nothing to distinguish. **Read every such row as
> `mnbt 8192 + mns 4` — the pre-fold recipe.** A row is at a different budget
> only where it says so (`MUTATION mnbt …`, `mnbt 65536 = THE FOLDED RECIPE`).
> **And do not compare a number you measure on today's recipe to any of these
> rows** without either re-measuring the baseline in the same invocation at
> `-o max_num_batched_tokens=8192`, or stating the budget as an uncontrolled
> term — the budget is worth up to **+233%** at `c>1` (R13c) even though it is
> worth **+0.27%** at c1 (R11). See the epoch warning at the top of this file
> and the cross-condition rule in `journal.md`'s synthesis.

tg/pp columns are MEDIANS of the runs — means are not verdicts (MTP acceptance
is bimodal). σ is the run standard deviation, kept as the noise flag.
`ctx_` rows are **Phase 1 of the same run, the CONTEXT LOAD** — a separate board
cell, and the *uncached* pass. Rows without `ctx_` are Phase 2. Do not compare a
`ctx_pp` figure to a `pp` figure: they are charged different token counts. `tg`
figures may be compared across the two phases. See the phase-label correction.

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

**R5c CORROBORATION (2026-08-22, NO BOX TIME) — the source reading now has a
second, independent instrument behind it.** R5c was queued to settle this from
the board side; R10 settled it from llama-benchy's source first, so R5c re-tested
the *conclusion* against all **34 archived `c>1` benchmark records** in
`experiments/`. Three predictions the aggregate reading makes and the
per-request reading does not:

| prediction of the aggregate reading | result |
|---|---|
| `tg_throughput > tg_req_throughput` at every `c>1` point — they are different fields, not the same number | **34 / 34**, ratios 1.13x to 4.02x |
| `tg_throughput <= peak_throughput` always — an aggregate cannot exceed the sustained ceiling | **34 / 34**, no violations |
| `tg_throughput / tg_req_throughput <= c` always — the ratio is `c / stagger` and stagger >= 1 | **34 / 34**, no violations |

The per-request reading predicts `tg ≈ tg_req` at `c>1` and is refuted in every
single row. `c x tg_throughput` exceeds `peak_throughput` in **14 of 34** rows —
the double-count made visible — and all fourteen are low-stagger arms, which is
why the error hid until the raised-budget and c16 runs. **No board re-scrape was
needed and none was done. No verdict, margin or standing changes.**

One new methodology note falls out. `c / (tg/tg_req)` recovers R10's
timestamp-measured stagger to within a few percent at c2 and c4, and at c5 **only
when `max_num_seqs >= c`**. Where a request is excluded from residency (c5 at
`max_num_seqs 4`) the aggregate-derived proxy reads ~3.9 against R10's measured
~2.4. **The proxy is valid only at full residency** — read the scheduler's
`Running/Waiting` lines before trusting it.

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
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d16384 c1 | 129.32 | 18.38 | 3230.01 | 28.11 | **RETIRED — SUPERSEDED by R6's 7-run 116.43 (4.14x).** A lucky 3-run draw, 11% high. The standings carry 4.14x, not 4.60x |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d32768 c1 | 115.56 | 10.40 | 6937.09 | 23.31 | **RETIRED AS A STANDALONE FIGURE by R8c.** A 3-run draw, 5.4% above the 7-run re-measurement of its own condition (109.62). The cell is still a **WIN**; the standings now carry the **pooled 10-run 112.59 = 4.83x**, not 4.96x |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d8192 c1 | 126.52 | 7.94 | 1345.97 | 207.60 (LFM2.5-350M BF16) | **LOSS — 0.61x** vs the top, but **1.07x** over the best vLLM+NVFP4 entry (118.07, Nemotron-3.5-Lightning-30B-A3B-NVFP4). Board figure came from R5b's scrape and was never carried into the standings until the synthesis pass. ⚠ 3-run figure |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d16384 c1 | 130.16 | 3.01 | 2787.86 | 193.09 (LFM2.5-350M BF16) | **SUPERSEDED by R6's 7-run 122.97** — same cell, same instrument that retired R1's cold tg32 figure. The cell is a **LOSS at 0.64x**; runners-up 153.86 / 152.14 are our own model on Atlas |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d32768 c1 | 84.03 | 10.69 | 6453.91 | 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**) | **RETIRED BY R8c, AND IT WAS WRONG BY 28% — the campaign's largest single-figure retraction, and it went UPWARD.** A 3-run LOW draw; the identical condition at runs=7 reads **110.61**. The cell is still a **LOSS** but at **0.92x**, not 0.72x. It was also the campaign's last surviving deep ctx inversion (−27.3%) and **R8c retired that too**: +0.9% at runs=7 |
| bench_f58c56da6658 | 2026-08-21 | tg128 @ d16384 c4 | 53.56 | 0.43 | 10167.05 | 46.68 | win — 1.15x, verify required at this margin |
| bench_f58c56da6658 | 2026-08-21 | ctx_tg128 @ d16384 c4 | 56.40 | 0.16 | 8554.95 | 27.68 | win — 2.03x; board figure landed later in R5b's scrape, pooled with the verify run below |
| bench_f58c56da6658-verify | 2026-08-21 | tg128 @ d16384 c4 | 52.69 | 0.75 | 10151.35 | 46.68 | win CONFIRMED — pooled median of 6 runs 52.85 = 1.13x; worst single run 51.25 still +9.8% |
| bench_f58c56da6658-verify | 2026-08-21 | ctx_tg128 @ d16384 c4 | 55.92 | 0.62 | 8641.49 | 27.68 | **win — pooled median 56.36 = 2.04x** over the R5b-scraped incumbent |
| bench_dab043abba20 | 2026-08-21 | tg128 @ d65536 c1 | 108.15 | 10.41 | 17281.66 | 16.48 | **RETIRED — SUPERSEDED by R8's 7-run 94.10 (5.71x).** A lucky 3-run draw, 13% high, at a cell whose σ is 9.0%. The standings carry 5.71x, not 6.56x |
| bench_dab043abba20 | 2026-08-21 | ctx_tg128 @ d65536 c1 | 89.76 | 1.80 | 16377.23 | 20.70 | win — 4.34x; **SUPERSEDED by R8's 7-run 92.98 (4.49x)**, which is the claimed figure. First ctx_ cell with a known board figure. Phase 1, the context load — not a cached pass |
| bench_0ef7af8997ce | 2026-08-22 | tg128 @ d16384 c2 (mnbt 8192 — pre-fold recipe) | 84.00 | 1.18 | 5657.56 | 163.27 best vLLM NVFP4 (325.44 overall) | **LOSS — 0.51x** on the campaign config. Board figure landed in R5b's scrape after the run; scored by R10. ~~aggregate 168.0, 82% scaling efficiency vs c1~~ **WITHDRAWN — `per-request × c` double-counts an already-aggregate metric (R10, R5c).** R12 later read 140.77 (0.86x) at the raised budget |
| bench_0ef7af8997ce | 2026-08-22 | ctx_tg128 @ d16384 c2 | 79.44 | 1.06 | 4825.98 | not scraped | hold — BELOW cold (-5.4%), first below-cold ctx_ at this depth |
| bench_0ef7af8997ce | 2026-08-22 | tg128 @ d16384 c5 (max_num_seqs 4, mnbt 8192 — pre-fold recipe) | 45.60 | 0.26 | 11866.00 | 225.46 best vLLM NVFP4 (428.95 overall) | **LOSS — 0.20x.** Scheduler-limited: the fifth request queues, so this arm is not the cell's claimed figure (the `mns 5` row below is). ~~aggregate 228.0~~ **WITHDRAWN — double-counts (R10, R5c)** |
| bench_0ef7af8997ce | 2026-08-22 | ctx_tg128 @ d16384 c5 (max_num_seqs 4) | 48.18 | 0.31 | 9914.85 | not scraped | hold — above cold (+5.7%) |
| bench_858173ba5753-mns5 | 2026-08-22 | tg128 @ d16384 c5 (MUTATION max_num_seqs 5) | 48.12 | 0.07 | 12088.40 | 225.46 best vLLM NVFP4 (428.95 overall) | **LOSS — 0.21x**, and this is the cell's campaign-config-plus-`mns 5` figure in the standings. +5.5% over the unmutated arm; mutation NOT kept in recipe.yaml. R12 read 128.93 (0.57x) and R13 164.27 (0.73x) at raised budgets — still losses |
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
| bench_5399a85d7aec-a0 | 2026-08-22 | tg128 @ d16384 c4 (**arm A0 — mnbt 8192 + mns 4, the PRE-FOLD recipe, unmutated as of the run date**) | 52.64 | 0.58 | 10205.51 | 46.68 | hold — reproduces R2's pooled 52.85 to 0.4%. Same engine start as the c5 row below (`session_count: 1`). ~~Verdict NOT rewritten: units dispute (R5c) still open.~~ **R5c CLOSED 2026-08-22 — there was no dispute: the board reports the same aggregate field we do, so this row's 1.13x always compared like with like and the verdict stands unchanged.** **Engine log shows this cell never reaches full occupancy** — see the R9 occupancy note |
| bench_5399a85d7aec-a0 | 2026-08-22 | tg128 @ d16384 c5 (**arm A0 — mnbt 8192 + mns 4, the PRE-FOLD recipe, unmutated as of the run date**) | 45.05 | 0.28 | 11847.76 | 225.46 best vLLM NVFP4 | LOSS — 0.20x, and reproduces R4's campaign-config c5 figure. Read here as a control, not as the cell's claim. **D0 = -14.4% against the c4 row above, measured in ONE engine start**. R4 computed -13.7% across two invocations; the deficit is real and is not an engine-start artefact |
| bench_5399a85d7aec-a0 | 2026-08-22 | ctx_tg128 @ d16384 c4 (arm A0, mnbt 8192 — pre-fold recipe) | 54.98 | 0.19 | 8633.16 | not scraped | hold — ABOVE cold (+4.4%) |
| bench_5399a85d7aec-a0 | 2026-08-22 | ctx_tg128 @ d16384 c5 (arm A0, mnbt 8192 — pre-fold recipe) | 48.04 | 0.44 | 9840.74 | not scraped | hold — ABOVE cold (+6.6%); reproduces R4's 48.18 to 0.3% |
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
| bench_ac37f5b64487 | 2026-08-22 | ctx_tg128 @ d16384 c2 (MUTATION mnbt 32768 + mns 5, runs=7) | 127.09 | 4.01 | 5269.25 | not scraped | hold — BELOW cold (−9.7%), deepening the −5.4% the same cell shows at mnbt 8192. `peak_throughput` 167. **Stagger 1.17 — HIGHER than cold's 1.13**, and `tg_req` 74.45 is BELOW cold's 79.73, so Phase 1 is behind on both terms. ⚠ The "why does removing prefill work make the batch stagger worse?" question this row used to point at is **DISSOLVED** — Phase 1 removes no prefill work — and R13 refuted the regularity at mnbt 98304 anyway. The two numbers stand; the puzzle does not |
| bench_ac37f5b64487 | 2026-08-22 | tg128 @ d16384 c5 (**MUTATION mnbt 32768 + mns 5**, runs=7) | **128.93** | 2.34 | 14484.92 | 225.46 best vLLM NVFP4 (428.95 overall) | **LOSS — 0.57x, short by 43%**, but was 0.21x on the campaign config (48.12): **+168%**. First run of c5 with BOTH settings raised (R9's arm A1 had mnbt 32768 but `mns 4`, so the fifth request still queued for a slot; it read 81.73). `peak_throughput` **290**, up +9.4% on 265. **Stagger 1.70**; zero-stagger bound `5 × tg_req` = **218.60 = 0.97x of the incumbent**, so **93% of the residual gap is admission stagger and 7% is decode rate**. Residency 4.92 of 5. σ 1.81%. ttfr ROSE +19.8% |
| bench_ac37f5b64487 | 2026-08-22 | ctx_tg128 @ d16384 c5 (MUTATION mnbt 32768 + mns 5, runs=7) | 104.75 | 1.16 | 12731.35 | not scraped | hold — BELOW cold (−18.7%), a **SIGN FLIP** against the +6.5% the same cell shows at mnbt 8192, reproducing what R10 saw at c4 (+4.4% → −14.2%). `peak_throughput` 290. **Stagger 2.12 — HIGHER than cold's 1.70**, which contradicts R10's stated mechanism for the flip. ⚠ That mechanism ("Phase 1 does no prefill so it never staggers") is now **withdrawn at the premise**, not merely contradicted |

| bench_433eeaf9827e | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 98304 + mns 5**, runs=7) | **174.68** | 7.70 | 12101.77 | 46.68 | **WIN — 3.74x on these 7 runs; SUPERSEDED by the pooled 14-run 171.31 = 3.67x** (R13c re-ran this exact config and read 169.69). Up from 3.15x at mnbt 32768. `peak_throughput` **310**, span ratio 1.53, `tg_req` 66.76 (+15.5%), residency 3.88 of 4. σ 4.41%. ttfr WORSE again (+2.3% on R10) |
| bench_433eeaf9827e | 2026-08-22 | ctx_tg128 @ d16384 c4 (**MUTATION mnbt 98304 + mns 5**, runs=7) | **170.59** | 6.34 | 10517.21 | 27.68 | **WIN — 6.16x on these 7 runs; SUPERSEDED by the pooled 14-run 170.36 = 6.15x** (R13c re-ran this exact config and read 168.37). ⚠ **SUPERSEDED as the widest margin by R13d** — the mnbt 131072 pooled 14-run 171.77 = 6.21x. This row stays a win at 6.15x. Phase 1, the context load. `peak_throughput` 294, span ratio 1.45, `tg_req` 61.93, residency 3.95 of 4. σ 3.72%. BELOW Phase 2 (−2.3%), and it staggers LESS than Phase 2 — refuting R12's asymmetry |
| bench_433eeaf9827e | 2026-08-22 | tg128 @ d16384 c5 (**MUTATION mnbt 98304 + mns 5**, runs=7) | **164.27** | 5.40 | 15126.01 | 225.46 best vLLM NVFP4 (428.95 overall) | **LOSS — 0.73x, short by 27%**, up from 0.57x. The round's target cell, not taken. Against the cell top 428.95 it is **0.38x**. `peak_throughput` 303, span ratio 1.54, `tg_req` 50.50 (+15.5%), residency 4.81 of 5. σ 3.29% |
| bench_433eeaf9827e | 2026-08-22 | ctx_tg128 @ d16384 c5 (**MUTATION mnbt 98304 + mns 5**, runs=7) | 160.67 | 3.48 | 15552.29 | not scraped | hold — Phase 1. `peak_throughput` 314, span ratio 1.52, `tg_req` 48.73, residency 5.06 of 5. σ 2.16%. BELOW Phase 2 (−2.2%) |
| bench_9379c15468ec-a-chunk | 2026-08-22 | tg128 @ d16384 c4 (**R9b ARM A — prefix caching OFF, mnbt 32768, mns 4, chunked prefill ON**, runs=3) | 62.13 | 0.70 | 11559.86 | **NOT SCOREABLE** | diagnostic — three flags off the pre-fold campaign config (mnbt 8192), not a standings row. `peak_throughput` **297**, IDENTICAL to R9's A1 with caching ON, while `tg` falls **−56.6%** (143.08 → 62.13): the hardware ceiling did not move, the batch span did. ⚠ **The −56.6% is SUPERSEDED as the size of the effect** — it compares two 3-run medians across two engine starts four hours apart. R9c re-measured both endpoints at runs=7 inside one session: **146.32 vs 60.60 = 2.414x**, decomposed 83% span / 17% decode / 0.7% hardware. This row's *reading* (ceiling flat, span moved) is what R9c confirmed and sharpened; only its magnitude is retired. Stagger **3.32** vs A1's 1.62. `tg_req` 51.49 (−11.0%) |
| bench_9379c15468ec-a-chunk | 2026-08-22 | tg128 @ d16384 c5 (**R9b ARM A**, runs=3) | 50.28 | 0.81 | 12309.92 | **NOT SCOREABLE** | diagnostic — `peak_throughput` 298, `tg_req` 25.46, stagger 2.53, residency 3.77 of 5. Scheduler `(4,1)` in four samples, reproducing R9's direct observation at this cell |
| bench_9379c15468ec-a-chunk | 2026-08-22 | ctx_tg128 @ d16384 c4 (**R9b ARM A**, runs=3) | 70.90 | 0.56 | 10123 | **NOT SCOREABLE** | diagnostic — **and this row is the CONTEXT-LOAD pass, not a cached pass**: with prefix caching off there is no cache, and llama-benchy's `ctx_` phase was never the cached one anyway (see the phase-label correction above). `peak_throughput` 282 |
| bench_9379c15468ec-a-chunk | 2026-08-22 | ctx_tg128 @ d16384 c5 (**R9b ARM A**, runs=3) | 57.48 | 0.47 | 10760 | **NOT SCOREABLE** | diagnostic — `peak_throughput` 281 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | tg128 @ d16384 c4 (**R9b ARM B — prefix caching OFF, mnbt 32768, mns 4, chunked prefill OFF**, runs=3) | 52.92 | 0.83 | 9575.12 | **NOT SCOREABLE** | diagnostic — **the arm R9 could not start.** vs arm A: `tg` **−14.8%**, `tg_req` **−44.2%** (51.49 → 28.74), stagger IMPROVES 3.32 → **2.17**, ttfr IMPROVES **−17.2%**. Turning chunked prefill off halves per-request decode while tightening admission — it PROTECTS decode, it does not interfere. Scheduler sits at `(2,2)` in three of eight loaded samples and never holds a stable `(4,0)`. `peak_throughput` 285 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | tg128 @ d16384 c5 (**R9b ARM B**, runs=3) | 45.28 | 0.36 | 11115.00 | **NOT SCOREABLE** | diagnostic — vs arm A: `tg` −9.9%, `tg_req` −21.7%, stagger 2.53 → 2.20, ttfr −9.7%. `peak_throughput` 276, `tg_req` 19.92, residency 3.94 of 5 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | ctx_tg128 @ d16384 c4 (**R9b ARM B**, runs=3) | 58.80 | 0.16 | 8280 | **NOT SCOREABLE** | diagnostic — context-load pass. `peak_throughput` 269 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | ctx_tg128 @ d16384 c5 (**R9b ARM B**, runs=3) | 49.54 | 0.60 | 9645 | **NOT SCOREABLE** | diagnostic — `peak_throughput` 288 |

### R13c — the `max_num_batched_tokens` curve at c4, six invocations, `mns 5`, runs=7 each

Every row below is `tg128 @ d16384 c4` or its Phase-1 partner at one token
budget. Six separate engine starts, all `session_count: 1`, `crash_count: 0`.
Three of the six budgets re-measure a protected headline figure and the
reproduction gap is stated in the row.

| benchId | date | cell / probe | tg med t/s | tg σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| bench_0f4c34c12223-mnbt8192 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 8192 + mns 5**, runs=7) | 52.07 | 0.54 | 10217.01 | 46.68 | **WIN — 1.12x.** **PROTECTION POINT: reproduces R2's pooled 52.85 to −1.48%**, from a separate engine start at runs=7, so the campaign-config c4 win STANDS. `peak_thr` 271, span proxy 2.535, `tg_req` 33.00. σ **1.03%**. **Scheduler never holds full occupancy** — `(1,3)` x1, `(2,2)` x4, `(3,1)` x5 against `(4,0)` x9, reproducing R9's finding at this cell from a fourth engine start; the span figure is therefore a proxy only (R5c) and is not read as a physical stagger |
| bench_0f4c34c12223-mnbt8192 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 8192 + mns 5, runs=7) | 54.57 | 0.47 | 8697.44 | 27.68 | **WIN — 1.97x.** **PROTECTION POINT: reproduces 56.36 to −3.18%**, the largest of the six gaps, still well inside the ±10% band. Row STANDS at its claimed 2.04x. `peak_thr` 263. **ABOVE Phase 2 (+4.8%)** — the campaign-config sign |
| bench_fa5630a4ac79-mnbt16384 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 16384 + mns 5**, runs=7) | 85.90 | 1.79 | 11175.45 | 46.68 | **WIN — 1.84x.** New budget value, below the knee. `peak_thr` 277, span proxy 2.048, `tg_req` 43.99, σ 2.08%. **Occupancy still partial** — `(2,2)` x4 and `(3,1)` x5 against `(4,0)` x7, so 16384 does not admit this batch cleanly either |
| bench_fa5630a4ac79-mnbt16384 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 16384 + mns 5, runs=7) | 68.79 | 0.58 | 9798.00 | 27.68 | **WIN — 2.49x.** `peak_thr` 259. **BELOW Phase 2 by −19.9%, the deepest ctx-vs-Phase-2 gap in the campaign** and the minimum of that curve — see the budget-response note below |
| bench_10bd1b5f24ea-mnbt32768 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 32768 + mns 5**, runs=7) | 143.83 | 5.56 | 11858.59 | 46.68 | **WIN — 3.08x.** **PROTECTION POINT and the strongest of the six**: it sits between R9's arm A1 (143.08, `mns 4`, runs=3, **+0.5%**) and R10's 147.25 (`mns 16`, runs=7, **−2.32%**) — three measurements, three scheduler widths from 4 to 16, inside a 2.9% band. R10's row STANDS at 3.15x. `peak_thr` 288, span 1.654, `tg_req` 59.48. **`(4,0)` in 13/13 loaded samples** — full residency starts here |
| bench_10bd1b5f24ea-mnbt32768 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 32768 + mns 5, runs=7) | 125.74 | 3.23 | 10362.20 | 27.68 | **WIN — 4.54x.** **PROTECTION POINT: reproduces R10's 126.35 to −0.48%**, the tightest of the six. Row STANDS at 4.56x. `peak_thr` 283, span **1.848 — HIGHER than Phase 2's 1.654**, reproducing R12's asymmetry at this budget exactly |
| bench_0bd1f20dca74-mnbt65536 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 65536 + mns 5**, runs=7) | **173.34** | 7.60 | 12167.21 | 46.68 | **WIN — 3.71x, AND THIS IS THE KNEE OF THE CURVE.** New budget value. `peak_thr` **308**, span **1.505**, `tg_req` **65.24 — the highest of the six**, σ 4.39%. `(4,0)` 10/10. Statistically identical to mnbt 98304 and 131072 (top three span 2.1% against σ/med ~4%), so **this is the cheapest budget that reaches the ceiling and it is R11's fold value** |
| bench_0bd1f20dca74-mnbt65536 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 65536 + mns 5, runs=7) | 164.95 | 3.21 | 10562.91 | 27.68 | **WIN — 5.96x.** `peak_thr` 289, span 1.505 — identical to Phase 2's, the crossover point of the asymmetry |
| bench_d6cec044441c-mnbt98304 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 98304 + mns 5**, runs=7) | 169.69 | 6.81 | 12374.74 | 46.68 | **WIN — 3.64x on these 7 runs alone. PROTECTION POINT: reproduces R13's 174.68 to −2.86%**, so the row STANDS; because this is the SAME configuration, the two 7-run sets are **pooled to a 14-run median of 171.31 = 3.67x**, which is now the claimed figure. `peak_thr` 302, span 1.509, `tg_req` 64.02. `(4,0)` 11/11. ⚠ This arm's `pp2048` control missed its band — see the prefill rows |
| bench_d6cec044441c-mnbt98304 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 98304 + mns 5, runs=7) | 168.37 | 5.83 | 10573.68 | 27.68 | **WIN — 6.08x alone. PROTECTION POINT: reproduces R13's 170.59 to −1.30%**; pooled 14-run median **170.36 = 6.15x**. ⚠ **No longer the widest margin — R13d took the title with mnbt 131072's pooled 171.77 = 6.21x.** `peak_thr` 284, span 1.454 |
| bench_0509b2a740f6-mnbt131072 | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 131072 + mns 5**, runs=7) | 170.89 | 6.65 | 12207.83 | 46.68 | **WIN — 3.66x.** New budget value, above the knee: **−1.4% against mnbt 65536, i.e. doubling the budget twice past the knee buys nothing.** `peak_thr` 304, span 1.501, `tg_req` **64.14 — 1.0019x of the mnbt 98304 figure**, which is the round's discriminator and reads H_admission_decode. Engine start cost **310 s**, the only budget above the size trend |
| bench_0509b2a740f6-mnbt131072 | 2026-08-22 | ctx_tg128 @ d16384 c4 (MUTATION mnbt 131072 + mns 5, runs=7) | 175.40 | 6.93 | 10631.59 | 27.68 | **6.34x MEASURED, NEVER PROMOTED, and now RETIRED as the high draw it looked like.** R13d repeated this exact config and read 170.16 (−2.99%); the claimed figure for the cell is the **pooled 14-run 171.77 = 6.21x**. R13c's refusal to promote a single 7-run median at a once-measured config was correct — 6.34x would have been an overstatement of 2.1%. `peak_thr` 296, span 1.465. ABOVE Phase 2 (+2.6%) |
| **bench_0509b2a740f6-r13d** | 2026-08-22 | tg128 @ d16384 c4 (**MUTATION mnbt 131072 + mns 5**, runs=7) | 168.97 | 9.90 | 12847.72 | 46.68 | **WIN — 3.62x on these 7 runs; pooled 14-run 170.84 = 3.66x.** **R13d.** Rode along free with the ctx arm. Reproduces R13c's 170.89 to **−1.12%** — the eighth consecutive same-sign low reproduction, and the FIRST one of a figure nobody had promoted. `peak_thr` 307, span 1.517, `tg_req` 64.11, residency 3.99 of 4. **σ 5.86%, and the runs span 151.04–183.90** — the mode-plus-one-low-draw shape again |
| **bench_0509b2a740f6-r13d** | 2026-08-22 | ctx_tg128 @ d16384 c4 (**MUTATION mnbt 131072 + mns 5**, runs=7) | **170.16** | 3.59 | 11284.21 | 27.68 | **WIN — 6.15x on these 7 runs; pooled 14-run 171.77 = 6.21x, THE CAMPAIGN'S WIDEST MARGIN.** **R13d — the promotion test, and it moved the title by 0.83%**, which the round predicted in advance (band 168–174, centre 171.0; measured 171.77). `peak_thr` 296, span 1.440, `tg_req` 61.27. **`(4,0)` in 13/13 loaded samples with the span still at 1.44** — third confirmation that the span ratio is not admission. σ **2.11%**, against Phase 2's 5.86% in the SAME invocation — the σ ordering flipped against R13c's equal 3.95/3.89% at this identical config, so there is no ctx-vs-Phase-2 dispersion rule. ABOVE Phase 2 by +0.70%, same sign as R13c's +2.6% |

**The ctx-vs-Phase-2 sign is a budget response, not a rule.** Across the six
budgets it reads **+4.8% / −19.9% / −12.6% / −4.8% / −0.8% / +2.6%** — a smooth
curve with a minimum near 16384 that crosses zero twice. Every earlier round
sampled it at one or two budgets and read the local sign as a regularity, which
is why it has now "broken" six times. R12's stagger asymmetry gets the same
treatment: the `ctx_` phase staggers MORE than Phase 2 at 16384 and 32768
(2.464 vs 2.048; 1.848 vs 1.654), exactly as R12 found, and LESS at 65536, 98304
and 131072, exactly as R13 found. **Both rounds were right about their own budget
and wrong to call it a rule.** With the phase-label correction having dissolved
the question this asymmetry was posed to answer, no puzzle remains attached to
these numbers.

### R11 — the fold decision: the c1 anchor at the folded budget, one invocation, runs=7

The round that changed `recipe.yaml`. `mnbt 65536`, `mns 4` (the recipe's own
width — **one** mutation, not two), `session_count: 1`, `crash_count: 0`. Neither
row is a standing: `tg128 @ d16384 c1` is the crowded cell the campaign never
targeted, and the Phase-1 partner has no scraped incumbent. **Their job is to
show the fold does not move the baselines, and they do.**

| benchId | date | cell / probe | tg med t/s | tg σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| **bench_c9518e3e96a3-r11** | 2026-08-22 | tg128 @ d16384 c1 (**mnbt 65536 = THE FOLDED RECIPE + mns 4**, runs=7) | **112.92** | 9.05 | 3303.92 | 116.03 best vLLM NVFP4 (188.47 overall) | **THE FOLD ANCHOR — +0.27% on the 112.62 mnbt-8192 pooled anchor, i.e. nothing** (0.07 standard errors of the median). Pre-declared fold band 107.0–118.3; the pre-declared caution zone 117.2–118.3 was not entered. **NOT pooled with the anchor — different configuration.** 0.97x like-for-like, unchanged. `peak_throughput` **117.43 — identical to the last decimal to both R6's and R8's**, three engine starts and two budgets on one number. **`tg_throughput == tg_req_throughput` exactly**, so span ratio **1.000** by assignment (`results.py:195`) — there is no denominator here for the budget to shorten. Scheduler `(1,0)` in 4 of 4 loaded samples. ⚠ **σ/med 8.01%, the noisiest reading of this cell in the campaign** (2.6% R6 / 5.5% R8 / 8.01% R11) — runs span 91.92–118.65, mode-plus-low-draws |
| **bench_c9518e3e96a3-r11** | 2026-08-22 | ctx_tg128 @ d16384 c1 (**mnbt 65536 + mns 4**, runs=7) | 98.72 | 10.08 | 2851.19 | not scraped | hold — the second, independent inertness test, and it agrees. −4.15% on the 102.99 pooled Phase-1 anchor (R6 104.85 + R8 102.68), which is **0.89 standard errors** on a cell whose σ/med is **10.21%**: not a move, and inside its own pre-declared 96–110 band. `peak_throughput` 108.14. BELOW Phase 2 by −12.6% |

**What these two rows establish, and it is the whole point of the round.** The
token budget is a **scheduling** lever end to end, and at a concurrency of one
there is nothing to schedule: the two routes by which it has ever moved this
metric — **occupancy** (measured: `(1,0)`, residency 1 of 1 at any budget) and
**the span denominator** (measured: `tg == tg_req`, span exactly 1.000) — are
structurally absent. **`peak_throughput` reading 117.43 across three engine
starts and two budgets says the hardware ceiling at c1 does not know the flag
exists.**

**And it answers open question 13 at no extra cost.** R13 found `tg_req` rising
**+15.5% at both c4 and c5** on a budget change, and R13c curved it to **+98%**
across 8192 → 65536 at c4 — a *per-request* quantity moving with a scheduler
knob, measured only ever at `c>1`. At c1, `tg` **is** `tg_req` by assignment, so
this row measures that quantity with sharing removed. It moved **+0.27%**. If
even a tenth of the +98% were intrinsic to the request, c1 would have lifted
~10%. **The per-request rise at `c>1` is a sharing artefact — a request stalled
behind its neighbours' chunked prefills — and not a property of the request.**

**One prediction missed in an interesting direction.** R11 predicted `ttfr` would
**fall** at c1, on the argument that its six consecutive budget-driven rises were
all `c>1` effects (more neighbours admitted per step ⇒ a longer step before
anyone's first token) and that mechanism cannot apply with no neighbours.
Measured **3303.92 ms against 3237.23 / 3269.39** — it **rose**, by 1–2%, which
is 2.7–3.9 SE and therefore real. **Seventh consecutive budget increase, seventh
worse `ttfr`, and the first at a concurrency where the campaign's explanation for
it does not apply.** The magnitude argument survives (+1.6% here against +7.3% to
+32.4% at `c>1`, an order of magnitude), so most of the effect *is* a `c>1`
effect; what is left at c1 needs a smaller cause. Candidate, not a finding: at
65536 the whole 18432-token prefill runs in **one** scheduler step instead of
three, and a single 18432-token forward pass looks marginally less efficient per
token than three chunked ones — `pp2048` agrees in sign and size (−0.8%).

### R9c — the prefix-caching mechanism round: four arms, four engine starts, `mnbt 32768` + `mns 4`, runs=7 each

**CONFIGURATION BEHIND EVERY ROW BELOW, stated because the recipe changed under
this round:** `max_num_batched_tokens 32768` (**pinned by the arm recipes, NOT
the shipped 65536** — these arms deliberately reproduce R9/R9b's condition
across the R11 fold), `max_num_seqs 4`, `max_model_len 32768`, image
`dgx-vllm-eugr-nightly:2026082102`. Arms P and G run
`--enable-prefix-caching`; arm N runs `--no-enable-prefix-caching`; arm G adds
`--block-size 32768`. **All eight rows are NOT SCOREABLE** — two arms turn off a
flag the recipe ships and all four sit at a budget it does not. Recipes are
archived with each run as `recipe-r9c-*.yaml`.

**All four arms are under one session, within one hour, on one idle box** — the
round did not compare a post-fold number to a pre-fold row, it re-measured both
endpoints. `session_count: 1` and `crash_count: 0` in all four.

| benchId | date | cell / probe | tg med t/s | tg σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| **bench_30d6586cc70a-p-pc-on** | 2026-08-22 | tg128 @ d16384 c4 (**ARM P — prefix caching ON, `mamba_block_size` 2144**) | **146.32** | 4.17 | 11853.9 | **NOT SCOREABLE** | **THE CONTROL, AND IT REPRODUCES: +2.27% on R9 A1's 143.08** from a separate engine start four hours later. span ratio **1.607** (R9: 1.618, −0.7%), `tg_req` 58.78, `peak_thr` **287**, ttfr within-batch spread **1516 ms**. Scheduler `(4,0)` in **13 of 14** loaded samples — full residency. `Prefix cache hit rate: 0.0%` in 22 of 22 samples. ⚠ **The first same-cell repeat in the campaign to reproduce HIGH**, against a run of 8 low — see open question 8 |
| **bench_107f95223a60-n-pc-off** | 2026-08-22 | tg128 @ d16384 c4 (**ARM N — prefix caching OFF, `mamba_cache_mode none`, `mamba_block_size` 32768**) | **60.60** | 0.97 | 11762.1 | **NOT SCOREABLE** | **THE OTHER CONTROL, AND IT ALSO REPRODUCES: −2.46% on R9b arm A's 62.13.** span ratio **3.346** (R9b: 3.315), `tg_req` 50.68, `peak_thr` **289 — 0.7% from arm P's 287**, ttfr spread **6269 ms**. **So the prefix-caching effect is 146.32 vs 60.60 = 2.414x on 14 runs**, and the decomposition closes exactly: `tg` ratio 2.415 = `tg_req` ratio 1.160 x span ratio 2.082 — **83% batch span, 17% per-request decode**. ⚠ **NOT at full residency: `(3,1)` in 7 of 13 loaded samples** with 3.34M tokens of KV free, so this row is doing double duty as a queueing figure and the stagger proxy does not strictly hold on it |
| **bench_76bccce3d8b3-g-block32768** | 2026-08-22 | tg128 @ d16384 c4 (**ARM G — prefix caching ON + `--block-size 32768`, so `mamba_block_size` 32768**) | 54.05 | 0.77 | 9462.5 | **NOT SCOREABLE** | the first of two G runs. ⚠ **Its engine-log capture FAILED (three lines)** — see the repeat below and the journal's capture section. Gate evidence for this run rests only on its agreement with the repeat |
| **bench_76bccce3d8b3-g-block32768-repeat** | 2026-08-22 | tg128 @ d16384 c4 (**ARM G, repeat**) | **53.07** | 0.49 | 9514.3 | **NOT SCOREABLE** | **THE ROUND'S PRIMARY MEASUREMENT, AND IT LANDS OUTSIDE EVERY BAND THE HYPOTHESIS ALLOWED** — 53.07 against 60–80 under `H_gran` and 130–150 under `H_align`. **Pooled 14-run median with the run above: 53.46.** Reproduces run 1 at −1.81%; span ratio **2.184 vs 2.183 — identical to three decimals**. **`R_span` = 2.184/1.607 = 1.359, inside the pre-declared dead zone (confirm >1.70, refute <1.25), so `H_gran` is NEITHER CONFIRMED NOR REFUTED** and neither is claimed. **AND THE ARM IS CONFOUNDED:** `'block_size': 32768` took (gate passes, the `interface.py:911` 2144 line is absent) but KV capacity collapsed **3,071,735 → 395,264 tokens**, max concurrency 93.74x → **12.06x**, and residency fell to `(4,0)` in only **6 of 16** samples. Its loss decomposes as **70% per-request decode, 30% span** — the *opposite* shape to arm N's. `peak_thr` 286 passed its gate throughout, so **that gate does not detect a memory-layout change** |
| **bench_30d6586cc70a-p-pc-on** | 2026-08-22 | ctx_tg128 @ d16384 c4 (**ARM P**, Phase 1) | 123.92 | 0.90 | 10312.4 | **NOT SCOREABLE** | hold — Phase 1 partner. span ratio 1.827, `peak_thr` 280, ttfr spread 2005 ms |
| **bench_107f95223a60-n-pc-off** | 2026-08-22 | ctx_tg128 @ d16384 c4 (**ARM N**, Phase 1) | 70.91 | 1.82 | 10365.9 | **NOT SCOREABLE** | hold — reproduces R9b arm A's 70.90 to **0.01%**, the tightest cross-invocation agreement in the campaign after R11's `ctx_pp` pair. span ratio 2.728, `peak_thr` 286, ttfr spread 5066 ms |
| **bench_76bccce3d8b3-g-block32768** | 2026-08-22 | ctx_tg128 @ d16384 c4 (**ARM G**, Phase 1) | 58.65 | 0.56 | 8243.8 | **NOT SCOREABLE** | hold — span ratio 2.075, `peak_thr` 280, ttfr spread 6551 ms |
| **bench_76bccce3d8b3-g-block32768-repeat** | 2026-08-22 | ctx_tg128 @ d16384 c4 (**ARM G, repeat**, Phase 1) | 58.50 | 0.59 | 8281.9 | **NOT SCOREABLE** | hold — reproduces run 1 to **−0.26%**, span ratio 2.070 vs 2.075. The Phase-1 partner is the steadiest quantity in the round |

**What these rows are for, in one line:** they do not move a standing; they price
`--enable-prefix-caching` at **2.414x of the board metric, 83% of it batch span
and 0.7% of it hardware**, and they establish by source read that prefix caching,
`mamba_cache_mode` and `mamba_block_size` **cannot be varied independently in
this engine** — so open question 1's remaining half is a reading task, not a
benchmark.

⚠ **AND THE AUDIT THAT MATTERS FOR THE STANDINGS: no board margin in this file
was ever credited to prefix caching, so none has to be restated.** Every row that
varies the flag — R9's A1, both R9b arms, all eight R9c rows — is **NOT
SCOREABLE**, because turning the flag off is a mutation of the shipped recipe and
all of them sit at a budget the recipe does not ship. The 8 won / 12 lost
standings are measured with the flag **ON in every case**, i.e. entirely inside
the ON arm, where the 2.414x is a level and not a difference. What the
decomposition does change is **language, not arithmetic**: any sentence anywhere
that explains a `c>1` margin by "prefix caching" is wrong twice — the cache never
hits (R9b) and 83% of the flag's value is the batch-span denominator (R9c). The
margins themselves stand at exactly the recorded values.

### R13b — the span-ratio mechanism round: one engine start, `mnbt 98304` + `mns 5`, a probe of our own, 7 batches

**CONFIGURATION BEHIND EVERY ROW BELOW:** `max_num_batched_tokens 98304`
(**pinned by `-o`, NOT the shipped 65536**, to sit on R13's condition),
`max_num_seqs 5` (**NOT the shipped 4**), `max_model_len 32768`,
`gpu_memory_utilization 0.8`, image `dgx-vllm-eugr-nightly:latest`
(vLLM `0.27.2rc1.dev360+ge85d1b69c`), plus the instrument flag
`--per-request-spec-decode-metrics detailed`. Recipe:
`recipe-r13b-perreq.yaml`. Archive: `experiments/r13b-perreq-probe/`.

⚠️ **BOTH ROWS ARE NOT SCOREABLE, AND NOT ONLY FOR THE CONFIGURATION.** They were
not measured by llama-benchy. **There is no sparkrun benchId for this round** —
R13b ran no benchy grid, because the per-request metric it needed is delivered in
the HTTP response body and llama-benchy discards it. The numbers come from
`r13b-probe.py`, an independent client written from llama-benchy's source
(same corpus, same `PromptGenerator`, same payload, same throughput arithmetic
re-derived from `llama_benchy/results.py`). **They are quoted to establish that
the probe reproduces the cell, and for nothing else. No standing moves.**

⚠️ Each column is its own median over the 7 batches, so **the span column is the
median of the per-batch span ratios, not `5 x tg_req_median / tg_median`** — the
two differ by ~0.6% here. R13's row is built the same way; do not "correct" one
against the other.

| source | date | cell (configuration) | tg median | tg σ | tg_req median | span ratio | verdict |
|---|---|---|---|---|---|---|---|
| `r13b-perreq-probe` | 2026-08-22 | tg128 @ d16384 c5 (**mnbt 98304 + mns 5**, instrument flag, 7 batches, OUR CLIENT) | **167.14** | 11.20 | 49.76 | **1.499** | **NOT SCOREABLE — reproduction check only.** vs R13's benchy `bench_433eeaf9827e`: `tg` **+1.75%**, `tg_req` **−1.46%**, span **−2.63%**. The campaign's first cross-client reproduction |
| `r13b-perreq-probe` | 2026-08-22 | ctx_tg128 @ d16384 c5 (**mnbt 98304 + mns 5**, instrument flag, 7 batches, OUR CLIENT) | **161.68** | 5.13 | 46.72 | **1.439** | **NOT SCOREABLE.** vs R13: `tg` **+0.63%**, `tg_req` **−4.13%** — the round's one figure outside 3% |

**WHAT THE ROUND ESTABLISHED, which is a mechanism and not a row.** The span
ratio's ~1.50 floor is **prefill-completion stagger**, not admission stagger
(refuted R13) and not MTP acceptance dispersion (refuted here):

| quantity | reading |
|---|---|
| span ratio if MTP acceptance dispersion were the only term | **1.085** (vs 1.499 observed) — **17% of the excess** |
| per-request acceptance spread *within* one batch, max/min | **1.167** median, 35 requests, range 2.224–3.657 |
| `corr(start stagger, ms per verify step)` | **−0.980** (Phase 2), −0.986 (Phase 1) |
| `corr(verify steps, decode duration)` | **+0.142** — decode time is not set by step count |
| ms per verify step, **first** request to finish prefill | **88.5 ms** |
| ms per verify step, the other four in the same batch | **55.4 / 56.4 / 57.8 / 56.8 ms** |
| first-token spread across the batch | **1.26 s** median, on a clean decode of ~2.3 s |
| zero-parameter check `1 + 1.26/2.30` | **1.548** vs observed **1.499** |
| residency | **`Running: 5, Waiting: 0`** in 28 of 30 loaded samples |
| exact-length gate | **70 of 70** requests returned exactly 128 tokens |
| prefix cache hit rate | **0.0% in all 53 samples** — campaign total 374, seven budgets, zero hits ever |

⚠️ **The three terms are substitutes, not addends.** Removing the first-starter
penalty alone *raises* the span ratio to 1.634, because the span then passes to
the last starter. Do not quote a three-way percentage partition.

⚠️ **`recipe-r13b-perreq.yaml` IS AN INSTRUMENT, NOT A CANDIDATE.** It must never
be folded: `--per-request-spec-decode-metrics detailed` appends per verify step
and its overhead was never measured.


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
they sit higher because they are charged `depth` prompt tokens per request
against the Phase-2 rows' **2048**. The correction pass then measured the ratio
across all 18 archived pairs and it is `(depth+2048)/2048` to within 4%, at five
depths and with prefix caching both on and off. **The entire gap is the
denominator. Never compare a `ctx_pp` figure to a `pp` figure.** See the
phase-label correction above.

⚠️ **AND THE CORRECTION DOES NOT RESCUE THE PREFILL LOSSES — do not let a future
session think it does.** The obvious move on learning that `pp2048` is charged
2048 for `depth + 2048` tokens of real work is to rescale our figures by
`(depth+2048)/2048` and declare the losses void: at d32768 that would turn
295.71 into ~5027 against the best like-for-like vLLM entry's 4644.54, i.e. a
win. **That is wrong and it is the most dangerous available misreading of this
correction.** The board's prefill figures come through the same llama-benchy CSV
and carry the identical understatement, so the artefact cancels and the ratio of
ours to theirs is untouched. **The six prefill c1 cells remain losses, at
exactly the margins recorded above.**

What the correction *does* sharpen is the open mismatch question below: our
Phase-1 series **falls** with depth (6148.56 → 2803.17 over 16x) while the
board's `ctx_pp` incumbents **rise** (775123 → 945271 over 4x). Ours is a real
prefill rate against a real token count and attention makes it fall. Theirs
cannot be the same quantity behaving the same way. That is a shape disagreement
on top of the ~150x magnitude one, and it is evidence for a definition mismatch
rather than against it.

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
| bench_076db52d341c | 2026-08-22 | ctx_pp2048 @ d131072 c1 | 2803.17 | 2.43 | 46770.69 | not scraped | hold — 0.70x of d65536, the steepest fall in the **Phase-1 (context-load)** prefill series. This series is the campaign's only honest prefill-rate curve: Phase 1 is charged the tokens it actually processes, so 6148.56 / 5910.22 / 5086.51 / 4013.59 / 2803.17 is the real prefill rate against depth. The `pp2048` series is the same physics divided by a fixed 2048 |
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
| bench_433eeaf9827e | 2026-08-22 | pp2048 @ d16384 c4 / c5 (**MUTATION mnbt 98304 + mns 5**, runs=7) | 676.40 / 676.14 | 13.25 / 5.86 | 12101.77 / 15126.01 | not scraped | hold — **R13 SESSION CONTROL PASSES**: both within 0.2% of R12's 677.44, the raised-budget plateau. This is what licenses reading R13's tg figures as budget effects |
| bench_433eeaf9827e | 2026-08-22 | ctx_pp2048 @ d16384 c4 / c5 (**MUTATION mnbt 98304 + mns 5**, runs=7) | 6222.20 / 5175.31 | 26.51 / **817.16** | 10517.21 / 15552.29 | not scraped | hold — Phase 1. The c4 figure gives `ctx_pp/pp` = **9.20** against the predicted 9.00, in line with the other 17 records. **The c5 figure is a BROKEN MEASUREMENT and is not used**: σ 817 on a median of 5175 is 15.8%, twenty times the c4 arm's, and its ratio (7.65) is the only outlier in the campaign's 18 pairs. Recorded, not quoted |
| bench_9379c15468ec-a-chunk | 2026-08-22 | pp2048 @ d16384 c4 (**R9b ARM A — prefix caching OFF, chunk ON, mnbt 32768**) | 663.93 | 0.75 | 11559.86 | **NOT SCOREABLE** | diagnostic — matches R9's A1 (669.28) to **0.8%** with prefix caching OFF, so the flag buys nothing in prefill. Session control passes |
| bench_9379c15468ec-a-chunk | 2026-08-22 | pp2048 @ d16384 c5 (**R9b ARM A**) | 597.78 | 4.26 | 12309.92 | **NOT SCOREABLE** | diagnostic — **`D_pp` = −9.96%** against the c4 row. R4's c5 depression REPRODUCES with prefix caching off |
| bench_9379c15468ec-a-chunk | 2026-08-22 | ctx_pp2048 @ d16384 c4 / c5 (**R9b ARM A**) | 6106.93 / 5379.73 | 16.60 / 16.34 | — | **NOT SCOREABLE** | diagnostic — **these figures broke the round's validity gate and the gate was wrong, not the arm.** They are the CONTEXT-LOAD pass, charged 16384 tokens per request against the cold rows' 2048, so the ~9x is `16384/2048` and not a cache effect. `Prefix cache hit rate: 0.0%` in all 22 engine samples |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | pp2048 @ d16384 c4 (**R9b ARM B — prefix caching OFF, chunk OFF, mnbt 32768**) | 655.82 | 1.48 | 9575.12 | **NOT SCOREABLE** | diagnostic — within 1.2% of arm A, so removing chunked prefill does not move the prefill rate at c4 |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | pp2048 @ d16384 c5 (**R9b ARM B**) | 584.04 | 1.24 | 11115.00 | **NOT SCOREABLE** | **THE ROUND'S PRIMARY MEASUREMENT. `D_pp` = −10.95%**, against arm A's −9.96% — so `R_pp` = **1.099**, above the pre-declared 0.60 refutation threshold and pointing the WRONG WAY. **R4's chunked-prefill mechanism is REFUTED**: the c5 prefill deficit survives, slightly enlarged, in an engine that physically cannot chunk a prefill into a decode step |
| bench_10496035f7fd-b-nochunk | 2026-08-22 | ctx_pp2048 @ d16384 c4 / c5 (**R9b ARM B**) | 6008.87 / 5262.09 | 4.74 / 19.00 | — | **NOT SCOREABLE** | diagnostic — context-load pass, within 1.6% / 2.2% of arm A |
| bench_0f4c34c12223-mnbt8192 | 2026-08-22 | pp2048 @ d16384 c4 (**R13c, MUTATION mnbt 8192 + mns 5**) | 638.04 | 1.31 | 10217.01 | not scraped | hold — **SESSION CONTROL PASSES** inside the campaign-config 623-643 series, at its tenth invocation |
| bench_fa5630a4ac79-mnbt16384 | 2026-08-22 | pp2048 @ d16384 c4 (**R13c, MUTATION mnbt 16384 + mns 5**) | 659.21 | 3.82 | 11175.45 | not scraped | hold — **SESSION CONTROL PASSES**, in the raised-budget plateau |
| bench_10bd1b5f24ea-mnbt32768 | 2026-08-22 | pp2048 @ d16384 c4 (**R13c, MUTATION mnbt 32768 + mns 5**) | 670.76 | 2.49 | 11858.59 | not scraped | hold — **SESSION CONTROL PASSES** |
| bench_0bd1f20dca74-mnbt65536 | 2026-08-22 | pp2048 @ d16384 c4 (**R13c, MUTATION mnbt 65536 + mns 5**) | 671.68 | 2.13 | 12167.21 | not scraped | hold — **SESSION CONTROL PASSES** |
| bench_d6cec044441c-mnbt98304 | 2026-08-22 | pp2048 @ d16384 c4 (**R13c, MUTATION mnbt 98304 + mns 5**) | **645.90** | **38.43** | 12374.74 | not scraped | ⚠ **SESSION CONTROL MISSES its pre-declared 655-690 band by 1.4%, and the declared consequence was NOT applied — see the argument in the journal.** The miss is one low draw (runs 556.89 / 627.74 / 636.74 / 645.90 / 661.85 / 676.11 / 678.13, the mode-plus-one-low-draw shape R8 and R12 documented); the same arm's `ctx_pp` reads 6189.65 against R13's 6222.20, **0.5%**, and `ctx_pp` is the same physics charged 16384 tokens instead of 2048; the arms either side of it passed; telemetry passed. **The gate was built from seven historical point estimates without pricing their dispersion and was too tight — recorded as a broken gate, the campaign's second after R9b's `ctx_pp2048 < 1200`.** Future rounds should gate on `ctx_pp` |
| bench_0509b2a740f6-mnbt131072 | 2026-08-22 | pp2048 @ d16384 c4 (**R13c, MUTATION mnbt 131072 + mns 5**) | 670.32 | 25.06 | 12207.83 | not scraped | hold — **SESSION CONTROL PASSES** |
| **bench_0509b2a740f6-r13d** | 2026-08-22 | pp2048 @ d16384 c4 (**R13d, MUTATION mnbt 131072 + mns 5**) | 636.99 | **3.59** | 12847.72 | not scraped | hold — inside the 610–690 band R13d recorded it against (it was **not** gated, per R13c's finding that this gate was too tight). Reproduces R13c's 670.32 to −5.0%, and its σ collapses from 25.06 to 3.59 |
| **bench_0509b2a740f6-r13d** | 2026-08-22 | ctx_pp2048 @ d16384 c4 (**R13d**, Phase 1) | 5781.15 | 136.29 | — | not scraped | ⚠ **THE REPLACEMENT GATE MISSED ON ITS FIRST OUTING.** R13c declared `ctx_pp` the session gate after `pp2048` broke its own; R13d predicted 5900–6400 from R13c's single 6163.69 and measured **5781.15 — low by 2.0%**. Not a broken instrument: this is a −6.2% move whose σ fell from 416.60 to 136.29, so the two arms disagree about dispersion as much as level. **Widen the `ctx_pp` gate to ±10% — the band the protection points use — or stop calling it a gate.** Phase pair: `ctx_pp / pp` = **9.08** against the prediction 9.00, residual +0.9%; the phase-label audit now stands at **36 of 37 pairs** |
| R13c, all six arms | 2026-08-22 | ctx_pp2048 @ d16384 c4 (Phase 1) | 5875.22 / 6007.70 / 6117.63 / 6200.01 / 6189.65 / 6163.69 | 25.63 / 19.47 / 15.42 / 17.79 / 172.99 / 416.60 | — | not scraped | hold — Phase 1, at mnbt 8192 / 16384 / 32768 / 65536 / 98304 / 131072. **Six new phase pairs for the phase-label correction**: `ctx_pp / pp` reads 9.21 / 9.11 / 9.12 / 9.23 / 9.58 / 9.20 against the zero-free-parameter prediction `(16384+2048)/2048` = **9.00**, residuals **+1.2% to +6.4%**, the 9.58 being the arm with the depressed `pp` draw. The correction pass's 29-of-30 result now stands at **35 of 36 pairs**, and these six add a token-budget dimension it did not have |


### R11 — the prefill rows at the folded budget, c1

| benchId | date | cell / probe | pp med t/s | pp σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| **bench_c9518e3e96a3-r11** | 2026-08-22 | pp2048 @ d16384 c1 (**mnbt 65536 = THE FOLDED RECIPE + mns 4**, runs=7) | 629.78 | 5.32 | 3303.92 | 99229 (Atlas) — 637.09 is our own pre-fold figure | **LOST as a cell** at the recorded ~0.006x margin, unchanged and unaffected by the fold. Read here as the **session control, and it PASSES**: 629.78 sits inside the flat **623–643** d16384 series held across nine invocations, so the round's `tg` readings are not sitting on a slow session. −0.8% against R6's 634.99 — the same small negative sign as the `ttfr` rise, and the two together are the (unproven) candidate for why one 18432-token prefill step is marginally worse than three chunked ones |
| **bench_c9518e3e96a3-r11** | 2026-08-22 | ctx_pp2048 @ d16384 c1 (**mnbt 65536 + mns 4**, runs=7, Phase 1) | **5853.81** | 80.38 | 2851.19 | 884765 (Atlas) | **LOST as a cell**, unchanged. **THE SESSION GATE, WIDENED TO ±10% PER R13d — AND IT PASSES COMFORTABLY.** Predicted 5270–6440; measured 5853.81, which reproduces R6's 5849.11 to **0.09%** and R8's 5856.93 to **0.05%** — the tightest cross-invocation reproduction of any quantity in the campaign. **R13d's advice to widen this gate rather than abandon it was correct**, and this is its first clean outing. Phase pair: `ctx_pp / pp` = **9.295** against the zero-free-parameter prediction `(depth+2048)/2048 = 9.00`, residual **+3.3%** — the **38th** archived pair and the first at c1 above mnbt 8192, so the phase-label audit now stands at **37 of 38 pairs across five depths, eight token budgets and five concurrencies** |

### R9c — the prefill rows, four arms at `mnbt 32768` + `mns 4`

Same configuration caveat as the R9c generation rows above: `mnbt 32768`
(**pinned, not the shipped 65536**), `mns 4`, `max_model_len 32768`, image
`2026082102`; arms P and G with `--enable-prefix-caching`, arm N without; arm G
adds `--block-size 32768`. **NOT SCOREABLE**, read as session controls.

| benchId | date | cell / probe | pp med t/s | pp σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| **bench_30d6586cc70a-p-pc-on** | 2026-08-22 | pp2048 @ d16384 c4 (**R9c ARM P — prefix caching ON**) | 671.62 | 1.49 | 11853.9 | **NOT SCOREABLE** | **SESSION CONTROL PASSES** — within 0.35% of R9 A1's 669.28 and 0.13% of R10's 672.59, i.e. squarely in the raised-budget plateau. This is what licenses reading arm P's `tg` as a real reproduction rather than a fast session |
| **bench_107f95223a60-n-pc-off** | 2026-08-22 | pp2048 @ d16384 c4 (**R9c ARM N — prefix caching OFF**) | 651.95 | 1.78 | 11762.1 | **NOT SCOREABLE** | **SESSION CONTROL PASSES**, −1.8% on R9b arm A's 663.93 at the identical engine config. **The prefill rate moves 2.9% between arms P and N while `tg` moves 141% — so the flag buys nothing in prefill and the whole of its `tg` effect is downstream of prefill work**, which is the same conclusion R9b reached from a 0.8% gap |
| **bench_76bccce3d8b3-g-block32768** | 2026-08-22 | pp2048 @ d16384 c4 (**R9c ARM G — `--block-size 32768`**) | 665.69 | 1.37 | 9462.5 | **NOT SCOREABLE** | hold — **within 0.9% of arm P despite an 87% KV-capacity collapse.** Prefill is insensitive to the block size; the arm's damage is entirely in decode and residency |
| **bench_76bccce3d8b3-g-block32768-repeat** | 2026-08-22 | pp2048 @ d16384 c4 (**R9c ARM G, repeat**) | 662.34 | 1.65 | 9514.3 | **NOT SCOREABLE** | hold — reproduces run 1 to −0.50%. Four arms spanning three `mamba_block_size` values and both settings of the flag land in **651.95–671.62, a 3.0% band** |
| R9c, all four arms | 2026-08-22 | ctx_pp2048 @ d16384 c4 (Phase 1) | 6157.16 / 5958.00 / 6091.48 / 6059.13 | 14.64 / 26.68 / 15.19 / 6.53 | — | **NOT SCOREABLE** | hold — Phase 1, arms P / N / G1 / G2. **Four new phase pairs for the phase-label correction**: `ctx_pp / pp` reads **9.167 / 9.139 / 9.151 / 9.148** against the zero-free-parameter prediction `(16384+2048)/2048` = **9.00**, residuals **+1.5% to +1.9%** — the tightest cluster of four in the audit, and the first taken at three different `mamba_block_size` values and both settings of prefix caching. **The audit now stands at 41 of 42 pairs.** That the ratio is invariant to the flag is itself evidence the two phases differ by token count and not by caching |
| **bench_2b0f7bc8fb7b-mnbt8192** | 2026-08-22 | tg32 @ d32768 c1 (**R8c ARM E — pre-fold replica, mnbt 8192 + mml 40960**, runs=7) | **109.62** | 17.34 | 7042.4 | 23.31 | **WIN — 4.70x, and the PROTECTION POINT for this cell.** Reproduces R1's 115.56 at **−5.14%**, inside the ±10% band declared before the run → **row STANDS**, pooled 10-run median **112.59 = 4.83x**. Runs 93.54 / 95.01 / 106.57 / 109.62 / 120.65 / 122.97 / 142.85, **σ/med 15.82%**. Residency `(1,0)` in 9 of 9 loaded samples; `tg == tg_req` exactly, span **1.0000** |
| **bench_2b0f7bc8fb7b-mnbt8192** | 2026-08-22 | ctx_tg32 @ d32768 c1 (R8c ARM E, Phase 1) | **110.61** | 13.03 | 6478.9 | 117.37 (Atlas) / 116.65 (best vLLM) | **LOSS — 0.94x**, up from a recorded 0.72x. **FAILS its ±10% protection band by +31.64%**, upward — R1's 84.03 was a low draw and had never been re-measured in eleven rounds. Runs 93.44 / 106.30 / 109.16 / 110.61 / 118.65 / 124.81 / 133.06, σ/med 11.78%. **Phase 1 vs Phase 2 = +0.9%**, against R1's −27.3%: the campaign's last deep ctx inversion, retired |
| **bench_964a188f3d16-mnbt65536** | 2026-08-22 | tg32 @ d32768 c1 (**R8c ARM F — the FOLDED recipe, mnbt 65536 + mml 40960**, runs=7) | **110.03** | 26.63 | 6794.9 | 23.31 | **WIN — 4.72x, and the current-epoch row for this cell.** Against arm E's 109.62 the 8x budget change moves it **+0.37%**, reproducing R11's **+0.27%** at d16384 — **the token budget is inert at c1 at a second depth**, and this is the stiffer test (5 admission steps vs 1, where R11's was 3 vs 1). ⚠ **σ/med 24.20%, the noisiest cell in the campaign** — runs 75.36 / 91.92 / 108.73 / 110.03 / 137.07 / 141.52 / 144.99. `peak_thr` 153.08 |
| **bench_964a188f3d16-mnbt65536** | 2026-08-22 | ctx_tg32 @ d32768 c1 (R8c ARM F, Phase 1) | **117.65** | 11.11 | 6225.3 | 117.37 (Atlas) / 116.65 (best vLLM) | ⚠ **1.002x — A DEAD HEAT, NOT CLAIMED, cell scored a LOSS.** +0.24% is **0.06 SE** at σ/med 9.44%, and this is the only measurement of the cell at this budget; per R13c's rule a single 7-run median at a config measured once is not a claim. Runs 103.57 / 111.93 / 116.47 / 117.65 / 119.83 / 124.18 / 139.43. +6.36% over arm E is **1.0 SE**, so Phase-1 budget inertness is **NOT established** here. **Queued for a protection round at BOTH budgets** — 125-entry cell, now the closest unclaimed cell in the campaign |
| R8c, both arms | 2026-08-22 | ctx_pp2048 @ d32768 c1 (Phase 1) | 5068.43 / 5275.26 | — | — | **NOT SCOREABLE** | hold — Phase 1, arms E / F. **Phase pairs 43 and 44 of the phase-label audit**: `ctx_pp / pp` reads **17.396** and **17.468** against the zero-free-parameter prediction `(32768+2048)/2048` = **17.00**, residuals **+2.3%** and **+2.8%**. **The audit stands at 43 of 44.** Both are at d32768 and arm F is the first there above the old budget; the ratio is unmoved by an 8x budget change, which is what a pure denominator artefact must do |
| R8c, both arms | 2026-08-22 | MTP acceptance @ d32768 c1 (engine log) | length **3.61** / **3.67**; rate **87.0%** / **88.9%** | — | — | **NOT SCOREABLE** | hold — **the missing middle point of open question 3, taken at TWO independent engine starts** and reproducing each other to 1.7% / 2.2%. Against R5's 93.6% at d16384 and 47.7% at d131072 the decay is **gentle to d32768 and collapses beyond it**. ⚠ **This does NOT close open question 3** — the endpoints are R5's, from other invocations; only the middle point is controlled. R8b's two-depths-one-start design is still the measurement that closes it. Prefix cache hit rate **0.0% in 12/12 and 11/11 samples** — 23 more, campaign run now past 180 with no hit ever |

### R21 — the three-run audit, two arms, both reproducing a pre-fold row's own configuration

Both arms ran `-o max_num_batched_tokens=8192` to restore the **pre-fold** budget
(the recipe ships 65536 since R11), plus the row's original `max_model_len`
override. Image `2026082102`, framework 0.4.0, `mns 4`, **one session and
`crash_count 0` per arm**. Every figure below is `c1`, where `tg == tg_req` by
assignment and the span is **1.000**, so no `c>1` reporting applies.

| benchId | date | cell / probe | tg med t/s | tg σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---|
| **bench_deb3090b9a29-r21-armA** | 2026-08-22 | tg128 @ d131072 c1 (**R21 ARM A — R5's condition, mnbt 8192 + mml 139264**, runs=7) | **81.32** | 8.59 | 47931.4 | 81.60 (Nemotron Lightning NVFP4) | ⚠ **LOSS — but 0.995x, not the recorded 0.95x.** Reproduces R5's 77.13 at **+5.43%**, inside the ±10% band declared before the run → **row STANDS**, pooled 10-run median **81.22**. **The recorded deficit was overstated by a factor of ten: 0.47%, not 5.5% — and 0.47% is 0.11 SE** at σ/med 10.56%. A dead heat we are on the wrong side of; **NOT claimed as a win**, exactly as R8c declined the 1.002x. Runs 63.56 / 79.20 / 81.12 / 81.32 / 83.59 / 88.93 / 92.89. ⚠ **Do not re-run** — 0.11 SE is unresolvable at any affordable budget and this depth costs 784 s of grid for seven runs |
| **bench_deb3090b9a29-r21-armA** | 2026-08-22 | ctx_tg128 @ d131072 c1 (R21 ARM A, Phase 1) | **78.38** | 8.99 | 46629.9 | never scraped | hold — **+2.24%** on R5's 76.66, inside the band → stands, pooled 10-run **77.52**. Runs 61.33 / 70.01 / 76.22 / 78.38 / 84.25 / 85.86 / 88.94. **Phase 1 vs Phase 2 = −3.62%** against R5's −0.61% on three runs |
| **bench_6921c874daee-r21-armB** | 2026-08-22 | tg32 @ d8192 c1 (**R21 ARM B — R1's d8192 leg, mnbt 8192 + mml 40960**, runs=7) | **123.81** | 16.31 | 1783.3 | sole entry, no number published | ⚠ **R1's 3-run 106.24 is RETIRED — it was 16.54% LOW.** **FAILS the ±10% band, upward**, so the figures are **NOT pooled** and this replaces it outright. Runs 99.04 / 112.49 / 118.58 / 123.81 / 125.59 / 140.64 / 152.31, σ/med 13.18%. Was the **worst-sampled row in the standings** (R1 σ/med 21.4%, a 1.76x spread inside one cell). **Uncontested cell — no margin moves either way**, which is why it was the round's third priority and not its first |
| **bench_6921c874daee-r21-armB** | 2026-08-22 | ctx_tg @ d8192 c1 (R21 ARM B, Phase 1) | **128.76** | 10.66 | 1358.5 | 207.60 (LFM2.5-350M BF16) / 118.07 (best vLLM+NVFP4) | ✅ **STANDS — the round's smallest correction, +1.77%** on R1's 126.52, and **the thin published claim survives**: pooled 10-run **127.64** is **1.08x** over best vLLM+NVFP4, up from 1.07x. Loss to the cell top unchanged at **0.615x** — 207.60 was never in play. Runs 112.87 / 118.11 / 121.39 / 128.76 / 129.32 / 138.12 / 145.91. **Phase 1 vs Phase 2 = +4.00%**, against R1's **+19.1%** — the last unaudited extreme in the phase-pair table, collapsed |
| R21, both arms | 2026-08-22 | pp2048 / ctx_pp2048 @ d131072 and d8192 c1 | 42.74 / 2811.63 · 1158.52 / 6101.75 | 0.01 / 1.76 · 19.25 / 77.66 | — | **NOT SCOREABLE** | **INSTRUMENT CHECK — ARM A PASSES CLEANLY.** The hypothesis named the two near-zero-σ d131072 `pp` figures as the round's control: they moved **+0.35%** and **+0.30%** on R5's 42.59 and 2803.17, so Arm A reproduces R5's invocation and its `tg` verdict is trustworthy. Arm B's `pp2048` at **−2.44%** on R1's 1187.51 sits on the campaign's known ~2% reproduction floor (R13c's six-of-six −1.94%); its Phase-1 partner moved −0.76% |

**Read these four `tg` rows together and the round's finding is visible in the
sign column: every one moved UP.** With R8c's +31.64% that is five consecutive
upward corrections of rows nobody was auditing, against five consecutive downward
corrections of rows somebody was defending. See *the rows still on three runs*.
