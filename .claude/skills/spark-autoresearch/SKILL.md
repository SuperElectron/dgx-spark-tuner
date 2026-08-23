---
name: spark-autoresearch
description: Run one round of an experiment — decide what the next run should test, dispatch it, record the result, then conclude the round and act on what it gave. Use when a round is open.
---

# spark-autoresearch

## Role

You run one round of an experiment and decide when its runs are done. Use
these skills:

- `spark-hypothesis`: sets up the experiment and its rounds, and later reads
  your runs to conclude the round and decide what follows
- `experiment`: runs one run directory

`spark-model` set up <model>, `spark-hypothesis` set up the experiment and its
rounds. You work inside one round:

```
Qwen3.6-35B-A3B-NVFP4/experiments/decode-tg

├── EXPERIMENT.md           // objective, strategy, held — frozen
├── recipe.yaml             // the baseline, we start with this.
├── h1                      // the round you are running
│   ├── HYPOTHESIS.md       // hypothesis, method, decision rule, runs
│   └── run-0001            // directory run with `experiment` skill
│       ├── id.txt
│       ├── out
│       │   ├── engine-capture.log
│       │   ├── results.yaml
│       │   └── telemetry.jsonl
│       └── recipe.yaml
...
```

You own `run-*/` and the round's runs table. Everything else — the objective,
the strategy, the held, the hypothesis, the decision rule — is frozen before
you start and you never edit it.

## How to use this skill

0. Free the card — the embedder is a vLLM instance sharing it with every
   benchmark. Idempotent, so just assert it when a round starts.

```bash
scripts/memory.sh stop
```

1. EXPERIMENTS: cycle CREATE, RUN, RECORD, once per planned row in "## Runs".
2. VALIDATE: when no row is left to run.

## THE LOOP

Agents do the work. You hold `h<N>/HYPOTHESIS.md` — the hypothesis, the rule,
the rows — and nothing else. Every benchmark, every read of a run archive, and
the conclusion pass go to an agent, which returns an answer rather than a file.

You may add rows the method calls for; you never touch the hypothesis or rule.

### CREATE

Use `h<N>/HYPOTHESIS.md` to do these steps:

1. setup: create the next `run-000N/`.
```bash
scripts/new-run.sh research/<model>/experiments/<experiment>/h<N>
```
2. Set `run-000N/recipe.yaml`; reason with `HYPOTHESIS.md` and previous runs (if they exist).

To read previous runs, send an agent — one run is thousands of lines and you
only need what it concludes:

```bash
scripts/show-run.sh <run-dir>
```

Give the agent the run dirs, the question, and that command. Do not run it
yourself.

### RUN

Hand the run directory to an agent using the `experiment` skill. It runs the
benchmark, reads the archive, and returns the report.

The agent is not given the hypothesis.

### RECORD

Take the agent's report and fill in that run's row in "## Runs".

Rows still blank → CREATE. None → VALIDATE. If the blank rows cannot reach the
Objective's number — the effect is smaller than the scatter in Strategy, or the
best case left falls short of the target — stop and VALIDATE now rather than
spend them.

The columns:

- **run** — the run directory, e.g. `run-0003`.
- **changed** — this run's recipe against the experiment's baseline, as
  `field: old → new`; comma-separated when a run moves more than one.
- **why** — the prior result that prompted it. `baseline` for the first run.
- **pp t/s, tg t/s, ttfr ms** — medians from the report's named cell, not its
  context-prefill phase.
- **bench** — the `bench_*` id.

A run that crashed still gets its row: `—` for the figures, and what the engine
reported in **why**.

A report saying declared and served disagreed voids the row. Run it again.

## VALIDATE

1. Conclude the round.
- Only once every row in the round's "## Runs" is filled.
- Send an agent to run the `spark-hypothesis` skill. It reads every run, writes
  the conclusion, and returns which of three the rule gave: **target met**,
  **lever alive**, or **lever spent**. It reads the archives so you do not.

2. Act on it.

    lever alive: it added rows to this round. Go to CREATE.
    lever spent: it opened `h<N+1>/`, or closed the experiment as exhausted.
                 A new round is a new loop — start it at CREATE.
    target met:  validate it before closing.

3. Validate a met target. `recipe-new.yaml` is the experiment's answer, so run
   it and see the target hold:

```bash
scripts/new-run.sh research/<model>/experiments/<experiment> recipe-new.yaml
```

- then hand it to an agent using the `experiment` skill, as in RUN.

    PASS: it reaches the target. The experiment is closed.
    FAIL: it doesn't. Hand back to `spark-hypothesis` — the round is not done.

## MEMORY

Once, when the experiment closes. The embedder wants the same card the
benchmarks do, so it goes back down after.

```bash
scripts/memory.sh start
scripts/remember.sh "<text>" <entity>   # one per round, one for the experiment
scripts/memory.sh stop
```

Each line restates a conclusion already written, and has to stand alone —
recall prints the line and nothing else.

```
[OBSERVATION] 2026-08-22 decode-tg/h1: max_num_seqs 4→64 at d0 c1 — tg flat within ±3% across all five, so single-stream decode does not use the extra slots (runs=5, bench_2ebcb63db398..bench_9f1)
```

Entity: the widest scope it is true for — `experiment:`, `model:`, `family:`,
`stack:`, `box:`, `flag:`.
