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

**One run per rung rather than one schedule, for isolation.** A separate run is
a separate server, so no rung inherits another's prefix cache or the heat it
left behind. The rungs are compared to each other and to nothing else, so that
independence is the measurement, not an overhead on it. It costs ~17 minutes
against ~7.

(Until 2026-08-23 this also cited a harness limit: the fixed corpus was sized
from the largest cell in a grid, so `run.py` refused a multi-cell grid outright.
That is no longer true — a schedule entry can carry its own `book_url` and each
cell gets its own pinned corpus. The obstacle is gone; the reason above is not,
and it is the one that decides it.)

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

d0 and d30592 run at `runs 9`. The rule is stated on those two medians and the
middle three only witness monotonicity, so the repeats belong where the verdict
is decided.

### What to record

Per rung: `tg` median and IQR, `pp` median, the true prefill rate `run.py`
prints beside it, `ttfr`, peak power, the worst repeat ratio, and the maximum
prefix cache hit rate.

The hit rate is a protocol check here, not an open question. decode-tg h2
settled it: the 0.0% every run reported was our own `post_run_cmd` resetting
the cache between runs, and h2 kept the reset because it is what makes runs
independent. So every rung should read 0.0%, and a rung that does not has lost
its reset and is not comparable to the others. d0 reads 0.0% for a second
reason — its 2048-token prompt is under this model's forced 2144-token
attention block, so it cannot hit at all, and `run.py` labels that case.

## Decision rule

Read `tg` at `pp2048 · tg128 · c1` — the cell itself, never its context-prefill
phase — from the d0 and d30592 rows. Evaluated on medians, since each rung
carries its own values.

Let **D** be the decline from d0 to d30592 as a fraction of d0, and **S** the
larger of those two rungs' `tg` interquartile spreads.

- **Flat** if D is at most 10%. Decode is depth-independent on this stack; the
  attention-side levers are bounded by the 10 full-attention layers and the
  objective's ceiling lies elsewhere.
- **Sloped** if D exceeds 10%, is monotone across the rungs, **and exceeds S**.
  KV read is a live term, and `--kv-cache-dtype` and the attention backend are
  worth their own rounds.
- **Neither** if D exceeds 10% and is not monotone. Something other than depth
  is moving — check each rung's hit rate, peak power and IQR before reading
  anything into the shape.
- **Unreadable** if D exceeds 10% but does not exceed S. The ladder cannot
  separate the effect from the scatter that produced it. Re-run both anchor
  rungs at higher `runs` before calling anything; do not report a slope.

A rung whose `tg` IQR exceeds 5% is not counted toward the decline until it is
re-run; an unstable rung cannot anchor a slope. Every rung carries at least 7
values, so an interquartile range exists at all of them.

(Amended 2026-08-23, before any rung ran. It previously had three branches and
a bare 10% threshold, with no branch for a decline that clears 10% while
sitting inside the rungs' own spread — the outcome the prior evidence makes
most likely, since the nearest measurement on this box declines 5.3% across
four times this span. A threshold that can be met by noise is not a rule.)

## Runs

One row per planned run. Figures blank until it is run.

| run | depth | runs | why | tg t/s | iqr | pp t/s | prefill t/s | ttfr ms | hit % | bench |
|-----|-------|------|-----|--------|-----|--------|-------------|---------|-------|-------|
| run-0001 | 0 | 9 | the intercept: no KV term, single phase, and the rule reads it | 114.6 | 5.1% UNSTABLE | 5695.1 | 5610.5 | 377.0 | 0.0 | bench_594c47d62013 |
| run-0002 | 4096 | 7 | first rung with a context | 110.1 | 4.2% | 1995.5 | 5933.4 | 1049.4 | 0.0 | bench_a0c409874de1 |
| run-0003 | 8192 | 7 | witnesses monotonicity | 127.0 | 5.6% UNSTABLE | 1165.8 | 5796.0 | 1779.2 | 0.0 | bench_fa59c397c082 |
| run-0004 | 16384 | 7 | re-bases the incumbent under the new corpus offset | 117.8 | 2.6% | 628.6 | 5639.4 | 3279.0 | 0.0 | bench_c003c48ede71 |
| run-0005 | 30592 | 9 | the deepest legal context at max_model_len 32768; the rule reads it — HTTP 400, one token over: prompt 32641 + tg 128 = 32769 vs max_model_len 32768 | — | — | — | — | — | — | bench_5330c0302d07 |

| run-0006 | 30591 | 9 | one token shallower than run-0005 — HTTP 400 again, at the same 32641 input tokens. The endpoint adds a token of its own, so the served prompt is pp + depth + 2 | — | — | — | — | — | — | bench_f574047b8c2e |
| run-0007 | 30464 | 9 | measured ceiling is d30590 with zero margin; this takes 126 tokens of headroom for the same rung. Stands in as the rule's deep anchor | 109.5 | 4.3% (±2.1%) | 327.1 | 5195.9 | 6270.8 | 0.0 | bench_6bd19fe9a3c2 |

run-0001 is also the first end-to-end run of the harness rewritten on
2026-08-23 — per-cell corpora, rolled progress files, schedule-aware grid
checking. It is the cheapest cell in the tree, so it proves the instrument
before the ladder spends anything on it.

## Conclusion

Pending.
