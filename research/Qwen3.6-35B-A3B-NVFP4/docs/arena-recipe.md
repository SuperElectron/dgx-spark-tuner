
# decode-tg
https://spark-arena.com/benchmark/1199b578-cfa4-47cd-b1fa-374fd4815565
https://spark-arena.com/api/benchmarks/1199b578-cfa4-47cd-b1fa-374fd4815565/raw


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
    ours        95.83 median   137.82 median  176.06 median  141.46 median

The two runtimes run opposite curves. Atlas takes c1 and collapses under
concurrency; vLLM is weakest at c1, peaks at c2, and still holds ~100 at c10.
Chasing 152.76 is chasing a runtime we do not run.

vLLM decode is nearly flat with depth — `1199b578` reads 118.91 at d0, 116.03
at d16384, 114.92 at d32768. Whatever bounds decode here is depth-independent,
and depth-curve measured the same flatness on our side.

> The `ours` row was corrected on 2026-08-25. It previously read
> `119.6 median` at c1 with dashes elsewhere. **That figure was not
> board-comparable** — it came from a single-cell run at `runs: 7` with a fixed
> corpus and `temperature 0`, none of which arena's grid does, and it overstated
> the c1 cell by about 14%. It must not be set beside any entry above.
>
> The row now carries `concurrency/recipe-new.yaml` measured on arena's own
> unmodified 28-cell grid, `bench_95fdfa8922a3` — the deliverable recipe, and
> the only configuration of ours with all four cells on the board's protocol.
> Read it with three caveats:
>
> - **c1 does not resolve.** Its three values were 95.83, 124.19 and 86.06, a
>   ±15% span on an unchanged config. Our other two grid runs read 103.74 (h5)
>   and 105.12 (h6) at the same cell. Any c1 comparison here is noise; we lose
>   to all five entries on every reading of it.
> - **c5 and c10 are the real results** — 176.06 against the best held 148.30,
>   and 141.46 against 102.31. Both come from the tightest cells in the campaign
>   (c10 read 141.46 / 140.80 / 141.68).
> - **`tg` only.** Every figure of ours is cold-cache (0.0% prefix hit rate,
>   MTP defeats the cache), which costs `pp` and `ttfr` roughly 4x and `tg` 2.3%.
>   No `pp` or `ttfr` figure of ours is comparable to anything in this document.

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
