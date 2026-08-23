# <experiment-id> — <one line: what this experiment is trying to win>

## Objective

<the metric, its cell, where it stands now, and the number it must reach>

Reached when: <the condition that closes this experiment>

## Strategy

<what we know about the machine that makes the target look reachable: which
phase is bandwidth-bound and which is compute-bound, what the architecture
spends its time on, what the box can and cannot do>

Measured scatter, per cell — what a decision rule here has to clear:

    <cell>: <metric> ±<n>%, <metric> ±<n>%   (<where it was measured>)

## Held

<the invariants every round shares: box, container image, checkpoint, the cell
we are scored in, anything we refuse to change for reasons outside this
experiment>

Not "every field not under test" — a round holds its own fields constant, and
says so in its own Method. Anything named here is closed to every round.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | <one line> | <pending> |

## Conclusion

<pending — written when the objective is reached or the levers are exhausted>
