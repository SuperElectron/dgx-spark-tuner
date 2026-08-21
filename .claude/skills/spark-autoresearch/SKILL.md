---
name: spark-autoresearch
description: Run the DGX Spark benchmark-tuning research loop — create experiment series, run single-mutation sparkrun benchmark rounds, archive runs, keep/revert verdicts, and promote to arena. Use when creating an experiment, running or resuming a tuning round, archiving a benchmark, or interpreting round results in research/.
---

# Spark autoresearch loop

The stack is the spark-arena community's, not ours: `sparkrun` (laptop CLI, via
`uvx sparkrun`), their recipe YAML format, `llama-benchy` measurement. We add
only the research loop around it. The box hostname comes from `.claude/box.json`
(gitignored); SSH config carries the user + key.

## Create an experiment series

```
.claude/skills/spark-autoresearch/scripts/new-experiment.sh <model>-<cell>
```

Copies `research/_template/` to `research/<model>-<cell>/`:

```
research/<name>/
├── recipe.yaml                  # the incumbent config — the ONLY tuned artifact
├── journal.md                   # hypothesis before each run, keep/revert after,
│                                #   synthesis every ~5 rounds (decisions only)
├── RESULTS.md                   # one table row per run (human comparison view)
├── docs/                        # model-card.md, arena-recipe.md (source URL + scrape date)
└── experiments/<benchId>/      # one dir per benchmark run: exported YAML/JSON/CSV
                                 #   + full sparkrun state dir contents
```

## One round

1. Read journal.md + prior `experiments/*/`. Pick ONE mutation. Journal the
   hypothesis BEFORE running.
2. Run (mutation = `-o key=value`; template-flag change = edit a candidate
   recipe copy, e.g. `recipe-candidate.yaml`):
   ```
   uvx sparkrun benchmark perf ./recipe.yaml --solo -H <box-host> \
     -b pp=2048 -b tg=128 -b concurrency=1 -b runs=3 \
     [-o key=value] --fresh --output round-tmp.yaml
   ```
   Bare hostname only in `-H` (no user@). Fixed `-b` probe args per series —
   never vary them mid-series.
3. sparkrun prints `Benchmark ID: bench_<id>`. Archive:
   ```
   .claude/skills/spark-autoresearch/scripts/archive-round.sh <experiment-dir> bench_<id> [suffix]
   ```
   sparkrun reuses the benchId for identical recipe+params — pass a suffix
   (`rebaseline`, `verify`, `crash`) on collision; never overwrite a past dir.
4. Read metrics:
   ```
   .claude/skills/spark-autoresearch/scripts/parse-round.py <experiments-dir-or-cwd>/round-tmp.json
   ```
   Compare MEDIANS, not means — prompt draws are bimodal (occasional
   high-ngram-acceptance runs). Verify any apparent win with a repeat run
   before keeping. Keep → fold the mutation into recipe.yaml. Revert →
   recipe.yaml untouched. Crash → journal the lesson; run dir stays.
5. Append one row to RESULTS.md:
   `| bench_<id> | <date> | <mutation> | <tg mean> | <tg σ> | <pp mean> | <pp σ> | <ttfr mean> | keep/revert/crash — note |`
6. Journal the outcome. Commit per repo workflow rules.

## Promotion

Stall or satisfied → full official grid + submission (needs
`sparkrun arena login` once, and the user's explicit go):

```
uvx sparkrun benchmark perf ./recipe.yaml --solo -H <box-host> --arena
```

## Debugging a stuck round

Server-wait past ~6 min usually means an engine crash loop. On the box:
`docker ps`, then read `/tmp/sparkrun_serve.log` inside the sparkrun container.
Kill the waiting benchmark task, `docker rm -f` the container, archive with
`-crash` suffix plus a `crash-log.txt` excerpt.

## Hard rules

- Never edit past `experiments/` contents; never hand-maintain results
  tables — numbers live in the exported files only.
- Transient benchmark failures (e.g. corpus download 504): re-run with
  `--resume`, same benchId continues.
- Image/vLLM version comes from the recipe's container and is recorded in
  every export (`runtime_info`); a version change = new epoch — re-run the
  incumbent before comparing across it. `--image <ref>` overrides the
  container for epoch experiments.
- System-state changes on the box (clock/power policy, driver, kernel, apt)
  are never made autonomously — measure, journal, and leave the decision to
  the user.
