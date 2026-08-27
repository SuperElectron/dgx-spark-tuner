# h1 — our token budget is twice the reference's and starves decode under load

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**Lever spent** — c10 falls monotonically as the token budget falls, 49.0 →
48.0 → 44.2, so the hypothesis is refuted with the sign reversed.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c10 | — | 49.0 ±0.3% | — | bench_685e42bde522 |
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c1 | — | 96.0 ±4.1% (n=7) | — | bench_685e42bde522 |
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c5 | — | 84.3 ±0.6% | — | bench_685e42bde522 |
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c2 | — | 136.1 ±1.6% | — | bench_685e42bde522 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c10 | — | 48.0 ±0.6% | — | bench_da8989775690 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c1 | — | 107.2 ±4.1% (n=7) | — | bench_da8989775690 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c5 | — | 80.8 ±0.5% | — | bench_da8989775690 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c2 | — | 131.3 ±2.9% | — | bench_da8989775690 |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | d16384 c10 | — | 44.2 ±0.5% | — | bench_fbb28a3df00f |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | d16384 c1 | — | 106.2 ±2.9% (n=7) | — | bench_fbb28a3df00f |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone — this cell is DAMAGED, do not quote | d16384 c5 | — | 61.3 | — | bench_fbb28a3df00f |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | d16384 c2 | — | 130.5 ±1.6% | — | bench_fbb28a3df00f |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Lowering `max_num_batched_tokens` from 65536 to the reference recipe's 32768
raises `tg` at `d16384 c10` above h5's 48.9, and does not lower `tg` at
`d16384 c1` below 103.7.

The mechanism is scheduler share. With chunked prefill on, each engine step
spends its token budget on whatever the scheduler admits — prefill chunks and
decode tokens compete for the same budget. At c10 the grid presents ten prompts
of 18432 tokens against four slots, so there is always prefill waiting. A
65536-token budget lets one step swallow three and a half whole prompts, and
every decode token in flight waits behind that step. Halving the budget halves
the worst-case time a decode token can be stuck behind prefill.

The measured signature is already on record for this model at this depth:
raising this field makes time-to-first-response worse at *every* concurrency
tested — +7.3% (c2), +15.6% (c4), +19.8% (c5), +32.4% (c16) — attributed to a
larger budget batching more prefill together so each first token competes with
more peers. h5's c10 ttfr at this cell was 20963.9 ms. We are running the
setting that memory says costs latency, at twice the reference's value, and the
board entry that beats us by 2.1x runs the lower one.

Worth, if right: the c10 deficit is 53.4 t/s and this is the largest single
field difference remaining between our recipe and the reference. It cannot be
worth the *whole* gap on its own — the reference also differs in
`gpu_memory_utilization`, sampling and the chat template — but the arithmetic
does not need it to be. Per-sequence, their four slots produce 25.6 t/s against
our 12.2; recovering the scheduling share that memory prices at 15-32% of
first-token latency is the only one of the four fields with a mechanism that
acts on *aggregate decode under queueing*, which is exactly what c10 measures.

The honest case against: the same memory entry calls a larger budget "good for
aggregate throughput, bad for latency". The board scores `tg`, not ttft. If
that trade holds at c10 the sign flips and this round loses — which is why it
is worth one screen rather than an argument.

## Method

### Variables to test

    max_num_batched_tokens: 65536 (control) -> 32768 -> 16384

16384 is included because the mechanism, if real, should be monotone over the
range that still admits one 18432-token prompt in two chunks. A non-monotone
result means the mechanism is not what is moving the number.

### Constant for this round

Everything else in the experiment's `recipe.yaml`, byte for byte:
`max_model_len 262144`, `gpu_memory_utilization 0.8`, `max_num_seqs 4`, the
same serve command, the same sampling (the checkpoint's own), MTP depth 3 on
triton. **`max_num_seqs` does not move in this round** — the reference serves 4
as we do, so it is not a candidate explanation for this gap, and moving two
scheduler fields at once would confound both.

### The screen, and what it cannot do

This round runs a **reduced schedule** — `d16384` only, at c1, c10, c5, c2, in
that order. That order is arena's own relative order for the d16384 cells
(indices 13, 17, 20, 23 of 28), so the cells stay in their board sequence
relative to each other even though the sweep around them is gone.

    schedule:
      - { depth: 16384, concurrency: 1,  runs: 7 }
      - { depth: 16384, concurrency: 10, runs: 3 }
      - { depth: 16384, concurrency: 5,  runs: 3 }
      - { depth: 16384, concurrency: 2,  runs: 3 }

`runs: 7` at c1 and `runs: 3` elsewhere is not arbitrary. Acceptance bimodality
on this model is per-sequence: inside one c4 run individual request rates span
5.4x while the four-sequence average holds sigma under 1.5%, so c4-and-above
reach ±1.5% in about three runs where c1 needs seven or more to rank anything.
c1 is the guard and the guard is the noisy cell, so it buys the repeats.

**These figures are not board-comparable and cannot close the experiment.**
Cell order decides what is warm and what is hot; twelve cells of arena's sweep
precede `d16384 c1` in the real grid and none of them run here. The screen
compares arms to each other, which is valid because all three arms run the
identical schedule. A number from it must never be set beside 102.31.

### What is ruled out before it is proposed

- **Acceptance.** It does not move between c4 and c5 while throughput drops
  14.4%, and it has been flat under scheduler knobs for five consecutive
  rounds. If this round moves `tg`, the explanation is scheduling. Capture
  acceptance from the engine log anyway — as a control that it did *not* move,
  not as a candidate.
- **Prefix cache.** 0.0% across 374+ samples and confirmed again in h5 under
  arena's own protocol. Every arm here is cold-cache and no arm may claim
  otherwise.
- **KV capacity.** 9.8% peak in h5 with zero preemptions. Lowering the token
  budget does not touch it.

### Pre-registered non-findings

- **c5 pads to the 24-token CUDA-graph bucket** at `max_num_seqs 4`, wasting
  ~20% of decode slots. Expect c5 slightly below trend in every arm. Not a
  finding, and not evidence about this field.
- `max_num_batched_tokens` is **not in the torch.compile hash**, so changing it
  costs a graph recapture of a few seconds, not a recompile. An arm that takes
  dramatically longer to become ready has a different problem.
- Peak activation was profiled at 65536. The two lower arms profile lower and
  should show *more* free KV, not less.

## Decision rule

Read `d16384 c10` and `d16384 c1`, aggregate `tg` medians, from each arm.

Sized against h5's measured scatter at these cells: ±0.5% at c10 and ±5.2% at
c1 on the arena grid, at n=3. At `runs: 3` the c10 standard error is small
enough that a 5% move is many multiples of it; at `runs: 7` the c1 guard is
read against its own ±0.9% from depth-curve, and the floor is set at one
scatter width below the control rather than at the bare 103.7.

- **Target met** — c10 exceeds 102.31 *and* c1 holds at or above 102.8. Then
  the field carries the whole gap on its own, which would be surprising; go
  straight to a full 28-cell arena run to earn the board-comparable figure.
- **Lever alive** — c10 rises more than 5% over the control and c1 holds at or
  above 102.8, but c10 is still below 102.31. The mechanism is real and
  partially spent; the remaining reference diffs are worth taking next, and
  this field's best value carries forward.
- **Lever spent** — c10 moves less than 5% either way, or it rises while c1
  falls below 102.8. In the second case the field is a genuine trade rather
  than a free win, the guard governs, and the control value stands.

The rule reads **aggregate** `tg`, which is what the board scores. Per-request
`tg/req` carries iqr up to 141.6% at these cells and no branch above may be
evaluated on it.

Three values per arm at c10 means no interquartile range; the rule is stated on
medians and a 5% threshold for exactly that reason, and this is said before the
numbers exist rather than after.

## Conclusion

run-0003's c5 cell is damaged and its 61.3 must not be quoted. Verified in the
archive: request 27 returned **1 token in 0.0 s** and the cell logged 29
first-token events against 30 request-ends, which is also the source of that
cell's 817.9 t/s `pp` outlier against 580. The c10 trend does not depend on it.
(Recorded 2026-08-24, after the round's own conclusion pass caught it.)

Epoch, recorded per arm because the recipe names a floating tag: image
`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:latest`, which resolves today to
image id `b277afb7c08f`, digest `sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990`
— byte-identical to the `:2026082102` tag h5 ran, so this is h5's epoch and not
a new one. If a later arm records a different digest, the arms straddle an epoch
break and are not comparable. Pinning the recipe by digest is a hygiene item.

Prefix cache hit rate 0.0%, as everywhere.

**The screen validates at the cells it was built for.** Against h5's full 28-cell
sweep: c10 49.0 vs 48.9, c5 84.3 vs 84.2. Two independent schedules agree to
0.2% at the primary cell, so the reduced schedule is a sound instrument for
comparing arms at high concurrency.

**c1 does not, and the decision rule is mis-specified because of it.** The
control reads 96.0 where h5 read 103.7. The rule's guard is stated as "c1 holds
at or above 102.8", a floor derived from h5's number — so the control itself
fails its own guard and no arm can pass it as written. That is an inconsistency
inside this document: the Runs section says run-0001 does not inherit h5's
figure, and the rule then set the guard from h5's figure anyway. The rule is
left exactly as written; the round is concluded against it and the defect
reported, not edited away. The reading the guard was *intended* to carry is
"c1 must not regress against this round's own control, 96.0", and both readings
should be reported.

The 7.4% between 96.0 and 103.7 is itself a finding rather than noise to
explain away: identical recipe, identical cell, different position in the
schedule — cold and alone here, mid-sweep at index 13 there. That is the
thermal-and-warm-cache effect h5 was built to measure and could not, because
the cache never engaged. With the cache at 0.0% in both, whatever separates
them is not cache.

### run-0002, and the hypothesis inverting

    arm        mnbt      c1      c2     c5     c10
    run-0001  65536    96.0   136.1   84.3    49.0
    run-0002  32768   107.2   131.3   80.8    48.0

**The primary cell does not move.** c10 reads 48.0 against the control's 49.0 —
a 2.0% *decrease*, well inside the rule's 5% threshold and in the wrong
direction. Halving the token budget did not free decode under queueing. c5 and
c2 drift the same way, -4.2% and -3.5%. run-0002's c10 additionally carries
2 of 60 requests LOOPING, which run.py flags as decoding faster and inflating
`tg`, so 48.0 is if anything generous. The mechanism argued in the Hypothesis —
prefill hogging the step budget, halved budget halving the wait — is not what
governs this cell.

`running max 4, waiting max 6, kv max 3.6%, preemptions 0` in both arms: the
queue is real, the capacity is not the limit, and the budget does not change
either.

**The guard cell moves instead, and upward.** c1 reads 107.2 against 96.0,
+11.7%, on n=7 both sides. This was not predicted and it contradicts the
memory this round was built on, which records the field as INERT at c1 —
+0.27% (0.07 SE) across 8192 -> 65536, a range that contains this change.

Not claimed as established. c1 is this screen's noisy cell (iqr 14.1% and
10.4%, ±4.1% each), so the SE of the difference is about 5.8% and 11.7% is
roughly 2 SE. run-0003 at 16384 is the discriminator: monotone continuation
says the effect is real, a fall back to ~96 says it was scatter. Whichever it
is, it is a finding about the *guard*, and the Objective's primary is
unmoved — a round can be interesting and still spend its lever.

### run-0003, and the direction settled

    mnbt      c1      c2     c5     c10
    65536   96.0   136.1   84.3    49.0
    32768  107.2   131.3   80.8    48.0
    16384  106.2   130.5   61.3    44.2

**c10 is monotone, and the hypothesis had the sign backwards.** 49.0 -> 48.0
-> 44.2, a 9.8% loss at the lowest arm. Lowering the token budget does not free
decode under queueing; it costs it. c5 falls harder, 84.3 -> 61.3. The control
is the best arm for the primary cell, so `max_num_batched_tokens` 65536 is
already the better setting of the three for what this experiment is chasing,
and the reference recipe's 32768 is not the source of its c10 advantage.

Refuted, not merely unproven — a monotone response in the opposite direction is
a stronger result than no response, and it says the prefill-hogs-the-budget
mechanism is not what governs this cell. It also carries a forward implication:
if c10 rises with the budget over the range measured, the untested direction is
*upward* from 65536, which no arm here reached.

**c1 reads as a step, not a slope.** 96.0 at 65536; 107.2 and 106.2 at the two
lower arms, agreeing within 1%. Two independent arms agreeing is better evidence
than run-0002's lone 2-SE difference, so something real separates 65536 from
the values below it at c1.

**A confound that must be resolved before that c1 number is used.** run-0003's
seven c1 values in execution order are

    95.5  102.0  101.2  106.2  108.8  111.6  114.1

which drifts upward across the cell, lowest first and highest last — a 19%
span. run-0001's c1 drifts the same way, roughly 90 to 108. These are not
stationary measurements: the cell is warming up while it is being measured, and
`runs: 7` at c1 was chosen to beat scatter, not drift. Part of the 96-vs-107
gap may be where each arm's c1 cell sat in its own warm-up rather than the
field under test, and c1 runs FIRST in this schedule, so it is the cell most
exposed to a cold start. Any later round resting on c1 must handle this —
discard a warm-up run, or read the second half of the series, or run c1 last.

Two further observations from the arms:

- `waiting max` rises as the budget falls: 6, 6, 8. Consistent with smaller
  batches admitting less work per step.
- c10 carried LOOPING requests in every arm (0, 2/60, 1/60), which run.py says
  decode faster and inflate `tg`. The arm with the most looping is the middle
  one, so this does not explain the monotone trend.

run-0001 is not h5's number and does not inherit it: h5 ran the full 28-cell
sweep and this is a four-cell screen, so the control must be measured on the
same schedule as the arms it is compared against.

**Lever spent. The hypothesis is refuted with the sign reversed.**

`max_num_batched_tokens` was moved 65536 → 32768 → 16384, one field, nothing
else, on one reduced schedule (`d16384` at c1, c10, c5, c2; `runs` 7/3/3/3).

The three arms are valid and comparable. Each engine's `non-default args:`
matches its recipe's `defaults:` field for field — 65536/32768/16384 with
`max_model_len 262144`, `gpu_memory_utilization 0.8`, `max_num_seqs 4` in all
three. All three ran vLLM `0.27.2rc1.dev360+ge85d1b69c.d20260821` on image
digest `sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990`
with flashinfer `4927c0e1`, so no epoch break separates them. The three recipe
hashes differ and the recipes are byte-identical apart from the one field, so
each arm tested something. `crash_count 0` and `failed_indices []` throughout.

### Against the decision rule as written

    branch          requires                                  reads
    target met      c10 > 102.31 and c1 >= 102.8              c10 max is 49.0 — no
    lever alive     c10 rises > 5% and c1 >= 102.8            c10 never rises — no
    lever spent     c10 moves < 5% either way, or rises
                    while c1 falls below 102.8                yes, via the 32768 arm

The 32768 arm reads c10 48.0 against the control's 49.0, −2.0%, inside the 5%
threshold in the wrong direction: **lever spent**. The 16384 arm's −9.8% is
outside every clause verbatim — the rule wrote no branch for a large *fall* —
but both other branches require a rise, so nothing else can fire, and a lever
that only moves the primary downward is spent by any reading.

**The rule is mis-specified, and it is recorded rather than repaired.** Its
guard, "c1 at or above 102.8", is one scatter width below decode-tg h5's 103.7,
a figure measured on the full 28-cell grid. This screen's own control reads
96.0. The control therefore fails its own guard, and no arm could have reached
*target met* or *lever alive* whatever c10 had done — the rule could only ever
return *lever spent*. It is left exactly as written.

**The reading the guard was intended to carry** is that c1 must not regress
against this round's own control of 96.0. Under that reading the guard holds
comfortably: both lower arms sit *above* the control, 107.2 (+11.7%) and 106.2
(+10.6%). The outcome is unchanged — **lever spent under both readings**,
because the primary cell never rose under either.

### What the primary cell says

    mnbt      c1      c2     c5     c10      c10 per-request decode median
    65536   96.0   136.1   84.3    49.0      28.5 tok/s
    32768  107.2   131.3   80.8    48.0      20.2 tok/s
    16384  106.2   130.5   61.3    44.2      19.7 tok/s

c10 is monotone downward as the budget falls, 49.0 → 48.0 → 44.2, and the
per-request decode *medians* fall the same way and harder, 28.5 → 20.2 → 19.7.
Aggregate `tg` is an arithmetic mean of a rate and overweights fast samples; the
medians of the underlying per-request values agree with it on direction, so the
result does not rest on the mean's shape. c5 falls further still, 84.3 → 61.3.
The control is the best arm at the primary cell, so 65536 is already the better
of the three settings for what this experiment chases, and the reference
recipe's 32768 is not the source of its c10 advantage.

This refutes the hypothesis rather than failing to support it. The mechanism
argued for prefill hogging the step budget and a halved budget halving the
decode wait; the budget was halved twice and decode got *worse* twice, monotone,
with the c10 arms internally tight (±0.3%, ±0.6%, ±0.5% at n=3). It agrees
instead with what memory already held about this field — that a larger budget is
"good for aggregate throughput, bad for latency". This round read the latency
half of that entry and predicted the throughput half would follow it. It does
not.

**The LOOPING requests do not rescue the arms below the control.** Recomputed
from the archives: 0/60, 2/60 (requests 13, 15) and 1/60 (request 48) at c10 for
65536, 32768 and 16384. `measure.py` flags these as decoding faster and
inflating `tg`. The arm with *zero* looping is the one that wins, so the bias
runs against the two losing arms — de-biasing 48.0 and 44.2 would push them
lower and steepen the trend, not flatten it. That is a stronger argument than
"the middle arm loops most so it cannot produce a monotone trend", which is also
true but only rules out a monotone confound.

**Forward implication.** If c10 rises with the budget across every value
measured, the untested direction is *upward* from 65536, which no arm reached.
The step sizes say not to chase it: +8.6% for 16384 → 32768, +2.1% for 32768 →
65536. The response is decelerating hard, so the next doubling extrapolates to
about +1%, roughly 49.0 → 49.5, against an Objective that needs 102.31 — a
2.1x. Memory also already records this model measured at `max_num_batched_tokens`
98304 with nothing remarkable to show for it. The lever is spent in both
directions, not merely in the one tested.

### The c1 step does not survive its confound

The 96.0 → 107.2 → 106.2 step at the guard cell is **not established**, and no
later round may rest on it.

Three things stand against it. First, the cell is not stationary: run-0003's
seven c1 values in execution order are 95.5, 102.0, 101.2, 106.2, 108.8, 111.6,
114.1 — a 19% upward span with no reversal — and run-0001's drift the same way,
88.7 to 108.4. c1 runs first in this schedule and is the cell most exposed to a
cold start. The within-cell span, ~19-20 t/s, is larger than the ~11 t/s
between-arm step it is being asked to support.

Second, the drift is not even consistent in direction: run-0002's c1 drifts
*downward* across its seven runs (median of the first three 117.1, of the last
three 107.2). A cell that warms up would warm up in every arm. And in run-0001
the `tg128` and `ctx_tg` phases anti-correlate at −0.88 across the seven runs —
`tg128` climbing 88.7 → 108.4 while `ctx_tg` falls 105.4 → 91.5 — which reads as
work being attributed between the two phases run to run rather than as the
machine getting faster. Memory independently holds that c1's ~14% scatter on
this model is per-sequence MTP acceptance bimodality and is "not thermal and not
clock-related", which is consistent with a bimodal draw landing in an order that
looks like a ramp.

Third, memory records this exact field as **inert at c1**: 8192 → 65536 moved
`tg128 d16384 c1` by +0.27% (0.07 SE) at n=7, a range that *contains* this
round's change. Against that, the step here is +11.7% and +10.6% at roughly 2.0
and 2.1 SE of the difference — marginal individually. Two arms agreeing with
each other is better evidence than one 2-SE difference, which is why the step is
called unresolved rather than absent; but a 2-SE result that contradicts a
direct n=7 null, measured in a cell whose own drift exceeds the effect, is not a
finding.

The archives name the likely mechanical culprit: triton JIT compilation fires
*inside* the measurement window, nine kernels during c1's first run in run-0001
and eight in run-0003, with two more landing inside c10's first run in both.
vLLM's own log says this causes a latency spike and warmup should be extended.
Only the c1 cell ran a per-test warmup and the coherence test; c10, c5 and c2
ran with `--skip-coherence` and no per-test warmup, so the cells are not warmed
alike.

**What a later round resting on c1 must do**: extend warmup to cover these
shapes, or discard the first run of the cell, or read the second-half median
alongside the full one — and report which. Simply raising `runs` does not help,
because the problem is drift, not scatter.

### The box, and the rest of the round

Nothing in the machine's state qualifies these figures. Over the benchmark
windows only, GPU utilisation was sustained (median 96%, dipping to zero only in
the inter-cell gaps), clocks held 2392-2411 MHz with no frame in the 400-900 MHz
power-delivery fault band, GPU temperature peaked at 76 C, and swap did not grow
in any arm (768 → 767, 781 → 779, 784 → 783 MB). Host memory fell to a 6949 MB
low-water mark in run-0001, which is worth watching but is not scarcity. The
clock telemetry reports only two or three distinct values per run and no
throttle field exists in this box's schema, so throttling can only be inferred
from the clock, and the clock shows none.

Other observations from the arms:

- **KV capacity is not close to binding and neither is the queue's cause.**
  `running max 4` in every arm — pinned at `max_num_seqs` — with `waiting max`
  6, 6, 8 rising as the budget falls, `kv max` 3.9%, 3.6%, 3.1%, and zero
  preemptions anywhere. The engine reports maximum concurrency of 19.3x at the
  full 262144-token window, and this grid asks for 18432.
- **The reported aggregate at c10 is dominated by queueing, not by decode
  rate.** In the control, aggregate `tg` falls 97.9 → 136.8 → 84.7 → 49.1 across
  c1, c2, c5, c10 while aggregate *peak* throughput rises monotonically 106 →
  174 → 297 → 316. The mean-to-peak gap widens from 1.09x at c1 to 6.4x at c10.
  With four slots serving ten requests, six wait at the peaks, and the wall-clock
  window the aggregate divides by is mostly serialized prefill and queueing.
  That is the single most useful thing this round measured, and it is what h2
  goes after.
- **Prefix cache hit rate 0.0%** over 44 samples in each of the three arms, with
  `measure.py` flagging the recipe as asking for caching. Every figure here is a
  cold-cache figure. Standing defect, not this round's to fix.
- **MTP acceptance is flat, as a control and not a candidate**: mean acceptance
  length 3.07, 2.9-3.2 and 3.15 across the three arms, draft acceptance ~69% in
  each. It did not move with the token budget, for the sixth consecutive round.
- **run-0003's c5 cell is damaged** and its 61.3 should carry an asterisk: one
  request in c5 run 3 returned a single token with no first-token event, which
  also cost `e2e_ttft` a sample and produced that run's 817.9 t/s `pp` outlier
  against 580.4 and 580.0. c5 is a pre-registered non-finding in this round
  anyway, but the c5 column should not be quoted from this arm.

### Was it worth running

It settled a question rather than moving the Objective, and it was worth one
screen for that. It closes the largest single field difference between our
recipe and the reference in both directions, retires the prefill-share account
of the c10 gap, and it hands the next round a measured mechanism — four slots,
six waiting, zero preemptions, 3.9% KV, and a 6.4x mean-to-peak gap — that the
Objective's arithmetic can actually be argued from. The control's 65536 stands;
`recipe.yaml` is untouched.
