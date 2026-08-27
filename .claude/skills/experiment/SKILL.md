---
name: experiment
description: Run one benchmark from a prepared run directory, read its archive, and return the figures and validity checks. Use when a run-000N directory holds a recipe and needs running.
allowed-tools: Bash(uv:*) Bash(.claude/skills/experiment/scripts/reset-cache.sh:*) Bash(.claude/skills/memory/scripts/remember.sh:*) Bash(jq:*) Read Grep Glob
disallowed-tools: WebFetch WebSearch Bash(.claude/skills/memory/scripts/memory.sh:*) Bash(.claude/skills/memory/scripts/recall.sh:*) Bash(.claude/skills/memory/scripts/forget.sh:*) Bash(.claude/skills/memory/scripts/prune-round.sh:*) Bash(.claude/skills/memory/scripts/record-run.sh:*) Bash(.claude/skills/memory/scripts/update.sh:*)
---

# experiment

## Role

You run one benchmark and archive it. Nothing else.

You are given a run directory holding `recipe.yaml`. You do not see the
hypothesis, the claim, or the expected result — an agent that can see the
expected answer can steer toward it.

Never edit `EXPERIMENT.md`, `RESULTS.md`, `recipe.yaml`, or another run's
archive.

Every command here assumes cwd is the repo root, which is why scripts are
reached as `.claude/skills/...`.

**Memory:** you write `[ENV]` at `box:<alias>` when the box leaves its band, and
nothing else. No recall — you must not see what the round expects, or you could
steer toward it. No deletes, no runs table, and **never the embedder**: it is a
vLLM instance on the same card you are timing. Matrix:
[../memory/references/access.md](../memory/references/access.md).

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
epoch     vllm <version>, flashinfer <sha>, build_source <digest>
sampling  temperature <n>, top_p <n>, top_k <n>
notes     <anything anomalous, or none>
```

`build_source` is `container_dev_sparkrun_source_digest` under
`cluster.runtime_info` — the upstream image sparkrun built from, not the image
the box ran. The archive holds no digest for the image that ran, so do not
report one and do not present this as one.

`sampling` matters because llama-benchy sends no sampling parameters, so the
checkpoint's own `generation_config.json` silently governs. The engine logs
what it resolved.

This block is the only thing the caller sees — the archive stays with you.
**Send it with `SendMessage` to `main`**, and write it as your final text too.
A named agent's plain output reaches nobody.

If genuinely blocked — box unreachable, engine dead after two attempts — send
one line starting `ESCALATE:` with what was tried. Send it early: a blocked run
reported an hour late has cost the box an hour.

## 4. If the box left its band, write one `[ENV]`

The band is the one `run.py` already checks, in
`.claude/skills/experiment/scripts/measure.py`. You add no instrumentation: the
emit reads the `box:` line of the report you just pasted, or the message
`run.py` died with.

| value | known band | out of band means |
|---|---|---|
| peak clock while busy | 2300–2400 MHz | 400–900 MHz is the GB10 power-delivery fault (`CLOCK_FAULT_BAND`); anything else outside is unexplained |
| peak power | at or above 60 W (`POWER_FLOOR_W`) | the box was power-capped and the figures measure the cap |
| busy frames | at least one on any cell over a minute | telemetry saw the card idle throughout, so nothing above was actually checked |

Inside the band, write nothing — a clean run is the normal case and needs no
memory. Outside it, write exactly **one** memory for the run, naming every
value that left band:

```bash
.claude/skills/memory/scripts/remember.sh \
  "[ENV] GPU pinned near 700 MHz while busy against a 2300-2400 MHz band, throttle bitmask all-clear — the GB10 power-delivery fault signature" \
  box:spark-6f0e \
  --meta date=2026-08-26 --meta scope="one run, under load, figures discarded" \
  --meta bench=bench_c9518e3e96a3 --meta epoch.vllm=<version> \
  --meta epoch.flashinfer=<sha> --meta epoch.build_source=<digest>
```

`date` and `scope` are required; the three `epoch.*` fields are the ones you
already read from the archive for the report block, so stamp all three.

Never stamp `epoch.image`. That key means the digest of the image the box ran,
and the archive does not record it — only `memory`'s box sweep, reading the
running container, can supply it. Putting the build-source digest there would read as
an image change against every record that carries a real one.

**Observation, not decision.** State the measurement and the band it left.
Never name a cause you did not measure, never say what should be done about it,
and change nothing on the box — clocks and power policy are Mat's.

Keep the text canonical: round the figure to its signature ("near 700 MHz", not
`721.3`) and let the run's own detail ride in the metadata. The store dedupes
on the sha256 of the text alone, so a fault that recurs writes the same
sentence and returns the first memory's id rather than a second row. That is
the intent — the store records that the box left its band and when it first
did; how many runs it hit is in the archives, not here.

The memory goes with the report, not instead of it. The run is still reported,
and a run whose figures measure a fault is still returned as a crash.
