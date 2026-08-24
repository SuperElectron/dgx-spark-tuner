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

depth-curve measured a shape rather than chasing a number, so its row carries
the `d16384` rung — the one cell comparable to the rest of the tree — and not a
winning config. That 117.8 re-bases the standing 119.6: the same cell under the
per-cell corpus offset, cold, and it replaces the older figure rather than
continuing it. The full five-rung ladder is in
`experiments/depth-curve/h1/HYPOTHESIS.md`. The finding: `tg` at c1 declines
4.5% from d0 to d30464 (5.1% once MTP acceptance is divided out), matching the
board's own 3.4% and closing `--kv-cache-dtype` and `--attention-backend` as
levers.
