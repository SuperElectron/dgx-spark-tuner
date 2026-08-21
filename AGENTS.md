# Project rules

## Autoresearch workflow (repeatable — follow exactly)

The stack is the spark-arena community's, not ours: `sparkrun` (laptop CLI,
via `uvx sparkrun`), their recipe YAML format, `llama-benchy` measurement.
We add only the research loop around it. The box hostname comes from
`.claude/box.json` (gitignored); SSH config carries the user + key.

### Experiment layout

One directory per experiment series: `research/<model>-<cell>/` (copy
`research/_template/`):

```
research/<name>/
├── recipe.yaml                  # the incumbent config — the ONLY tuned artifact
├── journal.md                   # hypothesis before each run, keep/revert after,
│                                #   synthesis every ~5 rounds (decisions only, never numbers-copying)
├── RESULTS.md                   # one table row per run (human comparison view)
├── docs/                        # model-card.md, arena-recipe.md (source URL + scrape date)
└── experiements/<benchId>/      # one dir per sparkrun benchmark run:
                                 #   its exported YAML/JSON/CSV + the full sparkrun
                                 #   state dir contents (state.yaml, consolidated.json, runs/)
```

### One round

1. Read journal.md + prior `experiements/*/`. Pick ONE mutation. Journal the
   hypothesis BEFORE running.
2. Run (mutation = `-o key=value`; bigger change = edit a candidate recipe copy):
   ```
   uvx sparkrun benchmark perf ./recipe.yaml --solo -H <box-host> \
     -b pp=2048 -b tg=128 -b concurrency=1 -b runs=3 \
     [-o key=value] --fresh --output round-tmp.yaml
   ```
   Bare hostname only in `-H` (no user@). Fixed `-b` probe args per series —
   never vary them mid-series.
3. sparkrun prints `Benchmark ID: bench_<id>`. Archive the run:
   ```
   mkdir -p experiements/bench_<id>
   mv round-tmp.* experiements/bench_<id>/
   cp -r ~/.cache/sparkrun/benchmarks/bench_<id>/* experiements/bench_<id>/
   ```
4. Read tg mean ± std from the export YAML. Better than incumbent beyond
   noise → fold the `-o` into recipe.yaml (keep). Otherwise recipe.yaml
   untouched (revert). Crash/fail → journal the lesson; the run dir stays.
5. Append one row to RESULTS.md:
   `| bench_<id> | <date> | <mutation> | <tg mean> | <tg σ> | <pp mean> | <pp σ> | <ttfr mean> | keep/revert/crash — note |`
6. Journal the outcome. Commit per the workflow rules below.

### Promotion

Stall or satisfied → full official grid + submission:
```
uvx sparkrun benchmark perf ./recipe.yaml --solo -H <box-host> --arena
```
(`--arena` needs `sparkrun arena login` once.)

### Hard rules

- Never edit past `experiements/` contents; never hand-maintain results
  tables — numbers live in the exported files only.
- Transient benchmark failures (e.g. corpus download 504): re-run with
  `--resume`, same benchId continues.
- Image/vLLM version comes from the recipe's container and is recorded in
  every export (`runtime_info`); a version change = new epoch — re-run the
  incumbent before comparing across it.

## GitHub issues
Every issue created in this repo MUST use this body structure, in this order:

```markdown
## Feature
<one short paragraph: what this delivers>

## Requirements
<bullet list: constraints, dependencies on other feature groups, integrations touched>

## Objectives
<bullet list: measurable outcomes — what is true when this closes>

## Tasklist
- [ ] task 1
- [ ] task 2
```

One issue per feature group. Close via its PR merge into staging (manual close with comment — auto-close only fires on default-branch merges).
Before closing an issue, edit its body so every completed Tasklist item is checked (`- [x]`);
Never close an issue with unchecked boxes for work that was done.

## Workflow
- `main` ← `staging` ← `feature/*`. One PR per feature group. Never commit directly to staging/main.
- Review pass (code-reviewer agent) on every PR before merge.

## Code rules
- Minimize code comments and ensure they are friendly for a human developer to read. 
- Try to keep files small — aim under 400 lines, ~500 is a guideline not a hard cap; when a file grows, split it into smaller parts.
