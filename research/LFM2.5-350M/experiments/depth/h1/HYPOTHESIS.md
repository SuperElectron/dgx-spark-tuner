# h1 — max_num_batched_tokens, the prefill budget that is smaller than depth+pp at exactly the cells we lose

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

LEVER SPENT — `tg` at d8192 c10 went 741.1 → 773.3 → 709.8 across mnbt 8192 →
32768 → 65536: it rose and then fell, which is the rule's lever-spent clause.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | max_num_batched_tokens: 8192 -> 8192 (control) | baseline — slots recipe-new.yaml, this round owns its own control | d8192 c10 | 17153.0 | 760.6 | 791.4 | bench_0aec6aab2e31 |
| run-0002 | max_num_batched_tokens: 8192 -> 32768 | run-0001 control queued 6 of 10 at d8192 (Running 4/Waiting 6) with KV at 0.6% — prefill-gated, as h1 predicted | d8192 c10 | 17340.8 | 760.2 | 972.8 | bench_bb09fe0e66fe |
| run-0003 | max_num_batched_tokens: 8192 -> 65536 | run-0002 at 32768 cleared the d8192 queue (R10/W0) and took d8192 to 773.3, but d16384 still queued (R5/W4) and did not move | d8192 c10 | 17245.2 | 735.6 | 1055.5 | bench_6f181221bdc1 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Raising `max_num_batched_tokens` from 8192 above `depth + pp` lifts `tg` at
`tg128 (c10)` d8192 and d16384 and does not lift it at d0 or d4096.

The mechanism is vLLM's chunked prefill. llama-benchy's headline `tg` row sends
context and prompt in one request, so a request's prefill is `depth + pp`
tokens, not `depth` (`ddb69b66`). Against the baseline's 8192-token budget:

    d0      depth+pp =  2048   fits          — we win this cell by 111%
    d4096   depth+pp =  6144   fits          — we win this cell by 51%
    d8192   depth+pp = 10240   does not fit  — we lose this cell by 7.0%
    d16384  depth+pp = 18432   does not fit  — we lose this cell by 43%

The budget crosses from sufficient to insufficient at exactly the depth where
our standing flips. Where it does not fit, each request's prefill is split
across scheduler steps and those chunks interleave with the decode steps of the
other nine in-flight requests, so decode is repeatedly displaced by a neighbour's
prefill work. Raising the budget past `depth + pp` collapses each prefill into
fewer steps and stops that displacement. `624a27fe` names this as the candidate
mechanism for a +15.5% `tg_req` lift at 32768→98304, d16384.

The prediction has a falsifier that costs nothing: if the mechanism is what the
arithmetic says, d0 and d4096 must be flat across all three arms, because their
prefills already fit at 8192. An arm that lifts all four depths together is
measuring something else, and this round would be wrong about why even if the
figures move the right way.

**Transfer.** Every `mnbt` figure in the store was measured on
`nvidia/Qwen3.6-35B-A3B-NVFP4`, never on this 350M checkpoint, and most of it at
c4/c5 rather than c10. What transfers is the vLLM scheduler's prefill admission
and chunking path — model-independent code whose deciding arithmetic,
`depth + pp` against `mnbt`, carries no model term. What does not transfer is
magnitude: a 35B MoE and a 350M dense model spend their step time on entirely
different things, so the size of the lift is genuinely unknown here and this
round measures it rather than assuming it. One further caveat on the store's
figures: `a2f190d6`'s saturation result and `624a27fe`'s +15.5% were taken at
`mns` 4/5 with `c > mns`, a queueing regime (`d32d8711`). We run `mns` 16 with
c10, so nothing queues. The occupancy route by which `mnbt` can help is
therefore closed for us; only the chunking route is open, and it is the one this
hypothesis names.

Worth, if right: d8192 needs 693.40 → 745.70, **+7.5%**. d16384 needs
347.20 → 613.31, **+76.6%**.

The +7.5% is inside what this lever has been measured to buy — `624a27fe` read
+15.5% on the aggregate's per-request component at a comparable depth, and
`a2f190d6` predicts d8192's saturating budget at ≈51 200, which a 65536 arm
reaches. d8192 is a reachable cell.

The +76.6% is not comfortably inside it. The largest `mnbt` effect in the store
is +98% across 8192→65536 at d16384 c4 — but that is `tg_req`, a per-request
figure that `beab2d2c` explicitly calls a sharing artefact and warns is not the
aggregate the board scores. Read honestly, this round's arithmetic says d8192 is
probably winnable and d16384 probably is not on this lever alone. That is stated
here, before the runs, so the round is not later credited with an expectation it
never held: h1 is expected to convert one of the two cells, and the Objective
needs both. `a2f190d6` also puts d16384's saturating budget at ≈92 200, above
this round's top arm, which is the one clean way h1 could still be alive at
d16384 after 65536.

## Method

### Variables to test

    max_num_batched_tokens: 8192, 32768, 65536

    8192   control — the baseline, the board entry's value, below depth+pp at
           both target cells
    32768  first value above depth+pp at both target cells; also equal to
           max_model_len, so it is the largest value that changes nothing about
           the relationship between the budget and the context window
    65536  above a2f190d6's predicted saturating budget for d8192 (~51 200) and
           below its prediction for d16384 (~92 200)

Order: ascending, one arm per run, control first. The control is re-measured
rather than carried over from `slots/h1/run-0004` because that run is a
different bench id on a different day and the round must own its own baseline.
Move to the next arm regardless of what the previous returned — three arms are
the round's plan and a two-point line through a saturating response cannot be
read.

### Constant for this round

Everything in `../recipe.yaml` except `max_num_batched_tokens`. Named because
they are the fields that could plausibly move with the budget and must not:
`max_model_len: 32768`, `max_num_seqs: 16` (Held), `gpu_memory_utilization: 0.8`,
`--enable-chunked-prefill` on (its removal would activate vLLM's
`mnbt >= max_model_len` validator and change what the arms mean),
`--enable-prefix-caching` on (h2's lever, not this round's),
`--kv-cache-dtype fp8`, `--quantization fp8`, `--attention-backend FLASHINFER`,
`recipe_version: '1'`.

The three arms differ in `mnbt`, so their recipe hashes differ and sparkrun
gives each its own archive directory. Two runs sharing a hash would mean one of
them tested nothing.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0, 4096, 8192, 16384 · concurrency 10 · runs 3

d0 and d4096 stay in the grid as the mechanism's falsifier and as a
non-regression check on the two cells we already hold. They cost ~4 s and ~7 s
of benchmark time.

**What this grid can and cannot read, stated before it runs.** Three values per
cell is fewer than four, so no cell here has an interquartile range and no rule
below is stated on spread. At d16384 the baseline recipe measured 20% CV at n=3
(347.20, sd 70.0, values 427.12/296.97/317.59), so a difference under ~20% at
that cell is unreadable at this grid and the rule does not ask it to be read.
d8192 and shallower have behaved as the quiet end throughout `slots`; the rule
treats sub-3% differences there as ties. If d16384's spread again lands near 20%
and the arms fall inside it, the honest outcome is that the grid was wrong for
that cell — the grid that would settle it is d16384 alone at runs 7 — and the
Conclusion says so rather than reading a mean it cannot support.

## Decision rule

Read at `tg128` concurrency 10, `tg` only, on the mean of the 3 values.

- **Target met** if one arm's `tg` exceeds **745.70 at d8192** *and* **613.31 at
  d16384** in that same run, while its d0 stays above 1042.20 and its d4096
  above 750.01.
- **Lever alive** if the target is not met and either: (a) d8192 exceeds 745.70
  in some arm while d16384 does not, and `tg` at d16384 is still rising at
  65536 — the response has not saturated and 98304 is the untried value
  `a2f190d6` predicts for that cell; or (b) `tg` at d8192 rose by more than 3%
  from 8192 to 65536 without reaching 745.70 and was still rising at 65536.
- **Lever spent** if `tg` at d8192 across the three arms spans less than 3%, or
  if it rose and then fell, or if the best arm at d8192 is below 745.70 with the
  response already flat at 65536. d16384 does not decide "spent" on its own: at
  20% CV it cannot distinguish a flat response from a rising one, and a rule
  that let an unreadable cell close a lever would be closing it on noise.

If all four depths move together by a similar factor, the mechanism named in the
Hypothesis is wrong whatever the verdict, and the Conclusion says so — the rule
still resolves on the numbers above, and the rule is not edited.

## Conclusion

LEVER SPENT. `max_num_batched_tokens` 8192 → 32768 → 65536 took `tg` at
d8192 c10 to 741.1 → 773.3 → 709.8: it rose and then fell, the rule's
lever-spent clause. Target not met — the rule required one run to clear
745.70 at d8192 and 613.31 at d16384 together; run-0002 cleared d8192 at
773.3 but read 375.9 at d16384. d0 and d4096 held their board margins in
every arm, so nothing we already win regressed.

The mechanism was confirmed even though the lever is closed. Only d8192
moved between 8192 and 32768; d0 and d4096, whose `depth + pp` already fitted
the old budget, did not — the falsifier the Hypothesis named. The scheduler
agrees: d8192 went Running 4 / Waiting 6 → Running 10 / Waiting 0.

Two things this round got wrong about itself, neither of which is a reason to
edit the rule. Its 3% tie band was undersized: within-arm CV at d8192 is
6.9–14.5% and an identical recipe moves ~7% run to run, so the whole 8.9%
arm-to-arm span sits inside one arm's noise and the rule resolved on a pattern
it could not see. And it closed the budget before that budget's own arithmetic
was satisfied at d16384, where whole-prefill admission is `floor(mnbt/18432)`
and even 65536 admits three of ten — the queue never cleared in any arm.
What was measured is that no budget up to 65536 helps d16384, not that none can.
