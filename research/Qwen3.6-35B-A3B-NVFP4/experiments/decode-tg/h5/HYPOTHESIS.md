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
| run-0001 | arena-v2 grid, `max_model_len` 262144 | the board-comparable figure | | | | |

## Conclusion

<pending>
