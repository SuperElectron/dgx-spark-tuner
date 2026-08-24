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
| run-0001 | baseline, `max_num_seqs` 4 | the control, on this round's schedule and session | d16384 c10, guard d16384 c1 | 583.9 | 49.0 ±0.2% | 21430 | bench_270c9926d658 |

Full cell menu: c1 107.0 ±4.9% (n=7), c2 136.3 ±5.1%, c5 84.2 ±1.7%,
c10 49.0 ±0.2%. `running max 4`, `waiting max 6`, prefix cache 0.0% over 44
samples. Integrity check passed on all four cells — `request_end` and
`request_first_token` counts agree (14/14, 60/60, 30/30, 12/12); one c5 request
returned 94 tokens rather than 128, which is a short generation, not the
missing-first-token damage h1 run-0003 carried.

### This control is also an unplanned replicate, and it settles h1's c1 question

run-0001 here is byte-identical in the fields that matter to h1's run-0001 —
`max_num_seqs 4`, `max_num_batched_tokens 65536`, same schedule, same epoch —
so the pair is a direct measure of run-to-run reproducibility on this screen.

    cell     h1 run-0001    h2 run-0001    delta
    c10             49.0           49.0     0.0%
    c5              84.3           84.2    -0.1%
    c2             136.1          136.3    +0.1%
    c1              96.0          107.0   +11.5%

**c10, c5 and c2 reproduce to within 0.2%.** The screen is an excellent
instrument at those cells and the h1 trend it measured is trustworthy.

**c1 does not reproduce at all.** Same configuration, 11.5% apart, at n=7 both
times. That retires h1's c1 step as a finding about the token budget: the four
c1 medians this experiment has measured are 96.0, 107.2, 106.2 and 107.0, and
the one that made the "step" look real is the single low draw among them. h1's
Conclusion already declined to establish it on the drift and the anti-correlation
evidence; this is the direct replicate that closes it.

Consequence for this round, recorded before the arms run: **c1 cannot function
as a guard at better than about ±11%**, whatever `runs` it is given, so a guard
stated on a few percent of c1 is unreadable. The rule below reads c1 against
this control and against that reproducibility figure, not against a tighter
band.
| run-0002 | `max_num_seqs` 4 → 10 | the queue disappears at exactly the primary cell's concurrency | d16384 c10, guard d16384 c1 | 577.6 | **137.5 ±1.8%** | 8127 | bench_8ced4b0ea3c2 |

Full cell menu: c1 102.1 ±4.2% (n=7), c2 137.9 ±3.2%, c5 **172.0** ±1.9%,
c10 **137.5** ±1.8%. Integrity clean on all four cells — `request_end` and
`request_first_token` agree (14/14, 60/60, 30/30, 12/12) and every request
returned a full 128 tokens with an empty error string.

Three qualifications on those numbers:

- **c5's 172.0 is inflated.** 1 of 30 requests was flagged LOOPING, which
  run.py records as decoding faster and lifting `tg`. c1, c2 and c10 raised
  none, so the headline c10 figure is clean and c5's is an upper bound.
- **Latency moved the other way.** c10 ttft median went 19.12 s -> 28.08 s
  against the control. Arena scores `tg`, so this costs nothing on the board,
  but the round bought throughput with first-token latency and the record
  should say so rather than report only the half that flatters it.
- **KV rose but did not bind:** 3.6% -> 9.4% of pool, preemptions still 0.
  CUDA-graph capture now runs to size 80 at 1.95 GiB. Headroom remains, which
  is what makes the 16-slot arm worth running rather than reckless.

One non-finding, checked and dismissed: the c10 progress file holds 65
`request_start` lines for 60 distinct request ids — five ids emit a duplicate
start line. Unique starts, ends and first-tokens all equal 60, so nothing is
lost or double-counted; it is a duplicated log emission, not a data fault.

### The mechanism did exactly what it was raised to do

    cell    mns 4    mns 10    change      board (1199b578)
    c1      107.0     102.1     -4.6%      116.03
    c2      136.3     137.9     +1.2%      165.88
    c5       84.2     172.0    +104.3%     142.30
    c10      49.0     137.5    +180.6%     102.31

`running max` rose 4 -> **10**, `waiting max` fell 6 -> **4**. That is the
pre-registered check, and it passed before any throughput figure was read: the
queue shortened because the slots exist to serve it.

**c10 clears the Objective's 102.31 by 34% and c5 clears the board's 142.30 by
21%**, on a screen that reproduces those two cells to within 0.2%. This is the
lever the experiment was looking for, and it was not the token budget.

The guard holds. c1 reads 102.1 against this round's own control of 107.0, a
4.6% fall — well inside the ±11% run-to-run reproducibility measured at this
cell above, and therefore not readable as a regression. It is also not readable
as "no cost": c1 simply cannot resolve a change of this size, which is a fact
about the instrument and is why the full-grid run below is what settles it.

**What this does NOT yet establish.** These figures are from the reduced screen
and Held forbids setting them beside the board. Arena's grid runs 28 cells in a
heat-aware order with `runs: 3` and no per-cell repeats at c1; the screen runs
four cells cold. The Objective closes on a full 28-cell arena-v2 run and nothing
less, so what run-0002 buys is a *candidate*, not the board-comparable number.

**A correction this round owes the experiment's own Strategy.** `EXPERIMENT.md`
argues "the gap is not slots", reasoning that the reference recipe serves
`max_num_seqs 4` exactly as we do and therefore slot count cannot be what
separates us. That reasoning is sound about the *reference* and wrong about the
*Objective*: we are not required to beat 102.31 by the route the reference took.
The Strategy sentence stands as written with this correction beneath it, and
`max_num_seqs` was deliberately left out of Held, which is what made this round
legal to run.
| run-0003 | `max_num_seqs` 4 → 16 | separates "the queue was the cost" from "more slots always help" | d16384 c10, guard d16384 c1 | 668.6 | **139.8 ±0.4%** | 29047 | bench_4363a52d9d21 |

Full cell menu: c1 114.1 ±3.2% (n=7), c2 133.4 ±0.6%, c5 171.5 ±1.9%,
c10 **139.8** ±0.4%. Integrity clean on all four cells (14/14, 60/60, 30/30,
12/12, every request 128 tokens), and **no LOOPING raised on any cell** — so
this arm's c5 is the clean one, where run-0002's carried an inflating loop.

### The two explanations separate, and it was the queue

    arm   mns   running max   waiting max     c1      c2      c5     c10
    0001    4             4             6  107.0   136.3    84.2    49.0
    0002   10            10             4  102.1   137.9   172.0   137.5
    0003   16            10             4  114.1   133.4   171.5   139.8

**`running max` stops at 10 in the 16-slot arm.** The grid never offers more
than ten concurrent requests, so slots eleven through sixteen have nothing to
admit and the engine never uses them. c10 moves 137.5 -> 139.8, a 1.7%
difference against ±1.8% and ±0.4%: noise, not a gain.

So the mechanism is settled. The cost was requests **waiting for a slot**, it is
paid in full once slots reach the offered concurrency, and beyond that the field
is inert on this grid. "More slots always help" is refuted; "the queue was the
cost" is what the data shows.

Consequence for `recipe-new.yaml`: the winning value is the smallest that covers
arena's maximum concurrency, which is **10**. Sixteen buys nothing measurable
here and cannot, because the grid tops out at c10. Preemptions stayed 0 and KV
peaked at 9.2% in this arm, so nothing argues against a larger value either —
the argument for 10 is that it is the value the evidence actually covers.

c1's three readings across the round are 107.0, 102.1, 114.1 — an 11.7% span on
a field that provably does not reach c1 (`running max` is 1 there by
construction). That is the same ±11% reproducibility recorded above, and it is
the clearest demonstration in the experiment that this cell cannot resolve a
change of the size the guard was written to catch.

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
