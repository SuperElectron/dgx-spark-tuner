# h1 — decode is flat with depth

## Hypothesis

`tg` at c1 declines by less than 10% from d0 to d30592, matching the shape the
board's vLLM entries show rather than a KV-bound decline.

The argument is arithmetic on what a decode step actually reads. Per forward
the model reads ~2.25 GB of weights — 1.02 GB across the 30 linear-attention
layers, 0.27 GB across the 10 full-attention layers, 0.64 GB of active MoE
experts, and 0.29 GB of `lm_head`. KV is paid on the 10 full-attention layers
only: 2 kv-heads x 256 head-dim x 2 x 1 byte fp8 = 10.2 KB per token, so 168 MB
at d16384 and 313 MB at d30592. The 30 linear-attention layers carry a
recurrent state instead, and that state is constant in context length.

So KV goes from ~0% of the read at d0 to ~7% at d16384 to ~12% at d30592. If
decode is bandwidth-bound, that predicts a decline of roughly the same order —
single-digit percent across the ladder — and not the steep decay a full-KV
transformer would show.

The board corroborates the shape on a different instrument: `1199b578` declines
3.4% from d0 to d32768 while the Atlas entries, which quantize KV to nvfp4 and
run a different runtime, fall 218.85 to 112.39 over the same span.

Worth, if right: it closes the attention-side levers for this objective. If
decode is flat, `--kv-cache-dtype` and `--attention-backend` can only touch the
10 depth-dependent layers of 40, and the ceiling is weight-read bandwidth and
per-step overhead — which points every future round at the MoE path, the draft
path and the scheduler instead. If it is wrong and decode slopes, those
attention levers are live and worth rounds.

## Method

### Variables to test

    depth: 0, 4096, 8192, 16384, 30592

One run directory per rung, run in that order. Nothing else moves.

One run per rung rather than one grid, for two reasons. The fixed corpus is
sized from the largest cell in a grid, so a multi-rung grid would pin only the
deepest and let every shallower rung jitter — `run.py` refuses such a grid
outright. And a separate run means a separate server, so no rung can leave
state for another. It costs ~17 minutes against ~7 for a single schedule, and
the whole reason our `tg` is readable is the pinned prompt.

d0 is the important rung and the cheapest. It is the only one with no KV term
at all, so it is the intercept the whole curve is read against, and llama-benchy
skips the context-load phase there entirely — a d0 run is single-phase, which
also gives a clean reading of prefill uncontaminated by the numerator artifact
that affects every deeper cell.

### Constant for this round

Everything in Held. The per-cell corpus offset means each rung's text is fixed
and reproducible but disjoint from every other rung's, so no rung can feed
another's prefix cache.

Grid per rung:

    pp 2048 · tg 128 · concurrency 1 · runs 7

### What to record

Per rung: `tg` median and IQR, `pp` median, the true prefill rate `run.py`
prints beside it, `ttfr`, peak power, and the maximum prefix cache hit rate.

That last one matters here. Every run so far reports 0.0%, which decode-tg h2
is chasing. If h2 lands first and the cache starts hitting, this experiment's
rungs must all be measured on the same side of that fix — a curve half-measured
with a working cache and half without is not a curve.

## Decision rule

Stated on the total decline across the ladder, because that is the quantity the
Objective asks about, and evaluated on medians since each rung has its own
seven values.

- **Flat** if `tg` at d30592 is within 10% of `tg` at d0. Decode is
  depth-independent on this stack; the attention-side levers are bounded by the
  10 full-attention layers and the objective's ceiling lies elsewhere.
- **Sloped** if the decline exceeds 10% and is monotone across the rungs. KV
  read is a live term, and `--kv-cache-dtype` and the attention backend are
  worth their own rounds.
- **Neither** if the decline exceeds 10% but is not monotone. Then something
  other than depth is moving — check each rung's hit rate, peak power and IQR
  before reading anything into the shape.

A rung whose `tg` IQR exceeds 5% is not counted toward the decline until it is
re-run; an unstable rung cannot anchor a slope.

## Runs

One row per planned run. Figures blank until it is run.

| run | depth | why | tg t/s | iqr | pp t/s | prefill t/s | ttfr ms | hit % | bench |
|-----|-------|-----|--------|-----|--------|-------------|---------|-------|-------|
| run-0001 | 0 | the intercept: no KV term, single phase | | | | | | | |
| run-0002 | 4096 | first rung with a context | | | | | | | |
| run-0003 | 8192 | | | | | | | | |
| run-0004 | 16384 | re-bases the incumbent under the new corpus offset | | | | | | | |
| run-0005 | 30592 | the deepest legal context at max_model_len 32768 | | | | | | | |

## Conclusion

Pending.
