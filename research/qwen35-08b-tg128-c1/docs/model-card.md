# Model card — Qwen/Qwen3.5-0.8B

Source: https://huggingface.co/Qwen/Qwen3.5-0.8B (checkpoint served verbatim
by the arena recipe; BF16, no quantization).

- Dense decoder (no MoE — the MoE kernel sub-space does not apply).
- ~0.8B params, BF16 → ~1.6 GB weights; loads in seconds, so rounds are
  fast: this experiment doubles as the harness shakedown.
- Declared context 262144 (recipe serves full length; KV sized for it at
  bf16 unless overridden — a known lever: our cell needs ~136 tokens).
- Qwen3.5 generation: hybrid reasoning family; GQA attention. Head-dim
  compatibility with flash_attn on sm_121a proven by the arena run itself.
- No MTP layers at this size — speculative decoding would need ngram or a
  draft model; at 0.8B decode is already cheap, expect thin gains.
- Small model ⇒ decode is memory-bandwidth-light and overhead-heavy:
  scheduler/step overhead, CUDA-graph coverage, and sampling cost dominate
  tok/s more than kernels do. Tune there first.
