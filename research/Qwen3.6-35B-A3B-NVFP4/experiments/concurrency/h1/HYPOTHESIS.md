# h1 — our token budget is twice the reference's and starves decode under load

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

## Runs

| run | changed | why | c10 tg | c1 tg | c5 tg | c2 tg | bench |
|-----|---------|-----|--------|-------|-------|-------|-------|
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | 49.0 ±0.3% | 96.0 ±4.1% (n=7) | 84.3 ±0.6% | 136.1 ±1.6% | bench_685e42bde522 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | | | | | |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | | | | | |

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

run-0001 is not h5's number and does not inherit it: h5 ran the full 28-cell
sweep and this is a four-cell screen, so the control must be measured on the
same schedule as the arms it is compared against.

## Conclusion

<pending>
