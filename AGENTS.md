# Project rules

Benchmark-tuning research on a DGX Spark box. The work is hypothesis-driven:
understand what governs model performance on this hardware.

These are the invariants — they hold before you know which task you are doing.
Procedures live in the skills; see `## Skills`.

- Nothing is ever submitted to Spark Arena. There is no login and one is not
  wanted. 

## Research

- Benchmarks are run by an agent using the `experiment` skill, never inline.
- Everything under `research/` is read-only unless a skill you are running
  operates on it. Each skill defines the layout it owns.
- One PR into `staging` per experiment, opened when the experiment closes. Mat
  merges it.

## The box

- Never change system state autonomously: clocks, power policy, driver, kernel,
  `apt`. Measure it, record it, leave the decision to Mat.
- The hostname comes from `.claude/box.json` (gitignored).
- An image or vLLM version change is a new epoch — re-measure the incumbent
  before comparing across it.

## Skills

Invoke the skill; do not reimplement it from memory.

- `spark-model` — brings a model into the research tree: its docs, its baseline
  recipe, its results table.
- `spark-hypothesis` — opens an experiment (objective, strategy, held) and the
  rounds that chase it; concludes each round and decides what follows.
- `spark-autoresearch` — the loop inside one round: create a run, dispatch it,
  record it, then conclude and act.
- `experiment` — runs one run directory and reports the figures. Sees no
  hypothesis.

## Code rules

- Minimize comments; keep them friendly for a human developer to read.
- Keep files small — aim under 400 lines; when a file grows, split it.
