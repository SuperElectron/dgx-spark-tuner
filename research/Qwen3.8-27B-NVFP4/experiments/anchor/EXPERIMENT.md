# anchor — measure our own grid against the board's leaders on the same checkpoint, and take the first cell off them

## Objective

`tg128 @ d16384`, concurrency 10, clusterSize 1, vLLM, median of the run's
values: **≥ 72.5 t/s**.

Where it stands: unmeasured by us, well measured by others on this exact
checkpoint. Read live 2026-08-29 from each submission's own `benchmarkData`,
**eight board entries serve `unsloth/Qwen3.8-27B-NVFP4` on vLLM at
clusterSize 1**. At this cell they read:

    63.05  sub1786821875313   MTP k=3, max_num_seqs UNSET   <- best like-for-like
    61.51  sub1786754097881   no speculation, max_num_seqs UNSET
    47.87  sub1786875964739   MTP k=3, max_num_seqs 4
    42.21  sub1786803355903   MTP k=3, max_num_seqs unset, gmu 0.6, no ctx caps
    33.74  sub1786810530268   MTP k=3, max_num_seqs 4
    13.09  sub1787467674993   DFlash2 k=8, max_num_seqs 4

**72.5 is the best like-for-like entry plus 15%** — the imported scatter band, so
a win cannot be noise. The roofline says it is reachable: at c10 the weights
amortize to 19.10/10 + 0.537 KV + 0.151 GDN state = 2.60 GB per token, an
aggregate ceiling of **84 t/s** at 80% of peak. 63.05 is 75% of that ceiling, so
there is real room, and it is room in bytes rather than in hope.

Reached when: the median at `tg128 @ d16384 c10` reads ≥ 72.5 t/s on a run whose
engine log confirms the served config matches the recipe, measured on the same
28-cell arena grid the board entries were measured on.

## Strategy

This is a comparative campaign, not a blind search. Eight entries run our
checkpoint on our runtime at our cluster size, they publish their full recipes,
and they disagree with each other by 5x at the Objective's cell. **The spread
between them is the map of the lever space**, and reading it is cheaper than
discovering it.

What the published recipes already say:

- **Capping admission is what separates the pack from the leaders.** The two
  fastest c10 entries (63.05, 61.51) both leave `max_num_seqs` **unset**, at
  vLLM's default. Every entry that pins it to 4 lands at 33.74-47.87, and the
  one that pins it to 1 lands at 14.28. This inverts the assumption this
  experiment was first written with — the lever is not "raise the cap", it is
  "do not impose one". Our recipe already leaves it unset, so h1 starts on the
  right side of it and must *record what the engine resolves it to*.
- **Speculation is worth much less here than the cycle arithmetic implies.** At
  `d16384 c1` the no-spec entry reads 11.19 and the MTP k=3 entries read
  16.13-18.52 — 1.44-1.65x, against the 2.2x implied by ~2.9 of 4 accepted. And
  at c10 speculation is nearly free either way: 63.05 with MTP against 61.51
  without. Acceptance on this checkpoint is evidently well below the MoE's.
- **DFlash2 wins c1 and loses c10 badly.** The Inferact/DFlash2 entries take
  29.15 at c1 and collapse to 13-15 at c10. It is also not reachable from a
  stock image — it needs a locally built `vllm-node-dflash2` on vLLM mainline
  `b389ac2` plus the `z-lab` draft — so it is out of scope for this experiment
  and belongs to a later one if at all.
- **Nobody pins a checkpoint revision.** No submission carries a `revision`
  field. Ours does, in Held.

The roofline is validated rather than assumed: 19.10 GB per forward against
273 GB/s predicts 11.4 t/s unspeculated at 80% of peak, and `sub1786754097881`
measured 11.19 on the same checkpoint. Agreement to 2%. **That gives every
no-speculation arm in this experiment a known cell to reproduce, and a probe
that does not reproduce it is broken rather than interesting.**

The nearest reproducible twin is `sub1786821875313` — our checkpoint, MTP k=3,
`kv-cache-dtype fp8`, `attention-backend flashinfer`, `load-format
instanttensor`, `gpu-memory-utilization 0.8`, no `max_num_seqs`, on the **public
pinned** image `dgx-vllm-eugr-nightly:2026081501`. It differs from our
`recipe.yaml` in exactly three places: `max_model_len` 131072 against our
262144, `max_num_batched_tokens` 32768 against our 16384, and it sets
`VLLM_MARLIN_USE_ATOMIC_ADD=1`. Those three are the first hypotheses this
experiment has, and they are hypotheses because a twin measured 63.05 with them.

Measured scatter, per cell — what a decision rule here has to clear:

    tg128 @ d16384 c10 (this model): UNMEASURED. h1's sweep measures it.

Imported priors, to be replaced by our own the moment they exist:

    tg128 @ d16384 c1, MTP on:   ±15%     (Qwen3.6-35B-A3B-NVFP4, concurrency/h1)
    tg, MTP on vs off:           σ 8.6 vs 0.24 — speculation widens tg ~36x
    board's own c10 spread:      ±0.5-0.9 on 61-63 (sub1786821875313 ±0.55,
                                 sub1786754097881 ±0.49) — far tighter than our
                                 c1 prior, which is consistent with the tree's
                                 finding that c>1 cells resolve in ~3 runs and
                                 c1 cells need 7+

## Held

- Box `spark-6f0e`, container image digest `sha256:4894c3f1…3818990`, vLLM
  `0.27.2rc1.dev360+ge85d1b69c`, flashinfer `0.6.18`, llama-benchy `0.4.0`. Any
  change is a new epoch and re-bases every figure here.
- Checkpoint `unsloth/Qwen3.8-27B-NVFP4` at sha
  `57926baca9a82b4d6906b43f2750d55315f5b10f`, single node, TP=1, `vllm-node`.
  Changing the checkpoint is a different experiment. No board entry pins a
  revision; we do, because the repo was last modified 2026-08-29.
- Runtime is vLLM from the arena image. SGLang, DFlash2 and any locally-built
  image are out of scope — a result we cannot reproduce from a public pinned
  image is not a result this tree can defend.
- Scored on `tg` only. `pp` and `ttfr` are recorded; ours are cold-cache and
  comparable to nothing on the board.
- Prompt pinned: `no_adapt_prompt: true` — verified against sparkrun's adapter,
  where it is a `_BOOL_ARGS` member and renders as the bare flag.

  **Generation length is deliberately NOT forced in this experiment.**
  llama-benchy has `--exact-tg`, which sends `min_tokens=<tg>` and
  `ignore_eos=true` and would guarantee every request emits exactly 128 tokens —
  the direct fix for the early-EOS short returns that biased 13 of 60 cells on
  LFM2.5. It is held off because this experiment's whole purpose is to sit
  beside eight board entries measured without it, and forcing length changes
  what `tg` means. **Every round here therefore reports short-return counts per
  cell as a validity gate.** If they are material, that is a finding, and
  turning `exact_tg` on is an epoch break to be declared, not a quiet fix.

  Sampling parameters are likewise unset: llama-benchy exposes no
  temperature/top_p/top_k/seed argument, only `--extra-body` for arbitrary JSON.
  Generation is therefore governed by the checkpoint's own
  `generation_config.json`, unrecorded — the same as every board entry.
- Medians, never the means `run.py` prints.
- **Cell order is depth-major ascending**, 28 cells against one running server,
  and it is held for every round that runs a schedule. Order decides what is
  warm and what is hot, and no figure reveals which order produced it. Note this
  is *not* the board's own order — arena uses a heat-aware `bucket_43521_seed42`
  schedule in which `d16384 c1` sits at index 13 of 28, measured mid-sweep and
  warm. Ours is a different order, so cell-by-cell comparison to a board entry
  carries that systematic and must say so.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | baseline sweep — our recipe over the board's own 28-cell grid, to place every cell of ours beside the eight like-for-like entries and measure our scatter | LEVER SPENT — 11.22 t/s at the objective cell, under the 55.0 floor. c1 is healthy at 16.96 (inside the board's 16.13-18.52); only c10 collapses. Engine ran 10 / waited 9 with `max_num_seqs` resolved to 256, so `max_num_batched_tokens` 16384 gates admission against a per-request prefill of 18432. Our c10 scatter is 0.9% of median |
| h2 | `max_num_batched_tokens` — raise the token budget off 16384 so a c10 batch at d16384 can be admitted at all | pending |

Later rounds are motivated by h1's deltas, not pre-committed. The three standing
candidates from the twin's recipe — `max_num_batched_tokens` 32768,
`max_model_len` 131072, `VLLM_MARLIN_USE_ATOMIC_ADD=1` — are named in Strategy
so that h1 is not tempted to test them; h1 measures, it does not tune.

## Conclusion

<pending — written when the objective is reached or the levers are exhausted>
