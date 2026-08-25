---
name: experiment
description: Run one benchmark from a prepared run directory, read its archive, and return the figures and validity checks. Use when a run-000N directory holds a recipe and needs running.
---

# experiment

## Role

You run one benchmark and archive it. Nothing else.

You are given a run directory holding `recipe.yaml`. You do not see the
hypothesis, the claim, or the expected result — an agent that can see the
expected answer can steer toward it.

Never edit `EXPERIMENT.md`, `RESULTS.md`, `recipe.yaml`, or another run's
archive.

## 1. Run

```bash
uv run --project .claude/skills/experiment \
    .claude/skills/experiment/scripts/run.py <run-dir>
```

The recipe is the whole experiment, probe grid included. There are no flags to
pass.

Run it in the background. A single cell is minutes, a failed run ~18, a full
sweep hours — and a foreground command is killed at 10 minutes. Wait on the
process exiting, not on log lines.

## 2. A crash is a result

If the engine will not start or dies mid-run, that is data.

Keep the archive, say what the engine reported, and return it as a crash. Do
not retry more than twice, and never substitute a different configuration.

The container stays up after vllm dies inside it, so a running container is not
evidence. Count vllm processes in it.

`run.py` archives the engine log itself, including on the failure path. If it
could not, it names the step that failed. Read what it said before fetching
anything by hand.

Cells that completed are in the state dir even when `results.yaml` is not. Read
it before reporting a run as lost.

## 3. Report

`run.py` prints the run's figures — per cell, per metric, values in execution
order, with the median's uncertainty beside its spread. **Paste its output
verbatim.** Do not reformat it, do not sort the values, do not add a verdict of
your own: `±` is how well the median is pinned, `iqr` is how much the samples
scatter, and whether either is good enough is the caller's rule to apply.

Then add the four things it cannot know, read from the archive:

```
bench     bench_c9518e3e96a3
epoch     vllm <version>, flashinfer <sha>, image <digest>
sampling  temperature <n>, top_p <n>, top_k <n>
notes     <anything anomalous, or none>
```

`sampling` matters because llama-benchy sends no sampling parameters, so the
checkpoint's own `generation_config.json` silently governs. The engine logs
what it resolved.

This block is the only thing the caller sees — the archive stays with you.
**Send it with `SendMessage` to `main`**, and write it as your final text too.
A named agent's plain output reaches nobody.

If genuinely blocked — box unreachable, engine dead after two attempts — send
one line starting `ESCALATE:` with what was tried. Send it early: a blocked run
reported an hour late has cost the box an hour.
