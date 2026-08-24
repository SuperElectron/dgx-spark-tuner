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
| run-0001 | `recipe-new.yaml`: `max_num_seqs` 10, full 28-cell arena-v2 schedule | the only measurement that can close the Objective | d16384 c10, guard d16384 c1 | | | | |

Record, as h2 did: the container image tag and digest, the vLLM and flashinfer
commits, `running max`, `waiting max`, `kv max`, preemptions, prefix cache hit
rate and samples, LOOPING counts per cell, MTP acceptance, and the full 28-cell
menu — the grid produces the whole board row, not just the two cells the rule
reads, and the other twenty-six are the record of what `max_num_seqs 10` costs
and buys everywhere else.

## Conclusion

<pending>
