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
    run-0003   pp 128 · tg 8192 · d0 · c1 · runs 3    64x longer, corroboration

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
| run-0001 | 128 | 7 | the short cell at d0 — the baseline this round needs | | | | |
| run-0002 | 2048 | 7 | 16x longer: is steady state different? | | | | |
| run-0003 | 8192 | 3 | 64x longer, corroboration and drift check | | | | |

## Conclusion

Pending.
