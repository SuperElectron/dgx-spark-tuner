# h1 — is the deep collapse configuration or checkpoint?

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

Our checkpoint served under the peer's configuration recovers their deep-cell
range, which would mean the 20x gap is configuration and ours to close.

The mechanism is not one flag; the point of this round is that we do not yet
know which flag, and that the six candidates cannot be bisected economically
until we know the gap is bisectable at all. `sub1779001966608` runs the same
architecture, quant, runtime and container as us and stays flat across the deep
range where we fall off a cliff. Either its configuration explains that, or its
checkpoint and mods do. One run separates those.

Worth, if right: the peer holds 150.52 / 162.07 / 143.50 / 116.26 at d32768 c5,
d65535 c5, d100000 c5, d100000 c10 against our 125.87 / 20.56 / 8.51 / 5.50.
Recovering even half of that range takes four of the six cells past their
leaders. If wrong — if the arm stays in the collapsed range — the experiment
learns something worth more than a round: that no configuration reachable from
this recipe closes the gap, and the remaining explanation is the checkpoint or
its two mods (`fix-qwen3-coder-next`, `fix-qwen3.6-chat-template`), neither of
which this experiment holds open.

This is a deliberate departure from the campaign plan's ordering, which put
"drop `--max-num-seqs`" first as the cheapest single variable. Cheapest-first
is the wrong order when the expensive question is whether any of the cheap
levers can matter. `1db899b2` records the cost of the opposite mistake — a
round spent on a lever the data had already closed.

## Method

Two runs on an identical grid, so the comparison is arm against our own
control and not against a figure measured on a different schedule
(gate 3 of the campaign plan; `187c85b1` for why a foreign figure is not a
control).

### Variables to test

    run-0001  control: our recipe, unchanged
    run-0002  arm:     all six peer fields at once

              max_num_seqs             10      -> absent
              gpu_memory_utilization   0.8     -> 0.5
              max_num_batched_tokens   65536   -> 32768
              speculative num tokens   3       -> 2
              load_format  fastsafetensors     -> instanttensor
              async-scheduling         set     -> absent

Order: control first, arm second. Six fields move together on purpose — this
round asks whether the set matters, not which member does. A round that
bisects comes next and only if this one moves.

### Constant for this round

The checkpoint (`nvidia/Qwen3.6-35B-A3B-NVFP4`, unmodified), the container, the
grid and its order, `max_model_len 262144`, `kv-cache-dtype fp8`,
`attention-backend flashinfer`, `enable-prefix-caching`, and the mtp method
itself — only its token count moves.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 32768, 65535, 100000 · concurrency 5, 10 · runs 3

Six cells, ascending depth, c5 before c10 at each depth.

## Decision rule

Read per cell on the mean of `tg128`, n=3, arm against control.

- **Target met** if any cell's arm figure exceeds that cell's live board leader
  by more than 3%.
- **Lever alive** if the arm beats the control by more than 2x in any deep cell
  without reaching a leader. The configuration matters, the set is worth
  bisecting, and the next round does that.
- **Lever spent** if the arm is within 25% of the control in every cell. Six
  fields moved at once and nothing followed, so no single one of them is
  hiding a 20x — and the remaining explanation is the checkpoint or its mods,
  which Held closes to this experiment.

2x and 25% are coarse on purpose. These cells reproduce to within 2% across
four days (`bf2cf33a`), so the bands are not about noise; they are about what
size of move would justify the expense of a bisection round.

One thing this rule cannot do: attribute. If the arm moves, it says the set
matters and nothing about which member. Any sentence naming a single field as
the cause, written off this round's data, is a hypothesis for the next round
and must be labelled as one.

## Conclusion

<pending>

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here. 15
lines is enough to name the verdict, the deciding figure, and one line of
why; it is not enough to re-derive the round.
