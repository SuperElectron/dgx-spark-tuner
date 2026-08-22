# Results — <experiment name>

Target cell: <cell>. Arena reference: <value> (docs/arena-recipe.md).
One row per benchmark run, appended after archiving the run into
`experiments/<benchId>/`.

| benchId | date | mutation | tg t/s | tg σ | pp t/s | pp σ | ttfr ms | verdict |
|---|---|---|---:|---:|---:|---:|---:|---|
| bench_6c1d46e5fd36 | 2026-08-22 | round 0: NVFP4 de-rayed baseline (MTP n=3, kv fp8, flashinfer, marlin) | 102.23 | 7.81* | 634 | — | 3245.6 | baseline — tg128@d16384 median 102.2 (runs 101.1/102.2/118.2, MTP-acceptance outlier); ctx_tg 105.4 |
