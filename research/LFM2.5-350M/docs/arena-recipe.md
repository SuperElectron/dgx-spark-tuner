https://spark-arena.com/benchmark/sub1787760284956
https://spark-arena.com/api/benchmarks/sub1787760284956/raw

read 2026-08-28. `recipe.yaml` is a copy of this entry's recipe.

Board rank at read: #1 outright at `tg128 (c10)`, all models, single node.

The run measures four depths only — d0, d4096, d8192, d16384 — and no depth
beyond. `tg128` from the raw log, mean +/- std over the cell's own repeats:

| depth | c1 | c2 | c5 | c10 |
|---|---|---|---|---|
| d0 | 366.07 +/- 0.36 | 704.64 +/- 13.24 | 927.20 +/- 117.06 | **1042.20 +/- 6.49** |
| d4096 | 343.78 +/- 0.59 | 562.11 +/- 98.50 | 670.93 +/- 41.99 | **750.01 +/- 28.21** |
| d8192 | 332.58 +/- 5.64 | 614.24 +/- 0.94 | 712.16 +/- 116.99 | **745.70 +/- 34.78** |
| d16384 | 363.46 +/- 44.76 | 494.53 +/- 46.15 | 574.19 +/- 20.03 | **613.31 +/- 6.03** |

The std is the entry's own within-run scatter, not run-to-run scatter across
submissions. It is wide where it matters: c5 carries +/-117 at d0 and +/-117 at
d8192 — 13% and 16% of the mean. Any margin we claim has to clear our own
control's scatter, measured on our box, not this column.

Four other board runs of this same config (`max_num_seqs: 4`) at `tg128 (c10)`
span 700.00 to 742.01 — sub1777989095056, sub1787756929368, sub1787784431339,
sub1787597045113. So 1042.20 sits far above the config's own run-to-run band.
The band, not the headline, is what our control has to land inside.
