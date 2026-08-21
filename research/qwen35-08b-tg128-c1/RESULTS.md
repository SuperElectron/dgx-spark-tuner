# Results — qwen35-08b-tg128-c1

Target cell: tg128 (c1). Arena reference: 121.19 ± 0.23 tok/s
(docs/arena-recipe.md). One row per benchmark run, appended after archiving
the run into `experiements/<benchId>/`.

| benchId | date | mutation | tg t/s | tg σ | pp t/s | pp σ | ttfr ms | verdict |
|---|---|---|---:|---:|---:|---:|---:|---|
| bench_59e87386d131 | 2026-08-21 | baseline (arena recipe verbatim) | 108.35 | 0.27 | 17777 | 4733 | 140.6 | baseline — repro gap −10.6% vs 121.19 |
