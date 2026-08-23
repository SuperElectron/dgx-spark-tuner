# decode-tg — raise single-stream decode, measured against ourselves

## Objective

Maximise `tg` at `tg128 @ d16384 c1`, and understand what governs it. There is
no ceiling here on purpose — the standing best is 119.6 (h1 run-0008) and every
round exists to move it or to close a lever and say why.

Two figures, because one number cannot serve both purposes:

- **Ours** — measured under the protocol in Held, which is what makes rounds
  comparable to each other. A round improves it only with a stable verdict,
  `tg` interquartile spread at or below 5%; a median claimed while the samples
  scatter is not an improvement. (Until 2026-08-23 this was stated on max/min
  at 1.10 — an extreme-value gate drawn from two of seven samples, which drifts
  upward as `runs` grows and so punishes longer runs.)
- **Board-comparable** — measured by running `@official/spark-arena-v2`
  unmodified and reading our own `d16384/c1` row out of it. This is the only
  figure that can be set beside the board at all, and beating the board means
  beating it *there*.

Reached when both are true: no lever in Strategy remains open, and two
consecutive rounds fail to move the standing best. Then the conclusion records
how far `tg` moved, which mechanisms carried it, and which are closed and why.

Not reached by hitting any particular number, and not closed early because a
number looked good.

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

That does not mean the board is out of reach — it means we cannot tell from
these numbers whether we are ahead or behind. So the board-comparable figure
above is part of this experiment, not deferred to another one: run their
profile, read our own row, and then a claim about beating them is checkable
rather than asserted.

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
    tg128 @ d16384 c1: tg max/min 1.11, pp 1.03   (h1 run-0008, prompt pinned)

Most of that scatter was the instrument, not the box. llama-benchy's
`adapt_prompt` defaults on and shrinks the grid by the measured template
overhead, which reopens the random prompt start that the fixed corpus was meant
to close. Pinning it (run-0008) took `tg` max/min from 1.24 to 1.108 and made
`prompt_tokens` constant. What survives is engine-level: with an identical
prompt, `temperature 0` and a seed, four of seven generations are byte-identical
and three diverge — greedy decoding occasionally taking a different branch under
MTP. run-0003 bounds that residue at 1.01 with speculation off.

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
  `extra_body temperature=0` removes sampling variance, `post_run_cmd` resets
  the prefix cache between runs, and `no_adapt_prompt: true` stops llama-benchy
  rewriting the grid at warmup — without it `total_needed` shrinks by the
  template overhead, `max_start` becomes `1 + delta` instead of 1, and every run
  draws a different prompt. The trade is that the served prompt carries the
  template on top of the 18432 corpus tokens rather than hitting the nominal
  size exactly; this experiment wants reproducibility over nominal exactness.
  The memory stack's embedder is down for every run — it is a vLLM instance on
  the same card.
- Nothing is submitted to Spark Arena.

Everything else in the recipe is open to some round. What a given round holds
constant it says in its own Method.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | The three numeric fields the reference recipe differs on are the whole gap | lever spent |

h1 is spent: its three fields moved `tg` 2.0 against a larger IQR of 11.3, and
`pp` moved 0.5% — inside this cell's own 1.02 max/min — which killed the
prefill-chunking mechanism behind them.

Levers still open, in the order to take them. Reordered 2026-08-23 after the
architecture was read: this is a hybrid, 30 of its 40 layers are linear
attention with no KV, and only 10 are full attention.

1. **The prefix cache never hits** — 0.0% on every sample of every run, while
   the recipe asks for it. Phase 2 recomputes all 18446 tokens instead of
   reusing phase 1's 16400. A defect, not a tuning knob, and the largest single
   thing this experiment has found. h2.
2. **Is `tg128` a transient?** — 128 tokens is ~41 speculative cycles in ~1.1 s,
   and MTP acceptance is a running statistic. If the metric the board scores is
   partly warm-up, that reframes every figure here. Cheap, and it can invalidate
   what everything else is measured in. h3.
3. **The draft path** — the MTP module is BF16 and unquantized, and re-reads the
   286 MB `lm_head` on every draft step: 30% of the spec cycle to produce ~2
   extra tokens. The one exposed flag is the draft's `moe_backend`.
4. **The board-comparable figure** — `@official/spark-arena-v2` unmodified. Not
   a lever; it is the second figure the Objective asks for. Costs one long run,
   and needs their `max_model_len` to reach the deep cells, so it is an epoch
   break run once.

Demoted, with reasons:

- **Attention backend** — reaches 10 of 40 layers, and this build offers only
  FLASHINFER and TRITON_ATTN. Decode is also nearly flat with depth on the
  board, and depth is what attention governs. The vLLM #37754 crash report cites
  GQA=16; this checkpoint is GQA 8, so it does not transfer unchecked.
- **Speculative depth** — settled. Measured per-position acceptance
  0.87/0.76/0.61 makes N=3 optimal by ~2% over N=2, and N=4 loses.

The sampling config is no longer a lever — the protocol pins `temperature 0`
itself.

## Conclusion

Pending.
