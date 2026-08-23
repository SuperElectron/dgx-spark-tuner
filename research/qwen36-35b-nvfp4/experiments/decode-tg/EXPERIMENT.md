# decode-tg — raise single-stream decode, measured against ourselves

## Objective

`tg` at `tg128 @ d16384 c1`, under the protocol in Held. The best figure that
protocol has produced is 118.9 (h1 run-0005).

Reached when: a recipe holds `tg` at or above **125** — 118.9 plus 5% — over a
full `runs: 7` grid, **and** that run reads stable, `tg` max/min at or below
1.10. A target claimed on a median while the samples scatter is not reached.

This said 116.03 until 2026-08-23, the best vLLM NVFP4 entry at this cell. That
was the wrong target — not because the figure is wrong but because it is not
the same quantity. Its `±` is a population standard deviation over three
requests inside one invocation; ours is across invocations. It was produced at
cell 14 of a 28-cell sweep, in one continuous server process, with warmup
suppressed after the first cell, no fixed output length, no sampling
parameters, and resumption across interruptions explicitly sanctioned. Seven
documented differences, none of them ours to close.

We read 116.2 before changing anything and 118.9 after, which is most of what
that comparison was ever worth.

Beating the board is still worth doing, and it needs its own experiment
starting from `@official/spark-arena-v2` run unmodified, so there is a number
measured the way theirs was. It is not this experiment's close condition.

## Strategy

We do not have to guess the levers. The reference recipe is public and it is
almost our recipe. Diffed 2026-08-23, everything it does that we do not:

    gpu_memory_utilization      0.65    vs ours 0.8
    max_model_len             262144    vs ours 32768
    max_num_batched_tokens     32768    vs ours 65536
    --override-generation-config        temp 0.6, top_p 0.95, top_k 20
    --default-chat-template-kwargs      preserve_thinking: true
    mods                                fix-qwen3.6-chat-template

Everything else is identical, field for field: `kv-cache-dtype fp8`,
`--attention-backend flashinfer`, `--moe-backend marlin`, `max_num_seqs 4`,
MTP depth 3 on triton, chunked prefill, async scheduling, prefix caching,
fastsafetensors, `VLLM_MARLIN_USE_ATOMIC_ADD=1`.

So the +13.7% lives in three numbers and a sampling config, not in the
mechanisms worth theorising about. KV cache format in particular is settled:
the recipe that beats us runs the same `fp8` we do.

The second signal is larger than the first. Their prefill at this cell is
1414.86 ± 7.14 against our 630.0 — 2.25x — and their decode spread is 3.1%
against our 20%. Whatever separates us is not a decode-side micro-lever; it
shows up hardest in prefill and in measurement stability.
`max_num_batched_tokens` governs how a long prompt is chunked and
`max_model_len` governs how much KV is reserved, so both touch prefill
directly. That is where a 2.25x can plausibly come from, and a decode win may
follow it rather than lead it.

Ceilings: the three numbers together are worth the whole gap if the diff is the
whole story, since they are all that separates us from a recipe measured at
116.03. If they are not, what remains is the sampling config — `top_k 20`
bounds the sampling work per token — and then the attention kernel, which has
never been varied on this box.

Measured scatter, per cell — what a decision rule here has to clear:

    tg128 @ d16384 c1: tg max/min 1.31, pp 1.02   (h1 run-0001, MTP on)
    tg128 @ d16384 c1: tg max/min 1.01, pp 1.02   (h1 run-0003, MTP off)

Speculation is the scatter. Removing it collapses `tg` standard deviation from
8.6 to 0.24 — a 36-fold drop — while `pp` does not move. It also costs 36% of
decode and returns 3.8x on prefill and time-to-first-token, so MTP stays; but
every `tg` figure here is drawn from a distribution it widens. Triton JIT was
the earlier suspect and is ruled out: the compilations fire inside llama-benchy's
warmup requests, before the timed runs.

The reference recipe runs the same MTP settings at a much tighter spread, so
25% is not what MTP costs by necessity. What differs is the protocol — see
Held. That comparison is also weaker than it looks: the board's figure is a
population standard deviation over three requests *within* one invocation,
while ours is across invocations. They are not the same quantity.

Everything measured before 2026-08-23 sits on the far side of two epoch breaks:
the memory embedder was resident on the card, and the measurement protocol in
Held did not exist.

## Held

- One node, one GB10. No ray, no tensor parallel above 1.
- The checkpoint pinned in `docs/model-card.md`.
- The container image and its vLLM and flashinfer commits. A change to any of
  them is a new epoch and reopens every figure above.
- The cell: `pp 2048 · tg 128 · depth 16384 · concurrency 1`. This is what the
  Objective is stated in. The experiment's `recipe.yaml` narrows the model
  baseline's grid to it — c1 only, and `runs: 7`, because a rule stated on
  interquartile range needs more than three values to evaluate.
- The measurement protocol, which is part of the recipe and therefore part of
  the epoch: `exact_tg` pins every request to exactly 128 generated tokens,
  `extra_body temperature=0` removes sampling variance, and `post_run_cmd`
  resets the prefix cache between runs. The memory stack's embedder is down for
  every run — it is a vLLM instance on the same card.
- Nothing is submitted to Spark Arena.

Everything else in the recipe is open to some round. What a given round holds
constant it says in its own Method.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | The three numeric fields the reference recipe differs on are the whole gap | pending |

If h1 lands short, the sampling config is next, then the attention kernel.

## Conclusion

Pending.
