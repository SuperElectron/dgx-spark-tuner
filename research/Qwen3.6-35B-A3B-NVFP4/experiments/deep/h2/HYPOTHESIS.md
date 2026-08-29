# h2 — does the 262144-token window cost us the deep cells?

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

Halving `max_model_len` from 262144 to 131072 lifts the deep cells, because the
window we declare — not the depth we actually serve — is what sizes the
per-sequence structures the engine carries through every decode step.

`7bd4c673` named this in July and nobody tested it: our d100000 c10 reads 5.49
against a same-family, same-quant, single-node board entry at 116.26, and the
suspect it named was `max_model_len 262144` at `gpu_memory_utilization 0.8` with
`max_num_seqs 10`. h1 has since removed the other two members of that triple
from suspicion in the only way that matters — moving them, along with three more
fields, made every cell worse. The window is what is left.

131072 is chosen to still exceed the deepest cell with room: d100000 plus a 2048
prompt is 102,048 tokens, well inside it. So the arm cannot fail by rejecting a
request the control accepted, which is the failure mode that made twelve LFM
cells publish empty on 2026-08-29.

Worth, if right: nothing in the store bounds the size of this effect, which is
itself the argument for spending a round on it — every other lever in this
experiment now has a measured bound and none of them reach a 21x. If the window
is inert here, the experiment has exhausted what it can reach without opening
the checkpoint, and should close saying so.

## Method

### Variables to test

    max_model_len: 262144 -> 131072

Order: single arm. The control is `deep/h1/run-0001` — same recipe, same grid,
same cell order, same epoch, measured hours earlier. It is not re-run: the h1
control already reproduced the 2026-08-24 figures to within 1.5% in all six
cells, so a third measurement of the same configuration buys nothing this round
needs.

### Constant for this round

Every other `defaults:` field, including the two that `7bd4c673` named alongside
the window: `gpu_memory_utilization 0.8` and `max_num_seqs 10`. Also
`max_num_batched_tokens 65536`, the mtp config at 3 tokens, `async-scheduling`,
`enable-prefix-caching`, `kv-cache-dtype fp8`, `attention-backend flashinfer`,
`moe-backend marlin`, `load-format fastsafetensors`. Verified by diff: the arm
differs from the h1 control in exactly one line.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 32768, 65535, 100000 · concurrency 5, 10 · runs 3

## Decision rule

Read per cell on the mean of `tg128`, n=3, arm against the h1 control.

- **Target met** if any cell's arm figure exceeds that cell's live board leader
  by more than 3%.
- **Lever alive** if the arm beats the control by more than 1.5x in any deep
  cell without reaching a leader — the window matters and a further reduction
  is worth a round.
- **Lever spent** if every cell lands within ±10% of the control, in either
  direction. The window is inert at this scale and the experiment has run out
  of reachable levers.

Stated for both signs, unlike h1's rule: if the arm comes in **below** the
control by more than 10% in any cell, that is also a result — the window is
load-bearing in the opposite direction, and the round that follows raises it
rather than lowering it. h1's rule failed precisely by assuming a large move
could only be an improvement.

±10% is wide against these cells' measured spread — they read cv 0.0-2.6% at
runs=3 — and is set that way because the question is whether the window matters
at all, not to resolve a small effect.

## Conclusion

<pending>

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here. 15
lines is enough to name the verdict, the deciding figure, and one line of
why; it is not enough to re-derive the round.
