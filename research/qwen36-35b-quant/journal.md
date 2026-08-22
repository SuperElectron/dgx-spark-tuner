# Journal — <experiment name>

Hypotheses before runs, lessons after them, a synthesis every ~5 rounds.
The last synthesis is the handoff every new session starts from.

## Round 0 — baseline

(reproduce the arena recipe verbatim; record the reproduction gap here)
# qwen36-35b-quant — Phase 1 quant tradeoff (milestone beat-the-board)

Cell: tg128 @ d16384, c1, single node. Arms: NVFP4 / BF16 (/FP8 stretch).
Memory recall done (mem0 live): clock cap 2405/3003 known; median-rule +
verify-wins discipline carries over; spec decode lesson (ngram on 0.8B) noted —
this recipe family uses MTP spec decode instead (n=3, from @eugr recipe).

## Round 0 — NVFP4 baseline (hypothesis)

Recipe @eugr/qwen3.6-35b-a3b-nvfp4 as incumbent, single-node overrides:
-o tensor_parallel=1 -o gpu_memory_utilization=0.8. Probe: pp=2048 tg=128
depth=16384 concurrency=1 runs=3. Expect ~110-116 (leaderboard vLLM entries
111.9-116.0 in this cell); first run pays model download (~20GB).

## Round 0 launch failures — vllm-ray OOM-killed on GB10

Two failed launches: first hit the 5-min readiness timeout mid-download (22GB);
retry crashed — Ray's memory monitor misreads GB10 unified memory and OOM-kills
the vLLM worker during weight load. Ray is pointless at TP=1: rewrote the
incumbent as recipe_version 1, container vllm-node, identical serve flags
(kv fp8, flashinfer, marlin MoE, MTP spec n=3, async). max_model_len trimmed
262144→32768 (probe needs 16384+2048; smaller KV alloc, faster boot).
