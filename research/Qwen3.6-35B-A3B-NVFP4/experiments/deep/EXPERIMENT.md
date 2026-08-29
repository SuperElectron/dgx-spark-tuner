# deep — close the deep-cell collapse at c5 and c10

## Objective

`tg128` at d32768 / d65535 / d100000, concurrencies 5 and 10, on
`nvidia/Qwen3.6-35B-A3B-NVFP4`. Board read live 2026-08-29; our figures are the
28-cell arena-v2 grid of 2026-08-24, `bench_95fdfa8922a3`.

    cell              ours     leader   sub                 gap
    d32768 (c5)     125.87     192.53   sub1777633319098   -34.6%
    d32768 (c10)     37.28     235.33   sub1777329489841   -84.2%
    d65535 (c5)      20.56     164.90   sub1777329489841   -87.5%
    d65535 (c10)     10.92     158.16   sub1777562736675   -93.1%
    d100000 (c5)      8.51     162.75   sub1775358348351   -94.8%
    d100000 (c10)     5.50     220.38   sub1775358348351   -97.5%

Target: our own measured figure exceeds the leader in at least one of the six.

Reached when: any cell clears its leader by more than the cell's own scatter.
This is the loosest target in the tree, and deliberately so — a 20x gap is not
closed by tuning, and the experiment's first job is to find out what kind of
gap it is.

## Strategy

The gap is not a tuning margin. `7bd4c673` recorded our d100000 c10 at 5.49
against a same-family, same-quant, single-node vLLM board entry at 116.26 — 21x,
far outside anything a flag moves. `bf2cf33a` reproduced the collapsed corner
exactly across two runs four days apart (d32768 c10 37.22 vs 37.28, d65535 c5
20.21 vs 20.56, d100000 c5 8.31 vs 8.51), so it is a stable property of this
configuration and safe to attack as a mechanism rather than chased as a bad run.

The peer to beat is `RedHatAI/Qwen3.6-35B-A3B-NVFP4` (`sub1779001966608`) — the
same architecture, the same NVFP4 quant, the same runtime, the same container.
It holds 150.52 / 162.07 / 143.50 / 116.26 at d32768 c5 / d65535 c5 / d100000 c5
/ d100000 c10 where we read 125.87 / 20.56 / 8.51 / 5.50. Flat where we fall off
a cliff.

Their served configuration differs from ours in six ways, read from the
published recipe:

    max_num_seqs               absent (vLLM default)   ours 10
    gpu_memory_utilization     0.5                     ours 0.8
    max_num_batched_tokens     32768                   ours 65536
    speculative num tokens     2                       ours 3
    load_format                instanttensor           ours fastsafetensors
    async-scheduling           absent                  ours set

What we already know narrows which of those can matter. Admission is part of
the story but not all of it: at c4, where offered concurrency never exceeds the
slot count and the queue confirmed max Waiting 1, the same depths give 37.45 and
11.93 against 20.56 and 8.51 at c5 — the collapse halves but does not vanish
(`round:c4/h1`, 2026-08-29). Raising slots moved the deep cells only 1.03-1.04x
(`00b3d74d`, `65527b17`), so a slot count alone is not it either. KV capacity is
not the constraint — the pool is 2.81M tokens and both sweeps peaked at 9.7-9.8%
with zero preemptions (`84a21213`). That leaves the memory-shape settings
(`gpu_memory_utilization`, `max_model_len`, `max_num_batched_tokens`) and
`async-scheduling`, which has never been measured on this box at all.

So the round order is not the cheapest-first order. The decisive question is
whether the gap is **configuration or checkpoint**, and one run answers it: our
checkpoint served with their configuration. If the numbers move to their range,
the gap is ours to close and the following rounds bisect which field did it. If
they do not, the gap is the checkpoint or its mods, and no amount of tuning this
recipe will close it — which is worth knowing before spending five rounds
finding out.

Measured scatter, per cell — what a decision rule here has to clear:

    deep cells, c5/c10:  the collapsed figures reproduce to within 2%
                         across four days (`bf2cf33a`), so the cells
                         themselves are quiet; it is their value that is bad
    c4 deep:             cv 0.4-1.3% at runs=3 (2026-08-29)
    shallow c5/c10:      sd/mean 0.3-1.8% at runs=3

These cells are among the quietest on the box. A 2x move is unmistakable; the
risk here is not noise, it is misattribution.

## Held

- Box `spark-6f0e`, and the container image digest recorded at h1's first run.
  A digest change is a new epoch; the incumbent is re-measured before anything
  crosses it.
- Checkpoint `nvidia/Qwen3.6-35B-A3B-NVFP4`, unmodified. We do not swap to
  RedHatAI's checkpoint — that would answer a different question and is not a
  configuration this experiment can own. The checkpoint is the one thing the
  decisive arm cannot vary, which is exactly why a null result there implicates
  it.
- Runtime vLLM. The cells are `tg128` at concurrency 5 and 10.
- Grid and cell order fixed for every arm: the six deep cells, ascending depth,
  c5 before c10 at each depth, `runs: 3`. Order decides what is warm and how hot
  the box is by the time a cell runs.
- Only `tg` is compared.

Deliberately NOT held: every field in the six-way difference above. Each is a
candidate and a later round must be able to reach it.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | the gap is configuration, not checkpoint: our checkpoint under the peer's configuration recovers their range | LEVER SPENT — worse in all six cells, 0.33x to 0.87x of control |
| h2 | halving `max_model_len` to 131072 lifts the deep cells | LEVER SPENT — 0.997x to 1.011x of control; inert |

## Conclusion

Closed as exhausted. The Objective was not met: no cell approached its leader,
and our figures are where they were on 2026-08-24.

Two rounds spent the reachable levers. h1 served our checkpoint under all six
fields separating us from `sub1779001966608` and every deep cell got worse —
0.33x at d32768 c5 — so the 21x gap is not this configuration. h2 halved
`max_model_len` alone and moved nothing, 0.997x to 1.011x, clearing the last
suspect `7bd4c673` named.

What remains is closed by Held: the checkpoint (`RedHatAI` vs `nvidia`) and the
two mods the peer carries, `fix-qwen3-coder-next` and `fix-qwen3.6-chat-template`.
An experiment that wants those has to open the checkpoint, which this one
deliberately did not.

Worth carrying forward. The control reproduced the 2026-08-24 grid to within
1.5% in all six cells, a third confirmation that the collapsed corner is a
stable property and not a bad run. And the collapse is roughly halved at c4
(37.45 and 11.93 at d65535/d100000 against 20.56 and 8.51 at c5), so admission
is part of the mechanism — but c4 still falls an order of magnitude from d32768
to d100000 with nothing queued, so it is not the whole of it.

No submission. Nothing here beats a board leader.
