# Architecture, quantization and roofline

Links and pin dates are in [model-card.md](model-card.md). This file holds what
was read from them, tagged by what each line is true of:

    [arch]    the Qwen3.8-27B architecture — the parent's text_config, so true
              of every quantization of it too
    [nvfp4]   `unsloth/Qwen3.8-27B-NVFP4` specifically
    [runtime] vLLM 0.27.2rc1.dev360+ge85d1b69c on GB10, SM121, image digest
              sha256:4894c3f1…3818990. Changes with the image
    [vllm]    vLLM's own serving guide, recipes.vllm.ai, read 2026-08-30 —
              their recommendation, not our measurement

Read 2026-08-29/30 from the pinned `config.json`, from every shard's safetensors
header by HTTP range request, and from the vLLM recipes page. Byte figures are
real tensor offsets, not parameter counts.

## [arch] Dense, hybrid, and multimodal

`model_type qwen3_5`, `Qwen3_5ForConditionalGeneration`. 64 layers,
`full_attention_interval 4`:

    48 linear_attention   Gated-DeltaNet, recurrent state, no KV
    16 full_attention     the only KV layers

    hidden_size 5120      num_attention_heads 24   num_key_value_heads 4
    head_dim 256          GQA ratio 6              vocab 248320
    intermediate_size 17408                        rope_theta 1e7
    max_position_embeddings 262144                 partial_rotary_factor 0.25
    tie_word_embeddings false                      mrope_interleaved true

- **No MoE.** Every forward reads every weight — 19.10 GB against the
  Qwen3.6-35B-A3B MoE's 2.25 GB. Every expert-routing lesson in the tree is a
  dead letter here, and no `--moe-backend` exists on this path.
- **It is a vision-language model** (`image-text-to-text`): 27-block vision
  tower, `image_token_id` 248056, `video_token_id` 248057. We serve text-only,
  so the tower is resident dead weight — 0.858 GiB, unquantized, never read on a
  text forward, excluded from the roofline below. `--language-model-only` would
  skip loading it; we do not pass it. See [runtime.md](runtime.md).

## [nvfp4] What is actually quantized

Not what the name implies. `format: "mixed-precision"`, `quant_method:
compressed-tensors`, two groups:

    NVFP4 W4A4, group_size 16    mlp.(gate|up|down)_proj, layers 0-55 ONLY
    FP8 W8A8, channel/dynamic    self_attn.(q|k|v|o)_proj
                                 linear_attn.(in_proj_qkv|in_proj_z|out_proj)
                                 lm_head
                                 mlp.(gate|up|down)_proj, layers 56-63
    BF16, untouched              vision tower, linear_attn.norm/in_proj_a/
                                 in_proj_b, the entire MTP module (`re:^mtp.*`)

- The last eight layers' MLP is a deliberate sensitivity carve-out.
- `lm_head` is FP8, not FP4 — it costs on the speculative path.
- KV is baked in: `kv_cache_scheme` is `num_bits 8, float, static, tensor`, so
  `--kv-cache-dtype fp8` agrees with the checkpoint rather than fighting it.
- The MTP module survives quantization, so `--speculative-config method=mtp` is
  available.

## [nvfp4] Roofline — measured from tensor offsets

    mlp            9.837 GiB          embed         2.368 GiB  (a gather)
    gdn            5.206 GiB          vision        0.858 GiB  (never read)
    full_attn      1.563 GiB          checkpoint   21.81  GiB
    lm_head        1.185 GiB
    mtp            0.791 GiB          read only when speculating

    forward read  17.792 GiB = 19.10 GB
    ceiling at peak                     14.3 t/s
    ceiling at 80% of peak              11.4 t/s

Validated externally: board entry `sub1786754097881` runs this checkpoint on
vLLM cs=1 with no speculation and measures **11.19** at `d16384 c1`. Agreement
to 2%.

With MTP a draft step reads the MTP module plus a full `lm_head` re-read:

    draft step      0.791 + 1.185 GiB = 2.12 GB
    MTP(3) cycle    19.10 + 3 x 2.12  = 25.47 GB, up to 4 tokens

At c10 the weights amortize and the picture inverts:

    per token = 19.10/10 + 0.537 (KV fp8) + 0.151 (GDN state) = 2.60 GB
    aggregate ceiling at 80% of peak                            84 t/s

## [arch] KV

16 KV layers x 4 heads x 256 dim x 2 = **64 KB/token BF16, 32 KB at fp8**, about
3x the MoE's 22.3 KB. Per sequence: 0.134 GB at d4096, 0.268 at d8192, 0.537 at
d16384, 1.074 at d32768, all fp8. GDN recurrent state is ~0.151 GB per sequence
and does not scale with depth.

At c1 that is ~3% of the forward. At c10 it is **26%** of per-token bytes.

## MTP acceptance — three independent readings agree it is poor here

    [arch]    one-module MTP re-driven k times: first-position acceptance
              degrades with k. On the MoE, 0.87 / 0.76 / 0.61
    [vllm]    recipes.vllm.ai puts this model's MTP acceptance at 0.77-0.90
              across checkpoints, and names ours as the weak one:
              Inferact NVFP4 (uniform W4A4) 0.897 vs **unsloth 0.788**,
              "mixed-precision FP8 + 4-bit, lower acceptance"
    [nvfp4]   our own h1, 1298 SpecDecoding frames over the 28-cell grid:
              mean acceptance length median 2.400 of 4, overall accepted/drafted
              51436/117225 = 0.439, per-position 0.684 / 0.434 / 0.267

The engine warns at startup: *"Enabling num_speculative_tokens > 1 will run
multiple times of forward on same MTP layer, which may result in lower
acceptance rate."*

**So the checkpoint that gives us the smaller forward gives us the worse
drafter, and vLLM says so in print.** That is the trade the `quant-tradeoff`
experiment has to price, and it is why our MTP buys 1.44-1.65x where the cycle
arithmetic asks for 2.2x.

## [vllm] What vLLM recommends

Their recipe, the hardware analogue question, and every divergence from ours:
[runtime.md](runtime.md).

## [nvfp4] Memory

21.81 GiB of weights against a ~97.4 GiB budget at `gpu_memory_utilization 0.8`.
h1 measured it directly: `Model loading took 21.97 GiB`, `Available KV cache
memory: 66.12 GiB`, `GPU KV cache size 1,865,762 tokens`. No memory risk.

**But the engine also prints `Maximum concurrency for 262,144 tokens per
request: 7.12x`** — below the offered concurrency of 10. That is a consequence
of `max_model_len 262144` and is a standing candidate lever.

`max_num_seqs` resolves to **256** on this box, not the 1024 a >=70 GiB device
would get: `pynvml` raises `NVMLError_NotSupported` for total memory on GB10
(the same reason `nvidia-smi` prints `[N/A]`), so vLLM's `get_batch_defaults`
sees `device_memory = 0` and takes the small-device branch. Box-specific.
