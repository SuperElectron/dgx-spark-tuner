# h1 — max_num_seqs, the admission cap, at the concurrency we are scored at

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

TARGET MET — `mns 16` measures 2197.72 t/s at `tg128 @ d0 (c10)`, against the
1042.20 t/s target. `mns 10` clears it too, at 1911.16.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | max_num_seqs: 4 -> 4 (control, baseline unchanged) | CRASH before engine launch: image distribution failed, 'pull access denied for vllm-node' — recipe_version '2' with no builder key leaves the vllm-node alias unresolved | d0 c10 | — | — | — | bench_d71964e4722e |
| run-0002 | max_num_seqs: 4 -> 4 (control, baseline unchanged) | run-0001 crashed before engine launch; recipe_version 1 fix (11d9722) makes the control runnable | d0 c10 | 21799.2 | 1020.7 | 510 | bench_3e383b29d978 |
| run-0003 | max_num_seqs: 4 -> 10 | run-0002 control reproduced the field at 1021.87 t/s and ran Running 4 / Waiting 6-7, so six of ten offered requests were queued and unadmitted | d0 c10 | 89754.2 | 1927.2 | 204 | bench_356582688687 |
| run-0004 | max_num_seqs: 4 -> 16 | run-0003 at mns 10 moved tg128 d0 c10 +87.0% over the control, so the Method calls for 16 to find the smallest sufficient value | d0 c10 | 91831.4 | 2188.4 | 199 | bench_4d8f02ff6b65 |
| run-0005 | none — recipe-new.yaml verbatim (max_num_seqs: 16) | post-close verification of the promoted recipe on a fresh boot; not an arm, decides nothing | d0 c10 | 88475.9 | 2229.8 | 173.6 | bench_97c6be259d27 |
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

TARGET MET. `max_num_seqs` ran 4 / 10 / 16 at `tg128 @ d0 (c10)`, n=3 each:
1021.87 (sd 2.97), 1911.16 (sd 30.49), 2197.72 (sd 32.24) t/s, spreads not
overlapping. The control sits inside the 700-1042 validity band, so the arms
read; 16 clears the 1042.20 target by 110.9%, and 10 clears it too.

The hypothesised mechanism holds only for 4 -> 10 — control Running 4 /
Waiting 6, `mns 10` Running 10 / Waiting 0. At 16 Running never passed 9, so
slots 11-16 admitted nothing and the +15.0% over 10 is a different effect;
16 is an exact `cudagraph_capture_size` and 10 is not, which is h2's to test.
That kills `0dfb65f1` and `65527b17` outside the 35B MoE they came from.

Two caveats the precondition does not cover: prefix cache was inert in every
arm (0.0 / 0.7 / 0.0% hit, llama-benchy's prompts share no prefix) so every
figure is cold-cache, and the 1042.20 entry pins an image absent from this box.
The arms compare to each other cleanly; against the board they cross a build.

Where the rule fits badly: its "lever spent" clause reads 16-over-10 as proof
the queue is fully admitted. It was fully admitted at 10, and 16 still gained
15.0%. Target met resolves first, so the clause never fired.
