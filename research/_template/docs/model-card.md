# Model card — <model>

Distill from the HF model card + config.json before round 1. The agent needs:

- Architecture: dense or MoE (experts/active), attention type, head dims,
  layers — decides which vLLM sub-spaces apply (MoE kernels, spec-decode
  support, attention backend head-dim coverage on sm_121a)
- Quantization of this checkpoint and what serves it (nvfp4/fp8/awq…)
- Declared context length vs what the cell needs (--max-model-len headroom)
- Native speculative decoding (MTP layers?) or a known-good draft model
- Tokenizer notes, weight size on disk, expected load time
