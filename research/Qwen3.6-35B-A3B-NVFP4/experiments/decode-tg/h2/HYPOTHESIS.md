# h2 — the prefix cache never hits, and one flag is why

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**LEVER SPENT** — no flag was disabling the cache; removing our own
`post_run_cmd` reset took the hit rate from 0.0% to 69.2%, and `tg` moved only
2.3%.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | none — arm A | control: confirm 0.0% under the new instrument; hit rate 0.0% | d16384 c1 | 633.9 | 112.3 | 3252.9 | bench_9db1360b8e5e |
| run-0002 | `--kv-cache-dtype` removed — arm B | fp8 KV is the most-cited APC blocker; never run — the premise was refuted by run-0005 | d16384 c1 | | | | |
| run-0003 | `--speculative-config` removed — arm C | MTP verify may bypass the cache path; never run — the premise was refuted by run-0005 | d16384 c1 | | | | |
| run-0004 | `--async-scheduling` removed — arm D | last of the three, and the least likely; never run — the premise was refuted by run-0005 | d16384 c1 | | | | |
| run-0005 | `post_run_cmd` removed | diagnostic: does the cache work at all? hit rate 69.2% | d16384 c1 | 2593.0 | 114.9 | 803.3 | bench (see id.txt) |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

The recipe asks for `--enable-prefix-caching` and the engine reports
`Prefix cache hit rate: 0.0%` on every logger interval of every run we have.
One of `--kv-cache-dtype fp8`, the MTP speculative config, or
`--async-scheduling` is disabling it, and removing that one restores hits.
Mechanism: phase 1 loads a 16400-token context and phase 2 should prefill only
the 2048 tokens that are new, but on run-0008 both ran at ~5700-5900 t/s — the
signature of a full recompute, not a cache hit. This is not a tuning question,
it is a defect.

Worth, if right: phase 2's prefill drops from 18446 tokens to roughly 2048, so
`est_ppt` falls from ~3242 ms toward ~360 ms and `ttfr` with it. It bears on
`tg` only indirectly — decode is not prefill-bound, so if `tg` moves too, that
is a finding in its own right.

## Method

### Variables to test

One flag removed per arm, everything else held:

    arm A   control                      the recipe as it stands
    arm B   --kv-cache-dtype fp8         removed (engine default)
    arm C   --speculative-config         removed
    arm D   --async-scheduling           removed

Order: A, B, C, D, stopping early if an arm restores hits — the question is
which flag, and the first one that answers it ends the round. Each arm is read
on one number that needs no statistics: the maximum `Prefix cache hit rate` the
engine reports during the run.

### Constant for this round

Everything in Held, plus the measurement protocol: `exact_tg`,
`extra_body temperature=0`, `no_adapt_prompt`, the fixed corpus, and
`post_run_cmd` resetting the cache between runs. The reset looks like the
obvious suspect and is not: it fires *after* each execution, while the hit that
fails is *within* one, between phase 1 and phase 2. Removing it would confound
the round with a real change to what we measure, so it stays.

Grid, unchanged from h1:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

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
credits 2048 tokens for work done on 18446.

## Conclusion

**The premise was wrong, and the round is answered without arms B, C or D.** No
flag was disabling the prefix cache — our own `post_run_cmd` was. run-0005
removed the reset and changed nothing else: the hit rate climbed 0.0 → 44.8 →
62.7 → 69.2% across the seven runs. Against arm A, the same cell with the reset
in place, `pp` went 633.9 → 2593.0 (4.1x), `ttfr` 3252.9 → 803.3 ms, `ctx_pp`
3.6x, and `tg` 112.3 → 114.9, +2.3% and inside the spread. As predicted: decode
is not prefill-bound, so a working cache buys latency, not throughput.

**This corrects the board comparison, in our favour.** Arena does not reset
between the three runs of a cell, so their prefill figure is warm and ours was
cold; measured the same way ours is 2593.0. We were never behind on prefill.
The reset stays for this Objective because `tg` is unaffected either way, but no
prefill figure taken under it may sit beside a board number again without saying
so. The round's reasoning is in the memory store — every record carries
`decode-tg/h2` in its `basis`.

## Amendment, 2026-08-25

Everything above stands for the pair it compares. Arm A and run-0005 differ
only by the reset, both carry a pinned corpus, and between those two the reset
is the discriminator. What over-reaches is the sentence "Our own `post_run_cmd`
was" read as *the* cause of every 0.0% in this tree. There are **two**
independent causes and every run in the campaign carries at least one.

The second is **MTP**. Controlled A/B already on disk, same grid
(pp2048 · tg128 · d16384 · c1 · runs 7), no reset in either, only
`--speculative-config` differing:

    decode-tg/h1/run-0001   MTP on    0.0%
    decode-tg/h1/run-0003   MTP off   42.1%  (37.7 -> 39.5 -> 42.1)

42.1% rising is llama-benchy's phase1/phase2 asymptote — 16384 hits over
16384+18432 queries is 47.1% — so a hit needs no repetition at all: each run
serves the context alone, then the context plus prompt. That is why a prompt
redrawn per run (`prompts.py:37`, `np.random.randint`, unseeded) is not the
explanation either, though it does cost the *cross-run* hits that pinning
recovers.

This retires the correction that ran the other way. concurrency h3 read 0.0%
over 527 samples with no reset at all, and that was taken as evidence the reset
account was wrong. It is not wrong; it is incomplete. h3 was MTP-on and
unpinned, so it had both other causes and needed no reset to read zero.

Two consequences beyond this round:

- Board entries that do not run MTP get roughly 47% for free. Ours read 0%
  because of MTP, not because of anything arena does. The claim that arena's
  protocol cannot benefit from prefix caching is false.
- `depth-curve/h1/run-0005` and `run-0006` logged a single hit-rate sample
  each, and the engine's first sample is always 0.0%. They were counted as
  confirmations and carry no information. `measure.py` now withholds the
  verdict below two samples, so they no longer assert.

Unsettled: *why* MTP defeats the within-run hit, given the shared prefix is
present and 2144-aligned either way. One run at this cell — MTP on, pinned
corpus, `VLLM_LOGGING_LEVEL=DEBUG` for per-request `num_cached_tokens` —
separates "phase 1 blocks never committed" from "phase 2 lookup misses". It
buys no `tg`, so it has not been run.

Provenance: source read of llama-benchy `prompts.py`/`runner.py` and sparkrun,
plus re-reading the engine logs of all 31 archived runs. No new benchmark.
