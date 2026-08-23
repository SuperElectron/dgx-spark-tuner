# <hypothesis-id> — <one line: what is under test>

Every `<...>` is a slot to fill. Claim, method and decision rule are written
before the first run and never edited after. Runs gains a row per run. The
conclusion is written last.

## Claim

<one falsifiable sentence, and why you expect it>

## Method

Each run starts from `recipe.yaml`, this hypothesis's baseline, and changes
what the next question needs — one field, several, or a sweep whose winner
later runs hold.

### Variables to test

One line per recipe field this hypothesis may move, with the values it may
take. Anything not listed is held.

    <recipe field>: <value>, <value>, <value>
    <recipe field>: <value>, <value>

Order: <which varies first, and what decides when to move to the next>

### Held

The probe grid, the container image, the box, and every recipe field not listed
above.

Grid, from the recipe's `benchmark:` block:

    pp <n> · tg <n> · depth <n> · concurrency <n> · runs <n>

## Decision rule

- The claim survives if <condition, with a number>.
- The claim fails if <condition, with a number>.

## Runs

One row per run, appended when the run returns.

- **changed** — this run's recipe against `recipe.yaml`, as `field: old → new`;
  comma-separated when a run moves more than one.
- **why** — the prior result that prompted it. `baseline` for the first run.
- **figures** — from the run's `out/results.yaml`.

| run | changed | why | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|--------|--------|---------|-------|
| run-0001 | <field: old → new> | baseline | <n> | <n> | <n> | <bench_...> |

A crashed run keeps its row: `—` for the figures, the failure in **why**.

## Conclusion

Pending — written once every run is in, against the decision rule as written.
If the rule was wrong, say so here; do not edit it.

## Memory

One line, written with `remember.sh` when the conclusion is. Recall prints the
line and nothing else, so anything not in it cannot be weighed later.

    [OBSERVATION] <date> <hypothesis>: <what varied> over <values> — <what held or did not>, <evidence>

    [OBSERVATION] 2026-08-22 test-runtime: max_num_seqs 4→64 at d0 c1 — tg flat within ±3% across all five, so single-stream decode does not use the extra slots (runs=5, bench_2ebcb63db398..bench_9f1)

Entity: the widest scope it is actually true for — `experiment:<name>`,
`model:<hf-id>`, `family:<name>`, `stack:<runtime>`, `box:<alias>`,
`flag:<vllm-flag>`.
