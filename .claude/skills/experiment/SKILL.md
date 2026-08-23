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

## How to use this skill

Run it, read the archive, return the report. One run per invocation.

## 1. Run

```bash
uv run --project .claude/skills/experiment \
    .claude/skills/experiment/scripts/run.py <run-dir>
```

The recipe is the whole experiment, probe grid included. There are no flags to
pass. A non-zero exit means the archive is incomplete — run it again.

## 2. A crash is a result

If the engine will not start or dies mid-run, that is data.

Keep the archive, say what the engine reported, and return it as a crash. Do
not retry more than twice, and never substitute a different configuration.

## 3. Report

Read the archive and return this block, and nothing else. It is the only thing
the caller sees — the archive stays with you.

```
bench     bench_c9518e3e96a3
valid     crash_count 0, failed [], 7/7 completed
served    declared == served          (or MISMATCH <field>: <declared> vs <served>)
epoch     vllm <version>, flashinfer <sha>, image <digest>

phase pp2048/tg128 @ d16384 c1
  pp      median 630.0    [616.3, 627.7, 629.4, 630.0, 632.0, 632.8, 635.8]
  tg      median 101.7    [97.7, 100.5, 101.6, 101.7, 102.5, 108.1, 118.5]
  ttfr    median 3261.6   [3231.6, 3247.1, 3251.0, 3261.6, 3264.6, 3273.2, 3333.6]

phase ctx_pp/ctx_tg @ d16384 c1
  pp      median 5858.5   [...]
  tg      median 103.4    [...]
  ttfr    median 2807.5   [...]

box       gpu_util 96 med, clock 2405 med, mem_avail min 4.2 GB, swap flat
notes     <anything anomalous, or none>
```

`results.json.benchmarks` holds two entries, one with
`is_context_prefill_phase: true`. Report both; the caller picks. Every value,
not just the median. Window telemetry to the session times in `state.yaml`.

If genuinely blocked — box unreachable, engine dead after two attempts —
return one line starting `ESCALATE:` with what was tried.
