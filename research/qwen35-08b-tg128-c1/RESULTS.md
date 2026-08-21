# Results — qwen35-08b-tg128-c1

Target cell: tg128 (c1). Arena reference: 121.19 ± 0.23 tok/s
(docs/arena-recipe.md). One row per benchmark run, appended after archiving
the run into `experiements/<benchId>/`.

| benchId | date | mutation | tg t/s | tg σ | pp t/s | pp σ | ttfr ms | verdict |
|---|---|---|---:|---:|---:|---:|---:|---|
| bench_59e87386d131 | 2026-08-21 | baseline (arena recipe verbatim) | 108.35 | 0.27 | 17777 | 4733 | 140.6 | baseline — repro gap −10.6% vs 121.19 |
| bench_129a556cce47 | 2026-08-21 | max_num_seqs=1 | 108.90 | 0.09 | 23195 | 266 | 102.3 | revert — +0.55 tg (~1.9σ, inconclusive); pp normalized to arena level, round-0 pp dip was anomaly |
| bench_1851f83d3653 | 2026-08-21 | max_model_len=8192 | 108.95 | 0.23 | 22455 | 477 | 107.0 | revert — +0.60 tg (~1.7σ, inconclusive); same-magnitude nudge as max_num_seqs=1 |
| bench_eb6e39538b5e | 2026-08-21 | --async-scheduling (candidate recipe) | 108.96 | 0.28 | 21274 | 243 | 110.0 | revert — +0.61 tg (~1.6σ); third straight ~+0.6 result, baseline suspect |
| bench_59e87386d131-rebaseline | 2026-08-21 | none (re-run incumbent) | 108.67 | 0.17 | 21580 | 402 | 107.2 | re-baseline — incumbent band 108.4–109.0; rounds 1–3 flags = no-ops |
