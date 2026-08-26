---
name: spark-autoresearch
description: Run one round of an experiment — decide what the next run should test, dispatch it, record the result, then conclude the round and act on what it gave. Use when a round is open.
allowed-tools: Bash(.claude/skills/spark-autoresearch/scripts/new-run.sh:*) Bash(.claude/skills/spark-autoresearch/scripts/show-run.sh:*) Bash(.claude/skills/memory/scripts/recall.sh:*) Bash(.claude/skills/memory/scripts/remember.sh:*) Bash(.claude/skills/memory/scripts/record-run.sh:*) Bash(.claude/skills/memory/scripts/prune-round.sh:*) Bash(.claude/skills/memory/scripts/memory.sh stop) Bash(jq:*) Bash(cut:*) Read Grep Glob
disallowed-tools: Bash(.claude/skills/memory/scripts/forget.sh:*) Bash(.claude/skills/memory/scripts/migrate.sh:*) Bash(.claude/skills/memory/scripts/regen.sh:*)
---

# spark-autoresearch

## What HYPOTHESIS.md is for

It is the **contract** for the round — hypothesis, method, decision rule, and
the runs table. It is not the notebook. Per-round analysis belongs in the
memory store, which is queryable and config-stamped; the file holds only what
the round is bound to. The decision rule was frozen before any figure existed,
and you never edit it.

## Role

Every command here assumes cwd is the **repo root**, which is why every script
is reached as `.claude/skills/...`. That is the one convention across all
skills, and it is what lets a single permission rule cover every caller.

**Memory:** you may recall by `--list`, `--get` and `--filter`; write
`[OBSERVATION]` at `round:<experiment>/h<N>` and promote `[LESSON]` to a tier-2
entity; write the runs table; and `memory.sh stop` — never `start`, because the
embedder shares the card with the benchmarks you dispatch. You are the only
skill that deletes, and deletion goes through `prune-round.sh` alone. Full
matrix: [../memory/references/access.md](../memory/references/access.md).

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
.claude/skills/memory/scripts/memory.sh stop
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
.claude/skills/spark-autoresearch/scripts/new-run.sh research/<model>/experiments/<experiment>/h<N>
```
2. Recall before the run is written. Has this cell already been measured? The
   embedder stays down — these forms do not need it.

```bash
.claude/skills/memory/scripts/recall.sh --list '' 2000 --filter model=<hf-id>,test=<test>,depth=<d>,conc=<c>
.claude/skills/memory/scripts/recall.sh --get <id>
```

`--get` anything you intend to act on. A scan line is triage; the record
carries the date, the protocol and the epoch, which are usually what decide
whether it transfers to your cell.

3. Set `run-000N/recipe.yaml`; reason with `HYPOTHESIS.md`, what recall
   returned, and previous runs (if they exist).

To read previous runs, send an agent — one run is thousands of lines and you
only need what it concludes:

```bash
.claude/skills/spark-autoresearch/scripts/show-run.sh <run-dir>
```

Give the agent the run dirs, the question, and that command. Do not run it
yourself.

4. Propose the row. A not-yet-run row is written by the same script that later
   fills it, with the figures left off:

```bash
.claude/skills/memory/scripts/record-run.sh research/<model>/experiments/<experiment>/h<N>/HYPOTHESIS.md --run run-000N \
  --changed "<field: old -> new>" --why "<the prior result that prompted it>" \
  --cell "d<D> c<C>"
```

That is the round's plan: the proposed rows are the ones still to run. RECORD
re-runs the same command with the figures, and the script replaces the row
rather than appending a second one. Planning lives nowhere else — no free-text
row, no hand edit.

### RUN

Hand the run directory to an agent using the `experiment` skill. It runs the
benchmark, reads the archive, and returns the report.

The agent is not given the hypothesis.

### RECORD

Take the agent's report and write two things: the row, and the memory. Both
once per run, both now — not at close.

```bash
.claude/skills/memory/scripts/record-run.sh research/<model>/experiments/<experiment>/h<N>/HYPOTHESIS.md --run run-000N \
  --changed "<field: old -> new>" --why "<prior result>" --cell "d<D> c<C>" \
  --pp <n> --tg <n> --ttfr <n> --bench <bench_id>

.claude/skills/memory/scripts/remember.sh \
  "[OBSERVATION] <what this run measured, and what it decides next>" \
  round:<experiment>/h<N> \
  --meta date=<YYYY-MM-DD> --meta model=<hf-id> --meta quant=<q> --meta runtime=vLLM \
  --meta test=<test> --meta depth=<D> --meta conc=<C> --meta runs=<n> \
  --meta bench=<bench_id> --meta protocol=<exact_tg> \
  --meta epoch.build_source=<digest> --meta epoch.vllm=<sha>
```

This is the round's notebook and it is written per run, so it can be verbose:
record the dead end as well as the result. The next run needs "changed X, no
effect at this cell, so go at Y" and nobody should have to re-derive it.

- **Exit 3 is a refusal** naming the field that is missing. Fix the write.
  Never route around a guard — a line without its config is a claim no later
  round can judge.
- **Exit 0 can still mean NOT written**, when the store is unreachable. Memory
  never blocks work, which is why stderr matters: check it.
- **Bench ids come from `run-000N/id.txt`**, read, never reconstructed.
- **`epoch.build_source` is the digest the agent reported**, sparkrun's upstream
  build source. It is not `epoch.image`, which means the image the box ran and
  which only `observe` can supply. Never write one under the other.
- **Every `<...>` above is a placeholder** — substitute the value, never the
  brackets. `test=` takes one of `tg128`, `pp2048`, `ctx_tg`; a stray
  `test=<tg128>` matches no filter and the CREATE dedupe scan then finds
  nothing. The full vocabulary is in
  [../memory/references/write.md](../memory/references/write.md).

Rows still blank → CREATE. None → VALIDATE. If the blank rows cannot reach the
Objective's number — the effect is smaller than the scatter in Strategy, or the
best case left falls short of the target — stop and VALIDATE now rather than
spend them.

The columns:

- **run** — the run directory, e.g. `run-0003`.
- **changed** — this run's recipe against the experiment's baseline, as
  `field: old → new`; comma-separated when a run moves more than one.
- **why** — the prior result that prompted it. `baseline` for the first run.
- **cell** — which cell the figures are from, e.g. `d16384 c1`.
- **pp t/s, tg t/s, ttfr ms** — medians from that cell, not its
  context-prefill phase.
- **bench** — the `bench_*` id.

A sweep returns every cell it ran. Record the one the rule reads; the rest are
data, not evidence, unless the hypothesis named them.

Two levers the grid gives you, worth knowing before you write a recipe:

- **`schedule:`** sets execution order, and a schedule entry may override any
  grid key for that cell — `runs` included. Spend repeats where the rule turns
  and leave coverage cells cheap. A cell needs four values before it gets a
  stability verdict.
- Cells in one schedule share a boot and a warm cache, so they are **not**
  independent. Use a schedule for coverage. An arm against a control is one
  cell per run, which is what the cache reset is for.

A run that crashed still gets its row: `--pp — --tg — --ttfr —`, and what the
engine reported in **why**.

A report saying declared and served disagreed voids the row. Run it again.

## VALIDATE

1. Conclude the round.
- Only once every row in the round's "## Runs" is filled.
- Send an agent to run the `spark-hypothesis` skill. It reads every run, fills
  the `## Verdict` line, writes the conclusion, and returns which of three the
  rule gave: **target met**, **lever alive**, or **lever spent**. It reads the
  archives so you do not.
- Then promote and prune this round's memories — see `## MEMORY`. The round is
  not closed until that is done.

2. Act on it.

    lever alive: it added rows to this round. Go to CREATE.
    lever spent: it opened `h<N+1>/`, or closed the experiment as exhausted.
                 A new round is a new loop — start it at CREATE.
    target met:  validate it before closing.

3. Validate a met target. `recipe-new.yaml` is the experiment's answer, so run
   it and see the target hold:

```bash
.claude/skills/spark-autoresearch/scripts/new-run.sh research/<model>/experiments/<experiment> recipe-new.yaml
```

- then hand it to an agent using the `experiment` skill, as in RUN.

    PASS: it reaches the target. The experiment is closed.
    FAIL: it doesn't. Hand back to `spark-hypothesis` — the round is not done.

## MEMORY

Writing happens at RECORD, once per run. What happens here is **promotion**,
after the conclusion is written and before the round is left.

Volume rises through a round and falls at its close. That fall is what bounds
the bloat: without it, every round's working notes live forever and recall
degrades into scrolling.

1. Read back everything the round wrote.

```bash
.claude/skills/memory/scripts/recall.sh --list round:<experiment>/h<N> 200
```

2. Promote what holds wider than this round's cell, model or epoch — a
   mechanism, not a figure; the runs table already holds the figures. Promote
   by writing a **new** memory at the widest entity it is actually true for.

```bash
.claude/skills/memory/scripts/remember.sh "[LESSON] <what holds wider>" flag:<lever> \
  --meta date=<YYYY-MM-DD> --meta basis="<experiment>/h<N>: <cells and figures>" \
  --meta model=<hf-id> --meta test=<test>
```

3. Confirm the promotion reads back.

```bash
.claude/skills/memory/scripts/recall.sh --list flag:<lever> 50
```

4. Then prune — and only then. **Promote, confirm the read-back, prune.** That
   order is not advice: deletion is permanent and the store keeps no undo, so
   the round's reasoning must exist somewhere wider before its only copy goes.

```bash
.claude/skills/memory/scripts/prune-round.sh round:<experiment>/h<N> \
  --promoted-to flag:<lever>

.claude/skills/memory/scripts/prune-round.sh round:<experiment>/h<N> \
  --promoted-to flag:<lever> --confirm-destructive
```

The first call is the review step: it prints every memory it would delete, ids
and text, and stops. It refuses outright (exit 3) unless a memory at
`flag:<lever>` already carries `<experiment>/h<N>` in its `basis=` — which is
why step 2's `--meta basis=` is load-bearing rather than decorative. Read what
it printed before running the second call.

**Never prune with `forget.sh` directly.** The old form —
`recall.sh --list <round> 200 | cut -f1 | forget.sh --yes -` — reads as safe
because `forget.sh` refuses without `--yes` and prints what it would delete. But
that pipeline passes `--yes` itself, so the guard never fires and the ids are
never surfaced. The review step existed on paper only, which is exactly what
`prune-round.sh` was written to fix.

A round that closes without pruning has not closed.

The markers are `[OBSERVATION]` `[ENV]` `[LESSON]` `[IDEA]` and nothing else;
`[EXPERIMENT]` is retired and rejected. Entities and the per-marker metadata
contract are in [../memory/references/write.md](../memory/references/write.md);
promotion in [../memory/references/tiers.md](../memory/references/tiers.md).
