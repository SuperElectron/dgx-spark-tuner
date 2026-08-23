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

## The rest of the cell, read 2026-08-23

Five entries at `tg128 @ d16384`, pulled from the page payloads. The `/raw`
endpoint returns a markdown table with no recipe and no identity, so the recipe
and the runtime come from the `benchmarkData` object embedded in the page.

    https://spark-arena.com/benchmark/5e0b8836-49e1-4b93-84db-c4aed27fc9ba
    https://spark-arena.com/api/benchmarks/5e0b8836-49e1-4b93-84db-c4aed27fc9ba/raw
    #2, Atlas, RedHatAI checkpoint, 96 tests, @Rajendra Rawat

    https://spark-arena.com/benchmark/af9a7d31-e0ee-42ed-941a-46adda982549
    https://spark-arena.com/api/benchmarks/af9a7d31-e0ee-42ed-941a-46adda982549/raw
    #3, Atlas, RedHatAI checkpoint, 92 tests, @Raphael Amorim

    https://spark-arena.com/benchmark/e6026faa-cc4c-4187-8019-4522c00a230a
    https://spark-arena.com/api/benchmarks/e6026faa-cc4c-4187-8019-4522c00a230a/raw
    #4, Atlas, RedHatAI checkpoint, 20 tests, @Szymon Walczak

    https://spark-arena.com/benchmark/13321ed7-516e-412a-ba13-bf00c4d805c3
    https://spark-arena.com/api/benchmarks/13321ed7-516e-412a-ba13-bf00c4d805c3/raw
    vLLM, nvidia checkpoint, 104 tests, @luis — the other vLLM entry

The whole cell, one row per entry:

    entry              c1              c2              c5             c10
    5e0b8836  152.76 ± 2.39   102.95 ± 9.30   45.36 ± 0.66   17.33 ± 6.09
    af9a7d31  149.07 ± 2313    71.97 ± 38.1   46.16 ± 2.99   24.76 ± 4.45
    e6026faa  131.44 ± 7.61    76.06 ± 28.0              —              —
    13321ed7   93.84 ± 13.1   178.29 ± 11.6  148.30 ± 4.02   98.66 ± 7.10
    1199b578  116.03 ± 3.61   165.88 ± 7.01  142.30 ± 6.11  102.31 ± 2.98
    ours       119.6 median              —              —              —

The two runtimes run opposite curves. Atlas takes c1 and collapses under
concurrency; vLLM is weakest at c1, peaks at c2, and still holds ~100 at c10.
Chasing 152.76 is chasing a runtime we do not run.

vLLM decode is nearly flat with depth — `1199b578` reads 118.91 at d0, 116.03
at d16384, 114.92 at d32768 — so our 119.6 already sits at its unloaded
ceiling. Whatever bounds decode here is depth-independent.

Atlas prefill figures are not physical and inflate the aggregate scores:
`5e0b8836` reports `ctx_pp @ d16384 c1` of 770513 t/s while its own e2e TTFT of
6155 ms implies 2662. The same arithmetic checks out for the vLLM entries. The
Atlas decode figures pass it too — it is prefill that is broken.

The grid behind all of these is `@official/spark-arena-v2`: depth
[0, 4096, 8192, 16384, 32768, 65535, 100000] x concurrency [1, 2, 5, 10],
pp 2048, tg 128, `runs: 3`, prefix caching on with no reset between runs. 104
tests = 6 depths x 4 kinds x 4 concurrencies + depth-0 x 2 kinds x 4. Cell order
is a fixed heat-aware schedule (`bucket_43521_seed42`), and `d16384 c1` sits at
index 13 of 28 — measured mid-sweep, warm, where ours is measured cold and
alone.

## Where `recipe.yaml` came from

https://github.com/spark-arena/eugr-recipes/blob/main/recipes/qwen3.6-35b-a3b-nvfp4.yaml

`@eugr/qwen3.6-35b-a3b-nvfp4`, pulled 2026-08-23, de-rayed for a single node:
no `--distributed-executor-backend ray`, no `tensor_parallel`. The box has one
GB10, so the published `tensor_parallel: 2` cannot run here.
