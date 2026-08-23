---
name: spark-model
description: Set up a model for tuning — its docs, its baseline recipe, its results table. Use once, when a model enters the research tree for the first time.
---

# spark-model

## Role

Owns `research/<model>/` and the four files at its root: `docs/model-card.md`,
`docs/arena-recipe.md`, `recipe.yaml`, `RESULTS.md`.

Never touches `experiments/`. Runs nothing.

## How to use this skill

Once per model, when it first enters the research tree. Everything here is
agreed with the user before any hypothesis exists.

Nothing is committed to a branch — no experiment has been run yet.

## 1. Create the directory

```bash
scripts/new-model.sh <model>
```

`<model>` is the model's name. Nothing else goes in it.

Copies `scripts/_template/` into `research/<model>/`: `RESULTS.md` with the
name substituted, and empty `docs/` and `experiments/`. Steps 2 to 4 fill it.

## 2. Write `docs/` with the user

- `model-card.md` — a pinned link to the upstream card, and the date it was
  pinned. Nothing else! 
```md
https://huggingface.co/<id>/blob/<sha>/README.md
```

- `arena-recipe.md` — the url to the yaml file we use as `recipe.yaml`.

## 3. Write `recipe.yaml` with the user

We have `docs/arena-recipe.md` as the source.
- read the recipe, and copy it to `recipe.yaml`
- talk with the user to see if this is the baseline they want to start with.

## 4. Fill the `RESULTS.md` header

- `new-model.sh` created `RESULTS.md`, now update the `## reference` section.
