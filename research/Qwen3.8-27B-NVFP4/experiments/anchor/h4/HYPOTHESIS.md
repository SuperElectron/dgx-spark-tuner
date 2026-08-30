# h4 — the twin's three config deltas, on our epoch

## Verdict

<one line, filled at conclusion: TARGET MET / LEVER ALIVE / LEVER SPENT — the
number that decided it>

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | max_model_len: 262144 -> 131072 | board twin sub1786821875313 scores 63.05 at this cell on our exact checkpoint and differs in only three fields; this is the first, isolated against h3 run-0001's 36.96 | d16384 c10 | 131.44 | 39.50 | 152682.6 | bench_aa90097c9a3d |
| run-0002 | env VLLM_MARLIN_USE_ATOMIC_ADD: absent -> 1 | arm 1 took the cell 36.96 -> 39.50 by adopting the twin's max_model_len; this adds the twin's second delta on top of the higher-reading arm, as the round's Method requires | d16384 c10 |  |  |  |  |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Adopting the three config fields where board entry `sub1786821875313` differs
from our recipe lifts `tg128 @ d16384 c10` above 38.1 t/s, because that entry
measures **63.05** on our exact checkpoint and runtime and those three fields
are the whole of the difference between its recipe and ours.

Argued from a measured row, not from theory. `sub1786821875313` runs our
checkpoint on vLLM at clusterSize 1, MTP k=3, `kv-cache-dtype fp8`,
`attention-backend flashinfer`, `load-format instanttensor`,
`gpu-memory-utilization 0.8`, no `max_num_seqs` — identical to ours except:

    max_model_len              131072   against our 262144
    VLLM_MARLIN_USE_ATOMIC_ADD 1        against our env: {}
    max_num_batched_tokens     32768    against our 65536

The third is *lower* than the budget h2 spent three arms raising. A twin at
1.7x ours on half our budget says the budget is not the governing quantity —
the same thing h3 found from the autotune side.

**Reopening `max_model_len`.** h2 retired a *mechanism* — computed max
concurrency below the offered 10 does not govern this cell — not the field. A
twin running 131072 and measuring 63.05 reopens it on different grounds; this
is not a re-run of a closed lever.

**The image.** The twin runs `dgx-vllm-eugr-nightly:2026081501`; ours is
`:latest` = `2026082102`. Different build, and `Held` pins our epoch, so we
cannot match their image without breaking the experiment. h4 tests their
*config* on our build, and **63.05 may be unreachable here for that reason
alone**. A null across all three arms is evidence about our epoch, not their
recipe.

Worth, if right: 63.05 against our 36.96 is 1.71x; 72.5 is 1.96x. One field
carrying half the gap puts the Objective in range of a further arm; all three
carrying nothing localises the 1.7x to the build.

## Method

### Variables to test

    max_model_len:              262144 -> 131072
    env VLLM_MARLIN_USE_ATOMIC_ADD:  unset -> 1
    max_num_batched_tokens:     65536 -> 32768

Order: strictly sequential, one field per arm, never two at once. Arm 1 moves
`max_model_len` alone against h3 run-0001's 36.96. Arm 2 adds the env var to
whichever of {h3 run-0001, arm 1} read higher. Arm 3 moves the budget on the
best config standing after arm 2. Stop early if any arm exceeds 72.5.

### Constant for this round

Everything else in `recipe.yaml`, including `language_model_only: true` as h3
left it — free at 65536, and it keeps arms comparable to h3 run-0001.
`max_num_seqs` stays unset, as both leading board entries leave it. No arm
raises `max_num_batched_tokens` above 65536: h3 showed the autotune ceiling is
a step function in allocation size that no memory lever moves.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 16384 · concurrency 1, 10 · runs 5

c1 rides along as a control. Recorded, not scored: KV and computed max
concurrency per arm, autotune duration, engine start time, ttfr, short returns
per cell, MTP acceptance.

## Decision rule

Read on the **median** at `tg128 @ d16384 c10`, best arm.

- **Target met** — ≥ 72.5 t/s at any arm.
- **Lever alive** — 38.1 to 72.5 t/s at any arm. A twin delta is buying, and
  h4 gets more arms.
- **Lever spent** — under 38.1 t/s at every arm that produces figures. This
  explicitly includes the case where **every arm crashes and no figure exists**:
  if none of the three fields yields a measurable cell, the twin's config is
  not transferable to our build and this lever is closed.

Sizing: 38.1 is h3 run-0001's 36.96 plus 3%, three times the **1.0% cv measured
at n=5** in that run. h2's 13.7% is superseded — it was a three-value artefact
from one bad draw. Every branch resolves on figures this grid can produce.

## Conclusion

<pending>

Budget: 15 lines — the verdict, the deciding figure, what varied, one line of
why. Everything else goes to the memory store.
