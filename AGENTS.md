# Project rules

Benchmark-tuning research on a DGX Spark box. The work is hypothesis-driven:
understand what governs throughput on this hardware and this model, and fold
what we learn into the series' `recipe.yaml`.

These are the invariants — they hold before you know which task you are doing.
Procedures live in the skills; see `## Skills`.

- Nothing is ever submitted to Spark Arena. There is no login and one is not
  wanted. Never pass `--arena`; never run `sparkrun arena` anything.

## Git

- `main` ← `staging` ← `feature/*`. Never commit directly to `main` or `staging`.
- Branch before your first commit, then verify. As commands, not as intent:
  `git checkout -b feature/<name> staging`, then `git branch --show-current`.
  A prohibition is only evaluated once you are already committing, which is too
  late; this failed exactly that way and cost a history repair.
- One agent owns the working tree at a time. Every agent shares one checkout, so
  while a round holds the box no other agent runs git operations.
- An agent commits and pushes only its own branch. Merging up is the
  orchestrator's call, and it verifies what the branch landed before merging.
- Never commit `QUEUE.md` (gitignored).

## A series

```
research/<series>/
├── recipe.yaml                        the tuned config
├── RESULTS.md                         Mat's lookup table
├── docs/  scripts/
└── experiments/<hypothesisId>/
    ├── HYPOTHESIS.md → EXPERIMENT.md  the claim, then its conclusion
    └── bench_<id>-<label>/            one archive per invocation
```

- Write only to `recipe.yaml`, `HYPOTHESIS.md` / `EXPERIMENT.md`, and
  `RESULTS.md`. Everything else in a series is read-only, archives included.
- Create no other files. Analysis belongs in `EXPERIMENT.md`.
- `recipe.yaml` changes only when a fold rule declared before the run fires.
- `RESULTS.md` is Mat's. Nothing derives from it — tooling reads the archives.
- Name a hypothesis directory for the claim, not the cell.

## The box

- Never change system state autonomously: clocks, power policy, driver, kernel,
  `apt`. Measure it, record it, leave the decision to Mat.
- The hostname comes from `.claude/box.json` (gitignored).
- An image or vLLM version change is a new epoch — re-measure the incumbent
  before comparing across it.
- Memory ops never block work. `remember.sh` / `recall.sh` always exit 0 on
  failure; never retry in a loop or ask what to do.

## Skills

Invoke the skill; do not reimplement it from memory.

- `spark-autoresearch` — the research loop: stating a hypothesis, running a
  round, archiving, reading the instrument's metrics, concluding, deciding next.
- `mem0` — the memory service: markers, entity scopes, what is derived vs
  hand-written, reconcile.
- `observe` — the observation pass over runs, telemetry and logs.
- `gh-issues` — issue body structure and closing rules.

## Code rules

- Minimize comments; keep them friendly for a human developer to read.
- Keep files small — aim under 400 lines; when a file grows, split it.
