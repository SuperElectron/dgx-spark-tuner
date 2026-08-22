# Results — qwen36-35b-nvfp4-cells

Model fixed: nvidia/Qwen3.6-35B-A3B-NVFP4 (de-rayed recipe). The campaign
varies the PROBE, not the config: each round measures a different board cell.
Targets and incumbents per cell: docs/arena-recipe.md.
One row per measured CELL, appended after archiving into `experiments/<benchId>/`.
A single benchmark run measures several cells, so one benchId spans several rows.

tg/pp columns are MEDIANS of the runs — means are not verdicts (MTP acceptance
is bimodal). σ is the run standard deviation, kept as the noise flag.
`ctx_` rows are the prefix-caching phase of the same run (a separate board cell).

| benchId | date | cell / probe | tg med t/s | tg σ | pp med t/s | pp σ | ttfr ms | board top | verdict |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d8192 c1 | 106.24 | 22.72 | 1187.51 | 26.39 | 1737.93 | sole entry | win — no number published to beat |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d16384 c1 | 129.32 | 18.38 | 637.09 | 3.76 | 3230.01 | 28.11 | win — 4.60x incumbent |
| bench_25a0e7f36ab0 | 2026-08-21 | tg32 @ d32768 c1 | 115.56 | 10.40 | 295.71 | 0.78 | 6937.09 | 23.31 | win — 4.96x incumbent |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d8192 c1 | 126.52 | 7.94 | 6148.56 | 15.56 | 1345.97 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d16384 c1 | 130.16 | 3.01 | 5910.22 | 36.03 | 2787.86 | not scraped | hold — board figure unknown |
| bench_25a0e7f36ab0 | 2026-08-21 | ctx_tg32 @ d32768 c1 | 84.03 | 10.69 | 5086.51 | 23.20 | 6453.91 | not scraped | hold — board figure unknown |
| bench_f58c56da6658 | 2026-08-21 | tg128 @ d16384 c4 | 53.56 | 0.43 | 644.01 | 1.12 | 10167.05 | 46.68 | win — 1.15x, verify required at this margin |
| bench_f58c56da6658 | 2026-08-21 | ctx_tg128 @ d16384 c4 | 56.40 | 0.16 | 5967.41 | 22.51 | 8554.95 | not scraped | hold — board figure unknown |
| bench_f58c56da6658-verify | 2026-08-21 | tg128 @ d16384 c4 | 52.69 | 0.75 | 642.82 | 1.47 | 10151.35 | 46.68 | win CONFIRMED — pooled median of 6 runs 52.85 = 1.13x; worst single run 51.25 still +9.8% |
| bench_f58c56da6658-verify | 2026-08-21 | ctx_tg128 @ d16384 c4 | 55.92 | 0.62 | 5924.46 | 30.56 | 8641.49 | not scraped | hold — pooled median 56.36 |
