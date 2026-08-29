# h1 — is the slots mechanism spent at max_num_seqs 64?

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

Raising `max_model_len` from 8192 does not move `tg128 (c10)` on this model,
because at `max_num_seqs: 64` against an offered concurrency of 10 nothing is
being withheld — there is no queue for extra capacity to drain.

The campaign plan names `max_model_len` as this track's arm. It is the field
that most plausibly interacts with capacity here: at 8192 the window is small
enough that KV per sequence is cheap, and raising it is the closest thing this
recipe has to spending the memory that `max_num_seqs: 64` has already claimed.
If capacity were binding at all, this is where it would show.

Worth, if right: nothing, in board terms — the cell is held by our own
LFM2.5-350M at 2044.66 and this model's ceiling is a third of that. The value
is diagnostic. A null keeps the admission account of `slots/h1` on LFM2.5-350M
intact. A move refutes it, and every conclusion drawn from that round has to be
re-read.

## Method

### Variables to test

    max_model_len: 8192 -> 32768

Order: single arm against `h1/run-0001`, our own control on this model,
measured on the same grid in the same epoch.

### Constant for this round

`max_num_seqs 64`, `max_num_batched_tokens 4096`, `gpu_memory_utilization 0.5`,
`tensor_parallel 1`, `dtype bfloat16`, `enable-prefix-caching`,
`enable-chunked-prefill`, `served_model_name`.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0, 4096 · concurrency 10 · runs 3

## Decision rule

Read per cell on the mean of `tg128 (c10)`, n=3, arm against control.

- **Lever spent** if both cells land within ±3% of the control, in either
  direction. The slots mechanism is exhausted at 64 and Track 1's admission
  account survives.
- **Lever alive** if either cell moves by more than 3% in either direction.
  Stated for both signs deliberately: a drop is as informative as a gain here,
  and `deep/h1` failed by writing a rule that only anticipated improvement.
- **Target met** does not apply. No configuration of this model takes the cell,
  and a rule that pretends otherwise would be theatre.

±3% is set against this model's measured spread of cv 0.1-0.3% at runs=3 — wide
enough that the band is about significance, not noise.

## Conclusion

<pending>

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here.
