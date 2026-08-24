# h2 — four slots serve ten requests, and the c10 aggregate pays for the queue

## Hypothesis

Raising `max_num_seqs` from 4 to 10 raises `tg` at `d16384 c10` above h1's
control of 49.0, and does not lower `tg` at `d16384 c1`.

The mechanism is admission, not batching efficiency. h1 measured `running max 4`
in every arm — pinned at `max_num_seqs` — with `waiting max` 6 and zero
preemptions, at a cell that presents ten requests. Six of the ten are queued at
the peaks. llama-benchy's aggregate `tg` divides generated tokens by a wall-clock
window that begins when the cell begins, so a request that spends most of its
life waiting still contributes its wait to the denominator and only 128 tokens to
the numerator. Four slots do not serve ten requests in one pass; they serve them
in roughly three waves, and the aggregate is diluted by two waves of waiting.

h1 measured the size of that dilution directly. In the control, aggregate `tg`
across c1, c2, c5, c10 reads 97.9, 136.8, 84.7, 49.1 while aggregate *peak*
throughput rises monotonically 106, 174, 297, 316. The engine gets faster as
concurrency rises; the reported mean falls. The mean-to-peak gap widens from
1.09x at c1 to **6.4x at c10**, and c10 is the only cell where `waiting` is
routinely non-zero. Nothing else in h1 tracks that pattern: KV usage peaked at
3.9% of a pool the engine sizes at 19.3x the full context window, preemptions
were zero in all three arms, and the token budget — h1's lever — moved the cell
by at most 9.8% while moving `waiting max` by 2.

Raising the slot count converts waves into one pass. Decode on this model is
weight-bandwidth bound with roughly 3B parameters active per token, so the
marginal cost of the fifth through tenth concurrent sequence in a decode step is
small: each weight read serves more sequences. That is the same property h1 saw
from the other side, where aggregate peak *rose* with concurrency while four
slots were saturated.

Worth, if right: the Objective needs c10 to go from 49.0 to above 102.31, a 2.1x.
The measured mean-to-peak gap at that cell is 6.4x and the measured peak is 316
t/s. Recovering a *third* of that gap clears the target. No other field in the
open search space has arithmetic of that size — h1 closed the token budget in
both directions at under 10%, and `gpu_memory_utilization` and the sampling and
chat-template diffs have no recorded mechanism acting on aggregate decode under
queueing. If this round moves nothing, the Objective is probably not reachable
from the scheduler at all, and that is worth knowing too.

**Against the experiment's own Strategy, explicitly.** Strategy says "the gap is
not slots", because the reference recipe that reads 102.31 also serves
`max_num_seqs 4`. That argument is sound as an account of *why the reference
beats us* — slots cannot explain a difference between two recipes that both set
four. It does not bear on whether raising slots raises *our* number, which is
what the Objective asks. Held deliberately leaves `max_num_seqs` open, which only
makes sense if a round may move it. If this round hits the target, it also
follows that the reference reaches the same place by a different route — most
likely its `gpu_memory_utilization 0.65` or its sampling and template config —
and that becomes the next thing worth knowing.

The honest case against: raising the slot count admits more prefill concurrently
as well as more decode, and memory records that batching more prefill together
makes every request's first token compete with more peers. If prefill dominates
the c10 window — 10 × 18432 tokens of it — then admitting all ten at once may
lengthen the window as much as it shortens it, and the aggregate does not move.
h1's ttfr at this cell was already 21.5 s with a 11.4-35.3 s spread. That is why
this is a screen and not a claim.

## Method

### Variables to test

    max_num_seqs: 4 (control) -> 10 -> 16

Order: 4 first, as the control on this round's own schedule; then 10, which is
exactly the concurrency of the primary cell and the value at which the queue
disappears; then 16 to separate "the queue was the cost" from "more slots are
always better". If 10 lifts c10 and 16 does not lift it further, the mechanism is
the queue, which is what is claimed. If 16 lifts it further, the claim is wrong
even if the number moves, because at c10 there is nothing left to admit.

The control is re-measured rather than inherited from h1's run-0001. h1
established that this screen's cells are not stationary — its c1 drifted up to
19% within a single cell — so a control measured in the same session as the arms
it is compared against is worth its cost, and it doubles as a reproducibility
check on 49.0.

### Constant for this round

Everything else in the experiment's `recipe.yaml`, byte for byte, and in
particular **`max_num_batched_tokens` stays at 65536**. h1 measured it as the
best of three values at the primary cell, and moving two scheduler fields at once
would confound both — the mistake h1's own Method declined to make.
`max_model_len 262144`, `gpu_memory_utilization 0.8`, `kv-cache-dtype fp8`, MTP
depth 3 on triton, the same serve command and the checkpoint's own sampling.

Grid, from the recipe's `benchmark:` block — the same reduced schedule h1 ran, in
the same order, so h2's arms are comparable to h1's as well as to each other:

    pp 2048 · tg 128 · depth 16384 · concurrency 1, 10, 5, 2 · runs 7/3/3/3

    schedule:
      - { depth: 16384, concurrency: 1,  runs: 7 }
      - { depth: 16384, concurrency: 10, runs: 3 }
      - { depth: 16384, concurrency: 5,  runs: 3 }
      - { depth: 16384, concurrency: 2,  runs: 3 }

**These figures are not board-comparable and cannot close the experiment.** Held
requires the unmodified 28-cell arena-v2 grid for that, and twelve cells precede
`d16384 c1` there. This round screens; a number from it is never set beside
102.31 as an equal. If an arm clears the target on this screen, the next step is
one full arena-v2 run of that arm's recipe to earn the board-comparable figure.

### Handling h1's open confound at c1

h1 found the c1 cell drifting up to 19% within itself, with triton JIT kernels
compiling inside its first run, and c1 runs first in this schedule. `runs: 7`
beats scatter and does nothing about drift. So, pre-registered:

- Report the c1 median over all seven runs **and** over runs 4-7 alone. The
  guard below reads the all-seven median; the second-half figure is reported
  beside it every time, and a round where the two disagree by more than the
  cell's own ±4.1% has not measured c1 at all.
- Record whether JIT compilation lands inside the measurement window, per arm,
  from the engine log. It did in two of h1's three arms.

The cell order is not changed. Held closes it for a round that runs a schedule,
and keeping it identical to h1's is what makes h1's arms usable as extra
context.

### What is ruled out before it is proposed

- **Acceptance.** Flat under scheduler knobs for six consecutive rounds now,
  h1 included (3.07 / ~3.0 / 3.15 across its arms). Capture it as a control that
  it did not move, never as an explanation.
- **Prefix cache.** 0.0% over 44 samples in each of h1's arms and everywhere
  before them. Every arm here is cold-cache and no arm may claim otherwise.
- **KV capacity.** 3.9% peak with zero preemptions, and the engine reports 19.3x
  maximum concurrency at the full context window. Raising the slot count to 16
  at `d16384` does not approach it. If an arm *does* preempt, that is a finding
  and the arm's figures are read as a capacity result, not a scheduling one.
- **The token budget.** Closed by h1 in both directions.

### Pre-registered non-findings

- **CUDA-graph bucket padding changes with the slot count.** h1's Method noted
  c5 padding to the 24-token bucket at `max_num_seqs 4`; the buckets differ at 10
  and 16. Expect c5 and c2 to move for reasons that are not this mechanism, and
  do not read them as evidence either way.
- **A longer graph capture at boot** is expected at higher slot counts. An arm
  that is slow to become ready has not thereby measured anything.
- `max_num_seqs` should be **inert at c1** by construction: with one request in
  flight there is nothing to admit. A c1 that moves with this field is a signal
  that something other than admission changed — graph capture, kernel selection —
  and must be reported as such rather than folded into the guard reading.

## Decision rule

Read `d16384 c10` and `d16384 c1`, aggregate `tg` medians, from each arm, against
**this round's own control arm** — not against h5's cross-schedule figures. h1's
rule set its guard from a number measured on a different schedule and was
unresolvable because of it; that defect is corrected here rather than repeated.

Sized against h1's measured scatter on this exact schedule: ±0.3-0.6% at c10 and
±2.9-4.1% at c1, at `runs` 3 and 7. The c1 guard floor is therefore one scatter
width below the control, 0.959 × control.

- **Target met** — c10 exceeds 102.31 *and* c1 holds at or above 0.959 × the
  control's c1. Then go straight to one full 28-cell arena-v2 run of that arm's
  recipe, which is the only thing that can close the Objective.
- **Lever alive** — c10 rises more than 5% over the control and c1 holds at or
  above 0.959 × the control's c1, but c10 is still below 102.31. Add arms to this
  round: the slot count has more to give and its best value carries forward.
- **Lever spent** — c10 moves less than 5% either way, or it rises while c1 falls
  below 0.959 × the control's c1. In the second case admission is a genuine trade
  against single-stream rather than a free win, the guard governs, and
  `max_num_seqs 4` stands.

Report the board's numbers alongside — 102.31 at c10 and 103.7 at c1 — as
context for how far the screen has come, never as a threshold this schedule can
resolve.

The rule reads **aggregate** `tg`, which is what the board scores. Per-request
`tg/req` spans up to 11.8x within a single c10 cell and no branch above may be
evaluated on it; the per-request medians are diagnostic and are reported because
h1 showed they can corroborate the aggregate's direction.

Three values per arm at c10 means no interquartile range; the rule is stated on
medians and a 5% threshold for exactly that reason, and this is said before the
numbers exist rather than after.

## Runs

One row per planned run. Figures blank until it is run.

| run | changed | why | cell | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|------|--------|--------|---------|-------|
| run-0001 | baseline, `max_num_seqs` 4 | the control, on this round's schedule and session | d16384 c10, guard d16384 c1 | | | | |
| run-0002 | `max_num_seqs` 4 → 10 | the queue disappears at exactly the primary cell's concurrency | d16384 c10, guard d16384 c1 | | | | |
| run-0003 | `max_num_seqs` 4 → 16 | separates "the queue was the cost" from "more slots always help" | d16384 c10, guard d16384 c1 | | | | |

Record per arm, because the recipe names a floating tag: the container image
digest and the vLLM and flashinfer commits. h1's epoch is image digest
`sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990` with
vLLM `e85d1b69` and flashinfer `4927c0e1`. An arm recording anything else has
crossed an epoch break and is not comparable to h1 or to its own siblings.

Record per arm as well: `running max`, `waiting max`, `kv max`, preemptions,
prefix cache hit rate and samples, LOOPING counts per cell, and MTP acceptance.
`waiting max` is this round's mechanism check — if it does not fall toward zero
at c10 as the slot count rises, the field did not do what it was raised to do,
whatever `tg` says.

## Conclusion

<pending>
