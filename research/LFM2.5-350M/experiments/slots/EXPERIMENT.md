# slots — take #1 outright at tg128 c10 by serving the concurrency we are scored at

## Objective

`tg128 (c10)` on LFM2.5-350M. The board's #1 outright, all models, single node,
is 1042.20 t/s — sub1787760284956, read 2026-08-28. We have never measured this
model on this box, so we stand nowhere: the cell is unmeasured, not lost.

Target: beat 1042.20 t/s at `tg128 (c10)` d0 on the same checkpoint.

Secondary, same lever, no extra grid: `tg128 (c10)` at d4096 (750.01), d8192
(745.70), d16384 (613.31). These ride along in the same run and cost nothing
extra to contest.

Reached when: our own measured `tg128 (c10)` d0 mean exceeds 1042.20 t/s.

## Strategy

The board scores `tg_throughput` as a batch aggregate at a fixed concurrency,
so the figure is the whole batch's decode rate, not one stream's. At c10 the
harness offers ten concurrent requests. Every top-5 entry at this cell serves
`max_num_seqs: 4`, so vLLM admits four and queues six. The queued six still
count against wall-clock but contribute no tokens while they wait. The cell is
therefore being scored at a concurrency nobody has configured the server to
accept, and the gap between offered and admitted load is unclaimed throughput.

A 350M BF16 checkpoint is ~0.7 GB of 121 GB unified memory. Decode on a model
this small is bandwidth-bound per stream and nowhere near compute-saturated, so
additional concurrent streams are close to free until either the KV cache or
the scheduler's token budget binds. Neither binds at 0.7 GB of weights with
`gpu_memory_utilization: 0.8` — there is room for far more than four slots.
`max_num_batched_tokens: 8192` is the constraint that must move with the cap:
raising slots without raising the token budget just moves the queue.

What we already measured, on a different model, same box, same image digest —
so this transfers by mechanism, not by magnitude:

- `mns` 4→10 took `tg128 d16384 c10` from 48.9 to 141.5, ±0.2% at n=3. The cost
  was admission, not batching: four slots admitted four of ten offered while six
  waited inside the aggregate window. Gain confined to cells where offered
  concurrency exceeds the slot count; c1 and c2 are flat. (`00b3d74d`)
- `mns` is paid in full at the grid's maximum offered concurrency and is inert
  above it. Running max stopped at 10 even with 16 configured; c10 moved
  137.5→139.8, 1.7% against ±1.8% spread. The smallest sufficient value is the
  offered concurrency itself. (`0dfb65f1`)
- Ten slots did not empty the queue on the full grid — h3 read waiting max 7.
  Slots above offered concurrency have nothing to admit; that is all that
  survives. (`65527b17`)
- `mnbt` gates prefill admission at `floor(mnbt/depth)` whole prefills per step
  and never gates decode. It must exceed `depth + pp`. (`97250b99`, `f7eddab5`)
- With `mns` pinned at 4, moving `mnbt` alone moved tg the *wrong* way,
  monotonically. `mnbt` is a companion to `mns`, never an arm. (`780cfd5b`)

No small model, no BF16 model, and nothing at c10 has been measured on this box
— `Qwen3.5-0.8B` exists only at d0 c1. The transfer argument is the vLLM
scheduler's admission path, which is model-independent; the magnitude is not.

Measured scatter, per cell — what a decision rule here has to clear:

    tg128 (c10) d0:      unmeasured on this box — h1's control measures it
    tg128 c10, general:  arm-internal ±0.2-1% at n=3   (`00b3d74d`, `bf2cf33a`)
    tg128 shallow:       sigma ~2.6-3.3% once the prompt is pinned (`6f05cb73`, `22e2c2c5`)
    vs a singly-measured figure: ~2-3% tie band, with a ~2% downward
                         error bar on any figure measured once (`a99db2a0`)

tg128 at d0-d16384 is the quiet end of this box; tg32 and d≥65536 are the noisy
end and are not in this grid. Treat a sub-3% arm difference as a tie.

The published field is not one wide distribution. Five entries exist for this
model, read live 2026-08-28 19:05Z, and they split into two tight populations
by a single flag:

    --quantization fp8 absent:  700.00, 708.80, 722.99, 742.01   (four entries, 6% wide)
    --quantization fp8 present: 1042.20                          (one entry)

The 1042.20 and the 708.80 are the same author, the same image digest, six
hours apart, and their recipes differ in exactly one line — verified by
diffing the two published recipes, not inferred. So the board's own top figure
is a controlled single-flag result worth +47.0% at d0, not a lucky draw. Our
baseline already carries that flag, since it is a copy of the 1042.20 entry.

Consequence for this experiment: the target is not a noise ceiling to out-roll.
It is a real configuration we start level with, and `mns` has to buy the margin
on top of it.

Independent support for the lever, from the same live read: across all five
entries the ratio of aggregate `t_s` to per-request `t_s` is 2.8-3.3 at every
depth and never near 10. Four slots minus scheduling overhead is ~3 in flight.
Every published entry is being scored at c10 while serving about three.

### Lever ladder

One lever per round, in this order. Each is a flag no entry in the published
field has ever set; the ordering is by how cleanly a round can read it, not by
expected size.

    h1  max_num_seqs 4 -> 10 -> 16        the queue, measured directly
    h2  cuda_graph capture at the batch   coupled to h1's winner; a batch size
                                          with no captured graph pads or falls
                                          back to eager
    h3  speculative-config ngram          no draft model, so the checkpoint
                                          stays unmodified; converts idle
                                          decode compute into tokens
    h4  async-scheduling                  fixed per-step CPU cost against a
                                          tiny 16-layer GPU step
    h5  VLLM_USE_FLASHINFER_SAMPLER=1     per-step sampler cost is proportionally
                                          large on a 350M model

Not levers, and why: `--quantization fp8` is already ours (it is what the
target entry has and what makes it the target). `--attention-backend` is
confounded on the board with `kv-cache-dtype` and is worth re-reading only
after h1 changes the batch size it operates at.

## Held

- Box `spark-6f0e`, and the container image digest recorded at h1's first run.
  A digest change is a new epoch; the incumbent is re-measured before anything
  crosses it.
- Checkpoint `LiquidAI/LFM2.5-350M` at sha `9e6c6ccf47cd318696e137d381a7ded8fe4df09f`.
  Unmodified — no requant, no local conversion. The checkpoint is not a lever
  in this experiment.
- Runtime vLLM, container `vllm-node`. The cell we are scored in is `tg128`,
  concurrency 10.
- Cell order within a run is the recipe's `benchmark:` block order, ascending
  depth. Order decides what is warm; no figure reveals which order produced it.
- Only `tg` is compared. Our `pp` and `ttfr` are cold-cache and comparable to
  nothing on the board.

Not "every field not under test" — a round holds its own fields constant, and
says so in its own Method. Anything named here is closed to every round.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | lifting `max_num_seqs` above 4 claims the offered-but-unadmitted load at c10 | TARGET MET — `mns 16` 2197.72 t/s at `tg128 d0 c10` vs 1042.20 target |

## Conclusion

Objective reached in h1, on the first lever of the ladder. `max_num_seqs` 4 ->
16 takes `tg128 d0 c10` from 1021.87 to 2197.72 t/s (+115.1%, n=3, spreads not
overlapping), against a target of 1042.20. `mns 10` also clears it, at 1911.16.
`recipe-new.yaml` carries `max_num_seqs: 16`; nothing else moved.

Half the win is the mechanism the Strategy argued: at `mns 4` the engine held
Running 4 / Waiting 6 of the ten offered, and `mns 10` emptied that queue. The
other half is not — at `mns 16` Running never passed 9, so the extra slots
admitted nothing and the +15.0% over 10 has another cause. h2's CUDA-graph
lever is the standing candidate and is now motivated by a measured row rather
than by the ladder's ordering.

Two things the figures do not claim. Every arm ran cold-cache (prefix-cache hit
rate ~0% throughout, a property of llama-benchy's prompts), and none ran the
image the 1042.20 entry pins. The arms are comparable to each other; a claim
against the board crosses a vLLM build boundary and would need re-measuring on
the board's own epoch to be clean. Submission is Mat's call, not this round's.
