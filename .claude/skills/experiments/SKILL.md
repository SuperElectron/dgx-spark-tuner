---
name: experiments
description: How a single benchmark experiment is run end to end — what the harness hands the agent, what the agent measures and archives, and the git and PR rules it follows. Use when running one experiment, or when setting an agent up to run one.
---

# Running one experiment

One experiment is one benchmark invocation and its archive. The agent that runs
it is deliberately narrow: it knows the configuration to run and nothing about
the hypothesis behind it. That isolation is the point — an agent that cannot
see the expected answer cannot steer toward it.

Division of labour:

- The harness creates the branch, checks it out, and hands the agent its context.
- The agent runs the experiment, archives it, adds one `RESULTS.md` row, commits,
  pushes, and opens a PR.
- The harness reviews, merges to `staging`, and derives the memory.

The agent never writes memories, never touches `EXPERIMENT.md`, and never merges.

## What the harness provides

Before the agent starts, the harness has already run
`git checkout -b feature/<name> staging` and confirmed with
`git branch --show-current`. The agent inherits that branch.

The agent is given, explicitly:

- the series directory and the hypothesis directory to archive into
- the recipe to run, and any `-o` overrides
- the probe arguments (`-b pp=`, `-b tg=`, `-b depth=`, `-b concurrency=`, `-b runs=`)
- the archive label to use as the directory suffix
- anything to capture beyond the defaults

It is not given the hypothesis, the objective, or the expected result.

## Procedure

1. Confirm the branch: `git branch --show-current` must not be `main` or
   `staging`. Stop if it is.

2. Start the engine log capture before the run, and keep it for the whole
   invocation. This is not optional — a run without `engine-capture.log` is
   incomplete and cannot be merged. It is the only artifact that records the
   serve command actually executed including `-o` overrides, and the only place
   the engine's prefix-cache hit rate and `Running/Waiting` scheduler lines
   appear. It is not recoverable afterwards from `~/.cache/sparkrun`.

3. Sample telemetry alongside the run:
   `.claude/skills/spark-autoresearch/scripts/sample-telemetry.sh <seconds> <outfile>`

4. Run the benchmark. Serve-command flags need a candidate recipe copy; `-o`
   overrides only templated recipe defaults.

5. Archive it. sparkrun prints `Benchmark ID: bench_<id>`:
   ```
   .claude/skills/spark-autoresearch/scripts/archive-round.sh \
       <series-dir> bench_<id> <label>
   ```
   sparkrun reuses a benchId for identical recipe+params, so the label suffix is
   what keeps a run from overwriting an earlier one. Move the archive into the
   hypothesis directory you were given, and put the engine log, telemetry log and
   any candidate recipe inside it.

6. Read the metrics with
   `.claude/skills/spark-autoresearch/scripts/parse-round.py <archive>/round-tmp.json`.
   Report medians, never means.

7. Add exactly one row to `RESULTS.md`, in the schema that file already uses.
   One row. Do not restructure the file, do not add narrative, do not correct
   other rows — it is a lookup table, not a work log.

8. Commit, push the branch, open a PR into `staging`.

## A crash is a result

If the engine will not start or dies mid-run, that is data, not failure.
Archive it with a `-crash` label, keep the engine log, and say what the engine
reported. Do not retry more than twice, and do not silently substitute a
different configuration.

## Git

- Branch off `staging`; merge back into `staging` via PR.
- Commit and push only your own branch. Never merge, never touch `main`.
- One agent owns the working tree at a time. If another round holds the box, do
  not run git operations.
- Never commit `QUEUE.md`.

## What the agent must not do

- Not write memories. `[EXPERIMENT]` memories are derived from the archive by
  the harness (`memory-backfill.sh --reconcile`) after the merge. A hand-written
  one has no archive to reconcile against and gets deleted as stale.
- Not check or start the memory service, or the embedding model. Infrastructure
  is the harness's concern.
- Not write or edit `EXPERIMENT.md`. The claim and its conclusion belong to the
  hypothesis, which the agent cannot see.
- Not edit `recipe.yaml`. Folding is a decision made against a pre-declared rule,
  after the round.
- Not edit anything inside another `bench_*` archive.
- Never pass `--arena`, and never run `sparkrun arena` anything.
- Never change box system state: clocks, power policy, driver, kernel, `apt`.

## What the agent returns

One line: the archive path, the medians, the crash count, and the PR URL.
Everything else is in the archive and the PR. Detail in the return value is
detail the harness has to hold in context for no reason.

If genuinely blocked — box unreachable, engine will not start after two
attempts, a validator refuses the configuration — return one line starting
`ESCALATE:` with what was tried.

## Then the harness

1. Verifies the PR: archive present with an engine log, one `RESULTS.md` row,
   nothing else modified.
2. Merges to `staging`.
3. Runs `memory-backfill.sh --reconcile <series-dir>` to derive the
   `[EXPERIMENT]` memory from the archive.
4. When every run for the hypothesis is in, writes the conclusion into
   `EXPERIMENT.md` and the `[OBSERVATION]` memory.
