---
name: experiment
description: How an agent runs one benchmark experiment — what the harness hands it, what it measures and archives, the single RESULTS.md row, and the git and PR rules it follows. Use when running one experiment, or when setting an agent up to run one. The memory and the merge are handled afterwards by experiment-postrun.
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

1. Run the experiment with one command:

   ```
   .claude/skills/experiment/scripts/run-experiment.sh \
       --series research/<series> \
       --hyp experiments/<hypothesisId> \
       --label <setting-under-test> \
       [--recipe <candidate.yaml>] [-o key=value] [-b key=value] [--runs N]
   ```

   Do not assemble the sparkrun invocation by hand. The script keeps the engine
   alive after the grid, captures the effective recipe and engine log from it,
   stops it, archives everything, and validates the archive.

   It exits non-zero if `state.yaml`, `round-tmp.json`, `effective-recipe.json`
   or `engine-capture.log` is missing, or if the engine log has no `Running:`
   lines. That means the run is not reproducible — re-run it, do not open a PR.

2. Add exactly one row to `RESULTS.md`, in the schema that file already uses.
   One row. Do not restructure the file, do not add narrative, do not correct
   other rows — it is a lookup table, not a work log.

3. Commit, push the branch, open a PR into `staging`.

Reading the metrics is not your job. `experiment-postrun` parses the archive
after the PR is open.

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

## What happens next

The PR is not merged by this agent. `experiment-postrun` takes over: it checks
the archive is complete, derives the `[EXPERIMENT]` memory from it, and only
then does the harness merge and delete the branch.

Once every run for a hypothesis is in, `spark-autoresearch` writes the
conclusion into `EXPERIMENT.md` and the `[OBSERVATION]` memory, and decides
whether a fold rule fired.
