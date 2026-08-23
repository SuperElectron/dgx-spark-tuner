---
name: spark-autoresearch
description: Run a hypothesis's experiments — decide what the next run should test, dispatch it, record the result, then validate the proposed config and close the hypothesis or keep going. Use when a hypothesis is open.
---

# spark-autoresearch

## Role

You are here to run the experiments and to decide when the hypothesis is
answered. Use these skills:

- `spark-hypothesis`: sets up the hypothesis, and later reads your runs to
  write the conclusion and propose `recipe-new.yaml`
- `experiment`: runs one run directory

Here we show when `spark-model` skill has been used to setup <model> directory and `spark-hypothesis` to setup <model>/experiments/<hypothesis> as follows:

```
qwen36-35b-nvfp4/experiments/test-runtime

├── EXPERIMENT.md           // setup with `spark-hypothesis` skill.
├── recipe.yaml             // the baseline, we start with this.
├── recipe-new.yaml         // what `spark-hypothesis` skill proposes as the conclusion.
├── run-0001                // directory run with `experiment` skill
│   ├── id.txt
│   ├── out
│   │   ├── engine-capture.log
│   │   ├── results.yaml
│   │   └── telemetry.jsonl
│   └── recipe.yaml
...
```

You own `run-*/` and the runs table. The claim and the decision rule are frozen
before you start and you never edit them.

## How to use this skill

1. EXPERIMENTS: You follow the sections `CREATE, RUN, RECORD` below.
- Repeat for as many runs as the method needs; there is no expected number. 
- When the method is answered, hand the runs to `spark-hypothesis`.

2. VALIDATE: A conclusion has been written to `EXPERIMENT.md`, so validate it!

## THE LOOP

EXPERIMENTS cycles three sections, defined below:
- CREATE
- RUN
- RECORD

After all experiments from the `EXPERIMENT.md` have been run, we use VALIDATE (details below).
- if it fails, we go back to the loop runs (EXPERIMENTS: CREATE, RUN, RECORD)

### CREATE

Use `EXPERIMENT.md` to do these steps:

1. setup: create the next `run-000N/`.
```bash
scripts/new-run.sh research/<model>/experiments/<hypothesis>
```
2. Set `run-000N/recipe.yaml`; reason with `EXPERIMENT.md` and previous runs (if they exist).

### RUN

Use the `experiment` skill to run one experiment (e.g. run-000N).

### RECORD

Read the contents of this run (e.g. `run-000{N}/`)
- append one row to "## Runs" section in `EXPERIMENT.md` to record the results
- Look at "## Runs" in `EXPERIMENT.md`: go to CREATE if not done, or VALIDATE.

## VALIDATE

1. Make a conclusion to the hypothesis: make a proposal to validate.
- you can only run this if all the experiment in the "## RUNS" section in `EXPERIMENT.md` are finished.
- Use the `spark-hypothesis` skill (adds conclusion in `EXPERIMENT.md` and writes `recipe-new.yaml`).

2. `recipe-new.yaml` is the hypothesis's prediction
- Run it and validate it holds the conclusion section of `EXPERIMENT.md`.

```bash
scripts/new-run.sh research/<model>/experiments/<hypothesis> recipe-new.yaml
```

- then, run the experiment with `experiment` skill.
- After you run, does it PASS or FAIL?

    PASS: the hypothesis is answered. Close it if the conclusion is true.
    FAIL: it didn't run as expected. You need to run more experiments and continue the loop.

If it fails, then you need to update `EXPERIMENT.md` and add new experiments to run, so the loop continues (runs `experiment` skill until end, then `spark-hypothesis` and we repeat this section).
