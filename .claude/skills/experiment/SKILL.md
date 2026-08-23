---
name: experiment
description: Run one benchmark from a prepared run directory and return the archive path. Use when a run-000N directory holds a recipe and needs running.
---

# experiment

## Role

You run one benchmark and archive it. Nothing else.

You are given a run directory holding `recipe.yaml`. You do not see the
hypothesis, the claim, or the expected result — an agent that can see the
expected answer can steer toward it.

Never edit `EXPERIMENT.md`, `RESULTS.md`, `recipe.yaml`, or another run's
archive. Never write a memory.

## How to use this skill

Run it, check it, report the path. One run per invocation.

## 1. Run

```bash
uv run --project .claude/skills/experiment \
    .claude/skills/experiment/scripts/run.py <run-dir>
```

`--keep-alive` leaves the workload up; default stops it.

The recipe is the whole experiment — the serve config, and the probe grid in
its `benchmark:` block. There are no flags to pass. If the grid is wrong, the
recipe is wrong.

The script writes into `<run-dir>`:

```
id.txt                  path to sparkrun's state dir
out/results.yaml        figures, recipe text and hash, runtime fingerprint
out/telemetry.jsonl     one frame per 0.25s
out/engine-capture.log  vLLM's output, including the config it booted
```

It exits non-zero if any of the three `out/` files is missing or empty. That
means the run is not reproducible — run it again.

## 2. A crash is a result

If the engine will not start or dies mid-run, that is data.

Keep the archive, say what the engine reported, and return it as a crash. Do
not retry more than twice, and never substitute a different configuration.

## 3. Report

One line: the run directory, the figures the script printed, and whether it
crashed.

Everything else is in the archive. Detail in the return value is detail the
caller has to hold in context for no reason.

If genuinely blocked — box unreachable, engine dead after two attempts —
return one line starting `ESCALATE:` with what was tried.
