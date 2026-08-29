# Results — MiniCPM5-1B

## reference
Model: `openbmb/MiniCPM5-1B`. Baseline: `recipe.yaml`. Reference: `docs/arena-recipe.md`.

1B params, BF16, ~2 GB. Baseline copies `sub1787650717319`, 704.63 t/s and rank
5 at `tg128 (c10)` — the only top-10 entry in that cell already running
`max_num_seqs: 64`. It is the control on LFM2.5-350M's slots result, not a
contender: `tg128 (c10)` is held by our own LFM2.5-350M submission at 2044.66.

## results

| experiment | date | varied | won | pp t/s | tg t/s | ttfr ms | bench | outcome |
|---|---|---|---|---:|---:|---:|---|---|
| <name> | <YYYY-MM-DD> | <field: values swept> | <field: value> | <n> | <n> | <n> | <bench_...> | <survived / failed> |
| slots | 2026-08-29 | max_model_len: 8192, 32768 | none — null result | 33536.7 | 667.1 | — | bench_7ff583b63330 | survived |
