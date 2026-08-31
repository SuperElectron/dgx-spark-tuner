---
name: spark-model
description: Set up a model for tuning — its docs, its baseline recipe, its results table. Use once, when a model enters the research tree for the first time.
allowed-tools: Bash(.claude/skills/spark-model/scripts/new-model.sh:*) Read Write Edit Grep Glob WebFetch mcp__claude-in-chrome__tabs_context_mcp mcp__claude-in-chrome__tabs_create_mcp mcp__claude-in-chrome__tabs_close_mcp mcp__claude-in-chrome__navigate mcp__claude-in-chrome__get_page_text mcp__claude-in-chrome__computer mcp__claude-in-chrome__find
disallowed-tools: Bash(.claude/skills/memory/scripts/memory.sh:*) Bash(.claude/skills/memory/scripts/remember.sh:*) Bash(.claude/skills/memory/scripts/forget.sh:*) Bash(.claude/skills/memory/scripts/prune-round.sh:*) Bash(.claude/skills/memory/scripts/record-run.sh:*) Bash(.claude/skills/memory/scripts/update.sh:*)
---

# spark-model

## Role

Owns `research/<model>/` and the four files at its root:

```
research/<model>/
├── recipe.yaml         the baseline experiments start from
├── RESULTS.md          Mat's lookup table — one row per closed experiment
├── docs/               model-card.md, arena-recipe.md, runtime.md
└── experiments/        owned by `spark-hypothesis`; you never touch it
```

Runs nothing.

**Memory:** nothing. No step here recalls, writes, deletes or starts anything —
no experiment exists yet to remember. Matrix:
[../memory/references/access.md](../memory/references/access.md).

## How to use this skill

Once per model, when it first enters the research tree. Everything here is
agreed with the user before any hypothesis exists.

Nothing is committed to a branch — no experiment has been run yet.

## 1. Create the directory

```bash
.claude/skills/spark-model/scripts/new-model.sh <model>
```

`<model>` is the model's name. Nothing else goes in it.

Copies `.claude/skills/spark-model/scripts/_template/` into `research/<model>/`:
`RESULTS.md` with the name substituted, and empty `docs/` and `experiments/`.
Steps 2 to 4 fill it.

## 2. Write `docs/` with the user

- `model-card.md` — a pinned link to the upstream card, and the date it was
  pinned. Nothing else! 
```md
https://huggingface.co/<id>/blob/<sha>/README.md
```

- `arena-recipe.md` — the board entry `recipe.yaml` is measured against: its
  page, and its raw results. The raw log is public; read it before trusting a
  headline number, and record the cells that matter.
```md
https://spark-arena.com/benchmark/<uuid>
https://spark-arena.com/api/benchmarks/<uuid>/raw
```

- `runtime.md` — what vLLM's own maintainers recommend for this model, at
  `https://recipes.vllm.ai/<org>/<model>`, and every place our recipe diverges.
  **Read it in the browser: the page is a configurator whose toggles rewrite the
  serve command, and a text fetch shows one default and hides the rest.** Which
  hardware is the right analogue, which checkpoint variant, what each feature
  toggle emits, and any version pin:
  [references/vllm-recipe.md](references/vllm-recipe.md).

## 3. Write `recipe.yaml` with the user

Two sources, and they disagree — `docs/arena-recipe.md` is what competitors
happened to run, `docs/runtime.md` is what the maintainers recommend.
- read both, and reconcile them into `recipe.yaml`
- **name every field where they differ, and say which one we followed.** A
  divergence nobody noticed is how a baseline ends up optimised for somebody
  else's constraint.
- talk with the user to see if this is the baseline they want to start with.

## 4. Fill the `RESULTS.md` header

- `new-model.sh` created `RESULTS.md`, now update the `## reference` section.
