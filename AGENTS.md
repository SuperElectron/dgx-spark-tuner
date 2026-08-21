# Project rules

## Autoresearch workflow

The full repeatable loop (experiment layout, one-round procedure, archiving,
promotion, hard rules) lives in the `spark-autoresearch` skill
(`.claude/skills/spark-autoresearch/SKILL.md`). Its helper scripts:

- `scripts/new-experiment.sh <name>` — create an experiment series from the template
- `scripts/archive-round.sh <experiment-dir> <benchId> [suffix]` — archive a benchmark run
- `scripts/parse-round.py <round-tmp.json>` — per-run tg/pp/ttfr with medians

`research/*/experiments/` run data is gitignored — numbers live in the local
exported files; journal.md and RESULTS.md carry the conclusions.

## GitHub issues

Issue body structure and closing rules live in the `gh-issues` skill
(`.claude/skills/gh-issues/SKILL.md`). Always follow it when creating or
closing issues.

## Workflow
- `main` ← `staging` ← `feature/*`. One PR per feature group. Never commit directly to staging/main.
- Review pass (code-reviewer agent) on every PR before merge.

## Code rules
- Minimize code comments and ensure they are friendly for a human developer to read.
- Try to keep files small — aim under 400 lines, ~500 is a guideline not a hard cap; when a file grows, split it into smaller parts.
