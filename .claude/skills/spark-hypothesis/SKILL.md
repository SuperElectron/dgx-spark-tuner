---
name: spark-hypothesis
description: Open a hypothesis — its claim, its decision rule, its baseline recipe — and close it once every run is in, with the conclusion, the memory and the winning config. Use when starting a hypothesis or finishing one.
---

# spark-hypothesis

## Role

Owns `EXPERIMENT.md` and `recipe.yaml` in
`research/<model>/experiments/<hypothesis>/`.

Reads `run-*/` but never writes to it, and never writes the runs table.
You help setup hypothesis, and then conclude on runs.

## How to use this skill

1. START: You are here to setup a hypothesis for the user.
2. END: Then after the runs, you are here to analyze the runs, update EXPERIMENTS.md with conclusion and then write a memory to capture your observations.

## START

1. `git checkout -b feature/<model>-<hypothesis> staging`
2. setup the new directory, run this:
```bash
scripts/new-hypothesis.sh research/<model>/experiments/<hypothesis>
```
- Fill every `<...>` in `EXPERIMENT.md` with the user.
- The decision rule is written before any number exists, and never edited again.
- Match the rule to `runs`. A bare ±% threshold needs `runs` of 5 or more to be
  evaluable at all; at `runs: 3` state the rule as a difference larger than the
  spread within a single run instead.

3. Create `recipe.yaml` with the user
- `recipe.yaml` is the config every run of this hypothesis starts from. It is this hypothesis's baseline — the model's `recipe.yaml`, or an earlier hypothesis's `recipe-new.yaml`. The user must agree on which.

Done when a run could be dispatched without asking anything further.

## END

After the run-* (e.g. run-0001, run-0002, ..., run-000N), you are used to analyze the runs.

### 1. Read

Read `EXPERIMENT.md`, then run this script:

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

2. Was your original hypothesis true? What did you learn from the runs?
- consider our objective from the hytpothesis.
- over the runs, where did you see improvements?
- what parameters resulted in improvements?
- are there constraints outside the hypothesis that we could have changed to get better results?
- did all the runs succeeed? if no, reason on why and what could be modified (if possible) to correct this.

3. Read into the data

- did you find errors? what things can we learn from the errors that we should tune, modify, or improve?
- when creating the hypothesis, did you get sufficient data to prove out your hypothesis? 
- what learnings can you deduce from the numbers you have?
- is there something that can be changed with the box, the hardware on which the experiments were run, that would improve the data?

4. What shape is the measurement, not just where is its centre?
- Read the individual values behind each reported mean. Are they clustered, or split into two groups with nothing between them? 
- The reported `pp t/s` and `tg t/s` are arithmetic means of a rate, which overweights the fast samples. Compare medians of the underlying values, not the means.
- How wide is the spread compared to the difference between runs you are about to call meaningful? A difference smaller than the spread within a single run is not a result. If it recurs across runs it is the next hypothesis, not this one's finding.

5. What state was the box in while it measured?
-  Over the benchmark window only — the model load either side of it will skew anything you compute across the whole file. 
- Did swap grow during the run? How much memory was left at the worst point? 
- Was GPU utilisation sustained or intermittent, and did the clocks hold? A run measured on a box that ran out of memory measured that, and no figure in the results will tell you.

6. Based on the data, what are your observations?
- after crunching data, looking at errors, and reasoning, what is your conclusion?
- was the hytpothesis useful, and did its runs help prove or disprove?
- what are the major learnings from this hypothesis test?

### 3. Write

1. The Conclusion in `EXPERIMENT.md`, against the decision rule as written.
   Wrong rule? Say so in the conclusion; do not edit the rule.
2. `scripts/remember.sh "<text>" <entity>` — one memory per hypothesis. Format
   and entity scopes are in `EXPERIMENT.md`.
3. Create a `recipe-new.yaml` beside `recipe.yaml` that would give the best scores based on our hytpothesis and conclusion.
4. One row in `RESULTS.md`: what varied, what won, the benchIds.
5. One PR into `staging`.

Done when the branch is up for review.
