https://huggingface.co/nvidia/Qwen3.6-35B-A3B-NVFP4/blob/491c2f1ea524c639598bf8fa787a93fed5a6fbce/README.md

Pinned 2026-08-23.

Everything below is tagged by what it is true of, because most of it is not
true of the checkpoint we serve alone:

    [arch]    the Qwen3.6-35B-A3B architecture. The parent's text_config is
              byte-identical to this build's — only quantization_config differs
              — so these hold for the BF16 parent and any other quantization
    [nvfp4]   this NVIDIA NVFP4 build specifically. Changes if someone
              requantizes, and the RedHatAI NVFP4 build is a different artifact
    [runtime] vLLM 0.27.2rc1.dev360+ge85d1b69c on GB10, SM121. Changes with the
              image

Read 2026-08-23 from the pinned `config.json`, `hf_quant_config.json`,
`.quant_summary.txt`, the safetensors headers (HTTP range requests), and our own
`run-0002` engine log. Byte figures come from real tensor offsets, not from
parameter counts.

## [arch] It is not a GQA transformer

`model_type qwen3_5_moe_text`. 40 layers, `full_attention_interval 4`:

    30 linear_attention   Gated-DeltaNet, recurrent state, no KV
    10 full_attention     layers 3,7,11,...,39 — the only KV layers

    hidden_size 2048   num_attention_heads 16   num_key_value_heads 2
    head_dim 256       GQA ratio 8              vocab 248320
    max_position_embeddings 262144              rope_theta 1e7

GQA is 8, not 16. An earlier note here said 16, taken from vLLM issue #37754;
that issue describes a different geometry and its flashinfer+MTP crash report
does not transfer unchecked.

A 27-block vision tower (~0.9 GB BF16, unquantized in this build) is resident
and is dead weight for a text benchmark.

## [arch] MoE

256 experts, top-8, `moe_intermediate_size` 512, plus a shared always-on expert
and a BF16 router. No dense layers — expert tensors exist for all 40. Active
params ≈ 2.94B, and that only reaches "3B" counting `lm_head`.

Load-bearing and counterintuitive: **the MoE is not the dominant read at batch
1.** The 30 linear-attention layers read 1.016 GB per forward against the entire
active MoE at 0.637 GB.

## [arch] MTP

`mtp_num_hidden_layers: 1` — one layer, looped N times by vLLM, sharing
`embed_tokens` and `lm_head`. No hard architectural cap; the ceiling is
statistical.

Measured per-position acceptance from our `run-0002`: 0.87 / 0.76 / 0.61.

    N   E[accepted]   cycle bytes   tokens/GB
    2      2.53          3.38 GB      0.749
    3      2.93          3.84 GB      0.764
    4     ~3.13          4.26 GB      0.736

**N=3 is optimal and beats N=2 by ~2%; N=4 loses. Settled — do not spend a
round on it.** (Cycle bytes are [nvfp4]; the acceptance rates are [arch].)

## [nvfp4] What is actually quantized

    FP8 E4M3, W8A8, per-tensor   all linear_attn projections (30 layers)
                                 all self_attn q/k/v/o (10 layers)
    NVFP4 W4A16, group_size 16   all MoE experts, shared expert, lm_head
    BF16 untouched               embeddings, routers, layernorms, conv1d,
                                 the vision tower, the entire MTP module

Two-level scaling: per-block scale in FP8 E4M3 over groups of 16 along the input
dim, plus a per-tensor FP32 `weight_scale_2`. Checkpoint is 23.4 GB.

The MTP module is excluded from quantization (`exclude_modules: ["mtp*"]`) and
is BF16 throughout. That is why `--speculative-config moe_backend triton`
differs from the target's `marlin` — the draft cannot use the NVFP4 path at all
and falls through to the unquantized dispatcher. Forced, not chosen.

KV: the checkpoint declares FP8 and we pass `--kv-cache-dtype fp8`, so the flag
agrees with the checkpoint rather than fighting it.

NVFP4 dequantizes to BF16 in-kernel. W4A16 is weight-only — it buys bandwidth,
not tensor-core throughput.

## [runtime] Flag to layer

Backend lists quoted from our own engine log, so these are what this build
offers rather than what the docs describe.

| flag | what it touches | what it trades |
|---|---|---|
| `--moe-backend marlin` | NVFP4 expert GEMMs only, all 40 layers. Offered: FLASHINFER_TRTLLM/CUTEDSL/CUTLASS, VLLM_CUTLASS, MARLIN, HUMMING, EMULATION. `triton`/`deepgemm` are **not** in the NVFP4 list | weight-only W4A16, good at low batch; CUTLASS/TRTLLM want arithmetic intensity and should win as batch rises |
| `--attention-backend flashinfer` | **10 of 40 layers.** The 30 linear-attn layers dispatch through `vllm::qwen_gdn_attention_core` and are untouched. Only FLASHINFER and TRITON_ATTN offered | `decode_backend=xqa` is the low-batch fp8-KV decode kernel. Max blast radius on decode is a quarter of the model |
| `--kv-cache-dtype fp8` | KV of those same 10 layers. 10.2 KB/token; 168 MB at d16384 | halves KV read, doubles capacity. Does not touch the recurrent state |
| `--speculative-config moe_backend` | the draft's expert GEMMs, via the unquantized dispatcher (TRITON, BATCHED_TRITON, two FlashInfer options) | the one open flag on the draft path |
| `--enable-chunked-prefill`, `--max-num-batched-tokens` | scheduler, not a layer | inert at c1 decode; governs prefill |
| `--async-scheduling` | host loop | pure launch-latency win, matters most at batch 1 |
| `--enable-prefix-caching` | KV blocks of the 10 full-attn layers | must also handle 30 layers of recurrent state, which is not block-structured — a correctness surface, not just a speed knob |
| `--load-format fastsafetensors` | load path | startup only |
| `VLLM_MARLIN_USE_ATOMIC_ADD=1` | gates on `n < 2048 and k >= 2048`, so `gate_proj`/`up_proj` qualify and `down_proj`/`lm_head` do not | ~2 of 3 expert GEMMs; wins only at small batch |

CUDA graphs: `cudagraph_capture_sizes [1,2,4,8,16,24,32]`, `FULL_AND_PIECEWISE`,
derived as `min(max_num_seqs x (1 + num_spec_tokens) x 2, ...)` = 4x4x2 = 32.

## [nvfp4] Roofline — how much headroom decode has

Per-forward weight read, from real byte offsets:

    30 linear-attn layers    1.016 GB
    10 full-attn layers      0.273 GB
    MoE 40 x 9 experts       0.637 GB
    routers (BF16, full)     0.042 GB
    lm_head                  0.286 GB
    weights subtotal         2.254 GB
    KV @ d16384 fp8          0.168 GB
    GDN recurrent state      0.126 GB   (unverified layout, ±2x on this 5%)
    total                  ~ 2.548 GB

Our `run-0003` measured 71.07 tok/s with speculation off:

    71.07 x 2.548 GB = 181 GB/s = 66% of the 273 GB/s GB10 peak

**Bandwidth-bound but not at the roofline.** A well-tuned memory-bound kernel
reaches 80-85%, so there is ~1.2-1.3x headroom in the non-spec path — real, not
transformative.

With MTP the cycle is ~3.84 GB for ~3.1 accepted tokens = 144 GB/s = 53% of
peak. Speculation lowers bandwidth efficiency while raising throughput 1.63x.

**Biggest tunable line item is `lm_head`**: 286 MB read 4x per spec cycle
(target + 3 drafts) = 1.14 of 3.84 GB, **30% of the cycle**, to produce ~2 extra
tokens.

Second: the linear-attn projections are 1.016 GB — 40% of the forward — and are
FP8, not NVFP4. At NVFP4 they would be ~0.5 GB. NVIDIA left the single biggest
weight block at 8 bits, and it is baked into the checkpoint. This is the one
line where a different quantization of the same [arch] would change the
roofline materially.

## [arch] What changes from c1 to c10

Two of the three big terms do not amortize.

With 256 experts top-8, a 10-token batch touches
`256 x (1 - (1 - 8/256)^10)` = **69.4 distinct experts per layer** against 8 at
c1 — 8.7x the expert bytes to serve 10x the tokens, only ~14% per-token saving.
KV and recurrent state are per-sequence and do not amortize at all.

    component            c1        c10 per token
    attention weights   1.289 GB      0.129
    MoE experts         0.637         0.491
    router + shared     0.049         0.011
    lm_head             0.286         0.029
    KV (per-seq)        0.168         0.168
    GDN state (per-seq) 0.126         0.126
    total               2.548 GB    ~ 0.954

**c10 is only ~2.7x more byte-efficient per token, not 10x.** Dense attention
weights dominate at c1 and become nearly irrelevant at c10, which inverts which
flags matter: KV dtype and anything touching recurrent state gain importance,
and `--moe-backend` shifts from a low-batch dequant problem to a grouped-GEMM
throughput problem.

Prediction to test: c10 no-spec ≈ 190 tok/s aggregate (~19/stream) vs 71 at c1.

Why speculation should stop paying: at c10 with N=3 the target verifies 40
tokens, touching ~183.8 distinct experts per layer against 69.4 unspeculated —
2.65x the dominant term for at most 4x the tokens, of which ~78% are accepted.
Strongly positive at c1 (measured 1.63x), near break-even at c10. Mechanism, not
measurement.
