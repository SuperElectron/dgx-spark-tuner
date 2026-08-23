# decode-tg — close the gap to the best vLLM entry at our own cell

## Objective

`tg` at `tg128 @ d16384 c1`. Our baseline serves ~102 t/s. The best vLLM NVFP4
entry at this cell serves 116.03 — a gap of +13.7%.

Reached when: a recipe holds `tg` at or above 116.03 at this cell, on this box
and image, over a full `runs: 7` grid.

116.03 ± 3.61 is `@luis`, same checkpoint, vLLM, single node — the entry in
`docs/arena-recipe.md`, read from its raw log on 2026-08-23. A 3.1% spread is
tight enough for the number to mean something.

The cell's outright top is 188.47, held by LFM2.5-350M in BF16 — a different
class of model, not a target. Ranks 2-4 are our checkpoint on Atlas, a
different runtime and out of scope.

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

    tg128 @ d16384 c1: tg ±20%, pp ±2%   (ours, pilot, discarded, runs=7)
    tg128 @ d16384 c1: tg ±3.1%, pp ±0.5% (@luis raw log, same cell)

Ours is the number a rule here must clear, and the difference between the two
is itself a finding: the spread is not intrinsic to the cell. Triton JIT
compilations firing inside the measured window and MTP acceptance drifting
62-82% are the named suspects.

## Held

- One node, one GB10. No ray, no tensor parallel above 1.
- The checkpoint pinned in `docs/model-card.md`.
- The container image and its vLLM and flashinfer commits. A change to any of
  them is a new epoch and reopens every figure above.
- The cell: `pp 2048 · tg 128 · depth 16384 · concurrency 1`. This is what the
  Objective is stated in. The experiment's `recipe.yaml` narrows the model
  baseline's grid to it — c1 only, and `runs: 7`, because a rule stated on
  interquartile range needs more than three values to evaluate.
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
