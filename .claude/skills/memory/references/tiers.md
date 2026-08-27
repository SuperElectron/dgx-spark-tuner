# The three tiers

Memory has three tiers with different lifetimes, different writers, and
different standards of evidence. Keeping them apart is what stops the store
growing without bound and what stops a round's working notes being mistaken for
a finding.

| tier | entities | written by | when | lifetime |
|---|---|---|---|---|
| 1 transient | `round:<exp>/<hN>` | the round agent | every RECORD | until round close |
| 2 durable | `model: family: stack: box: flag:` | the round agent, by promotion | round close only | indefinite |
| 3 canonical | — | `record-run.sh` | RECORD | the repo |

## Tier 1 — transient

Entity `round:<exp>/<hN>`, e.g. `round:decode-tg/h1`.

Written at **every RECORD**, not once at close. One or a few lines per run:
what the run measured, what it decided next, and why. Config-stamped like any
other write, which for a `[OBSERVATION]` means `model test depth conc bench
date` are mandatory.

This replaces the notebook prose. The old arrangement had no memory write until
an experiment closed, so prose became the required intermediate — the round had
nowhere else to put its reasoning, and Conclusions grew to 178 and 198 lines
inside a 47-line template. Tier 1 gives the reasoning a home that is
queryable, config-stamped, and disposable.

Because it is disposable, tier 1 can be verbose. Write the dead end as well as
the result — "changed X, no effect at this cell, so the next run goes at Y" is
exactly what the following run needs and exactly what nobody should have to
re-derive.

## Tier 2 — durable

Entities `model:` `family:` `stack:` `box:` `flag:`.

Written **only by promotion**, at round close. There is no direct write to a
tier-2 entity during a round: a claim earns a durable entity by surviving the
round that produced it.

Promotion means: read back the round's tier-1 entries, decide which hold wider
than this round, rewrite those at the widest scope they are actually true for,
then delete the rest.

## Tier 3 — canonical

The runs table in `HYPOTHESIS.md`, between `<!-- RUNS:BEGIN -->` and
`<!-- RUNS:END -->`.

```bash
.claude/skills/memory/scripts/record-run.sh <HYPOTHESIS.md> --run run-0003 \
  --changed "max_num_seqs: 4 → 64" --why "h1 c1 flat, retest at c10" \
  --cell "d16384 c10" --pp 412.7 --tg 129.32 --ttfr 118 --bench bench_2ebcb63db398
```

The script owns the block: it re-emits the header and rule, preserves the
existing rows in order, replaces the row whose run column matches, and appends
otherwise — so recording the same run twice never duplicates it. Everything
outside the markers is byte-identical. A file with no markers exits 2.

**Never hand-edit a row.** The table is the experiment's record of fact; a hand
edit is an unreviewable change to it.

## Promotion is what bounds the bloat

Volume **rises** during a round — a write per RECORD, plus the reasoning — and
**falls** at its close. That is the whole mechanism. Without the fall, tier 1
accumulates every round's working notes forever and recall degrades into
scrolling.

At round close, for each tier-1 entry, ask:

- Is it true outside this round's cell, model or epoch? If not, delete it. The
  runs table already holds the figure.
- Does it name a mechanism rather than a number? Mechanisms promote; single
  figures usually do not, because tier 3 already has them.
- Is it already implied by something being promoted? Promote the wider one.

Promote by writing a **new** memory at the wider entity — do not try to move
one. A promoted `[LESSON]` carries `basis=` naming the rounds and cells it
rests on, so a later reader can check it instead of taking it.

Then prune:

```bash
# the promotion landed?
.claude/skills/memory/scripts/recall.sh --list flag:<lever> 50

.claude/skills/memory/scripts/prune-round.sh round:decode-tg/h1 --promoted-to flag:<lever>
.claude/skills/memory/scripts/prune-round.sh round:decode-tg/h1 --promoted-to flag:<lever> --confirm-destructive
```

The first `prune-round.sh` call is the review: it prints every memory it would
delete and stops. It also refuses outright unless a memory at `flag:<lever>`
already carries this round in its `basis=`, so the promotion cannot be skipped.

Do **not** prune with `recall.sh --list <round> | cut -f1 | forget.sh --yes -`.
That pipeline reads as safe — `forget.sh` refuses without `--yes` and prints
what it would delete — but it passes `--yes` itself, so the guard never fires
and the ids never reach the agent. The review step was on paper only. That is
the whole reason `prune-round.sh` exists.

Deletion is permanent and the server keeps no undo.

A round that closes without pruning has not closed.
