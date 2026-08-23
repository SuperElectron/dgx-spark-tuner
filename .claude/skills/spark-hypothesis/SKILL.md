---
name: spark-hypothesis
description: Open an experiment — its objective, strategy and held — and the rounds that chase it, then conclude each round and decide whether the target is met, the lever has more to give, or the next hypothesis is needed. Use when starting an experiment or finishing a round.
---

# spark-hypothesis

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

An experiment has one objective and as many rounds as it takes. A round that
fails does not end the experiment — it ends that lever.

## How to use this skill

1. START: setup an experiment and its first round for the user.
2. END: after a round's runs, conclude it and decide what follows.

## START

1. `git checkout -b feature/<model>-<experiment> staging`
2. setup the new directory, run this:
```bash
scripts/new-experiment.sh research/<model>/experiments/<experiment>
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
  a round's Method, not here.

Then `h1/HYPOTHESIS.md`:

- **Hypothesis** — one falsifiable sentence and the mechanism behind it, argued
  from the machine. Its *worth* is the load-bearing part: the arithmetic saying
  how big a win this mechanism can buy. If that is smaller than the Objective
  needs, the round is wrong before it runs.
- **Variables to test** — one line per recipe field this round may move.
- **Runs** — one planned row each, figures blank. That is what tells the loop
  when the round is done.
- **Decision rule** — written before any number exists, never edited. Three
  outcomes: target met, lever alive, lever spent. Size it against Strategy's
  scatter, never against this round's own runs.

3. Create `recipe.yaml` with the user
- `recipe.yaml` is the config every round of this experiment starts from — the model's `recipe.yaml`, or an earlier experiment's `recipe-new.yaml`. The user must agree on which.

Done when a run could be dispatched without asking anything further.

## END

After a round's runs are in, analyze them and decide what follows.

### 1. Read

Read `EXPERIMENT.md` and the round's `HYPOTHESIS.md`, then run this script:

```bash
scripts/show-run.sh <run-dir>
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

### 3. Write

1. The Conclusion in `h<N>/HYPOTHESIS.md`, against that round's decision rule
   as written. Wrong rule? Say so; do not edit the rule. Then its row in
   `EXPERIMENT.md`'s rounds table.
   Write it so it stands on its own: what varied, over what values, what held
   or did not, and the evidence.

2. Then one of three, from the round's decision rule:

    **Target met** — close the experiment. Conclusion in `EXPERIMENT.md`,
    `recipe-new.yaml` beside `recipe.yaml`, one row in `RESULTS.md`, one PR
    into `staging`.

    **Lever alive** — the target is not met but this mechanism has more to
    give. Add rows to the round and hand back; do not open a new round.

    **Lever spent** — `scripts/new-round.sh <experiment-dir>`, and write the
    next hypothesis. It must aim at the same Objective, respect Held, and be
    motivated by a row already measured. If no such hypothesis exists, close
    the experiment as exhausted: same artifacts, saying what it cost and what
    is now known to be closed.

`RESULTS.md` gets one row per experiment, never per round.

Done when the branch is up for review.
