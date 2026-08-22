# Project rules

Benchmark-tuning research on a DGX Spark box. The work is hypothesis-driven:
understand what governs model performance on this hardware.

These are the invariants — they hold before you know which task you are doing.
Procedures live in the skills; see `## Skills`.

- Nothing is ever submitted to Spark Arena. There is no login and one is not
  wanted. Never pass `--arena`; never run `sparkrun arena` anything.

## Research Experiment setup

To do a research experiement, an agent is used to run that isolated experiment
- an agent must use context from .claude/skills/experiment
- the agent is responsible to add/push code, and create a PR.
- you are required to merge it back into staging.

## Folder Layout for research experiements.

All research experiments populate a folder structure as follows:

```
research/<series>/
├── recipe.yaml                     the tuned config
├── RESULTS.md                      Mat's lookup table
├── docs/                           model-card.md, arena-recipe.md
└── experiments/<hypothesisId>/
    ├── EXPERIMENT.md               the claim, then its conclusion
    └── bench_<id>-<label>/         one archive per invocation
```

- Do not modify these files unless a one of your skills permits it. These are read only unless a specific skill operates on them.

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
- `experiment` — how an agent runs one experiment: what it is handed, what it
  measures and archives, and the git and PR rules it follows.
- `experiment-postrun` — after that PR is open and before it merges: check the
  archive is complete, derive the `[EXPERIMENT]` memory from it, confirm the
  index converged.

## Code rules

- Minimize comments; keep them friendly for a human developer to read.
- Keep files small — aim under 400 lines; when a file grows, split it.
