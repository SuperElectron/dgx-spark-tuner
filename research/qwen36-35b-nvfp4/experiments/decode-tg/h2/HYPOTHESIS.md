# h2 — the prefix cache never hits, and one flag is why

## Hypothesis

The recipe asks for `--enable-prefix-caching` and the engine reports
`Prefix cache hit rate: 0.0%` on every logger interval of every run we have.
One of `--kv-cache-dtype fp8`, the MTP speculative config, or
`--async-scheduling` is disabling it, and removing that one restores hits.

This is not a tuning question, it is a defect. llama-benchy's prefix-caching
path exists to pay for the context once: phase 1 loads a 16400-token system
context, phase 2 sends the same context plus a 2048-token user prompt and
should prefill only what is new. Instead phase 2 recomputes all 18446 tokens.
Measured on run-0008: phase 1 `est_ppt` 2779.7 ms for 16400 tokens, phase 2
3242.4 ms for 18446 — both at ~5700-5900 t/s, which is the signature of a full
recompute, not a cache hit.

Worth, if right: phase 2's prefill drops from 18446 tokens to roughly 2048, so
`est_ppt` falls from ~3242 ms toward ~360 ms and `ttfr` with it. That is most
of our apparent prefill deficit against the two vLLM board entries (our 635.4
against their 1414.86 and 1590.66 — and theirs is measured with no reset
between runs, so part of their figure is warm cache we are not getting).

It bears on `tg` only indirectly. Decode is not prefill-bound, so a fix should
move `pp` and `ttfr` hard and leave `tg` roughly where it is. If `tg` moves too,
that is a finding in its own right.

## Method

### Variables to test

One flag removed per arm, everything else held:

    arm A   control                      the recipe as it stands
    arm B   --kv-cache-dtype fp8         removed (engine default)
    arm C   --speculative-config         removed
    arm D   --async-scheduling           removed

Each arm is read on one number that needs no statistics: the maximum
`Prefix cache hit rate` the engine reports during the run. `run.py` now prints
it, and flags the contradiction when the recipe asks for caching and every
sample reads zero.

Order: A, B, C, D. Stop early if an arm restores hits — the question is which
flag, and the first one that answers it ends the round.

### Constant for this round

Everything in Held, plus the measurement protocol: `exact_tg`,
`extra_body temperature=0`, `no_adapt_prompt`, the fixed corpus, and
`post_run_cmd` resetting the cache between runs.

The reset is worth defending here because it looks like the obvious suspect and
is not. It fires *after* each execution (llama-benchy calls it at the end of a
run), while the hit that fails is *within* an execution, between phase 1 and
phase 2. Verified on run-0008: the resets land at 11:30:35, :43, :51, :59 and
so on — one per 8.2-second execution, after both phases. Removing it would
confound the round with a real change to what we measure, so it stays.

Grid, unchanged from h1:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

Arm C removes speculation, which is also run-0003's configuration. That gives a
second reading of a cell we have already measured at a different epoch — useful
in itself, and a check that the epoch has not drifted.

## Decision rule

Stated on the hit rate, which is a fraction the engine reports rather than a
figure we estimate, so no spread applies.

- **Target met** if an arm reports a maximum hit rate above 0% and the control
  reports 0%. The flag removed in that arm is the cause. Record what it cost:
  `pp`, `tg` and `ttfr` all move when these flags come out, and the point of
  the round is the cause, not the arm's throughput.
- **Lever alive** if no arm restores hits but one changes the phase-2 prefill
  token count in `progress.jsonl` — that would mean caching is partly working
  and the reported rate is the wrong instrument.
- **Lever spent** if all four arms read 0.0%. Then it is not one of these three
  flags, and the next suspects are the hybrid architecture itself: 30 of 40
  layers carry a recurrent state rather than a block-structured KV cache, and
  vLLM's own code notes that such groups cannot be reused as freely.

Whatever the outcome, `pp` at every arm is recorded against the true prefill
rate that `run.py` now prints beside it, not against `pp_throughput` — which
credits 2048 tokens for work done on 18446 and would read as a 9x change for a
cache fix that only really removed 16398 tokens of recompute.

## Runs

One row per planned run. Figures blank until it is run.

| run | changed | why | hit % | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|-------|--------|--------|---------|-------|
| run-0001 | none — arm A | control: confirm 0.0% under the new instrument | | | | | |
| run-0002 | `--kv-cache-dtype` removed — arm B | fp8 KV is the most-cited APC blocker | | | | | |
| run-0003 | `--speculative-config` removed — arm C | MTP verify may bypass the cache path | | | | | |
| run-0004 | `--async-scheduling` removed — arm D | last of the three, and the least likely | | | | | |

## Conclusion

Pending.
