# Results — qwen36-35b-nvfp4

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
