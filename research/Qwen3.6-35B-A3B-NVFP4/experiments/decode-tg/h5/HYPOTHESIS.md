# h5 — our recipe, measured on the board's own grid

## Hypothesis

Our tuned recipe, run on `@official/spark-arena-v2` unmodified, reads above
116.03 `tg` at `d16384 c1` — the best vLLM entry on the board.

The grid is not the recipe. arena-v2 specifies depths, concurrencies, `pp 2048`,
`tg 128`, `runs: 3`, prefix caching on with no reset between runs, and a fixed
heat-aware cell order. It says nothing about `moe_backend`, `kv_cache_dtype`,
MTP, or any field we have tuned. So this round changes *how we measure*, not
what we serve: their grid, our flags.

Two things the board gets that our protocol denies us, and they point opposite
ways:

- **Cache warm.** No reset between runs, and `d16384 c1` sits at index 13 of 28
  — twelve cells of cache precede it. h2 measured what that is worth on this
  box: hit rate 0 → 69.2%, `pp` 633.9 → 2593.0 (4.1x), `tg` +2.3%. Our standing
  119.6 is the cold figure.
- **Thermally warm.** Index 13 is mid-sweep on a box that has been under load a
  while. Ours is measured alone on a cool card. This direction depresses their
  number, not ours.

Worth, if right: the Objective's second figure, which does not exist today.
119.6 x 1.023 is roughly 122 if the cache effect carries at this cell, against
116.03 — a 5% margin. But the honest claim is narrower: this is the only
measurement that can be set beside the board without an asterisk, and its value
is that it settles the question either way.

## Method

### Variables to test

    benchmark grid: @official/spark-arena-v2, unmodified

Nothing else varies. One run.

`profile:` is a sparkrun CLI option, not a recipe key — setting it in a recipe
is silently ignored, and passing it to the API discards the recipe's whole
`benchmark:` block. So the profile is transcribed into the recipe instead. It
is cached verbatim on this machine at

    ~/.cache/sparkrun/registries/_url_70b481ce5ca0/benchmarking/spark-arena-v2.yaml

**`schedule:` is the load-bearing part.** It is a recipe key, and it sets
execution order. Without it llama-benchy builds a depth-major cartesian
product, which puts `d16384 c1` at index 12 of a cold ascending sweep. arena
runs it at index 13, after five d8192/d4096 cells and two d100000 cells have
heated the box and filled the cache. Same grid, different thermal and cache
state, and nothing in the numbers would reveal the difference. Copy the 28
entries verbatim.

The whole `benchmark:` block, transcribed from the cached profile:

    benchmark:
      framework: llama-benchy
      args:
        depth: [0, 4096, 8192, 16384, 32768, 65535, 100000]
        pp: [2048]
        tg: [128]
        concurrency: [1, 2, 5, 10]
        prefix_caching: true
        runs: 3
      schedule:
        - { depth: 8192,   concurrency: 5 }
        - { depth: 4096,   concurrency: 5 }
        - { depth: 8192,   concurrency: 10 }
        - { depth: 8192,   concurrency: 2 }
        - { depth: 4096,   concurrency: 2 }
        - { depth: 100000, concurrency: 5 }
        - { depth: 100000, concurrency: 2 }
        - { depth: 65535,  concurrency: 10 }
        - { depth: 65535,  concurrency: 1 }
        - { depth: 0,      concurrency: 1 }
        - { depth: 65535,  concurrency: 5 }
        - { depth: 32768,  concurrency: 2 }
        - { depth: 4096,   concurrency: 10 }
        - { depth: 16384,  concurrency: 1 }
        - { depth: 8192,   concurrency: 1 }
        - { depth: 32768,  concurrency: 5 }
        - { depth: 0,      concurrency: 10 }
        - { depth: 16384,  concurrency: 10 }
        - { depth: 32768,  concurrency: 1 }
        - { depth: 0,      concurrency: 5 }
        - { depth: 16384,  concurrency: 5 }
        - { depth: 100000, concurrency: 1 }
        - { depth: 32768,  concurrency: 10 }
        - { depth: 16384,  concurrency: 2 }
        - { depth: 0,      concurrency: 2 }
        - { depth: 65535,  concurrency: 2 }
        - { depth: 4096,   concurrency: 1 }
        - { depth: 100000, concurrency: 10 }

`d16384 c1` is entry 14, index 13. The `serve` half of the recipe is
decode-tg's `recipe.yaml` unchanged apart from `max_model_len`.

### Constant for this round

The whole served recipe — every flag decode-tg has settled, including whatever
h4 concludes about the draft's `moe_backend`. **h4 closes before this runs.**
This round measures the recipe we finished tuning; it does not tune it.

Exactly one field changes, and it is capacity rather than tuning:

    max_model_len   32768 -> 262144

The grid reaches d65535 and d100000, which 32768 cannot serve at all. h1
measured this field as roughly neutral for `tg` — it moved 2.0 against an IQR
of 11.3 — so it is not expected to cost us.

### Memory: measured, not estimated

`gpu_memory_utilization` **stays 0.8**, and that is a decision taken before the
run on measurement, not a value left at its default. h4 run-0001's engine log
reports what 0.8 actually buys on this box:

    Model loading took 21.96 GiB
    Available KV cache memory: 59.88 GiB
    GPU KV cache size: 2,813,819 tokens
    Maximum concurrency for 32,768 tokens per request: 85.87x
    Free memory on device (115.95/121.69 GiB) on startup
    Actual usage: 52.66 GiB consumed (weights + non-torch),
                  6.64 GiB peak activation, 0.2 GiB CUDAGraph

The pool holds 2.81M tokens, or ~22.3 KB per token across the 10 full-attention
layers — the other 30 are linear attention and hold no KV.

Against the grid's worst cell, d100000 x c10:

    10 x (100000 + 2048 + 128) = 1,021,760 tokens = 36% of the pool

and `max_num_seqs 4` caps running sequences at four, so the real figure is
nearer 15%. `max_model_len 262144` needs 262,144 tokens for one sequence — 9%
of the pool, or 10.7x concurrency available where the grid asks for 10 only at
d100000, which is shallower.

Peak activation was profiled at `max_num_batched_tokens 65536`, which this
round does not change, so that 6.64 GiB stands.

Conclusion: the run fits at 0.8 with ~2.75x headroom at the worst cell. No
memory field needs to move.

**Lowering `gpu_memory_utilization` to 0.65 would make this worse, not safer** —
recorded here because it was the initial instinct and the measurement refuted
it. At 0.65 the budget is ~79.1 GiB; subtract the same 59.5 GiB of weights,
activation and graphs and KV falls to ~19.6 GiB, about a third of what 0.8
gives. The reference recipe serves these depths at 0.65 only because
`max_num_seqs 4` caps concurrent KV. The host-pressure argument for lowering it
does not survive `115.95/121.69 GiB free on startup`.

### Running it

The instrument was repaired for this round; both fixes are in and proven.

- `install_corpus` now runs only when the recipe declares `book_url`. This
  recipe declares none, so the fixed corpus is skipped and its one-cell guard
  never fires. stdout must say `no fixed corpus: the recipe does not ask for
  one`. If it instead dies with `the fixed corpus pins one cell`, the recipe
  has a stray `book_url`.
- A failed run archives its own engine log. Do not fetch one by hand before
  reading what `run.py` said.

Run it in the background. This sweep is hours, and a foreground command is
killed at 10 minutes.

If it fails mid-sweep, the cells that completed are recorded in the state dir
(`id.txt` points at it) even when `results.yaml` was never written. Read that
before reporting anything as lost. Only engine-start failure has been tested;
mid-sweep failure has not, though the recovery path has strictly more to work
with there.

`exit_on_first_fail` stays on, injected by `run.py`. A cell that fails should
stop the sweep loudly rather than leave a plausible table with a hole in it.
With `max_model_len` correct no cell should fail at all.

### What this round gives up

Our protocol is what made h1-h4 comparable to each other, and arena-v2 has
none of it: `runs: 3` not 7, no `exact_tg`, no fixed corpus, no
`no_adapt_prompt`, and sampling from the checkpoint's own
`generation_config.json` rather than a pinned `temperature 0`.

So this figure will be noisier and **is not comparable to h1-h4**. That is not
a defect. It is the second figure the Objective asks for, serving the board
comparison, and the two coexist: ours stays the internal yardstick, this one is
the external one.

One consequence is worth stating before the numbers exist, so it is not
mistaken for a fault later. `runs: 3` gives three values at c1, and an
interquartile range needs four. So **the headline cell prints no stability
verdict** — `d16384 c1` will read `n=3, too few for quartiles`. Cells at c2,
c5 and c10 are unaffected: their per-request series carry `runs x concurrency`
values, so 6, 15 and 30 respectively. This is inherent to their grid and
cannot be fixed without diverging from it, which is why the decision rule below
is stated on the median alone.

### What it answers beyond the headline

One run returns the whole cell menu, which no round so far has touched:

- concurrency c1, c2, c5, c10 at every depth — the vLLM curve peaks at c2 and
  holds ~100 at c10 on the board, and we have never measured ours above c1
- the depth curve d0 to d100000, which `depth-curve` was scaffolded to chase
  five rungs at a time
- `ctx_pp` / `ctx_tg` alongside `pp` / `tg` at every cell

### Epoch

`max_model_len` is part of the recipe and therefore part of the epoch. Every
figure produced here sits on the far side of that break from h1-h4, and the
incumbent must be re-measured before anything is compared across it.

## Decision rule

Read our own `d16384 c1` row out of the result and set it beside 116.03.

- **Target met** if our `tg` at `d16384 c1` exceeds 116.03. The board comparison
  is then settled in our favour on the board's own terms, and the Objective's
  second figure exists.
- **Lever alive** if it lands between 110 and 116.03 — behind, but close enough
  that the warm-cache and thermal effects are worth separating before conceding.
- **Lever spent** if it lands below 110. Then our cold 119.6 was an artifact of
  measuring alone on a cool box, the board comparison goes against us, and what
  we learned is that our protocol flatters us.

Their `±` is a population standard deviation over three requests inside one
invocation; ours across invocations. The rule is stated on the median and does
not depend on comparing the two spreads.

### If it runs out of memory

It is not expected to — the sizing above says 36% of the pool at the worst
cell. If it happens anyway, the run **stops and reports**. No served flag is
changed and the run is not retried with different memory settings.

This is not caution, it is what the round is for. h5 measures the recipe
decode-tg tuned. A `gpu_memory_utilization` or `max_num_batched_tokens` changed
mid-round to get past an OOM produces a figure for a recipe that was never
tuned and never measured internally, and it would not be board-comparable to
anything — it would just be a third recipe with one number against it.

So an OOM is a finding about the sizing above being wrong, and it is written up
as that. Any memory field that then needs to move is a recipe change, decided
deliberately, re-measured against the incumbent, and run as its own round.

Cells that completed before the failure are kept. If `d16384 c1` is among them
the decision rule still evaluates, since that cell sits at index 13 of 28 and
the deep cells that would fail come later.

## Runs

Nothing has been run and `run-0001` does not exist yet. To open it:

    .claude/skills/spark-autoresearch/scripts/new-run.sh \
        research/Qwen3.6-35B-A3B-NVFP4/experiments/decode-tg/h5

Then write its `recipe.yaml`: decode-tg's `recipe.yaml` with `max_model_len`
262144 in `defaults:`, and its `benchmark:` block replaced by the one above.
Carry nothing else over — no `book_url`, no `exact_tg`, no `no_adapt_prompt`,
no `extra_body`, no `post_run_cmd`.

One row per planned run. Figures blank until it is run.

| run | changed | why | d16384 c1 tg | d16384 c1 pp | ttfr ms | bench |
|-----|---------|-----|--------------|--------------|---------|-------|
| run-0001 | arena-v2 grid, `max_model_len` 262144 | the board-comparable figure | 103.7 ±5.2% (n=3) | 636.7 ±0.8% | 3242.6 | bench_e86574ff0e1e |

`tg` is the median of 115.1, 103.7, 101.1. run.py's own table prints 106.7 for
the same cell because that column is the arithmetic mean of a rate, which
overweights the fast sample; the rule reads the median. Both sit below 116.03
and below the rule's 110 floor.

The other 27 cells, `tg` medians, since one run returned the whole menu:

| depth | c1 | c2 | c5 | c10 |
|-------|------|-------|-------|------|
| 0 | 96.6 | 152.3 | 170.6 | 154.2 |
| 4096 | 109.6 | 138.6 | 131.8 | 105.8 |
| 8192 | 103.0 | 129.3 | 107.9 | 77.7 |
| 16384 | 103.7 | 130.9 | 84.2 | 48.9 |
| 32768 | 106.1 | 125.0 | 53.1 | 25.8 |
| 65535 | 95.6 | 107.7 | 19.7 | 10.5 |
| 100000 | 82.4 | 58.2 | 8.3 | 5.4 |

Conditions that qualify the table, from the archive:

- **Prefix caching never engaged.** `hit rate max 0.0% over 544 samples`, with
  `--enable-prefix-caching` set and the engine confirming
  `enable_prefix_caching=True`. Cell-phase `pp` reads 636.7 against 5907.5 for
  the context phase — h2's 0%-hit signature was 633.9. Every cell is affected,
  and the warm cache this round was built to inherit does not exist.
- **`running max 4, waiting max 7`.** `max_num_seqs 4` queues the c5 and c10
  cells rather than batching them, which is what the right-hand columns are
  measuring.
- `kv max 9.8%`, peak 99.0 W, peak clock 2398 MHz, 0 preemptions. The memory
  sizing above predicted 36% of the pool at the worst cell and it never passed
  10%.
- Sampling was the checkpoint's own — `temperature 1.0, top_p 0.95, top_k 20`,
  logged as overriding vLLM's defaults. That is arena's protocol, as declared.
- `d65535 c10` had 1 of 60 requests looping, which inflates that one cell.
- Dispersion at c5/c10 for depth >= 8192 is severe (iqr to 377%, max/min to
  53). The c1 and c2 columns are the tight ones at ±3.2-9.3%.
- Archive provenance: sparkrun derives the bench id from the recipe, so this
  run **overwrote** the 12-cell partial sweep of 2026-08-23 that shared
  `bench_e86574ff0e1e`. depth-curve's Strategy cites that id for figures the
  directory no longer holds. Its substance survives — it quoted 96.2 at
  d65535 c1 and this complete run reads 95.6.

## Conclusion

**Lever spent, by the rule as written.** `tg` median at `d16384 c1` is 103.7,
below the rule's 110 floor and 10.6% below the board's 116.03. The
board-comparable figure the Objective asks for now exists, and it goes against
us.

The rule reads the median, and that is the number above. run.py's own table
prints 106.7 for the same cell; that column is the arithmetic mean of the three
values 115.1, 103.7, 101.1, and a mean of a rate overweights the fast sample.
Both are below 110, so the choice does not change the branch. `±5.2%` is
`measure.spread()`'s standard error of the median, not a dispersion — the cell
has n=3 and prints `iqr n/a (n<4)`, exactly as this round said it would before
running.

**The rule's branch is right and its stated reasoning is wrong, and the
difference is the finding.** The Lever-spent arm says "our cold 119.6 was an
artifact of measuring alone on a cool box... our protocol flatters us." That
conclusion does not follow, because **the mechanism this round was built on
never engaged.** Prefix cache hit rate reads 0.0% on all 544 engine samples,
with `--enable-prefix-caching` set and `enable_prefix_caching=True` confirmed in
the engine's own config line. The cache-warm arm of the Hypothesis — twelve
cells of arena's cache preceding index 13, worth 4.1x prefill and +2.3% `tg` in
h2 — did not happen. So h5's hypothesis was **not refuted; it was never
tested.** What was measured is our recipe on arena's *grid* with a cold cache,
which is a different and narrower thing than our recipe on arena's *protocol*.

The figures say cold unambiguously. Set beside h2's arm A, same cell, our
protocol, reset in place:

                    h2 arm A (cold)   h2 run-0005 (warm)   h5 run-0001
    cell pp                  633.9               2593.0         636.7
    ctx  pp                 5912.9              21349.5        5907.5
    cell ttfr             3252.9 ms             803.3 ms      3242.6 ms

h5 lands on the cold column to within 0.5% on all three. There is no warm-cache
signature anywhere in this sweep.

That contradicts h2's conclusion, which is worth stating plainly: **h2 closed
the prefix-cache question on "our own `post_run_cmd` was disabling it", and h5
has no `post_run_cmd` at all and still reads 0.0%.** The reset was sufficient to
suppress hits; it was not the only thing that does. The leading candidate for
the residue is the one protocol field h5 gave up that h2 kept — `no_adapt_prompt`
and the fixed corpus. Without them llama-benchy re-derives the grid at warmup
and each of a cell's three runs draws a different prompt start, so there is
nothing for run 2 to reuse from run 1. h2's 0 → 44.8 → 62.7 → 69.2% climb was
across *seven identical prompts*. Not proven here, and h6 does not depend on it,
but it is the row to chase if the cache is ever chased again. If it holds, it
also applies to the board: arena's own entries would be as cold as ours, and
"they measure warm, we measure cold" stops being an explanation for anything.

**MTP acceptance is not the gap either.** Mean acceptance length reads a median
of 3.07 over 399 engine samples under the checkpoint's own sampling — at or
above the ~2.93 implied by the `0.87/0.76/0.61` per-position rates measured at
`temperature 0`. Stochastic sampling did not cost us draft acceptance.

So the 13.3% between our 119.6 and this 103.7 is unexplained, and it is not warm
cache and not acceptance. Four things remain conflated in one run and this round
cannot separate them: the prompt (adapt_prompt's random start, no fixed corpus,
so each run reads different prose — depth-curve h1 showed prose alone moves `tg`
enough to put a bump in a monotone ladder); the absence of `exact_tg`; the
sampler's per-token work at `top_k 20 / top_p 0.95` against a pinned greedy
path; and mid-sweep thermal state. Of those, sampling is the only one that is a
*served* field, board-legal, and still untested — the reference recipe overrides
generation config to `temperature 0.6` where our checkpoint's own file says 1.0.
That is h6.

**Validity.** The run is clean and self-consistent. `crash_count 0`,
`failed_indices []`, all 28 cells in `completed_indices`, one session
03:37:04 → 05:31:26 UTC. The engine's `non-default args:` line matches
`defaults:` field for field, including `max_model_len 262144`,
`gpu_memory_utilization 0.8`, `max_num_seqs 4`, `max_num_batched_tokens 65536`,
`kv_cache_dtype fp8`, `moe_backend marlin`, and the MTP config with
`moe_backend triton`. One run, so there is no cross-run digest or hash question
inside the round. Container `sha256:19d2158d…`, vLLM `e85d1b69`, flashinfer
`4927c0e1` — the same triple h1–h4 ran on.

**Epoch.** `max_model_len 262144` is a recipe field and therefore an epoch
break. **Nothing here may be set beside h1–h4 without saying so**, and the
119.6-vs-103.7 comparison above is stated across that break deliberately and is
worth exactly what a cross-epoch comparison is worth: it locates a question, it
does not answer one. The incumbent has not been re-measured at 262144.

**Box state, over the benchmark window only** (26,772 telemetry frames, model
load excluded). GPU utilisation sat at 96% for all but 158 frames (0.6%). Clocks
held: 2398 MHz median, 2385 minimum — no throttle. Power peaked at 91.9 W, GPU
temperature at 80 °C, CPU at 88.2 °C. KV cache usage never exceeded 9.8% against
the round's own 36% prediction for the worst cell, and there were zero
preemptions — the memory sizing in Method was correct and conservative. Host
memory fell from 21.3 GB available to ~3.1 GB and stayed there (97.2% used
median), but **swap did not move**: 778 MB at the start, 790 MB at its worst,
778 MB at the end. Nothing here was measured on a box that ran out of anything.
The four `ERROR` lines are transformers docstring complaints about
`min_frames`/`max_frames` at load; they are not runtime errors.

**Which of the 28 cells are readable, and which are not.** Per-request `tg`
dispersion, `runs x concurrency` values per cell:

    c1   n=3   max/min 1.0-1.3, no iqr           readable
    c2   n=6   iqr 12-30%, max/min 1.2-1.5       readable
    c5   n=15  iqr 40% at d0, 66-377% deeper     not readable at depth >= 8192
    c10  n=30  iqr 40% at d0, 68-302% deeper     not readable at depth >= 8192

The right-hand columns are not measuring decode. `max_num_seqs 4` against 10
concurrent requests means six of them queue, so per-request throughput is set by
queue position — `running max 4, waiting max 7` in the engine log. The
distribution is multi-modal by construction, and a median over it describes the
scheduler, not the model. **Treat c5 and c10 at depth >= 8192 as unreadable**:
the c10 column's collapse with depth (48.9 at d16384, 10.5 at d65535, 5.4 at
d100000) is the queue lengthening, not decode degrading. This matters to the
milestone, which targets both c1 and c10 at d16384: **that c10 figure of 48.9
cannot be improved by tuning decode, and cannot be compared to a board c10
number produced under a different `max_num_seqs`.** Raising `max_num_seqs` is
the first thing to establish there, and it is a recipe change and a new round,
not an adjustment. `d65535 c10` additionally had 1 of 60 requests looping, which
inflates that one cell; it was already unreadable.

The c1 depth column — 96.6, 109.6, 103.0, 103.7, 106.1, 95.6, 82.4 across d0 to
d100000 — is the readable part of the menu and is the first measurement the tree
holds above d30592. It is flat within its own scatter out to d32768 and falls
14% by d100000, which is consistent with depth-curve h1's "level, not slope"
finding extended two rungs further, and is not a substitute for it: different
epoch, different protocol.

**Sampling was arena's protocol, as declared, not a defect.** The engine logged
`Default vLLM sampling parameters have been overridden by the model's
generation_config.json: {'temperature': 1.0, 'top_k': 20, 'top_p': 0.95}`. That
is what arena-v2 unmodified produces and it is what makes this figure
board-comparable at all.

**Archive provenance — a defect in the instrument, not the measurement.**
sparkrun derives the bench id from the recipe, so this run wrote to
`bench_e86574ff0e1e` and **overwrote** the 12-cell partial sweep of 2026-08-23
that shared it. depth-curve's Strategy cited that id for figures the directory
no longer holds; it quoted `101.6 at d0` and `96.2 at d65535`, and the complete
run reads 96.6 and 95.6. The citation has been corrected in place so the tree
does not point at data that is gone. The substance of depth-curve's argument
survives — the c1 decline over that span is 1.0% here where it was 5.3% there,
which strengthens rather than weakens its "the effect is small" expectation.
**Any run that must not be overwritten needs a recipe that differs from every
earlier one, and no round can currently see that requirement before it runs.**

**Was it worth running?** Yes, and not for the reason it was opened. It did not
move the Objective and its own mechanism never fired. What it bought is the
second figure the Objective names, the whole 28-cell menu, the first evidence
that the prefix cache is inert for this model under *any* protocol we have run,
and the knowledge that `max_num_seqs 4` makes the milestone's c10 target
unmeasurable as currently configured. Three of those are findings the internal
yardstick could not have produced.
