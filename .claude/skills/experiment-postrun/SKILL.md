---
name: experiment-postrun
description: What happens after one experiment's PR is open and before it merges — check the archive is complete, derive the [EXPERIMENT] memory from it, and confirm the index converged. Runs once per experiment. Use after an experiment agent returns a PR.
---

# After one experiment

Runs once per experiment, on the experiment's own branch, before the merge.

Order matters: 
1. create a memory
2. merge the feature branch into staging.
3. checkout staging, pull it, and delete the feature branch.

# Create a memory

Look at the directory where the experiement was conducted.

```
.
├── consolidated.json
├── round-tmp.csv
├── round-tmp.json
├── round-tmp.yaml
├── runs
│   ├── 000_d16384_c1.json
│   ├── 000_d16384_c1.log
│   ├── 001_d65536_c1.json
│   └── 001_d65536_c1.log
├── sparkrun-stdout.log
├── state.yaml
└── telemetry.log
```

The memory is derived from the archive, never written by hand.
Load all files in this directory into memory.

Everything it needs is already recorded: `state.yaml` holds the probe arguments, the pinned
image, the crash count and the session timestamps; `round-tmp.json` holds every
individual run value; `engine-capture.log` holds the serve command actually
executed and the engine's own counters. A hand-written `[EXPERIMENT]` under an
`experiment:` entity has no archive behind it, so the next reconcile deletes it
as stale.

## Procedure

1. Check the archive is complete. Under the hypothesis directory, the new
   `bench_<id>-<label>/` must have:
   - `engine-capture.log` — without it the run cannot be reproduced and cannot
     be merged; the serve command it used is not recoverable from anywhere else
   - `state.yaml`, `round-tmp.json`
   - the candidate recipe, if the run used one
   - `telemetry*.log`

2. Check the working tree: exactly one new `RESULTS.md` row, no other file
   touched, nothing staged from another run.

3. Check the memory service before writing to it. This is the first step in the
   experiment cycle that touches mem0, so health belongs here:
   `.claude/skills/mem0/scripts/memory.sh status`
   If it is unhealthy, run `memory-doctor.sh`. If it stays unhealthy, continue
   anyway — memory never blocks work — and say so in the return line so the
   harness knows the index is behind.

4. Derive the memory:
   ```
   .claude/skills/mem0/scripts/memory-backfill.sh --reconcile <series-dir>
   ```

5. Confirm it converged. Run it again with `-n`; it must report
   `0 add(s), 0 delete(s)`. A second pass that still wants to change something
   means the archive and the index disagree — report that rather than merging.

## What this does not do

- Does not merge, and does not delete the branch. The harness does both, after
  this returns clean.
- Does not write `EXPERIMENT.md`. The conclusion belongs to the hypothesis, once
  all its runs are in.
- Does not edit `recipe.yaml`, and does not touch any `bench_*` archive.
- Does not hand-write any `[EXPERIMENT]` or `[CRASH]` memory.

## Return value

One line: whether the archive is complete, the reconcile counts, whether the
second pass converged, and anything that needs fixing before the merge.

If the archive is missing its engine log, say so plainly and do not merge — the
run is not reproducible and re-running is cheaper than pretending otherwise.
