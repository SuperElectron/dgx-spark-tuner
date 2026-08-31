# Results — Qwen3.8-27B-NVFP4

## reference
Model: `unsloth/Qwen3.8-27B-NVFP4`, pinned at sha
`57926baca9a82b4d6906b43f2750d55315f5b10f`. It is the only NVFP4 build of
Qwen3.8-27B from an official source — NVIDIA publishes no Qwen3.8-27B at all,
and Qwen publishes only BF16 and FP8. Baseline: `recipe.yaml`, derived from
`@official/qwen3.8-27b-fp8-mtp-vllm` with the checkpoint swapped and the runtime
de-rayed to `vllm-node`. Board entries it is measured against are in
`docs/arena-recipe.md`; the architecture, the quantization scheme and the
roofline are in `docs/architecture.md`; the pinned upstream links, including
vLLM's own serving guide, are in `docs/model-card.md`. The instrument is
unchanged from
`../Qwen3.6-35B-A3B-NVFP4/docs/measurement.md` — same image epoch, same
llama-benchy 0.4.0.

Dense, not MoE: every forward reads every weight, 19.10 GB against the MoE's
2.25 GB. At 80% of the 273 GB/s GB10 peak that is 11.4 t/s unspeculated and
24.9 t/s under MTP(3) at the tree's measured acceptance. No expert-routing
lesson from `Qwen3.6-35B-A3B-NVFP4` transfers.

The checkpoint is `mixed-precision`: NVFP4 W4A4 for the MLP of layers 0-55, FP8
W8A8 for all attention and GDN projections, the MLP of layers 56-63, and
`lm_head`. That FP8 `lm_head` is 1.185 GiB against 0.67 in the FP4-lm_head
builds the board leaders run, and it is re-read once per speculative draft step
— a 7% cycle tax we do not control.

**Where this checkpoint can and cannot win.** At c1 the board's best
clusterSize-1 entry is 29.15 at `d16384`, above our 24.9 expectation, and the
gap is structural. At `d16384 c10` the weights amortize to 2.60 GB/token for an
aggregate ceiling of 84 t/s against a best cs=1 board entry of 63.05 — winnable
before speculation is counted. Objectives should be set accordingly.

## planned

Agreed with Mat 2026-08-29, in this order. Each opens only when the previous
closes; the shape is pre-registered so that no round's outcome decides what gets
asked next.

1. **anchor** — `tg128 @ d16384 c10` ≥ 72.5 t/s (best like-for-like board entry
   63.05, +15%; our roofline ceiling 84). h1 is a measurement round: our recipe
   over the board's own 28-cell grid, to place every cell of ours beside the
   eight entries that serve this checkpoint on vLLM at clusterSize 1. Later
   rounds are motivated by those deltas.
2. **draft-path** — why MTP buys only 1.44-1.65x here. On the board's own
   figures for this checkpoint, no-speculation reads 11.19 at `d16384 c1` and
   MTP k=3 reads 16.13-18.52, where the cycle arithmetic implies 2.2x. The
   suspect is acceptance, and the structural cause is an FP8 `lm_head` re-read
   once per draft step — 1.185 GiB against 0.67 in the FP4-lm_head builds. k=2
   has never been measured anywhere in this tree.
3. **quant-tradeoff** — correctness against bytes, not a `tg` cell.
   `sparkrun benchmark tools` (tool-eval-bench, 69 scenarios plus hard mode) is
   unmeasured by us and is the axis quantization actually breaks. unsloth
   publishes no quant-vs-BF16 eval table, and QUASAR independently measures this
   build at GPQA-Diamond 0.8763-0.8939 against the BF16 parent's 0.9141.

## results

| experiment | date | varied | won | pp t/s | tg t/s | ttfr ms | bench | outcome |
|---|---|---|---|---|---|---|---|---|
| <name> | <YYYY-MM-DD> | <field: values swept> | <field: value> | <n> | <n> | <n> | <bench_...> | <survived / failed> |
| anchor | 2026-08-30 | max_num_batched_tokens: 16384-131072; language_model_only: off/on; max_model_len: 262144/131072; VLLM_MARLIN_USE_ATOMIC_ADD: unset/1 | max_num_batched_tokens: 65536 + language_model_only: true + max_model_len: 131072 | 131.44 | 39.50 | 152682.6 | bench_aa90097c9a3d | exhausted |
