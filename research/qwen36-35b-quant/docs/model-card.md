# Model card — Qwen3.6-35B-A3B (BF16 / FP8 / NVFP4)

One doc for all three checkpoints in the quant tradeoff study. Distilled from
the HF model cards and raw `config.json` files, accessed 2026-08-21.

Sources:

- https://huggingface.co/Qwen/Qwen3.6-35B-A3B (BF16 base)
- https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8
- https://huggingface.co/nvidia/Qwen3.6-35B-A3B-NVFP4
- Raw configs: `<repo>/raw/main/config.json` for each; sizes/param dtype
  breakdowns from `https://huggingface.co/api/models/<id>` safetensors metadata.

## Shared architecture (all three checkpoints)

Same base model; the quants differ only in weight storage.

- `Qwen3_5MoeForConditionalGeneration`, model_type `qwen3_5_moe` — despite the
  text-sounding name this is a multimodal architecture: the config carries a
  vision tower (27 blocks, hidden 1152) plus image/video token ids.
- MoE: 35B total params, ~3B active. 256 routed experts, 8 active per token
  + 1 always-on shared expert. moe_intermediate_size 512, shared expert 512.
- 40 layers, hybrid attention: `full_attention_interval: 4` — every 4th layer
  is full GQA attention (16 Q heads, 2 KV heads, head_dim 256 → tiny KV
  cache), the other 30 layers are Gated DeltaNet linear attention
  (16 K / 32 V linear heads, head_dim 128, conv kernel 4). Card notation:
  `10 × (3 × (Gated DeltaNet → MoE) → 1 × (Gated Attention → MoE))`.
- MTP: 1 native multi-token-prediction layer (`mtp_num_hidden_layers: 1`,
  shared embeddings), trained multi-step — this is what the recipe's
  `--speculative-config '{"method":"mtp",...}'` uses.
- Vocab 248,320, hidden_size 2048, embeddings NOT tied to lm_head.
- Context: 262,144 native (`max_position_embeddings`), extensible to
  ~1,010,000 with rope scaling per the card.
- License: Apache-2.0 (all three).
- Thinking mode by default; reasoning parser `qwen3`.

Recommended sampling (Qwen cards, identical for BF16 and FP8):

| mode | temp | top_p | top_k | presence_penalty |
|---|---|---|---|---|
| thinking, general | 1.0 | 0.95 | 20 | 1.5 |
| thinking, coding | 0.6 | 0.95 | 20 | 0.0 |
| non-thinking | 0.7 | 0.80 | 20 | 1.5 |

(The NVIDIA card evaluated with temperature=1.0, top_p=0.95. For the T4
quality runs we still decode greedy for determinism — that is a deliberate
departure from the cards, same for every quant, so deltas stay comparable.)

## Per-checkpoint quantization structure

### Qwen/Qwen3.6-35B-A3B (BF16 reference)

- Everything BF16: 35.95B params ≈ 71.9 GB weights on disk.
- Fits the 128GB Spark at our d16384 cell, per the phase plan; no
  quantization_config, so the recipe copy must drop quant-specific flags.

### Qwen/Qwen3.6-35B-A3B-FP8

- `quant_method: fp8`, fmt e4m3, fine-grained `weight_block_size [128,128]`,
  `activation_scheme: dynamic`.
- FP8 covers: 34.45B params — attention projections (both full-attention
  q/k/v/o and DeltaNet in_proj/out_proj linears) AND all expert + shared
  expert FFN weights.
- Stays BF16 (1.50B params): embed_tokens, lm_head, router gates
  (`mlp.gate`, `shared_expert_gate`), all norms, DeltaNet non-GEMM params
  (A_log, conv1d, dt_bias, in_proj_a/b/ba), the whole vision tower, and the
  whole MTP module.
- ≈ 37.5 GB weights. Card claims quality "nearly identical" to BF16.
- No KV-cache dtype guidance on the card.

### nvidia/Qwen3.6-35B-A3B-NVFP4

- modelopt 0.37.0, `quant_algo: MIXED_PRECISION` — two groups, not pure FP4:
  - **W4A16_NVFP4, group_size 16**: all routed-expert FFNs, shared-expert
    gate/up/down, and — unlike the FP8 checkpoint — **lm_head**.
  - **FP8 (static)**: every attention linear (full-attention q/k/v/o and
    DeltaNet in_proj_qkv/in_proj_z/out_proj).
- Stays BF16 (1.83B params): embed_tokens, router gates, norms, DeltaNet
  non-GEMM params, vision tower, and the entire MTP module
  (`ignore: ["mtp.layers.0*", "mtp*"]`) — so MTP speculative decoding drafts
  at full precision.
- `kv_cache_quant_algo: null` in the config; fp8 KV cache comes from the
  serve command (`--kv-cache-dtype fp8`), not the checkpoint.
- ≈ 21.3 GB weights (sparkrun estimates 21.82 GB), ~3.06x smaller than BF16.
- Card serve example: `vllm serve nvidia/Qwen3.6-35B-A3B-NVFP4 --port 8000
  --quantization modelopt --max-model-len 262144 --reasoning-parser qwen3`.

Implication for the study: NVFP4's quality delta vs FP8 should be driven
almost entirely by the 4-bit expert FFNs and lm_head — attention is FP8 in
both, and router/embeddings are BF16 in both.

## Recipe cross-check

`uvx sparkrun show @eugr/qwen3.6-35b-a3b-nvfp4` (2026-08-21) serves model
`nvidia/Qwen3.6-35B-A3B-NVFP4` — **matches** the checkpoint above. No id
discrepancy. Recipe adds beyond the card's example: `--kv-cache-dtype fp8`,
flashinfer attention, marlin MoE backend (`VLLM_MARLIN_USE_ATOMIC_ADD=1`),
MTP spec-decode (3 tokens, triton moe_backend), fastsafetensors load,
tp=2 / ray (multi-node oriented; our single-box runs override this).
