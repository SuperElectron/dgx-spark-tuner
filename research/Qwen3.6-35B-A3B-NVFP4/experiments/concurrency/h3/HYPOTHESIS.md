# h3 — validation: `max_num_seqs 10` on arena's own unmodified 28-cell grid

## Hypothesis

`recipe-new.yaml` — `max_num_seqs: 10`, every other field identical to
`recipe.yaml` — run once on the unmodified 28-cell arena-v2 schedule, reads
`tg` at `d16384 c10` above 102.31, and reads `d16384 c1` no lower than 103.7.

This is not a new mechanism. h2 established the mechanism on a four-cell screen:
four slots admit four of ten offered requests, the other six wait, and
llama-benchy's aggregate divides generated tokens by a wall-clock window that
counts their waiting. Raising the slot count to the grid's own maximum
concurrency empties the queue — `running max` 4 → 10, `waiting max` 6 → 4 — and
`d16384 c10` went 49.0 → 137.5. h2 also showed the field is inert past 10,
because the grid never offers an eleventh concurrent request.

What this round adds is the only thing h2 could not buy: a **board-comparable
figure**. `EXPERIMENT.md`'s Held requires the unmodified 28-entry schedule in
arena's own order, because cell order decides what is warm and what is hot and no
number reveals which order produced it. h2's screen ran four cells cold, with
`runs: 7` at c1; arena's grid runs twenty-eight at `runs: 3`, with twelve cells
preceding `d16384 c1` and seventeen preceding `d16384 c10`. Those are different
measurements of the same configuration, and only one of them may be set beside
102.31.

Worth, if right: it closes the Objective. h2's screen cleared the primary by 34%
(137.5 against 102.31) at a cell reproducing to 0.2%, so the margin is far wider
than any plausible schedule effect — a warm-grid figure would have to fall by a
quarter to miss. If it does miss by that much, the finding is that arena's
ordering costs a quarter of this cell's throughput, which is worth as much as the
win would have been and is not knowable any other way.

## Method

### Variables to test

    nothing — this is a validation run, not a sweep

    max_num_seqs: 10   (fixed, from h2 run-0002)

One run of `recipe-new.yaml`, unmodified, one engine start. There is no arm to
compare inside this round; the comparison is against the board's published
figures and against h5's incumbent run of `recipe.yaml` on the same schedule
(`bench_e86574ff0e1e`, `d16384 c10` = 48.9, `d16384 c1` = 103.7).

Order is arena's, not ours, and is not touched.

### Constant for this round

Everything. `recipe-new.yaml` differs from `recipe.yaml` in exactly one field
(`max_num_seqs` 4 → 10) and from h5 run-0001's recipe in exactly the same one,
which is what makes h5's grid run the incumbent for this comparison.
`max_num_batched_tokens 65536`, `max_model_len 262144`,
`gpu_memory_utilization 0.8`, `kv-cache-dtype fp8`, MTP depth 3 on triton, the
same serve command, the checkpoint's own sampling. The schedule block is copied
byte for byte from the arena-v2 grid and no cell, order or `runs` value is
changed.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0/4096/8192/16384/32768/65535/100000 ·
    concurrency 1, 2, 5, 10 · runs 3 · 28 cells in arena's order

Expect roughly two hours, from h5's 1h57m on the same schedule.

### The epoch

h2 ran on image tag `ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, vLLM
`e85d1b69cf2f1c6101cfc7c799bb0c457cacc4b3`, flashinfer
`4927c0e15cb63a2abb6df09019c39a172222f0eb`, source digest `sha256:19d2158d…`.
h5 ran on the same. This round must record the same three, and if it does not it
has crossed an epoch break — in which case its figures are not comparable to h5's
incumbent and the incumbent needs re-measuring before anything is claimed.

### What is ruled out before it is proposed

- **The guard cannot be read as a percentage.** h2 measured c1 at ±11%
  run-to-run under a byte-identical configuration, and this grid gives c1
  `runs: 3` where h2 gave it 7. Memory records the excess as protocol — the
  prompt is redrawn per run and this schedule does not pin it — so the number
  arriving here is at best a floor test against 103.7, never a comparison of
  medians against h2's arms. A c1 that lands within about 11% of 103.7 has not
  regressed and has not held; it has failed to resolve, and the rule below says
  so in advance.
- **Prefix cache.** 0.0% campaign-wide across 374+ samples and every h1 and h2
  arm. This run is cold-cache like all the others and may not claim otherwise.
- **Acceptance.** Flat under scheduler knobs for seven consecutive rounds.
  Capture it as a control that it did not move, never as an explanation.
- **More slots.** h2 run-0003 closed the upward direction: `running max` stops at
  10 because the grid tops out at c10. This round does not re-open it.

### Pre-registered non-findings

- **Cells other than `d16384` will move**, in both directions, because h2 showed
  the field acts wherever offered concurrency exceeds the slot count — c5 and
  c10 everywhere in the grid, not c1 or c2. That is expected and is not evidence
  about this round's two cells.
- **First-token latency will get worse at high concurrency.** h2 measured c10
  ttft median 19.12 s → 28.08 s. Arena scores `tg`, so it costs nothing on the
  board; report it anyway.
- **CUDA-graph capture runs to size 80 at 1.95 GiB** at ten slots, against 32 at
  four. Boot is slower and that measures nothing.
- **Host memory headroom is narrower** than at four slots — h2's worst-case free
  memory fell 7967 → 3558 MB. It did not bind on a four-cell screen; a 28-cell
  grid including `d100000 c10` is the first real test of that, so watch it.

## Decision rule

Read aggregate `tg` medians at `d16384 c10` and `d16384 c1` from this run's
`results.yaml`, against the board's published figures as floors — this is the
schedule those figures were produced on, which is the whole point of the round.

- **Target met** — `d16384 c10` above 102.31 **and** `d16384 c1` at or above
  103.7. The Objective closes, `recipe-new.yaml` is that run's recipe, and the
  experiment writes its Conclusion.
- **Target met, guard unresolved** — `d16384 c10` above 102.31 and `d16384 c1`
  within ±11% of 103.7. The primary closes and the guard is recorded as
  unresolvable on the board's own protocol, with the h2 evidence for why: at
  `runs: 3` and an unpinned prompt this cell cannot resolve a change of the size
  the guard was written to catch. The experiment closes on the primary and says
  in its Conclusion exactly what the guard does and does not establish. This
  branch is written before the number exists because h2 makes it the most likely
  one.
- **Lever alive** — `d16384 c10` rises materially over h5's incumbent 48.9 but
  lands below 102.31. Then arena's ordering costs part of the screen's gain, the
  size of that cost is the finding, and the round adds arms — the obvious first
  being `max_num_seqs` above 10, which the screen could not test because it never
  offered an eleventh request but which a 28-cell grid may reward differently.
- **Lever spent** — `d16384 c10` lands at or below 102.31 with no route left in
  the slot count, **or** it clears 102.31 while `d16384 c1` falls more than 11%
  below 103.7. In the second case the trade against single-stream is larger than
  the instrument's own noise and is therefore real, the guard governs,
  `max_num_seqs 4` stands, and `recipe-new.yaml` is withdrawn.

Sized against Strategy's scatter for this grid: `d16384 c10` ±0.5% and `d16384
c1` ±5.2% at `runs: 3` on the arena schedule (n=3, h5). The c10 branches are
therefore readable at the margins named; the c1 branches are stated as floors and
an 11% band for exactly the reason h2 recorded, and that band is written here
before the run rather than after.

One run means one value per cell and no interquartile range at all. Every branch
above reads a single median against a fixed external number, which is the only
form of rule a single validation run can support, and this is said in advance.

## Runs

One row per planned run. Figures blank until it is run.

| run | changed | why | cell | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|------|--------|--------|---------|-------|
| run-0001 | `recipe-new.yaml`: `max_num_seqs` 10, full 28-cell arena-v2 schedule | the only measurement that can close the Objective | d16384 c10, guard d16384 c1 | 677.9 | **141.5** ±0.2% (141.5 140.8 141.7) · guard c1 **95.8** ±15.0% (95.8 124.2 86.1), pp 628.0 | 28636.2 · guard c1 3281.9 | bench_95fdfa8922a3 |

Record, as h2 did: the container image tag and digest, the vLLM and flashinfer
commits, `running max`, `waiting max`, `kv max`, preemptions, prefix cache hit
rate and samples, LOOPING counts per cell, MTP acceptance, and the full 28-cell
menu — the grid produces the whole board row, not just the two cells the rule
reads, and the other twenty-six are the record of what `max_num_seqs 10` costs
and buys everywhere else.

## Conclusion

**Target met, guard unresolved** — the rule's second branch, the one this round
pre-registered as most likely.

    primary   d16384 c10   141.5  ±0.2%  (141.5 140.8 141.7)   floor 102.31   MET, +38%
    guard     d16384 c1     95.8 ±15.0%  ( 95.8 124.2  86.1)   floor 103.7    -7.6%, inside ±11%

Aggregate `tg` medians from `bench_95fdfa8922a3`'s `results.yaml`. The primary
clears the Objective's 102.31 by 38% and is **2.89x** h5's incumbent 48.9 at the
same cell on the same unmodified grid. The guard lands 7.6% below 103.7, inside
the pre-registered ±11% band (floor 92.29), so it is **unresolved — not held and
not regressed**.

### The run is valid and comparable to the incumbent

vLLM's `non-default args:` line agrees with `recipe.yaml`'s `defaults:` field for
field: `max_num_seqs 10`, `max_num_batched_tokens 65536`,
`gpu_memory_utilization 0.8`, `max_model_len 262144`, `kv_cache_dtype fp8`,
`attention_backend flashinfer`, `moe_backend marlin`, `enable_prefix_caching`,
`enable_chunked_prefill`, `async_scheduling`, and the MTP speculative config at
`num_speculative_tokens 3` on triton. The engine served what the recipe declared.

Epoch: vLLM `0.27.2rc1.dev360+ge85d1b69c.d20260821`, flashinfer 0.6.18, image
`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, image id
`sha256:b277afb7c08fb5941e27449fa936aafeeb360a952fc95c38a28f5f570739c2f2`, repo
digest `sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990`.
The **same epoch as h2 and as decode-tg h5**, which is what makes the comparison
against the incumbent `bench_e86574ff0e1e` legitimate rather than a cross-epoch
guess.

One session, `crash_count 0`, `failed_indices []`, all 28 cells completed, wall
1:51:51 — against h5's 1h57m on the identical schedule, so the grid cost nothing
extra. `exit_on_first_fail: true` was set and never fired.

### The whole board row, against the incumbent

Aggregate `tg` medians, h5 `bench_e86574ff0e1e` (`max_num_seqs 4`) against this
run (`max_num_seqs 10`). Everything else identical.

    depth      c1                 c2                 c5                  c10
    0        96.6 →  99.9 1.03x  152.3 → 151.0 0.99x  170.6 → 211.3 1.24x  154.2 → 276.8 1.80x
    4096    109.6 → 106.5 0.97x  138.6 → 136.2 0.98x  131.8 → 185.1 1.40x  105.8 → 237.7 2.25x
    8192    103.0 → 115.6 1.12x  129.3 → 141.6 1.10x  107.9 → 183.3 1.70x   77.7 → 230.5 2.96x
    16384   103.7 →  95.8 0.92x  130.9 → 137.8 1.05x   84.2 → 176.1 2.09x   48.9 → 141.5 2.89x
    32768   106.1 →  93.3 0.88x  125.0 → 128.3 1.03x   53.1 → 126.1 2.38x   25.8 →  37.5 1.46x
    65535    95.6 →  90.4 0.95x  107.7 → 102.4 0.95x   19.7 →  20.5 1.04x   10.5 →  10.9 1.04x
    100000   82.4 →  91.0 1.10x   58.2 →  58.3 1.00x    8.3 →   8.5 1.03x    5.4 →   5.5 1.03x

Read as one figure: **the win is admission, and it is confined to cells where
offered concurrency exceeds the old slot count.**

- **Where it gains** — c5 and c10 from d0 to d32768, 1.24x to 2.96x. The largest
  gain is not the Objective's cell but `d8192 c10` at 2.96x.
- **Where it is flat** — the whole c1 column (0.88x-1.12x, unsigned scatter about
  a cell that this run itself shows spans ±15%) and the whole c2 column
  (0.95x-1.10x). Two offered requests never queued behind four slots, so there
  was nothing for the field to buy, exactly as h2 predicted.
- **Where it is also flat, and shouldn't have been** — `d65535` and `d100000` at
  c5 and c10 move 1.03x-1.04x, which is nothing. At those depths the cells are
  already collapsed (20.5, 10.9, 8.5, 5.5 t/s) and something other than admission
  is bounding them. The slot count is not the lever there and this run does not
  say what is.
- **Nothing got materially worse.** The three cells below 1.00x by more than 5%
  are `d16384 c1` 0.92x, `d32768 c1` 0.88x and `d65535 c2` 0.95x. The two c1 cells
  sit inside a column whose own three values this run spans 86.1-124.2 at
  `d16384`, so they are not readable as regressions. No cell fell far enough to
  clear the instrument's noise.

### What the guard does and does not establish

It establishes that `d16384 c1` did not collapse: 95.8 against a floor of 103.7
is a 7.6% shortfall on a cell whose three values in this very run are 95.8, 124.2
and 86.1 — a **±15.0% span on a single unchanged configuration**. That is wider
than the ±5.2% Strategy carried from h5 and wider than the ±11% band this rule
pre-registered, and it is measured under the board's own protocol.

It does **not** establish that the guard held. At `runs: 3` with an unpinned
prompt, `d16384 c1` cannot resolve a change of the size the guard was written to
catch. h2 reached the same finding independently — 107.0 / 102.1 / 114.1 across
three arms of a field that provably cannot act at c1, where `running max` is 1 by
construction. Memory records the excess as protocol, not cell: the prompt is
redrawn per run and arena's schedule does not pin it. It is not fixable inside a
board-comparable run, because Held requires the unmodified grid. A pinned-prompt
c1 measurement is a separate instrument question and is not this experiment's.

**The milestone's c1 target of 116.03 is not claimed.** This run's `d16384 c1`
median is 95.8 and nothing here moves that target.

The rule was **not** mis-specified. It named this branch before the numbers
existed, on h2's evidence, and the numbers landed in it.

### The rest of the record

- **Scheduler.** `running max 10`, `waiting max 7`, `preemptions 0`, `kv max
  24.6%` of pool. The mechanism check passes on its own terms: ten slots are
  actually occupied, which is the difference from h5's `running max 4`. The queue
  is not empty at c10 — seven waiting at the worst point, against six in h2's
  four-cell screen — because the grid's deeper cells offer requests the slots
  cannot clear. KV at 24.6% is 2.6x h5's 9.8% and still nowhere near binding.
- **Box.** Peak 99.3 W, peak clock 2411 MHz. Neither power nor clock was the
  constraint across 1h51m.
- **MTP.** Median mean acceptance length 3.42 over 312 samples (min 2.35, max
  4.00) at `num_speculative_tokens 3`. Recorded as a control that it did not move
  — never as an explanation for anything above. Eighth consecutive round where
  acceptance is flat under a scheduler knob.
- **LOOPING.** None raised, for any cell. Worst repeat ratio 0.18 (`d0 c1`) to
  0.44 (`d100000 c10`). The h1 arms' looping-inflated figures have no analogue
  here, so no cell in the board row is an upper bound.
- **Prefix cache.** Hit rate max 0.0% over 527 samples, and `run.py` itself flags
  `SUSPECT: recipe asks for prefix caching`. Eighth confirmation of the standing
  campaign defect. **Every figure here is cold-cache**, including the 141.5.
  **Corrected 2026-08-27: "eighth" is inflated — it is the seventh.** Two of the
  counted runs (`depth-curve/h1/run-0005`, `run-0006`) logged a single hit-rate
  sample each, and the engine's first sample is always 0.0%, so they assert
  nothing; `measure.py` now gates at n >= 2. Count samples, not runs. This tally
  is the prefix-cache defect; it must not be added to the three sightings of the
  `request_end` double-flush, which is a different defect with its own count.

- **Integrity: 27 of 28 cells clean** — `request_end == request_first_token` and
  every request `total_tokens == 128`. **One failure:** `06-d100000c2.jsonl` has
  `request_end` 13 against `request_first_token` 12 — one extra completion with no
  matching first-token event, where the grid expects 12. All 13 ends carry
  `total_tokens 128`, so there is no short generation. That cell (`d100000 c2`,
  tg 58.3) is **SUSPECT** and is marked so. It is not a cell either branch of the
  rule reads and it does not touch the outcome; it is the same shape of damage h1
  run-0003 carried and it is now the second sighting, which makes it a pattern
  worth naming rather than a one-off. **Corrected 2026-08-27: that conflation is
  retracted — the two are different shapes.** `06-d100000c2` is a writer
  double-flush: 13 ends against 12 first-tokens with all 13 records at
  `total_tokens 128`, so no sample was lost. h1 run-0003 is real damage —
  request 27 returned `total_tokens: 1` at `decode_seconds: 0.0`, verified
  against `bench_fbb28a3df00f`, which carries zero duplicate lines. The
  discriminator: every record at full `total_tokens` means double-flush, anything
  short means damage. The sentence above is left as written; this note stands
  beneath it.
- **Known noise.** `SSH script <- spark-6f0e... FAILED rc=1 (0.4s)` fires at the
  start of every run in this tree, is unexplained, and is not fatal. The
  `HF_TOKEN` warning is benign.

### Was the round worth running

Yes, and it bought the one thing h2 could not: a board-comparable number.
141.5 at `d16384 c10` is measured on arena's own 28-entry schedule in arena's own
order, which is the only figure Held permits to be set beside 102.31. It also
cost h2's screen figure almost nothing — 137.5 cold on four cells against 141.5
warm on twenty-eight — so arena's ordering does not eat the gain, which was the
round's stated alternative finding and is now closed.

Nothing is submitted to Spark Arena. `recipe-new.yaml` is a deliverable for Mat.
