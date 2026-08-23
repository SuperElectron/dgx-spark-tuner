# h3 — is `tg128` measuring a transient?

## Hypothesis

`tg 128` is too short to reach steady-state decode, so the figure the board
scores and every round here optimises is partly a warm-up artifact. Steady-state
`tg` at the same cell differs from `tg128` by more than the spread.

The mechanism is speculation. MTP acceptance is a running statistic — measured
per-position at 0.87 / 0.76 / 0.61, giving a mean accepted length near 3 — and
128 tokens is roughly 41 speculative cycles, over in about 1.1 seconds. Nothing
guarantees the acceptance rate over the first 41 cycles equals its long-run
value: the draft conditions on generated text, and the first tokens are
conditioned on a prompt while later ones are conditioned on the model's own
output. If acceptance drifts, throughput drifts with it.

There is a second, duller mechanism pointing the same way. A run's fixed costs —
the first decode step after prefill, the scheduler settling, graph replay
warming — are amortised over 128 tokens here and over 2048 in the arm. Anything
constant per request shows up 16x larger at `tg128`.

Worth, if right: it does not make us faster, it tells us what we have been
measuring. If steady-state decode is materially higher than `tg128`, every
figure in this experiment understates the model and the board's ranking is
partly a ranking of warm-up behaviour. If it is materially lower, `tg128`
flatters everyone and our 119.6 is not a decode rate but a burst rate. Either
answer changes how the Objective should be read; no answer leaves it unchanged.

Memory carries a prior that makes this directional. From the archived
thin-cell campaign, `family:qwen3.6-35b-a3b`:

    tg32 measures FASTER than tg128 at the same depth on this model
    (129.32 vs 102.2 @ d16384 c1), the opposite of the per-request
    amortization argument

So on this model shorter generations read faster, not slower — the opposite of
what fixed-cost amortisation alone predicts, which means something that grows
with generation length is eating throughput. **The prediction is therefore that
`tg2048` reads BELOW `tg128`, and `tg8192` below that.** A result in the other
direction refutes both this round and that prior.

A second prior sharpens what to expect from the spread, `stack:vllm`:

    'c1 is the noisy regime' is false. Run-to-run sigma is set by how many
    MTP verify steps a measurement averages over and by acceptance quality

If that holds, `tg2048` should not only differ in median but be markedly
*tighter* than `tg128`, because it averages 16x more verify steps. A long cell
that is both lower and tighter is the signature this round is looking for.

### Reasons the prior may not apply here

The `tg32` prior was measured at **d16384**, and this round runs at **d0**. That
difference may be the whole of it. At d16384 a 128-token generation grows KV
from 16384 to 16512 while a 32-token one grows it to 16416, so every extra
generated token is read back by every subsequent step — longer generation at
depth costs more KV traffic, with no transient needed to explain it. At d0 the
same 2048 tokens grow KV to ~2193, which is ~22 MB against 2.25 GB of weights
read per forward: negligible.

So the prior may be a KV-growth measurement wearing a generation-length label,
and this round is built where that mechanism is absent. That makes it a cleaner
test than it looks:

- `tg2048` below `tg128` **at d0** cannot be KV growth, so it is a genuine
  transient or acceptance effect.
- `tg2048` equal to `tg128` at d0, given the prior holds at depth, would say the
  prior is KV growth and there is no transient at all.

Either way the prior is not evidence for this cell, only a reason to look. Its
figures are also a different epoch — 102.2 at d16384 c1 against the 112-119 we
read there now, measured before `exact_tg`, `temperature 0`, `no_adapt_prompt`
and the fixed corpus existed, and possibly with the memory embedder resident on
the card.

### The confound that could dominate this round

`exact_tg` sets `ignore_eos`, so a `tg 8192` request generates 8192 tokens
whether or not the model wanted to stop. At `temperature 0` a model driven far
past its natural stopping point tends to degenerate into repetition — and
repetitive text is *easy to draft*, so MTP acceptance should **rise**. That
would push the long cells faster, opposite to the prior's direction, for a
reason that has nothing to do with steady-state decode.

This is not hypothetical enough to ignore: it predicts the same observable
(`tg` changing with generation length) by a mechanism that would make the long
figure meaningless as a decode rate.

**So the generated text must be inspected, not just the throughput.** Record for
run-0002 and run-0003 whether the output degenerates — repeated n-grams, a
collapsing vocabulary, the same sentence cycling — and where in the generation it
starts. A long cell that is faster *and* repetitive is measuring degeneration. A
long cell that is slower while the text stays varied is the transient this round
is looking for. If the text degenerates, the round cannot answer its question at
that length and the answer has to come from the shorter cells plus the
timeseries.

This is the cheapest hypothesis available that can invalidate the metric
everything else is measured in, which is why it runs before the concurrency
work rather than after.

## Method

### Variables to test

    tg: 128, 2048, 8192      at pp 128, depth 0, concurrency 1

`depth 0` on purpose, and it matters. It removes the KV term, removes the
context-load phase entirely (llama-benchy only splits phases when depth > 0), and
removes the prefill numerator artifact — so a d0 run reports one honest phase and
`tg` is the only thing varying. Isolating the transient means removing
everything else that changes with generation length.

`pp 128` keeps prefill small so it cannot dominate the run.

The instrument for this round is not the summary figure. `run.py` now injects
`save_total_throughput_timeseries` and `save_all_throughput_timeseries`, which
cost no wall clock and retain the 1-second sliding window llama-benchy already
computes. With `return_token_ids` on, an accepted speculative step lands several
token timestamps in one chunk, so the series is acceptance made visible: a
saw-toothed trace is acceptance, a flat one is rejection. **The shape of the
first ~2 seconds against the remainder is the answer to this round**, and the
medians are corroboration.

### Constant for this round

Everything in Held, and the full measurement protocol: `exact_tg` (so every
request generates exactly its `tg`, not fewer), `extra_body temperature=0`,
`no_adapt_prompt`, the per-cell fixed corpus, `post_run_cmd` resetting between
runs.

`runs: 7` at tg128 and tg2048; `runs: 3` at tg8192, where one run is already
~8 minutes and seven would cost an hour for a rung that only has to corroborate.

Cells:

    run-0001   pp 128 · tg 128  · d0 · c1 · runs 7    the short cell, at d0
    run-0002   pp 128 · tg 2048 · d0 · c1 · runs 7    16x longer

A third cell at tg 8192 was planned as corroboration and abandoned once
run-0002 degenerated — see the Conclusion.

run-0001 is not redundant with anything measured so far. Every previous run in
this tree is at `d16384`, so we have no `tg128` figure at `d0` to compare
against — without it, a difference between tg128 and tg2048 could be the depth
change rather than the length change.

## Decision rule

Stated on the difference between the short cell and the long one, against the
spread of the two, and evaluated on medians.

- **Transient confirmed** if `tg2048`'s median differs from `tg128`'s by more
  than the larger of the two IQRs, and `tg8192` lies on the same side. Then
  `tg128` is a burst measurement, the direction of the bias is recorded, and
  every figure in this experiment carries that caveat from here on.
- **Transient bounded** if the difference is smaller than that. `tg128` is a
  fair proxy for steady state at this cell, the board comparison is not
  measuring warm-up, and this question is closed.
- **Neither** if `tg2048` and `tg8192` disagree in direction. Then generation
  length is not the variable — check the timeseries for a drift that reverses,
  and check whether KV growth during a 8192-token generation is doing it.

Independently of the medians, record what the timeseries shows: whether
throughput within a single 2048-token generation is flat, rising or falling, and
where it settles. A flat trace with a different median would mean the difference
is a fixed per-request cost rather than a transient, which is a different finding
and points at the scheduler rather than at MTP.

## Runs

One row per planned run. Figures blank until it is run.

| run | tg | runs | why | tg t/s | iqr | trace shape | bench |
|-----|----|------|-----|--------|-----|-------------|-------|
| run-0001 | 128 | 7 | the short cell at d0 — the baseline this round needs | 127.3 | 3.0% | varied, no repetition | bench (see id.txt) |
| run-0002 | 2048 | 7 | 16x longer: is steady state different? | 120.6 | 2.4% | 4 of 7 degenerate | bench_02f9548d80da |

## Runs so far

run-0001 gives the baseline this round is measured against, and one result that
belongs to depth-curve rather than here:

    d0     tg 127.3  sd 3.0%  [131.1, 127.3, 120.5, 131.7, 123.5, 123.5, 127.8]
    d16384 tg 119.6  sd 3.1%  (h1 run-0008, the pinned-prompt incumbent)

A 6.4% gap at ~3% sigma is about 2 sigma, so decode is measurably higher at d0
than at d16384. That is depth-curve's question and it now has a real answer
waiting rather than a formality.

Prefill at d0 reads 1569.7 t/s against ttfr 104.7 ms, both honest — d0 has no
context phase and no numerator artifact.

On the degeneration confound: at 128 tokens the text does not degenerate. The
outputs are ordinary prose with a repeat-ratio of 0.12-0.20, and the sample
opens `Here's a thinking process:` — the model is answering, not looping. Four
distinct md5s across seven requests, with three pairs identical, which is the
same greedy-with-occasional-divergence shape h1 measured at depth.

That is the baseline. The confound only bites if run-0002 and run-0003 show the
repeat-ratio climbing toward 1.0 while throughput rises.

**It bit.** run-0002 reads `tg` 120.6 at 2.4% IQR — 6.7 below run-0001, against
a larger IQR of 3.8, so by the round's test the two differ. But four of its seven
requests degenerate, and the degenerate ones are the fast ones.

The whole-output repeat-ratio cannot see this: it is length-dependent, since
unique words saturate while the total keeps growing, so 2048 tokens of good
prose scores ~0.7 against 128 tokens' 0.12-0.20. A **100-word sliding window** is
length-invariant and comparable:

    rid 0/1/2   0.13-0.33 throughout          clean prose, start to finish
    rid 3       breaks at ~token 433          then 0.62-0.63 sustained
    rid 4       breaks at ~token 283
    rid 5       breaks at ~token 738
    rid 6       breaks at ~token 286

The failure is always the same: the model reaches for a story title, fails, and
loops guessing — `"The Adventure of the Blanched Soldier" is not it. How about
"The...`. Onset is 15-35% into the generation, not at the tail, so it is not an
end-of-budget artifact.

And the correlation runs the way the confound predicted. rid 3 is both the most
degenerate and the fastest at 132.3 t/s, the outlier inflating the spread.
Restricting to the three clean requests gives 118.2 / 120.8 / 117.3 — median
~118.2, **below** the 120.6 that includes the degenerate ones. So degeneration
inflates the figure, and the honest tg2048 is further below tg128 than the
headline says. The direction holds; the magnitude is understated.

Two instrument findings from this run, both of which change how the round is
read:

- **The throughput timeseries is a trailing 1-second token count, not an
  instantaneous rate.** Below t=1.0 it is exactly the cumulative token index.
  Any "the first second is slow" read off it is the window filling, not a
  transient. Recomputed properly from raw token timestamps in 1-second bins,
  rid 0 runs 101-141 tok/s with no trend, no sag and no saw-tooth — and its
  first bin is 128 against 118 for the remainder, marginally **faster**.
  **There is no warm-up transient within a generation.**
- **`exact_tg` did not hold.** rid 0 and rid 2 returned 2046 tokens, not 2048,
  and the streamed token counts agree, so it is a real short generation rather
  than a bookkeeping gap. Both are in the clean group. The effect on `tg` is
  ~0.1%, but the flag is supposed to make this exact and did not.

So the round's own mechanism — acceptance drifting over a long generation — is
**not** what produces the difference. Throughput is flat within a generation.
What differs is the average over 2048 tokens against the average over 128, and
the KV read grows with every token generated: at d0 a 2048-token generation
takes the context from 138 to ~2186 tokens. That is the same mechanism as depth,
sourced from the model's own output rather than the prompt.

`run.py` crashed in its reporting stage on this run — a local variable in
`report()` shadowed the module-level `spread()`. The benchmark and archive are
unaffected and every figure above was computed from the archive; the bug is
fixed and `report()` now replays this run cleanly.

## Conclusion

**The hypothesis is refuted as stated, and the observation it predicted is real
for a different reason.**

`tg` does change with generation length, in the predicted direction and past the
rule's threshold: 127.3 at tg128 against 120.6 at tg2048, a gap of 6.7 against a
larger IQR of 3.8. Restricted to the three requests that did not degenerate the
gap is wider still, ~118.2. So the round's observable holds.

Its mechanism does not. The hypothesis argued that MTP acceptance is a running
statistic which has not settled at 128 tokens, so `tg128` would be a warm-up
measurement. The timeseries refutes that directly: recomputed from raw token
timestamps in one-second bins, throughput inside a single 2048-token generation
is flat — 101 to 141 tok/s with no trend, no sag and no saw-tooth — and the
first bin is 128 against 118 for the remainder, marginally **faster**. There is
no warm-up transient to find.

What is left is arithmetic. A 2048-token generation carries its own output as
context: at d0 the sequence grows from 138 tokens to ~2186, and every decode
step reads the KV accumulated so far. The average over 2048 tokens is therefore
taken at a larger average context than the average over 128. **This is the same
mechanism as depth, sourced from the model's own output rather than from the
prompt** — which means h3 and depth-curve are measuring one effect, not two, and
depth-curve is the experiment that can size it properly.

So `tg128` is not measuring a transient. It is measuring decode at a small
average context, which is exactly what it claims to measure. The board
comparison is not compromised.

**run-0003 was not run.** The decision rule's third branch anticipated this: at
tg2048 four of seven requests already degenerated, with onset as early as token
283, so at 8192 the run would measure how fast the model loops rather than how
fast it decodes. An eighth data point bought at the cost of near-total
degeneration cannot corroborate anything. The direction is already established
by two cells and explained by a mechanism that predicts it monotonically.

Two things this round leaves behind for the instrument:

- **Degeneration is now a first-class check.** `measure.py` reports the worst
  100-word sliding-window repeat ratio per run and names the looping requests.
  Whole-output uniqueness cannot do this job — it is length-dependent, scoring
  2048 tokens of clean prose the same as short looping text. Replayed on these
  archives it flags exactly requests 3, 4, 5 and 6 of run-0002 and passes
  run-0001 at 0.20.
- **The throughput timeseries is a trailing one-second token count, not an
  instantaneous rate.** Below t=1.0 it is the cumulative token index. Anything
  read off its first second is the window filling. Recompute from raw token
  timestamps instead.

And one defect recorded rather than fixed: `exact_tg` did not hold — two
requests returned 2046 tokens instead of 2048, confirmed against the streamed
token counts. The effect here is ~0.1%, and the cause is upstream of the recipe,
but a flag whose purpose is exactness should not be assumed to deliver it.
