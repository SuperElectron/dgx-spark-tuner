# Project rules

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
