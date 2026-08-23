https://spark-arena.com/benchmark/1199b578-cfa4-47cd-b1fa-374fd4815565
https://spark-arena.com/api/benchmarks/1199b578-cfa4-47cd-b1fa-374fd4815565/raw

`@luis`, same checkpoint, vLLM, single node, `tensor_parallel: 1`. The best
vLLM NVFP4 entry at `tg128 @ d16384 c1`. Read 2026-08-23:

    pp2048 @ d16384 c1   1414.86 ± 7.14
    tg128  @ d16384 c1    116.03 ± 3.61
    tg128  @ d16384 c2    165.88 ± 7.01
    tg128  @ d16384 c10   102.31 ± 2.98

This is the like-for-like comparison — our checkpoint, our runtime, our cluster
size. Ranks 2-4 in that cell are the same checkpoint on Atlas, a different
runtime and out of scope.

Board figures are not uniformly trustworthy. An Atlas entry in the same cell
(`af9a7d31-e0ee-42ed-941a-46adda982549`) reports `1789.07 ± 2313.05` for c1
decode — a standard deviation larger than its own mean, and a rate no 35B
reaches on one GB10. Read the raw log before treating any headline as a target.
This one holds up at 3.1% relative spread.

## Where `recipe.yaml` came from

https://github.com/spark-arena/eugr-recipes/blob/main/recipes/qwen3.6-35b-a3b-nvfp4.yaml

`@eugr/qwen3.6-35b-a3b-nvfp4`, pulled 2026-08-23, de-rayed for a single node:
no `--distributed-executor-backend ray`, no `tensor_parallel`. The box has one
GB10, so the published `tensor_parallel: 2` cannot run here.
