# vLLM parameters — the search space

Every `vllm serve` engine argument, grouped, annotated for our loop:
- **TUNE** — candidate for the agent's search space (affects tok/s)
- **FIXED** — part of the measurement protocol; loop must hold constant
- **N/A** — irrelevant on one GB10 / for benchmarking
- **?** — support unknown in our pinned container, verify before use

Container caveat first: we run a digest-pinned community image
(`ghcr.io/timothystewart6/vllm-gb10@sha256:fa87...`, built for sm_121a/arm64,
see `deploy/box/setup.sh`). Its vLLM version is a snapshot — flags below are
from current upstream docs and may be missing, renamed, or behave differently
in it. Known deviations already hit in practice (from runKali serving):
- `--kv-cache-memory-bytes` exists; the startup log mentions a
  `--kv-cache-memory` flag that does NOT exist in this build
- pooling runner is spelled `--runner pooling` (older builds: `--task`)
- without `--kv-cache-memory-bytes`, memory profiling on unified memory can
  measure free memory going UP and abort with "Error in memory profiling"
- no nvidia docker runtime; GPU access via CDI (`--device nvidia.com/gpu=all`)
- `vllm bench sweep` and `guidellm` are client-side tools — they don't need to
  exist inside our container, we can run them from the laptop or a venv on the box

First loop task for the agent: `vllm serve --help` inside the container, diff
against this list, mark what actually exists. That output is ledger row -1.

## 1. Memory / KV cache — the highest-leverage group on GB10 (121 GB unified pool)

| Flag | Meaning | Verdict |
|---|---|---|
| `--gpu-memory-utilization` | fraction of pool the engine may claim (default 0.92 upstream; we default 0.90) | TUNE (coarse) |
| `--kv-cache-memory-bytes` | exact KV cache size in bytes; overrides fraction-based sizing | TUNE — primary knob; also required for deterministic sizing on unified memory |
| `--kv-cache-dtype` | auto / fp8 / fp8_e4m3 / fp8_e5m2 (int8/nvfp4 ?) | TUNE — fp8 halves KV, more concurrency headroom, slight quality cost |
| `--block-size` | KV cache block granularity in tokens (16/32/…) | TUNE — small effect, cheap to test |
| `--enable-prefix-caching` | reuse KV across requests with shared prefixes | TUNE — benchmark prompts may or may not share prefixes; can add overhead |
| `--cpu-offload-gb` | offload weights/KV to "CPU" memory | N/A — one unified pool here, offloading to itself is meaningless (verify it doesn't help via page-cache effects — probably noise) |
| `--swap-space` | CPU swap for beam search etc. | N/A |
| `--watermark` | KV headroom fraction | TUNE (fine-tuning stage only) |

## 2. Scheduler / batching — second-highest leverage

| Flag | Meaning | Verdict |
|---|---|---|
| `--max-num-batched-tokens` | token budget per engine step; big = throughput, costs TTFT + activation memory | TUNE — known sensitive (runKali used 8192–16384) |
| `--max-num-seqs` | max concurrent sequences per step | TUNE — interacts with concurrency of the test |
| `--enable-chunked-prefill` | split long prefills across steps, interleave with decode | TUNE — matters exactly at our deep-context cells (d16384+) |
| `--max-model-len` | context window the engine sizes KV for | FIXED per test type — must cover the test's depth; smaller = more KV headroom, so set to test requirement, not checkpoint max |
| `--scheduling-policy` | fcfs / priority | FIXED (fcfs) — priority irrelevant for uniform benchmark load |
| `--num-scheduler-steps` (multi-step scheduling) | amortize scheduler overhead over N steps | TUNE ? — may not exist in this build / V1 engine |
| `--scheduler-delay-factor` | delay scheduling for batching | TUNE ? — small |
| `--preemption-mode` | recompute vs swap on preemption | FIXED — with right KV sizing, preemption shouldn't fire; if it does, that's a crash-class signal |

## 3. Attention backend

| Flag | Meaning | Verdict |
|---|---|---|
| `--attention-backend` (or `VLLM_ATTENTION_BACKEND` env) | FLASH_ATTN / FLASHINFER / TRITON_ATTN / FLEX_ATTENTION / XFORMERS | TUNE — few discrete values, potentially large deltas. sm_121a support is patchy: flashinfer lacks some head-dims on this arch; TRITON_ATTN is the known-good fallback (runKali lore). Wrong kernel can corrupt output silently → quality gate matters |

## 4. Quantization (weights)

| Flag | Meaning | Verdict |
|---|---|---|
| `--quantization` | awq / gptq / fp8 / nvfp4 / bitsandbytes / … | FIXED per experiment — you fixed model+quantization as a protocol dimension. Changing quant = changing the model = new loop. (Also: leaderboard entries name the checkpoint, e.g. NVFP4 builds) |
| `--dtype` | weight/activation dtype for unquantized models | FIXED per experiment (same reason) |
| `--quantization-config` | per-layer specs | N/A for v1 |

## 5. Speculative decoding — big potential wins at low concurrency

| Flag | Meaning | Verdict |
|---|---|---|
| `--speculative-config` (JSON: method, model, num_speculative_tokens, …) | draft-and-verify decoding: ngram / eagle / medusa / draft-model / MTP | TUNE — one of the richest sub-spaces. MTP-style spec decode is exactly what top arena recipes use. num_speculative_tokens is a classic hill-climb knob (2→3→4…) |
| spec-decode × attention-backend interactions | | expect crashes; crashes are data |

Note: helps most at concurrency 1–2 (our headline cells), can HURT at high
concurrency (wasted draft compute when batches are full). Concurrency is a
fixed protocol dim, so the loop will find spec-decode's value per cell honestly.

## 6. Compilation / CUDA graphs

| Flag | Meaning | Verdict |
|---|---|---|
| `-O` / `--compilation-config` (level, custom ops, inductor) | torch.compile level 0–3 | TUNE ? — startup cost per round (compile time), but steady-state gains; our fixed boot budget absorbs it. Verify supported in container |
| `--cudagraph-capture-sizes` / `--max-cudagraph-capture-size` | which batch sizes get CUDA graphs | TUNE ? — decode speed at small batch is graph-sensitive |
| `--enforce-eager` | disable CUDA graphs entirely | TUNE (as the off-switch for the above; expected slower, but a clean ablation) |

## 7. Parallelism

| Flag | Meaning | Verdict |
|---|---|---|
| `--tensor-parallel-size`, `--pipeline-parallel-size`, `--data-parallel-size`, `--distributed-executor-backend` | multi-GPU | N/A — one GB10 |
| `--enable-expert-parallel` | MoE experts across GPUs | N/A |
| MoE kernel selection (env: `VLLM_FUSED_MOE_BACKEND` etc., cutlass vs marlin vs triton MoE) | single-GPU MoE kernel choice | TUNE ? — relevant for MoE models (Qwen A3B-style); spelled via env vars, version-dependent |

## 8. Model loading / misc server

| Flag | Meaning | Verdict |
|---|---|---|
| `--load-format` | safetensors / runai_streamer / … | N/A for tok/s (affects boot time only) |
| `--served-model-name`, `--host`, `--port`, `--api-key` | serving plumbing | FIXED |
| `--tokenizer-mode` | tokenizer impl | FIXED (auto) |
| `--trust-remote-code` | some models need it | FIXED per model |
| `--seed` | sampling seed | FIXED — set it, for repeatability |
| `--disable-log-stats` / `--disable-log-requests` | logging overhead | FIXED on (tiny, but why pay it) |
| `--enable-sleep-mode` | /sleep /wake_up endpoints | N/A — known-broken pattern on unified memory (runKali lore); loop restarts engines anyway |

## 9. LoRA / structured output / multimodal

All N/A: no adapters, no guided decoding, text-only benchmarks.
(`--enable-lora`, `--max-loras`, `--reasoning-parser`, `--tool-call-parser`,
`--limit-mm-per-prompt`, …). Tool-call parsers only matter for serving agents,
not benchmarks — deliberately dropped from `start.sh`.

## 10. Environment variables (often forgotten, same power as flags)

| Env | Meaning | Verdict |
|---|---|---|
| `VLLM_ATTENTION_BACKEND` | same as flag | TUNE (use flag form) |
| `VLLM_USE_V1` | V0/V1 engine select | ? — build-dependent; if both exist, that's a huge A/B |
| `VLLM_FLASH_ATTN_VERSION` | FA2 vs FA3 | ? sm_121a support |
| `VLLM_CUDA_GRAPH_*`, `VLLM_FUSED_MOE_*`, `VLLM_USE_TRITON_FLASH_ATTN` | kernel selection family | TUNE ? — enumerate inside container: `env | grep VLLM` + docs |
| `OMP_NUM_THREADS`, CPU pinning | host-side | probably noise; late-stage |

## The protocol dimensions (yours — never touched by the agent mid-loop)

- **test type** — which benchmark cell (e.g. tg128@d16384; later pp, deeper ctx)
- **concurrency** — 1 / 2 / … (guidellm calls these rate modes; `vllm bench serve` = `--max-concurrency`)
- **model + quantization** — the checkpoint itself

Changing any of these = a new experiment series, not a new round.

## Benchmark tooling (client side — measures, doesn't serve)

- `vllm bench serve` — online benchmark against our engine; TTFT/ITL/TPOT + throughput, `--request-rate`, `--max-concurrency`, `--percentile-metrics`. Runs from laptop or box venv; does NOT need our pinned container.
- `vllm bench sweep serve` / `serve_workload` — Cartesian sweeps over server×bench param JSON files, 3 iterations per config, plot + Pareto tooling. Useful for the *scripted control arm* comparison later; the agent loop itself replaces the Cartesian sweep with guided search.
- `guidellm` — richer load profiles (synchronous/concurrent/throughput/poisson/sweep), synthetic data with exact prompt/output token counts (`prompt_tokens=…,output_tokens=…` — maps directly to arena cell definitions), JSON/CSV/HTML reports.
- llama-benchy — what spark-arena itself uses; the arena's cell definitions win any disagreement. Others are for the agent's own probing.

## Rough search-space size (why guided search, not sweeps)

~15 genuinely tunable flags above; even 3 values each ≈ 14M combos × 10 min/round.
Cartesian is dead on arrival — hence autoresearch: agent proposes one mutation
per round from ledger evidence, ~40 rounds/night, and learns the interactions
(spec-decode×attention, batch×KV-size, chunked-prefill×depth) instead of
enumerating them.
