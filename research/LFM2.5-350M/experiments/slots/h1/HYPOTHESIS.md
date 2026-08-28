# h1 — max_num_seqs, the admission cap, at the concurrency we are scored at

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
| run-0001 | max_num_seqs: 4 -> 4 (control, baseline unchanged) | CRASH before engine launch: image distribution failed, 'pull access denied for vllm-node' — recipe_version '2' with no builder key leaves the vllm-node alias unresolved | d0 c10 | — | — | — | bench_d71964e4722e |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Raising `max_num_seqs` from 4 to the offered concurrency of 10 raises
`tg128 (c10)` on this model, because the scored quantity is a batch aggregate
over a window that the unadmitted requests stretch without contributing tokens.

The mechanism is the scheduler's admission path, not the model. `tg_throughput`
is `sum(decode tokens) / (max_last_token - min_first_token)` — llama-benchy
`results.py:352`. The harness offers ten concurrent requests; vLLM admits
`min(max_num_seqs, offered)`. At `mns 4` six requests wait. Their tokens land
late, extending `max_last_token`, while the numerator gains nothing during the
wait. Admitting all ten shortens the window and raises the aggregate.

Worth, if right: the published field's own aggregate-to-per-request ratio is
2.8-3.3 at every depth, so about three requests are in flight where ten are
offered. If throughput scaled with slots served, the ceiling is ~10/3 = 3.3x.
It will not scale that cleanly — decode is bandwidth-bound and the queued
requests are not free — but the Objective needs only to clear 1042.20, and our
control is a copy of the configuration that produced 1042.20. Any real gain
wins the cell. A gain below the ~3% tie band means the mechanism does not
operate on this model, which is itself worth the round.

Transfer, stated honestly: the same lever measured 2.89x on
`nvidia/Qwen3.6-35B-A3B-NVFP4` at `tg128 d16384 c10`, same box, same image
digest (`00b3d74d`). That is a 35B MoE at NVFP4 and this is a 350M dense model
at BF16. It is cited as evidence the mechanism exists and is reachable from a
recipe, never as a prediction of the magnitude here. No small model, no BF16
model, and nothing at c10 has ever been measured on this box.

## Method

### Variables to test

    max_num_seqs: 4, 10, 16

Order: 4 first as the control — it is the published target's exact value, so
the control doubles as the reproduction check. Then 10, the offered
concurrency. Then 16, only if 10 moves the figure.

16 is included for a reason specific to this model, not to confirm someone
else's ceiling: decode batches pad to vLLM's CUDA-graph bucket (`b897bb19`),
and a 16-layer / 8-KV-head / head-dim-64 model sits in a different shape
regime from anything we have measured. Values above 16 are excluded
structurally, not empirically — the harness offers ten requests, so no
configuration can admit an eleventh, on any model.

### Constant for this round

Everything else in `recipe.yaml`, unchanged from the published target entry:
`max_num_batched_tokens 8192`, `gpu_memory_utilization 0.8`,
`max_model_len 32768`, `--quantization fp8`, `--kv-cache-dtype fp8`,
`--attention-backend FLASHINFER`, `--enable-prefix-caching`,
`--enable-chunked-prefill`, `--load-format fastsafetensors`,
`--language-model-only`, `--dtype auto`, `VLLM_MARLIN_USE_ATOMIC_ADD=1`.

`max_num_batched_tokens` stays at 8192 deliberately. It is a companion to
`mns`, never an arm — with `mns` pinned, moving it alone moved tg the wrong way
monotonically (`780cfd5b`). Holding it keeps this round single-variable.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0, 4096, 8192, 16384 · concurrency 10 · runs 3

Two properties of this grid to read the results against, both established
before the round:

- **d0 is a different instrument.** llama-benchy skips the context-load phase
  entirely at depth 0, so d0 is single-phase where every deeper rung is
  two-phase (`af45ab25`). No depth curve is drawn through it.
- **`mnbt 8192` gates the deep two cells.** A step admits `floor(mnbt/depth)`
  whole prefills and must exceed `depth + pp` (`97250b99`, `f7eddab5`). At
  d8192 and d16384, `8192 < depth + 2048`, so admission is prefill-gated there
  regardless of `mns`. This is expected and is a finding, not a fault: the
  Objective lives at d0, where there is no prefill gate and `mns` is clean.

## Decision rule

Read on `tg128 @ d0 (c10)`, the Objective's cell. Sized against the ~3% tie
band in Strategy, not against this round's own runs.

- **Target met** if the best arm's mean at `tg128 @ d0 (c10)` exceeds
  **1042.20 t/s**.
- **Lever alive** if the best arm beats the `mns 4` control at that cell by
  more than 3% but does not reach 1042.20.
- **Lever spent** if no arm beats the control at that cell by more than 3%; or
  if `mns 16` fails to beat `mns 10` there by more than 3% while the target is
  unmet — the queue is then fully admitted and this mechanism has no more to
  give.

Validity precondition, not part of the rule: if the `mns 4` control lands
outside 700-1042 — the range the five published runs of this config span — we
have not reproduced the field's setup and no arm comparison is meaningful.
Report that and stop rather than reading the arms.

The secondary cells d4096 / d8192 / d16384 are recorded but decide nothing.
Their leaders carry ±28 and ±35 within-run scatter, so margins under ~8% there
are ties.

## Conclusion

<pending>

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here. 15
lines is enough to name the verdict, the deciding figure, and one line of
why; it is not enough to re-derive the round.
