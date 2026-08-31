# vLLM's own recipe, and where ours diverges

Source: https://recipes.vllm.ai/Qwen/Qwen3.8-27B — read in-browser 2026-08-30,
page updated 2026-08-27. Their recommendation, not our measurement.

## No GB10 on the page

Listed hardware — `●` = author-verified:

    NVIDIA   H100 80G · H200 141G · B200 180G · GB200 NVL4 192G · B300 268G
             GB300 NVL4 288G ● · RTX 5090 32G ● (2x) · RTX 5090 32G ● (1x)
    AMD      MI300X 192G · MI325X 256G · MI355X 288G
    HUAWEI   Ascend 950PR 128G

Three different "closest", on three axes:

- **Kernel path — RTX 5090 (sm120).** The page: vLLM selects
  `FlashInferCutlassNvFp4LinearKernel` for NVFP4 GEMM on sm120, "a cutlass path,
  not an emulation fallback". Our h1 engine log printed that exact string. GB10
  is sm121, one step over, same path. The 2x5090 section is also the only place
  our checkpoint is benchmarked.
- **Shape — Ascend 950PR.** 128 GB single card, TP1, MTP k=3, and its recipe
  runs `--max-num-batched-tokens 16384`, the value h1 ran. Wrong ISA.
- **Capacity — H200 141G.** But HBM3e ~4.8 TB/s against our 273 GB/s.

**Consequence: no throughput figure on that page transfers to us.** They are all
from memory systems an order of magnitude faster. Kernel selection and MTP
acceptance are what transfer.

## The command the page emits for our configuration

NVFP4 · TP1 · Spec Decoding · Text Only, marked *Verified on NVIDIA RTX 5090*:

    vllm serve Inferact/Qwen3.8-27B-NVFP4 \
      --tensor-parallel-size 1 --enable-auto-tool-choice \
      --tool-call-parser qwen3_coder --reasoning-parser qwen3 \
      --speculative-config '{"method":"mtp","num_speculative_tokens":3}' \
      --language-model-only

## Where our recipe diverges

- **`--language-model-only` — we do not set it.** This is what the page's "Text
  Only" toggle emits: skip loading the vision encoder. Their 1x5090 figures —
  KV pool 91,022 tokens, **135,926 adding it (+49%)**, 152,917 also capping
  `--max-num-seqs 8`. We load a 0.858 GiB vision tower on every boot and never
  send an image. Board entry `sub1786766781072` uses it. **A recipe-level arm,
  checkpoint untouched.**
- **We chose the NVFP4 build the page recommends against for latency.** Its
  default NVFP4 is `Inferact`, not unsloth. Measured at 262K context:

        precision           KV tokens   weights/GPU   MTP acceptance
        FP8                   377,456      14.28 GiB       0.771
        NVFP4 (Inferact)      445,875      12.02 GiB       0.897
        NVFP4 (unsloth)       920,517      10.64 GiB       0.788   <- ours

  Their words: unsloth "leaves room for roughly twice the KV cache, while the
  uniform-W4A4 Inferact build drafts better." **That trade is decisive on a
  32 GB card and vacuous on 121 GiB unified** — h1 measured 66.12 GiB of KV,
  1,865,762 tokens, against a grid whose deepest cell needs ~10. We bought KV
  headroom we cannot spend and paid in drafting, on the exact axis where our
  rounds are losing. Belongs to `quant-tradeoff`, or to a decision to re-baseline.
- **`transformers >= 5.8.0` is a stated prerequisite**, matching the version
  `config.json` was written by, for the Qwen3-VL processor classes. **Unverified
  in our image.**

## Where our recipe already agrees

- `--reasoning-parser qwen3` — the page calls it "not optional in practice": the
  chat template opens every assistant turn with `<think>`, so without it the
  whole reasoning block lands in `message.content`.
- `--kv-cache-dtype fp8`, TP1, `--tool-call-parser qwen3_coder`,
  `--enable-auto-tool-choice`, `--mm-encoder-tp-mode data`.
- `--max-model-len 262144` is the page's own recommendation and the model's
  native window. **The twin's 131072 is the deviation, not ours** — relevant to
  any round tempted to chase it.

## Retracted

- Earlier note that our grid running at temperature 1.0 / top_p 0.95 / top_k 20
  was a protocol defect. **It is not.** The page states `generation_config.json`
  ships exactly those and its own client example uses them. Intended
  configuration, and every board entry inherits it.

## Open

- **Acceptance disagreement.** Page: unsloth 0.788. Our h1: **0.439** overall
  (`vllm:spec_decode_num_{accepted,draft}_tokens_total`, 1298 frames). Ours is
  averaged over a 28-cell grid weighted to deep and high-concurrency cells;
  theirs is presumably light load. **Read acceptance at c1 alone before treating
  0.439 as this checkpoint's number.**
- The page gives **no** `--max-num-batched-tokens` and **no** `--max-num-seqs`
  guidance for NVIDIA, so it supports neither side of h2.

## Levers named on the page, not yet tried here

- `--language-model-only` — above.
- `--default-chat-template-kwargs '{"enable_thinking": false}'` or
  `'{"reasoning_effort": "low|medium|xhigh"}'`; **xhigh is the default**, so
  every cell measured so far generated reasoning tokens at maximum effort.
- 1M context via `--hf-overrides '{"text_config": {"max_position_embeddings":
  1010000}}'` — note the nesting under `text_config`.
- DFlash2 (`incoai/Qwen3.8-27B-DFlash2`, k=7) needs vLLM PR #52816 — out of
  scope while Held pins us to public pinned images.
