# depth-curve — is our decode advantage a level or a slope?

## Objective

Measure `tg` as a function of context depth on our own instrument, and say
whether our position against the vLLM board is a constant offset or a slope
difference.

We hold exactly one point: 119.6 t/s at `tg128 @ d16384 c1`, against the two
vLLM board entries at 116.03 and 93.84. From one point we cannot tell whether
we sit above their whole curve or merely cross it at one depth, and the board
scores seven depths.

The board says vLLM decode is nearly flat with depth — `1199b578` reads 118.91
at d0, 116.03 at d16384, 114.92 at d32768, a 3.4% decline across an 8x change
in context. If ours is flat too, our c1 advantage generalises and d16384 was a
fair place to be looking. If ours slopes, then d16384 is where the two curves
happen to cross and our advantage disappears somewhere we have never measured.

Reached when every rung has a stable figure and the slope is stated with the
arithmetic behind it. This experiment answers a question; it does not chase a
number, and no rung's figure is a target.

## Strategy

Five rungs, one run each:

    d0  ·  d4096  ·  d8192  ·  d16384  ·  d30592

d30592 is the ceiling, not a choice: `max_model_len` is 32768 and the cell also
carries pp 2048 and tg 128, so 30592 is the deepest legal context. The board's
d65535 and d100000 cells cannot run here without raising `max_model_len`, which
is a new epoch and out of scope for this experiment.

Memory already holds two readings of this question and **they contradict each
other**, both scoped `family:qwen3.6-35b-a3b`:

    Depth is NOT flat for Qwen3.6-35B-A3B-NVFP4 tg128 c1: under ONE engine
    start at runs=7, d16384 reads 113.06 and d65536 reads 94.10, a 16% gap

    Decode throughput at c1 is FLAT within noise from d16384 to d65536:
    102.2 at d16384 vs 108.15 at d65536, a 5.8% gap against sigma of 10-

Same model, same cell, opposite conclusions — and the second one names its own
weakness, a sigma of 10 against a 5.8% gap. Neither was measured with a pinned
prompt, per-cell corpus offsets, or an interquartile verdict, and the earlier
epochs had the memory embedder resident on the card. That is the case for
running this experiment rather than reading the answer off memory: the question
has been asked twice and answered both ways on an instrument that could not
separate a 6% effect from its own noise.

Our own box has since answered a nearby question, and it favours flat. On
2026-08-23 a partial arena-v2 sweep (`bench_e86574ff0e1e`, 12 of 28 cells before
it was killed) read `tg` at c1 of **101.6 at d0 and 96.2 at d65535** — a 5.3%
decline across four times this ladder's span. It is not this experiment's
answer and cannot be: it ran arena's protocol, not ours — warm cache, `runs: 3`,
no `exact_tg`, no pinned prompt, sampling from the checkpoint — and at
`max_model_len 262144`, the far side of an epoch break from every rung here.
What it does is set the expectation: the effect this ladder is looking for is
small, which is exactly why the rule below has to be sized against our own
scatter rather than against a round number.

The same sweep is the only concurrency data the tree holds, and it is not
comparable either: `max_num_seqs 4` means its c5 and c10 cells queue rather
than batch.

Rungs must not contaminate each other, and our own instrument was worse than
the board's at this until recently. Sliced from token zero, a shallow rung's
prompt is a leading substring of a deeper one's, so the rungs would donate
prefix-cache blocks to each other. As of `4530cb3` each cell slices from an
offset derived from `(pp, depth)`, so rungs are disjoint while each stays
reproducible. That re-bases d16384: decode-tg's runs 0001-0008 sliced from
token zero and this rung does not, so its figure replaces 119.6 rather than
continuing it.

The levers this experiment can open, once the shape is known: `--kv-cache-dtype`
and `--attention-backend` both act on the 10 full-attention layers, which are
exactly the depth-dependent ones. What the curve does decides whether either is
worth a round.

## Held

- One node, one GB10. No ray, no tensor parallel above 1.
- The checkpoint pinned in `docs/model-card.md`.
- The container image and its vLLM and flashinfer commits.
- `pp 2048 · tg 128 · concurrency 1`, and `runs 7` as the floor. **Depth is the
  variable** — it is the only field that moves across rungs, and everything else
  in the recipe is what decode-tg holds. A rung the decision rule reads directly
  carries `runs 9`: the verdict rests on those two medians, and repeats are
  cheaper than a re-run. (Until 2026-08-23 this said `runs 7` flat, before
  per-rung repeats were available.)
- One rung per run directory, each with its own server. Rungs are compared to
  each other, so none may inherit another's cache or heat.
- The measurement protocol, which is part of the epoch: `exact_tg`,
  `extra_body temperature=0`, `no_adapt_prompt`, the per-cell fixed corpus, and
  `post_run_cmd` resetting the prefix cache between runs.
- The memory stack's embedder is down for every run — it is a vLLM instance on
  the same card.
- Nothing is submitted to Spark Arena.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | decode is flat with depth, as the board's vLLM entries are | pending |

## Conclusion

Pending.
