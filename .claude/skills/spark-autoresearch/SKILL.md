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

1. Read journal.md + prior `experiments/*/`. Before picking a mutation, recall
   prior findings:
   ```
   .claude/skills/mem0/scripts/recall.sh "prior findings <model> <cell> <lever>" experiment:<name>
   ```
   Best-effort — fold the digest into your hypothesis reasoning, but never
   block on it (see the mem0 skill's guardrail). Pick ONE mutation. Journal
   the hypothesis BEFORE running.
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
5. Append one row to RESULTS.md. Per-run table (the default — the recipe
   moves, the probe is fixed):
   `| bench_<id> | <date> | <mutation> | <tg mean> | <tg σ> | <pp mean> | <pp σ> | <ttfr mean> | keep/revert/crash — note |`

   A campaign that varies the PROBE instead of the recipe (depth,
   concurrency, tg length) may use a per-cell table instead — one row per
   measured cell, carrying the configuration it was measured under:
   `| bench_<id> | <date> | <cell> | <configuration> | <ours> | <runs> | <board top> | <margin> | <note> |`

   EITHER schema MUST carry `benchId` and `date` columns. Without them a
   row cannot be traced back to its archive under `experiments/`, and
   `memory-backfill.sh` cannot produce a provenanced memory from it.
6. Journal the outcome, then derive the round's verdict memories from the
   canonical table (best-effort, never blocking — see the mem0 skill's
   guardrail: on failure spawn a background agent to run
   `memory-doctor.sh`, never gate the round on it):
   ```
   .claude/skills/mem0/scripts/memory-backfill.sh --reconcile research/<name>
   ```
   `--reconcile` adds the new rows AND drops `[VERDICT]`/`[CRASH]`
   entries the table no longer produces, so the index converges on
   RESULTS.md instead of accreting retired figures. Never hand-write a
   `[VERDICT]` with `remember.sh` — a hand-written one has no row to
   reconcile against, and that is precisely how the index diverged from
   the table.

   Hand-written `remember.sh` calls stay correct for `[LESSON]`, `[ENV]`
   and `[IDEA]` findings that are NOT derivable from the results table. A
   crash belongs in RESULTS.md as a row — backfill tags it `[CRASH]` — with
   the takeaway written as a `[LESSON]`; a hand-written `[CRASH]` under the
   experiment entity is a reconcile deletion candidate. Commit per repo
   workflow rules.

## Observation sweep (mandatory at every synthesis, ~5 rounds)

Run an observation pass per the `observe` skill (.claude/skills/observe/SKILL.md)
over the series' runs, telemetry, and logs — surprises, headroom at every
layer, missing instruments — recording [ENV]/[LESSON]/[IDEA] memories and an
"Observations" journal subsection. Telemetry feed:
`scripts/sample-telemetry.sh <seconds> <outfile>` alongside at least one
benchmark per series; archive the log with that run. Empty sweeps are
suspicious.

## Cost ledger

Record harness-token spend for the round in the journal entry (canonical),
and write a `[COST]` memory per phase (tokens-per-point accounting):
```
.claude/skills/mem0/scripts/remember.sh "[COST] <phase>: <tokens> tokens, <result>" experiment:<name>
```

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
