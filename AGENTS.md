# Project rules

Benchmark-tuning research on a DGX Spark box. The work is hypothesis-driven:
understand what governs throughput on this hardware and this model, and fold
what we learn into the series' `recipe.yaml`.

These are the invariants — they hold before you know which task you are doing.
The procedures live in the skills; see `## Skills`.

**Nothing is ever submitted to Spark Arena.** There is no login and one is not
wanted. Never pass `--arena`; never run `sparkrun arena` anything.

## Git

`main` ← `staging` ← `feature/*`. Never commit directly to `main` or `staging`.

Branch before your first commit, then verify — as commands, not as intent:

```
git checkout -b feature/<name> staging     # off staging, not main
git branch --show-current                  # confirm before committing
```

A prohibition is only evaluated once you are already committing, which is too
late. This failed exactly that way and cost a history repair.

**One agent owns the working tree at a time.** Every agent shares one checkout.
While a round holds the box, no other agent runs git operations — a stray
checkout mid-round corrupts a benchmark that cost real box time.

An agent commits and pushes **only its own branch**. Merging up is the
orchestrator's call, and the orchestrator verifies what the branch actually
landed before merging.

Never commit `QUEUE.md` (gitignored).

## Layout

```
research/<series>/
├── recipe.yaml                     the tuned artifact — the ONLY thing we tune
├── RESULTS.md                      Mat's lookup table
├── docs/  scripts/
└── experiments/<hypothesisId>/
    ├── HYPOTHESIS.md → EXPERIMENT.md
    └── bench_<id>-<label>/         one directory per invocation
```

- **Creating any other file at a series root is a bug.** Analysis goes in
  `EXPERIMENT.md`; candidate recipes go in the run's archive.
- Runs live under the hypothesis that produced them. Hypothesis directories are
  named for the **claim**, not the cell.
- Never edit anything inside a `bench_*` directory — those exports are immutable.
- **`RESULTS.md` is Mat's personal lookup table. Nothing derives from it** —
  not memories, not conclusions, not tooling. It is an output of the work, never
  an input to it. Records that tooling reads come from the `bench_*` archives.

`.gitignore` allow-lists what is tracked per run and says why, inline.

## The box

- **Never change system state autonomously**: clocks, power policy, driver,
  kernel, `apt`. Measure it, record it, leave the decision to Mat.
- The hostname comes from `.claude/box.json` (gitignored).
- An image or vLLM version change is a new epoch — re-measure the incumbent
  before comparing across it.
- Memory ops must never block work. `remember.sh` / `recall.sh` always exit 0
  on failure; never retry in a loop or ask what to do.

## Skills

Invoke the skill; do not reimplement it from memory.

| Skill | Governs |
|---|---|
| `spark-autoresearch` | the research loop — stating a hypothesis, running a round, archiving, reading the instrument's metrics, concluding, deciding what is next |
| `mem0` | the memory service — markers, entity scopes, what is derived vs hand-written, reconcile |
| `observe` | the observation pass over runs, telemetry and logs |
| `gh-issues` | issue body structure and closing rules |

## Code rules

- Minimize comments; keep them friendly for a human developer to read.
- Keep files small — aim under 400 lines; when a file grows, split it.
