---
name: spark-hypothesis
description: Open an experiment — its objective, strategy and held — and the rounds that chase it, then conclude each round and decide whether the target is met, the lever has more to give, or the next hypothesis is needed. Use when starting an experiment or finishing a round.
allowed-tools: Bash(.claude/skills/spark-hypothesis/scripts/new-experiment.sh:*) Bash(.claude/skills/spark-hypothesis/scripts/new-round.sh:*) Bash(.claude/skills/spark-hypothesis/scripts/show-run.sh:*) Bash(.claude/skills/memory/scripts/recall.sh:*) Bash(.claude/skills/memory/scripts/remember.sh:*) Bash(.claude/skills/memory/scripts/memory.sh start) Bash(.claude/skills/memory/scripts/memory.sh stop) Bash(git checkout:*) Bash(git status:*) Bash(jq:*) Bash(grep:*) Bash(head:*) Read Write Edit Grep Glob
disallowed-tools: Bash(.claude/skills/memory/scripts/forget.sh:*) Bash(.claude/skills/memory/scripts/prune-round.sh:*)
---

# spark-hypothesis

## What HYPOTHESIS.md is for

It is the **contract** for the round — hypothesis, method, decision rule, and
the runs table. It is not the notebook. Per-round analysis, discarded theories
and per-run reasoning go to the memory store, which is queryable and
config-stamped; the file holds only what the round is bound to.

The decision rule is frozen the moment it is written, before any figure exists.
That is what makes the round falsifiable: a rule edited after the numbers
arrive is a rule fitted to them, and the round proves nothing. If the rule turns
out to be the wrong rule, say so in the Conclusion — never edit it.

## Role

Owns the experiment and its rounds:

```
research/<model>/experiments/<experiment>/
├── EXPERIMENT.md       objective, strategy, held — frozen once agreed
├── recipe.yaml         the baseline every round starts from
├── recipe-new.yaml     written when the objective closes
└── h1/, h2/, ...       one per round
    └── HYPOTHESIS.md   hypothesis, method, decision rule, runs
```

Reads `run-*/` but never writes to it, and never writes a runs table.

Every command here assumes cwd is the **repo root**, which is why every script
is reached as `.claude/skills/...`. That is the one convention across all
skills, and it is what lets a single permission rule cover every caller.

**Memory:** you may recall in every form, semantic included — and you are the
only skill that may raise the embedder, at START, and must lower it again in the
same breath. You write `[OBSERVATION]` at `round:<experiment>/h<N>`. You never
delete and never write a runs table. Full matrix:
[../memory/references/access.md](../memory/references/access.md).

An experiment has one objective and as many rounds as it takes. A round that
fails does not end the experiment — it ends that lever.

## How to use this skill

1. START: setup an experiment and its first round for the user.
2. END: after a round's runs, conclude it and decide what follows.

## START

### Recall first

Before a word of hypothesis is written. A round that starts without a recall is
a round betting its runs on nothing. Widest scopes first — and the widest scope
is the unfiltered one. Start here, always:

```bash
.claude/skills/memory/scripts/recall.sh --list '' 2000 | head -60
```

**The wide sweep comes first because `--filter` drops any record that lacks the
key.** `--filter model=<hf-id>` does not mean "this model or anything general" —
it means "records that carry a `model` key equal to this", so a cross-model
lesson written at `stack:vllm`, or any pre-contract memory with no config
stamped on it, is invisible to it. Filtering before you have looked wide is how
a round misses the memory that would have chosen its lever. Skim the whole
sweep; `grep` it by keyword rather than by metadata:

```bash
.claude/skills/memory/scripts/recall.sh --list '' 2000 | grep -i '<the lever, by name>'
```

Only then narrow, to sort what you have already seen:

```bash
.claude/skills/memory/scripts/recall.sh --list '' 2000 --filter model=<hf-id> | head -60
.claude/skills/memory/scripts/recall.sh --list <entity> 50
```

Entities worth trying by name: `stack:vllm` for engine-wide lessons,
`flag:<lever>` if one exists for your lever — but not every lever has one, and
the absence of a `flag:` entity is not the absence of a memory.

Only if you do not know what to ask for by name, bring the embedder up and put
it back down — it is a vLLM instance on the same card as every benchmark:

```bash
.claude/skills/memory/scripts/memory.sh start
.claude/skills/memory/scripts/recall.sh "<the lever question, in words>" stack:vllm 15
.claude/skills/memory/scripts/memory.sh stop
```

Then, for **every memory you intend to act on**:

```bash
.claude/skills/memory/scripts/recall.sh --get <id>
```

**No decision rests on a summary line.** The scan format exists to triage, not
to decide. `--get` the record and read its date and its config before the lever
is chosen: a figure from another cell, epoch or protocol is a reason to look,
not evidence for yours.

Date it from the record, not from the scan line. `created_at` is the store's
own timestamp and every memory carries one; `metadata.date` is stamped only by
schema-1 writes, so it is absent on everything written before the contract and
the scan line's config suffix renders nothing for those. Read both, take
`created_at` when `metadata.date` is missing, and then ask the question that
matters: **what ran after this date?** A memory written before the experiment
that tested its claim is a hypothesis someone held, not a result. Check it
against the research tree before spending a round on it. See [../memory/references/recall.md](../memory/references/recall.md)
for the questions to put to what comes back.

### Then set up

1. `git checkout -b feature/<model>-<experiment> staging`
2. setup the new directory, run this:
```bash
.claude/skills/spark-hypothesis/scripts/new-experiment.sh research/<model>/experiments/<experiment>
```

Fill every `<...>` with the user. `EXPERIMENT.md` first — it is frozen once
agreed, and every round is judged against it.

- **Objective** — a metric, its cell, where it stands, and the number it must
  reach. Something a run can hit or miss.
- **Strategy** — what we know about the machine that makes the target look
  reachable, and the measured scatter for the cell. Rounds are sized against
  this, so a cell with no scatter figure needs one measuring first.
- **Held** — the invariants every round shares. Be sparing: anything named
  here is closed to every future round. "Every field not under test" belongs in
  a round's Method, not here. A round that runs a schedule holds its cell
  order too: order decides what is warm and what is hot, and no figure reveals
  which order produced it.

Then `h1/HYPOTHESIS.md`:

- **Hypothesis** — one falsifiable sentence and the mechanism behind it, argued
  from the machine. Its *worth* is the load-bearing part: the arithmetic saying
  how big a win this mechanism can buy. If that is smaller than the Objective
  needs, the round is wrong before it runs.
- **Variables to test** — one line per recipe field this round may move.
- **Runs** — leave the block between the `RUNS` markers empty. The table is
  script-written; `spark-autoresearch` proposes each row at CREATE with the
  figures blank, and that is what tells the loop when the round is done. Never
  hand-write a row.
- **Decision rule** — written before any number exists, never edited. Three
  outcomes: target met, lever alive, lever spent. Size it against Strategy's
  scatter, never against this round's own runs. Name the cell it reads: a
  sweep returns many, and a rule that does not say which one is not a rule.
  A cell with fewer than four values has no interquartile range, so a rule
  stated on spread cannot be evaluated there — say so before running, not
  after.

3. Create `recipe.yaml` with the user
- `recipe.yaml` is the config every round of this experiment starts from — the model's `recipe.yaml`, or an earlier experiment's `recipe-new.yaml`. The user must agree on which.

Done when a run could be dispatched without asking anything further.

## END

After a round's runs are in, analyze them and decide what follows.

### 1. Read

Read `EXPERIMENT.md` and the round's `HYPOTHESIS.md`, then run this script:

```bash
.claude/skills/spark-hypothesis/scripts/show-run.sh <run-dir>
```


### 2. Reason

Answer all six, for every run and then across the set. They are not the only
things worth saying; say whatever else you found.

1. Is each run valid, and are they comparable to each other?
- did the engine serve what the recipe declared? Compare vLLM's `non-default args:` line against the recipe's `defaults:`, field by field. This is the only check on the recipe that does not come from the recipe. A run that disagrees measured a different configuration and its figures answer a question nobody asked.
- do all the runs share a container digest and the same vllm and flashinfer commits? A change in any of them is a new epoch, and figures either side of it are not the same measurement.
- do the recipe hashes differ between runs that were meant to differ? Two runs sharing a hash ran identical configurations, so one of them tested nothing.

2. Was the hypothesis true? What did you learn from the runs?
- did the Objective move? by how much, against the number it named?
- which parameters moved it, and is there room left in them?
- did all the runs succeed? if no, why, and what would correct it?

3. Read into the data

- did you find errors? what things can we learn from the errors that we should tune, modify, or improve?
- could the decision rule resolve against the data you actually got? if not, say what grid would have.

4. What shape is the measurement, not just where is its centre?
- Read the individual values behind each reported mean. Are they clustered, or split into two groups with nothing between them? 
- The reported `pp t/s` and `tg t/s` are arithmetic means of a rate, which overweights the fast samples. Compare medians of the underlying values, not the means.
- How wide is the spread against the difference you are about to call meaningful? Smaller than the spread within one run is not a result. If the spread differs from Strategy's figure, say so — that figure sizes every later round.

5. What state was the box in while it measured?
-  Over the benchmark window only — the model load either side of it will skew anything you compute across the whole file. 
- Did swap grow during the run? How much memory was left at the worst point? 
- Was GPU utilisation sustained or intermittent, and did the clocks hold? A run measured on a box that ran out of memory measured that, and no figure in the results will tell you.

6. Based on the data, what are your observations?
- what is your conclusion, and what are the major learnings?
- was the hypothesis worth running — did it move the Objective, or only settle a question?

7. Write the findings to memory, not to prose.

This skill writes its own findings now; they are not routed through the
Conclusion. Everything from questions 1–6 that another round would want — the
shape of the spread, the box state, the dead end, the theory the data killed —
is a memory, written at `round:<experiment>/h<N>` while it is still in hand.
Tier 1 is disposable, so it can be verbose.

```bash
.claude/skills/memory/scripts/remember.sh "[OBSERVATION] <what the set measured, and what it decides>" \
  round:<experiment>/h<N> \
  --meta date=<YYYY-MM-DD> --meta model=<hf-id> --meta test=<test> \
  --meta depth=<D> --meta conc=<C> --meta bench=<bench_id>
```

The metadata contract, the four markers, the per-class guards and the exit
codes are in [../memory/references/write.md](../memory/references/write.md). A
write refused for a missing field is the contract working; fix the write.

### 3. Write

1. The `## Verdict` line in `h<N>/HYPOTHESIS.md` — one of TARGET MET, LEVER
   ALIVE, LEVER SPENT, plus the number that decided it. It is filled at
   conclusion time and nowhere else.

2. The Conclusion in the same file, against that round's decision rule as
   written. Wrong rule? Say so; do not edit the rule. Then its row in
   `EXPERIMENT.md`'s rounds table.

   **Budget: 15 stated lines.** Enough to name the verdict, the deciding
   figure, what varied over what values, and one line of why. Anything beyond
   that — per-run analysis, discarded theories, exploratory reasoning — went to
   the memory store in §2.7 and does not belong here. If the Conclusion is
   growing past the budget, the overflow is a memory you have not written yet.

3. Then one of three, from the round's decision rule:

    **Target met** — close the experiment. Conclusion in `EXPERIMENT.md`,
    `recipe-new.yaml` beside `recipe.yaml`, one row in `RESULTS.md`, one PR
    into `staging`.

    **Lever alive** — the target is not met but this mechanism has more to
    give. Add rows to the round and hand back; do not open a new round.

    **Lever spent** — `.claude/skills/spark-hypothesis/scripts/new-round.sh <experiment-dir>`, and write the
    next hypothesis. It must aim at the same Objective, respect Held, and be
    motivated by a row already measured. If no such hypothesis exists, close
    the experiment as exhausted: same artifacts, saying what it cost and what
    is now known to be closed.

`RESULTS.md` gets one row per experiment, never per round.

Done when the branch is up for review.
