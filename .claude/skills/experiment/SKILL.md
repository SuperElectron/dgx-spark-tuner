---
name: experiment
description: Run one benchmark with the sparkrun CLI, archive it, and report the figures and validity checks. Use when a run directory holds a recipe and needs running.
allowed-tools: Bash(sparkrun:*) Bash(.claude/skills/experiment/scripts/capture.sh:*) Bash(.claude/skills/memory/scripts/memory.sh:*) Bash(.claude/skills/memory/scripts/remember.sh:*) Bash(.claude/skills/memory/scripts/recall.sh:*) Bash(ssh:*) Read
---

# Role

Run the benchmark in `<run-dir>/recipe.yaml`. Archive it. Report it.

Dispatch this to an agent — a run's output is large and belongs in its
context, not the caller's.

Run every command from the repo root.
`<host>` is the `host` field in `.claude/box.json`.
`<regime>` is the measurement protocol, from `protocol` in
[../memory/references/write.md](../memory/references/write.md).
Run all seven steps, in order, sequentially.

## 1. Dry run

```bash
export UV_PYTHON=/opt/homebrew/bin/python3.14
sparkrun benchmark <run-dir>/recipe.yaml --solo -H <host> --fresh --dry-run
```

Stop and report unless all three hold:

- the image line names a `ghcr.io/...` path, not a bare `vllm-node`
- no `Building — skipped (no builder)`
- the cell grid is the one the recipe declares

`recipe_version: '2'` fails all three — only `'1'` resolves the image alias.

## 2. Stop the embedder

```bash
.claude/skills/memory/scripts/memory.sh stop
ssh <host> 'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader'
```

Stop and report if utilisation is above 10%. `memory.used` reads `[N/A]` on
this box — unified memory — so it is not a check.

## 3. Measure

Flags you cannot modify in `sparkrun`:
- do not add these flags: "-b, -o, --tp, --pp, --gpu-mem, --max-model-len, --image, --framework."
- we want to run recipe.yaml as it is.

Flags you can modify in `sparkrun`:
- `--fresh` — re-measure a recipe that has run before.
- `--resume` — a grid that died partway keeps its finished cells instead of re-running them.
- `--timeout <seconds>` — default 14400. Raise for a long grid.
- `--skip-run --no-stop` — benchmark a server that is already up, and leave it up.
- `--no-exit-on-first-fail` — use if we are running a broad sweep, otherwise fail is good.
- `--port <n>` — only if 8000 is taken.

You can load box.json to get "<host>"

Boot first, then benchmark the running server. A single `sparkrun benchmark`
dies at `inference server health check timed out` — it gives up after 2 refused
connections and this image binds :8000 only once the model has loaded.

```bash
sparkrun run <run-dir>/recipe.yaml --solo -H <host> --no-follow

# `run` returns in ~27s; the model needs ~60s. Benchmarking early fails the
# first cell and the schedule aborts.
until [ "$(ssh <host> 'curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health')" = 200 ]; do sleep 10; done

sparkrun benchmark <run-dir>/recipe.yaml --solo -H <host> \
    --fresh --skip-run --no-stop --output <run-dir>/out/results.yaml
```

`--fresh` is not optional. Without it sparkrun re-emits a prior run's recorded
figures and sends no requests.

Note the `Benchmark ID:` it prints. The ID hashes the config only, so two run
directories holding identical recipes share one archive and the second
overwrites the first. `capture.sh` refuses the mismatch rather than attributing
the figures; capture each run before starting the next.

The CLI does not write the engine log. Save it before step 5 stops the server —
without it there is no served-vs-declared check and the run cannot be validated:

```bash
sparkrun logs <run-dir>/recipe.yaml -H <host> > <run-dir>/out/engine-capture.log
```

## 4. Capture

```bash
.claude/skills/experiment/scripts/capture.sh <bench-id> <run-dir>/out <regime>
```

## 5. Stop the server

```bash
sparkrun stop <run-dir>/recipe.yaml -H <host>
```

Run this even if step 3 or 4 failed.

## 6. Report

Paste `<run-dir>/out/summary.txt` verbatim. Add any command that failed. Say
nothing about whether the figures are good.

## 7. Write memory

```bash
.claude/skills/memory/scripts/memory.sh start
.claude/skills/memory/scripts/remember.sh "[OBSERVATION] <what this measured>" \
  round:<experiment>/h<N> \
  --meta date=<YYYY-MM-DD> --meta model=<hf-id> --meta test=<test> \
  --meta depth=<D> --meta conc=<C> --meta bench=<bench_id> \
  --meta protocol=<regime>
.claude/skills/memory/scripts/recall.sh --get <returned-id>
```

`remember.sh` exits 0 even when the write failed. The `--get` is how you know
it landed. Leave the embedder running.

Keys and required fields:
[../memory/references/write.md](../memory/references/write.md).
