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
| coverage | 2026-08-31 | nothing — the `slots` winner over the tg32/pp4096 grid | no lever; 22 board cells | 15273.2 | 122.8 | 1622.0 | bench_18c53808be50 | survived — published `sub1788141670208` |

`coverage` figures are `pp4096`/`tg32` at the rule's cell `d16384 c10`, the
grid's worst, not its best. Every other cell reads higher. Rank 1 board-wide in
all 22 cells that exist; the other 18 of the profile's 40 are absent from the
board, not lost.
