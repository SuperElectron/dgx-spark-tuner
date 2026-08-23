# The box — DGX Spark (GB10), what the agent must know

## Hardware / OS

- GB10 (Blackwell, **sm_121a**), aarch64, one **unified 121 GB memory pool**
  shared by GPU, host processes, and the Linux page cache.
- Ubuntu 24.04, NVIDIA kernel 6.17.0-nvidia, driver 580.173.02 (CUDA 13.0),
  CUDA toolkit 13.0.3 at /usr/local/cuda-13.0.
- 3.7 TB NVMe, ~74 GB HF weight cache at ~/.cache/huggingface (persists).
- **Never `apt upgrade`. Never touch driver or kernel.** The driver/kernel
  pairing is NVIDIA's factory image; breaking it bricks GPU access.

## Unified-memory rules (each one cost a debugging session to learn)

1. **Page-cache poisoning.** Loading 60+ GiB of weights fills the page cache;
   CUDA cannot claim those pages, and the next engine start dies at context
   creation with a bare "CUDA error: out of memory". Fix: drop caches between
   engine starts (`bench.sh`/`start.sh`/`stop.sh` do this automatically via a
   sudo helper). Nothing is lost — clean pages only.
2. **Exact KV bytes, not fractions.** `--gpu-memory-utilization` is measured
   against whatever is free at boot, so results depend on start order and
   history. Worse: memory profiling on unified memory can see free memory
   going UP and abort with "Error in memory profiling". Always prefer
   `--kv-cache-memory-bytes`.
3. **Sequential starts only.** vLLM sizes KV from free memory at boot; two
   engines starting in parallel race and the second dies. bench.sh runs one
   engine, ever.
4. **nvidia-smi lies about GPU memory** — reports `[N/A]` for used/total
   (unified pool). Use MemAvailable from /proc/meminfo instead.
5. `--enable-sleep-mode` deadlocks on this box (wake finds no room). Don't.

## Kernel/backend lore for sm_121a

- FlashAttention (flash-attn package) does not work on GB10 — and reportedly
  isn't needed: cuDNN SDPA is competitive or faster on Blackwell.
- FlashInfer in our image is source-built for arch 12.1a — it exists, but
  head-dim coverage on sm_121a is patchy; a bad kernel may CORRUPT output
  silently rather than crash. TRITON_ATTN is the known-good fallback.
- sm_120 and sm_121 are binary compatible; sm_120 kernels run on GB10.

## The serving stack

- Docker with CDI GPU access (`--device nvidia.com/gpu=all`); there is NO
  nvidia docker runtime — plain `--gpus all` fails.
- Image: `ghcr.io/timothystewart6/vllm-gb10` digest-pinned in
  deploy/box/start.sh — vLLM v0.27.1, torch 2.13.0/cu130, source-built
  sm_121 NCCL + FlashInfer. Full stack: research/docs/image-versions.env.
- Engine boot = 2–5 min (weight load dominates; page cache dropped first, so
  always cold from NVMe). Budget rounds at 10–15 min.

## Access

- `./deploy/connect.sh ssh '<cmd>'` from the laptop repo root — the only path.
- Box scripts live at ~/spark-tuner/ on the box (synced from deploy/box/).
