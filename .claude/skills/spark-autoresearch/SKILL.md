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
   high-ngram-acceptance runs). At `concurrency > 1`, read the metrics
   section below BEFORE quoting any throughput. Verify any apparent win
   with a repeat run before keeping. Keep → fold the mutation into recipe.yaml. Revert →
   recipe.yaml untouched. Crash → journal the lesson; run dir stays.
5. Append one row to RESULTS.md:
   `| bench_<id> | <date> | <mutation> | <tg mean> | <tg σ> | <pp mean> | <pp σ> | <ttfr mean> | keep/revert/crash — note |`
6. Journal the outcome. Write the verdict to memory (best-effort, never
   blocking — see the mem0 skill's guardrail: on failure spawn a background
   agent to run `memory-doctor.sh`, never gate the round on it):
   ```
   .claude/skills/mem0/scripts/remember.sh "[VERDICT] <one-liner>" experiment:<name>
   ```
   Also write `[ENV]`, `[CRASH]`, or `[LESSON]` lines the same way when the
   round surfaced one. Commit per repo workflow rules.

## Reading benchy metrics at concurrency > 1

`llama-benchy`'s `t_s` IS `tg_throughput`, and `tg_throughput` is a BATCH
AGGREGATE — `results.py:352` defines it as `sum(decode tokens) /
(max_last_token - min_first_token)`, i.e. every request's decode tokens over
the whole batch span. It is the same field the arena board's `c>1` figures come
from; sparkrun uploads that CSV. The per-request figure is the separate
`tg_req_throughput`.

- Report `tg_throughput` and `peak_throughput` side by side for any `c>1` row.
  Never quote one without the other — `tg` includes admission stagger,
  `peak_throughput` is the sustained ceiling.
- NEVER multiply a per-request figure by concurrency. `per-request x c`
  double-counts and breaks from c4 up.
- The stagger proxy `stagger ≈ c / (tg / tg_req)` is valid ONLY at full
  residency. At c5 against `max_num_seqs 4` it reads 3.85-4.08 where
  timestamps measure ~2.39.
- Read the scheduler's `Running/Waiting` lines at every new operating point.
  Residency is the precondition the proxy depends on; confirm it, don't assume
  it from the `-b concurrency` argument.

Evidence: `research/qwen36-35b-nvfp4-cells` (R10 from the source, R5c re-tested
on the archives). Across all 34 archived `c>1` records: `tg > tg_req` in 34/34
(ratios 1.13x-4.02x), `tg <= peak_throughput` 34/34, `tg / tg_req <= c` 34/34.
The per-request convention survived nine rounds because `c x tg` exceeds
`peak_throughput` in only 14 of 34 rows — all low-stagger arms — so the error
hides exactly where a new reader looks first.

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
