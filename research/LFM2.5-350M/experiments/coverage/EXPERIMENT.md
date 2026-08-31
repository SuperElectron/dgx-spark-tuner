# coverage — take the board cells the official profile never measures

## Objective

**Placement, not throughput.** No recipe field is under test here. The question
is how many near-empty board cells our already-validated `slots` winner would
place top-3 in, if the same config were run over a grid the official profile
does not cover.

The official `@official/spark-arena-v2` profile measures **`tg128` and `pp2048`
only**. The board also ranks `tg32`, `pp4096`, `ctx_tg` and `ctx_pp`. Live
sweep of all 167 existing cells, `generatedAt 2026-08-30T18:30:17Z`:

    tg32,  every depth, c1/c2/c5/c10   28 cells   27 hold exactly ONE entry
                                                  (Qwen3.6-27B-PrismaSCOUT-
                                                  Blackwell-NVFP4, submitted
                                                  2026-05-21, 0.6-61.4 t/s)
    tg32 (c1) @ d0                      1 cell    6 entries, rank-3 bar 50.09
    pp4096, d0/d16384/d32768, c1/c2/c4  9 cells   2 entries, 1399-1503 t/s
                                                  (DeepSeek-V4-Flash-0731-REAP
                                                  twice, 2026-08-15)

The grid is `profiles/arena-tg32-pp4096.yaml`: 20 grid points, `pp 4096`,
`tg 32`, depth [0, 4096, 8192, 16384] × concurrency [1, 2, 4, 5, 10]. Each
point yields one `tg32` figure and one `pp4096` figure, so the grid touches 40
board cells. The Objective is scored on the `tg32` metric, one per grid point.

**Target: at least 16 of the 20 grid points would rank ≤3 board-wide on `tg32`
against the live board figures.**

Sixteen, not twenty, because sixteen is the number that can be scored at all.
The board's `tg32` cells exist at c1/c2/c5/c10; our four c4 points have no live
`tg32` cell to be compared against and are excluded from the count rather than
counted as free wins. Of the sixteen that remain, fifteen sit in fields of one
— any valid figure is rank 1 or 2 there — and the sixteenth, `tg32 (c1) @ d0`,
has a rank-3 bar of 50.09. So a miss means a cell that produced no figure, or a
figure that collapsed, not a cell we were narrowly outrun in.

Secondary, riding along at no extra cost: 6 of the 9 `pp4096` cells (d0 and
d16384 at c1/c2/c4). A field of two means any third entry is top-3 by
arithmetic.

**Reached when** every grid point has a figure and the count of points that
would rank ≤3 is stated against a board read no older than the run.

Honesty about what "would rank" means: this is **Phase A**, a screen. It
produces our own figures, not board figures. A board rank comes from a
submitted grid, and Mat submits. Every placement claimed here is a
**prediction** — it crosses no epoch boundary check against the competitors'
images, and it is what recommends a submission, never a substitute for one.

## Strategy

**The argument is field size, not speed.** These cells are reachable by
coverage because almost nobody measures them, and almost nobody measures them
because the official profile does not. Fifteen of our sixteen scorable cells
hold one entry. That is the whole mechanism.

The magnitudes say the same thing much louder. Our LFM2.5-350M holds rank 1 in
21 of the 56 cells of `sub1787965681732`, including `tg128 (c10)` at
**2044.66 t/s**. The lone incumbent across the `tg32` cells reads 0.6-61.4, and
in `tg32 (c10)` specifically **39.2**. A memory from 2026-08-22 read the same
picture independently — `tg32 @ d16384 c1` held one entry at 28.11 (`ee442d8a`).
Two reads, five weeks apart, the same near-vacancy.

**`tg32` against `tg128`.** The tree's only direct measurement is
`concurrency/EXPERIMENT.md`: tg32 beat tg128 by **4.79% at c1**, and it was
recorded there as "not a lever". That was measured on
Qwen3.6-35B-A3B-NVFP4, not on this checkpoint, so it transfers as a direction
and not as a number: shortening the generation from 128 to 32 tokens does not
make decode slower. It means our `tg128` figures are a conservative floor for
our `tg32` figures, which is all the Objective needs. Nothing here depends on
the 4.79% being right for LFM2.5-350M.

**The scatter, and the band a rule here can clear.**

    tg128 (c10) d0, within-arm, n=3:  ±0.2-1.5%          (slots/h1)
    same recipe, run to run, at depth: -6.9% .. +10.9%   (`cadfb796`, 08-28)
    within one arm, CV at d8192:       6.9 / 8.05 / 14.5%  (depth/h1)
    within one arm, CV at d16384:      14.45 / 5.72 / 9.6%  (depth/h1)
    c1, unpinned prompt, n=3:          up to ±15%, max/min 1.44  (`1d82439a`)

The standing instruction on this model is explicit: **size decision rules
against 7-15%, never 3%**, and a four-depth sweep at `runs 3` is a coverage
grid, not a discriminating one (`cadfb796`). That is a fatal objection to a
tuning round and no objection at all to this one. The margins this experiment
reads are **~4x** at the single contested cell and **~50x** at the vacant ones.
A rule stated on ratios that large clears a ±15% band with two orders of
magnitude to spare, which is precisely why `runs 3` is the right spend here and
would not be if we were chasing a few percent.

Two known measurement properties that bound the claim rather than the round.
Every llama-benchy figure is cold-cache whatever the recipe declares, because
the harness generates prompts sharing no prefix (`8d4802a5`) — so our `pp4096`
figures carry that caveat outward, and the `pp4096` cells are secondary for
that reason. And `tg` cells do not reliably generate their full token count at
depth: early EOS, growing with depth, up to 13/60 short returns at d16384 on
this checkpoint (`b540500c`). At `tg 32` the shortfall has less room to grow,
but the short-return distribution in `progress.jsonl` is worth reading before
any depth figure is trusted.

**Precedent.** `Qwen3.6-35B-A3B-NVFP4/experiments/depth-curve` closed as
measurement-only, `recipe-new.yaml` byte-identical to `recipe.yaml`, and that
was recorded as the correct outcome for an experiment asked to measure rather
than to win. This experiment expects the same shape: it should close with the
recipe unchanged and a recommendation attached.

**Why this profile and not another.** `sparkrun benchmark` measures exactly the
cells it is given and `--arena` submits exactly what was measured, so the
experimenter chooses the competition (`e15bc2f1`). `pp 4096` is paired with
`tg 32` deliberately — llama-benchy emits one `pp` and one `tg` metric per
execution, so this pairing produces only near-empty cells. A `pp 2048` profile
would republish contested `pp2048`-at-depth cells where our existing
submissions already rank ≥100.

## Held

- **Depths stop at 16384.** `max_model_len` is 32768 and the grid carries
  `pp 4096`, so the deepest servable depth is `max_model_len − pp − 2` = 28670.
  The board's d32768, d65535 and d100000 rungs are unreachable without raising
  `max_model_len`, which would change a config that has been validated and is
  the one we would publish. **Four depths on a proven config beats seven on an
  unproven one**, and no round here may buy depth by moving `max_model_len`.
- **`pp 4096` is paired with `tg 32`, and neither is a variable.** The pairing
  is what confines the grid to near-empty cells. No round may substitute
  `pp 2048`: it would republish contested cells where our own submissions
  already rank ≥100, which is a loss dressed as coverage.
- `max_num_seqs: 16`, `max_num_batched_tokens: 8192`,
  `gpu_memory_utilization: 0.8`, `max_model_len: 32768` — the whole `slots`
  winner, unchanged. This experiment tunes nothing. A round that moves a recipe
  field is not this experiment.
- Checkpoint `LiquidAI/LFM2.5-350M` at sha
  `9e6c6ccf47cd318696e137d381a7ded8fe4df09f`. Unmodified — no requant, no local
  conversion.
- Box `spark-6f0e`. Container image
  `sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990`
  (`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, vLLM
  `0.27.2rc1.dev360+ge85d1b69c`, flashinfer `4927c0e1`). A digest change is a
  new epoch; the incumbent is re-measured before anything crosses it.
- Runtime vLLM, container `vllm-node`, `recipe_version: '1'`. At
  `recipe_version: '2'` sparkrun does not select the eugr builder and the run
  dies at image distribution before the engine launches (`fac487ad`).
- Cell order is the `schedule:` block of `profiles/arena-tg32-pp4096.yaml`:
  depth-major over a fixed concurrency sweep, not arena's
  `bucket_43521_seed42`. Order decides what is warm and no figure reveals which
  order produced it, so the schedule is part of the contract.
- The memory stack's embedder is down for every run — it is a vLLM instance on
  the same card.
- **Nothing is submitted to Spark Arena.** Every run is Phase A, screened
  without `--arena`. Submission is Mat's decision and it has not been given.

Not "every field not under test" — a round holds its own fields constant, and
says so in its own Method. Anything named here is closed to every round.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | the `slots` winner, run over the tg32/pp4096 grid, places top-3 in ≥16 of the 20 grid points | <pending> |

## Conclusion

<pending — written when the objective is reached or the levers are exhausted>
