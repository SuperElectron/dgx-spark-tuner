# h<N> — <one line: the lever under test>

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

## Runs

One row per planned run. Figures blank until it is run.

| run | changed | why | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|--------|--------|---------|-------|
| run-0001 | <what it varies> | <what it is for> | | | | |

## Conclusion

<pending>
