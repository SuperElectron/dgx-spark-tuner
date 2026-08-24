# Results — Qwen3.6-35B-A3B-NVFP4

## reference
Model: `nvidia/Qwen3.6-35B-A3B-NVFP4`. Baseline: `recipe.yaml`, copied from
`@eugr/qwen3.6-35b-a3b-nvfp4` and de-rayed for a single node. The board entries
it is measured against are in `docs/arena-recipe.md`; the checkpoint, its
architecture and the flag-to-layer map are in `docs/model-card.md`; the
instrument itself is in `docs/measurement.md`.

## results

| experiment | date | varied | won | pp t/s | tg t/s | ttfr ms | bench | outcome |
|---|---|---|---|---:|---:|---:|---|---|
| <name> | <YYYY-MM-DD> | <field: values swept> | <field: value> | <n> | <n> | <n> | <bench_...> | <survived / failed> |
| depth-curve | 2026-08-24 | depth: 0, 4096, 8192, 16384, 30464 | none — measurement only, no field moved | 628.6 | 117.8 | 3279.0 | bench_c003c48ede71 | survived |
| concurrency | 2026-08-24 | max_num_batched_tokens: 65536, 32768, 16384 · max_num_seqs: 4, 10, 16 | max_num_seqs: 10 | 677.9 | 141.5 | 28636.2 | bench_95fdfa8922a3 | survived |

depth-curve measured a shape rather than chasing a number, so its row carries
the `d16384` rung — the one cell comparable to the rest of the tree — and not a
winning config. That 117.8 re-bases the standing 119.6: the same cell under the
per-cell corpus offset, cold, and it replaces the older figure rather than
continuing it. The full five-rung ladder is in
`experiments/depth-curve/h1/HYPOTHESIS.md`. The finding: `tg` at c1 declines
4.5% from d0 to d30464 (5.1% once MTP acceptance is divided out), matching the
board's own 3.4% and closing `--kv-cache-dtype` and `--attention-backend` as
levers.

concurrency's row carries `d16384 c10` — the cell its Objective named — measured
on arena's own unmodified 28-cell grid, so it is board-comparable and is not the
`c1` cell the rest of this table reports. `max_num_seqs` 4 → 10 takes that cell
from 48.9 to **141.5**, a 2.89x and 38% above the best vLLM board entry's 102.31.
The win is admission, not batching: four slots were admitting four of ten offered
requests while six waited inside the measurement window. It is confined to cells
where offered concurrency exceeds four — the whole `c1` and `c2` columns are flat,
and `d16384 c1` reads 95.8, which neither held nor regressed against its 103.7
guard because that cell spans ±15.0% within this single run. `recipe-new.yaml`
is that run's recipe. Full account in `experiments/concurrency/EXPERIMENT.md`.
