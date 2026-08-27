# h<N> — <one line: the lever under test>

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

<one line, filled at conclusion: TARGET MET / LEVER ALIVE / LEVER SPENT — the
number that decided it>

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

<one falsifiable sentence, and the mechanism that argues for it>

Worth, if right: <the size of the win this mechanism can buy, and the
arithmetic behind it — this is what says the Objective is reachable>

## Method

### Variables to test

    <recipe field>: <value>, <value>, <value>

Order: <which varies first, and what decides when to move to the next>

### Constant for this round

<the recipe fields this round holds still, beyond what Held already closes>

Grid, from the recipe's `benchmark:` block:

    pp <n> · tg <n> · depth <n> · concurrency <n> · runs <n>

## Decision rule

- **Target met** if <the Objective's number is reached, stated against the
  measured figures>.
- **Lever alive** if <not met, but the values still trend toward the target>.
- **Lever spent** if <the condition that says this mechanism has no more to
  give>.

Sized against the scatter in Strategy — an effect smaller than the cell's
spread cannot be read, whatever the medians say.

## Conclusion

<pending>

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here. 15
lines is enough to name the verdict, the deciding figure, and one line of
why; it is not enough to re-derive the round.
