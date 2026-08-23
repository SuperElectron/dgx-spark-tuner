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
pass.

Run it in the background. A healthy run is minutes; a failed one takes ~18, and
a foreground command is killed at 10.

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

Read the archive and report this block, and nothing else. It is the only thing
the caller sees — the archive stays with you.

**Send it. Do not just write it.** If you were given a name you are a teammate,
not a one-shot: your plain output reaches nobody and you will sit idle holding a
finished report. Deliver it with `SendMessage` to `main` as the last thing you
do. Write it as your final text too, for the case where you were spawned
unnamed — but the send is what makes it arrive.

```
bench     bench_c9518e3e96a3
valid     crash_count 0, failed [], 7/7 completed
served    declared == served          (or MISMATCH <field>: <declared> vs <served>)
epoch     vllm <version>, flashinfer <sha>, image <digest>
sampling  temperature <n>, top_p <n>, top_k <n>   (from the engine log)

phase pp2048/tg128 @ d16384 c1
  pp      median 630.0  max/min 1.02  [616.3, 632.8, 629.4, 630.0, 627.7, 635.8, 632.0]
  tg      median 101.7  max/min 1.21  [102.5, 118.5, 100.5, 97.7, 101.6, 108.1, 101.7]
  ttfr    median 3261.6 max/min 1.03  [...]

phase ctx_pp/ctx_tg @ d16384 c1
  pp      median 5858.5 max/min 1.03  [...]
  tg      median 103.4  max/min 1.19  [...]
  ttfr    median 2807.5 max/min 1.02  [...]

box       peak <n> W, gpu_util <n> med, mem_avail min <n> GB, swap flat
notes     <anything anomalous, or none>
```

**Values go in raw execution order — the order they appear in `values`, never
sorted.** Sorting throws away when each sample happened, which is the only way
to see warmup cost, drift, or an ordering artifact. Report every value.

`results.json.benchmarks` holds two entries, one with
`is_context_prefill_phase: true`. Report both; the caller picks.

`sampling` matters because llama-benchy sends no sampling parameters, so the
checkpoint's own `generation_config.json` silently governs. The engine logs
what it resolved; find it and record it, because it changes what is generated
and therefore what decode measures.

`run.py` prints the grid it verified, peak power, and a stable/UNSTABLE verdict
per metric. Pass its verdict through — do not recompute it.

Window telemetry to the session times in `state.yaml`. `gpu_clock_mhz` is
readable: under load this box reports 2359-2398 MHz against a 3003 MHz ceiling,
and the 208s are the idle gaps between runs. A short shallow cell can read 208
in every frame because the 0.25 s sampler misses its busy windows, so a low
peak clock only means something when the GPU was seen busy at all.

If genuinely blocked — box unreachable, engine dead after two attempts — send
one line starting `ESCALATE:` with what was tried. Send it the same way, and
send it early: a blocked run reported an hour late has cost the box an hour.
