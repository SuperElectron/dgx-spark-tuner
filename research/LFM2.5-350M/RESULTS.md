# Results — LFM2.5-350M

## reference
Model: `LiquidAI/LFM2.5-350M`. Baseline: `recipe.yaml`. Reference: `docs/arena-recipe.md`.

350M params, BF16, ~0.7 GB — the board's `tg128 (c10)` leader at 1042.20 t/s
and #1 outright there. Baseline is a copy of that entry, `max_num_seqs: 4`.

## results

| experiment | date | varied | won | pp t/s | tg t/s | ttfr ms | bench | outcome |
|---|---|---|---|---:|---:|---:|---|---|
| <name> | <YYYY-MM-DD> | <field: values swept> | <field: value> | <n> | <n> | <n> | <bench_...> | <survived / failed> |
| slots | 2026-08-28 | max_num_seqs: 4, 10, 16 | max_num_seqs: 16 | 90384.3 | 2197.7 | 165.5 | bench_4d8f02ff6b65 | survived |
