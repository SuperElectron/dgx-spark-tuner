https://spark-arena.com/benchmark/sub1787650717319
https://spark-arena.com/api/benchmarks/sub1787650717319/raw

Read 2026-08-29. 704.63 t/s at `tg128 (c10)`, rank 5 in that cell.
The only top-10 entry already running `max_num_seqs: 64`, which is what makes
it the control on `LFM2.5-350M`'s slots result rather than a contender.

Key settings: `max_num_seqs: 64`, `max_num_batched_tokens: 4096`,
`gpu_memory_utilization: 0.5`, `max_model_len: 8192`, `tensor_parallel: 1`,
container `vllm-node`, `recipe_version: '1'`, `dtype bfloat16`.
