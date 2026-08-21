# dgx-spark-tuner

Automated serving-config search for LLM inference on NVIDIA DGX Spark (GB10).

An autoresearch loop — propose a vLLM config mutation, benchmark it, record everything,
learn, propose again — targeting the [Spark Arena](https://spark-arena.com) single-node
leaderboard. Built on the arena's own stack: [sparkrun](https://github.com/spark-arena/sparkrun),
[llama-benchy](https://github.com/eugr/llama-benchy),
[spark-vllm-docker](https://github.com/eugr/spark-vllm-docker) — so every number here is
directly comparable and directly submittable.

## What lives here

- `recipes/` — one sparkrun recipe YAML per target model; generation 0 is the current
  leaderboard incumbent, verbatim
- `tuner/` — the loop: runner (launch → benchmark → stop), append-only results ledger,
  recipe mutation with a legal-values schema, guardrails (repeats, quality gate, crash
  classification)
- `ledger/` — the dataset. Every run: full config, full metrics (decode/prefill throughput
  by depth and concurrency, TTFT, ITL, peak unified memory), environment fingerprint
- `analysis/` — parameter→metric reports; per-leaderboard-cell winners

## Status

Planning. Nothing runs yet.

## License

Apache-2.0
