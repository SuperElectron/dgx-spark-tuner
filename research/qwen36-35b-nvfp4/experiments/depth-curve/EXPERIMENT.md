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

One run directory per rung rather than one grid, for two reasons. The fixed
corpus is sized from the largest cell in a grid, so a multi-rung grid would pin
only the deepest and let every shallower rung jitter — `run.py` now refuses such
a grid outright. And a separate run means a separate server, so no rung can
leave state for another.

Contamination is the thing to get right here, because our own instrument made
it worse than the board's before this experiment existed. Sliced from token
zero, a shallow rung's prompt is a leading substring of a deeper one's, so the
rungs would donate prefix-cache blocks to each other and the deeper rungs would
prefill faster than they should. Arena does not have this problem: its
`adapt_prompt` and random offsets leave its cells sharing nothing. As of
`4530cb3` each cell slices from an offset derived from `(pp, depth)`, so rungs
are disjoint by construction while each stays reproducible.

That change re-bases d16384: runs 0001-0008 of decode-tg sliced from token
zero, this rung does not, so its figure replaces 119.6 as the incumbent rather
than continuing it.

What the shape would mean:

- **Flat, like theirs.** Decode is bound by something depth-independent —
  weight-read bandwidth and per-step overhead, not KV. Consistent with the
  roofline: 30 of 40 layers are linear attention whose recurrent state is
  constant in context length, and KV at d16384 is only ~168 MB against 2.25 GB
  of weights read per forward.
- **Sloped.** KV read is a real term at depth and `--kv-cache-dtype` and the
  attention backend matter more than the flat reading suggests — they touch the
  10 full-attention layers, which are exactly the depth-dependent ones.

## Held

- One node, one GB10. No ray, no tensor parallel above 1.
- The checkpoint pinned in `docs/model-card.md`.
- The container image and its vLLM and flashinfer commits.
- `pp 2048 · tg 128 · concurrency 1 · runs 7`. **Depth is the variable** — it is
  the only field that moves across rungs, and everything else in the recipe is
  what decode-tg holds.
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
