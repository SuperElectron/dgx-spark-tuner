# c4 — take #1 outright in the concurrency-4 column

## Objective

`tg128 (c4)` on `nvidia/Qwen3.6-35B-A3B-NVFP4`, five cells. Board read live
2026-08-29T13:00:07Z; every figure below is that read, not a stored scrape.

    d0      82.85   sub1781472573286  Qwen3.5-122B-A10B-int4-AutoRound  8 entries
    d4096   54.54   sub1784104203777  Gemma-4-26B-A4B-NVFP4             7 entries
    d8192   44.29   sub1781472573286  Qwen3.5-122B-A10B-int4-AutoRound  4 entries
    d16384  46.68   sub1784104203777  Gemma-4-26B-A4B-NVFP4             8 entries
    d32768  36.51   sub1781472573286  Qwen3.5-122B-A10B-int4-AutoRound  6 entries

We hold no entry in any c4 cell, so we stand nowhere: unmeasured, not lost.

Target: our own measured `tg128 (c4)` mean exceeds the figure above, in each
cell, on our own control.

Reached when: the control's five means clear all five. The primary cell is d0 —
the highest bar and the fullest field. d32768 is secondary and may be
unreachable; see Strategy.

## Strategy

The c4 column is thin because arena-v2's profile is `1/2/5/10` (`26121b1f`), so
almost nobody measures it. Four to eight entrants per cell, against 140-260 in
the c10 cells. A cell nobody contests is won by showing up with a configuration
that was tuned for a different one.

We have measured the columns either side of c4. Full 28-cell grid at
`max_num_seqs: 10`, 2026-08-24, `bench_95fdfa8922a3`, tg128 t/s:

    depth      c1      c2      c5     c10
    d0      101.30  146.57  211.29  277.23
    d4096   104.55  135.69  182.79  236.64
    d8192   113.18  140.65  183.14  230.49
    d16384  102.03  135.68  177.23  141.31
    d32768   98.85  128.58  125.87   37.28

c4 lies between the c2 and c5 columns. At d0-d16384 that interval is monotone
and well behaved, so a c4 figure in the 160-200 band is the straightforward
read — against board tops of 36.51 to 82.85. If the interpolation holds, the
control takes all four shallow cells by a factor of two or more, and the
experiment's remaining work is margin, not victory.

d32768 is the exception and is called out as such: the c5 column has already
turned over there (125.87 < c2's 128.58), so d32768 c4 is the one cell whose
value is not bracketed by a monotone trend. It is also the boundary of the
known collapse — d65535 and d100000 at c5/c10 fall to 20.56 and 5.50
(`bf2cf33a`, reproduced exactly four days apart). That collapse sits outside
this grid, and at c4 the admission mechanism behind it is absent by
construction, since offered concurrency never exceeds the slot count
(`e46ae493`). We do not predict d32768; we measure it.

Interpolation is a prediction, not a result. The control exists to settle it.

What the store says about the obvious lever, before anyone spends a round on
it: `max_num_seqs` acts on this model by **admission only**, and its gain is
confined to cells where offered concurrency exceeds the slot count — the c1 and
c2 columns were flat across the 4->10 change (`00b3d74d`, n=3, ±0.2%). At c4,
`mns 10` and `mns 4` both admit all four requests. Moving it is predicted null
here, and the capture-size argument does not rescue it: the ladder is the
default truncated at 2xmns (`1084d7c0`), so a batch of 4 is captured at both
values. `max_num_seqs` is therefore not the lever this experiment reaches for,
and any round that reaches for it must first say what mechanism it expects
other than admission.

Measured scatter, per cell — what a decision rule here has to clear:

    c4, this model:      sigma under 1.5% on the 4-sequence average at runs=3,
                         even though individual per-request values span 5.4x
                         within one run (`8950a696`, measured at c4, d16384)
    c5/c10 shallow:      sd/mean 0.3-1.8% at runs=3 (arena-v2 grid)
    c2:                  3-5%
    c1:                  unresolvable on this schedule — ±15%, max/min 1.44
                         (`1d82439a`). Not in this grid.

c4 is the quiet end of this box. Treat a sub-3% arm difference as a tie, and
never read a single run as a value: MTP is the dominant term in tg spread on
this model, and removing it collapsed tg sd 8.6 -> 0.24 (`309b7175`). Every
figure here is a with-MTP figure and must be sized against the with-MTP spread.

## Held

- Box `spark-6f0e`, and the container image digest recorded at h1's first run.
  A digest change is a new epoch; the incumbent is re-measured before anything
  crosses it.
- Checkpoint `nvidia/Qwen3.6-35B-A3B-NVFP4`, unmodified. No requant, no local
  conversion. The checkpoint is not a lever in this experiment.
- Runtime vLLM. The cells we are scored in are `tg128` at concurrency 4.
- Grid and cell order are fixed for every arm: depths ascending, concurrency
  [4], `runs: 3`. Order decides what is warm and how hot the box is by the time
  a cell runs, and no figure reveals which order produced it. This is not
  negotiable between arms — a changed grid is what voids comparability, never
  the width of it.
- Only `tg` is compared. Our `pp` and `ttfr` are cold-cache and comparable to
  nothing on the board.

Deliberately NOT held, so a later round can reach them: `max_num_seqs`,
`max_num_batched_tokens`, the speculative config, `async-scheduling`, and
prefix caching. A Strategy sentence that closes a lever is a hypothesis, not a
Held — reading one as a Held is what cost `concurrency/h1` an entire round
(`1db899b2`).

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | the tuned recipe, unchanged, already clears every c4 leader | |

## Conclusion

Open.
