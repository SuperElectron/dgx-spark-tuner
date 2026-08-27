# h6 — the checkpoint's own `temperature 1.0` is costing decode on the board grid

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

LEVER SPENT, by the rule as written — `tg` median at `d16384 c1` is 105.12,
below the rule's 110.7 floor. The mechanism did fire: acceptance rose 3.07 →
3.22 and bought no throughput.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | `--override-generation-config` temperature 0.6 | the last untested field in the reference diff; tg is the median of n=3, max/min 1.132, values 105.12 94.43 106.91; accept len 3.22 median over 401 samples | d16384 c1 | 633.71 | 105.12 | 3243.59 ms | bench_44dd96bddd72 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Overriding the served generation config to `temperature 0.6` raises `tg` at
`d16384 c1` on the arena-v2 grid above h5's 103.7. Mechanism: MTP proposes three
tokens per step and the target accepts a prefix of them, and how long that prefix
is depends on how sharply the target's distribution is peaked. h5 served the
checkpoint's own `temperature 1.0`; the reference recipe that reads 116.03 sets
0.6 with the same `top_p` and `top_k`. Arena does not pin sampling, so this is
board-legal, and it is the last served field in the Strategy diff never varied.

Worth, if right: h5's acceptance reads 3.07 against a ceiling of 4.0, and
decode here is target-pass-bound, so closing half that headroom is ~15% more
accepted tokens per forward pass — 103.7 x 1.15 clears 116.03. One measurement
argues against it already: h1's per-position rates at `temperature 0` imply
~2.93, *below* h5's 3.07. That is precisely why it is worth one cheap run.

## Method

### Variables to test

    --override-generation-config: temperature 0.6 (top_p 0.95, top_k 20 unchanged)

Order: nothing else varies, so there is no order. One run.

### Constant for this round

Everything else in h5 run-0001's recipe, byte for byte: the same `serve`
command, the same `defaults:` including `max_model_len 262144`,
`gpu_memory_utilization 0.8`, `max_num_seqs 4`, `max_num_batched_tokens 65536`,
and the same 28-entry `schedule:` in the same order. **The schedule is
load-bearing** — it decides what is warm and what is hot, and `d16384 c1` must
stay at index 13 or the two runs are not comparable. Copy the file and add one
flag; do not re-transcribe it. This is the **board-comparable** lane: it
inherits h5's epoch and protocol, and its figures are comparable to h5 run-0001
and to nothing else.

Grid, from the recipe's `benchmark:` block — arena-v2 unmodified:

    pp 2048 · tg 128 · depth 0/4096/8192/16384/32768/65535/100000
    concurrency 1/2/5/10 · runs 3

## Decision rule

Read our own `d16384 c1` row, cell phase, and take the **median** of its three
`tg` values — not run.py's table column, which is an arithmetic mean of a rate.

- **Target met** if the median exceeds **116.03**. The board comparison is then
  settled in our favour on the board's own terms.
- **Lever alive** if it exceeds **110.7** (h5's 103.7 plus 6.8%, one max/min
  half-width — the smallest move this cell can distinguish from h5) but does not
  reach 116.03. Sampling is then carrying real decode and there is a second
  value to try; `temperature 0.3` is the next row, not a new round.
- **Lever spent** if the median lands at or below **110.7**. Sampling does not
  govern decode here, the reference recipe's `temperature 0.6` is not what makes
  it 116.03, and the gap belongs to one of the three candidates h5 could not
  separate.

Sized so that an effect smaller than what h5's own scatter can resolve is read
as no effect. Note before any number exists: this cell's spread is wide enough
that a genuine 5% win would be reported as a spent lever. That is the cost of
`runs: 3`, inherent to arena's grid, and this round accepts it.

## Conclusion

**Lever spent, by the rule as written.** Median 105.12 (n=3; 105.12, 94.43,
106.91; max/min 1.132), below both the 110.7 floor and the 116.03 target.
Sampling does not govern decode on the board grid.

**The mechanism fired and bought nothing** — a stronger refutation than one that
fails to engage. The engine served `temperature 0.6`, acceptance moved as
predicted (3.07 → 3.22, +4.9%, 401 samples), and `tg` moved 103.7 → 105.12
(+1.4%) inside a cell spanning 94.43 to 106.91. That breaks the campaign's
`tg ≈ 37 × acceptance` relation at fixed depth: the quotient *fell*, 33.8 →
32.6, while acceptance rose.

Two qualifications, neither rescuing the prediction. The relation's 118.8 is
**cross-epoch and cross-protocol** and must not be quoted bare; **the
within-lane break is the part that counts.** Both moves are small against this
cell's scatter, so what is established is a **bound, not a slope**: the relation
survives as a normaliser in a depth ladder, never as a lever. Reasoning in the
store, under `decode-tg/h6` in the `basis`.
