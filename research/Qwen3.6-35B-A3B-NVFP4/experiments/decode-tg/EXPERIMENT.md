# decode-tg — raise single-stream decode, measured against ourselves

## Objective

Maximise `tg` at `tg128 @ d16384 c1`, and understand what governs it. There is
no ceiling here on purpose — the standing best is 119.6 (h1 run-0008) and every
round exists to move it or to close a lever and say why.

Two figures, because one number cannot serve both purposes:

- **Ours** — measured under the protocol in Held, which is what makes rounds
  comparable to each other. A round improves it only with a stable verdict,
  `tg` interquartile spread at or below 5%; a median claimed while the samples
  scatter is not an improvement. (Until 2026-08-23 this was stated on max/min
  at 1.10 — an extreme-value gate drawn from two of seven samples, which drifts
  upward as `runs` grows and so punishes longer runs.)
- **Board-comparable** — measured by running `@official/spark-arena-v2`
  unmodified and reading our own `d16384/c1` row out of it. This is the only
  figure that can be set beside the board at all, and beating the board means
  beating it *there*.

Reached when both are true: no lever in Strategy remains open, and two
consecutive rounds fail to move the standing best. Then the conclusion records
how far `tg` moved, which mechanisms carried it, and which are closed and why.

Not reached by hitting any particular number, and not closed early because a
number looked good.

This said 116.03 until 2026-08-23, the best vLLM NVFP4 entry at this cell. That
was the wrong target — not because the figure is wrong but because it is not
the same quantity. Its `±` is a population standard deviation over three
requests inside one invocation; ours is across invocations. It was produced at
cell 14 of a 28-cell sweep, in one continuous server process, with warmup
suppressed after the first cell, no fixed output length, no sampling
parameters, and resumption across interruptions explicitly sanctioned. Seven
documented differences, none of them ours to close.

We read 116.2 before changing anything and 118.9 after, which is most of what
that comparison was ever worth.

That does not mean the board is out of reach — it means we cannot tell from
these numbers whether we are ahead or behind. So the board-comparable figure
above is part of this experiment, not deferred to another one: run their
profile, read our own row, and then a claim about beating them is checkable
rather than asserted.

## Strategy

We do not have to guess the levers. The reference recipe is public and it is
almost our recipe. Diffed 2026-08-23, everything it does that we do not:

    gpu_memory_utilization      0.65    vs ours 0.8
    max_model_len             262144    vs ours 32768
    max_num_batched_tokens     32768    vs ours 65536
    --override-generation-config        temp 0.6, top_p 0.95, top_k 20
    --default-chat-template-kwargs      preserve_thinking: true
    mods                                fix-qwen3.6-chat-template

Everything else is identical, field for field: `kv-cache-dtype fp8`,
`--attention-backend flashinfer`, `--moe-backend marlin`, `max_num_seqs 4`,
MTP depth 3 on triton, chunked prefill, async scheduling, prefix caching,
fastsafetensors, `VLLM_MARLIN_USE_ATOMIC_ADD=1`.

So the +13.7% lives in three numbers and a sampling config, not in the
mechanisms worth theorising about. KV cache format in particular is settled:
the recipe that beats us runs the same `fp8` we do.

The second signal is larger than the first. Their prefill at this cell is
1414.86 ± 7.14 against our 630.0 — 2.25x — and their decode spread is 3.1%
against our 20%. Whatever separates us is not a decode-side micro-lever; it
shows up hardest in prefill and in measurement stability.
`max_num_batched_tokens` governs how a long prompt is chunked and
`max_model_len` governs how much KV is reserved, so both touch prefill
directly. That is where a 2.25x can plausibly come from, and a decode win may
follow it rather than lead it.

Ceilings: the three numbers together are worth the whole gap if the diff is the
whole story, since they are all that separates us from a recipe measured at
116.03. If they are not, what remains is the sampling config — `top_k 20`
bounds the sampling work per token — and then the attention kernel, which has
never been varied on this box.

Measured scatter, per cell — what a decision rule here has to clear:

    tg128 @ d16384 c1: tg max/min 1.31, pp 1.02   (h1 run-0001, MTP on)
    tg128 @ d16384 c1: tg max/min 1.01, pp 1.02   (h1 run-0003, MTP off)
    tg128 @ d16384 c1: tg max/min 1.11, pp 1.03   (h1 run-0008, prompt pinned)

On the board grid, which is a different instrument and a different epoch, added
2026-08-24 from h5 run-0001. `runs: 3` gives no interquartile range at c1, so a
rule in that lane is stated on the median and sized against this:

    tg128 @ d16384 c1: tg max/min 1.14, median SE 5.2%, n=3   (h5 run-0001)

Most of that scatter was the instrument, not the box. llama-benchy's
`adapt_prompt` defaults on and shrinks the grid by the measured template
overhead, which reopens the random prompt start that the fixed corpus was meant
to close. Pinning it (run-0008) took `tg` max/min from 1.24 to 1.108 and made
`prompt_tokens` constant. What survives is engine-level: with an identical
prompt, `temperature 0` and a seed, four of seven generations are byte-identical
and three diverge — greedy decoding occasionally taking a different branch under
MTP. run-0003 bounds that residue at 1.01 with speculation off.

Speculation is the scatter. Removing it collapses `tg` standard deviation from
8.6 to 0.24 — a 36-fold drop — while `pp` does not move. It also costs 36% of
decode and returns 3.8x on prefill and time-to-first-token, so MTP stays; but
every `tg` figure here is drawn from a distribution it widens. Triton JIT was
the earlier suspect and is ruled out: the compilations fire inside llama-benchy's
warmup requests, before the timed runs.

The reference recipe runs the same MTP settings at a much tighter spread, so
25% is not what MTP costs by necessity. What differs is the protocol — see
Held. That comparison is also weaker than it looks: the board's figure is a
population standard deviation over three requests *within* one invocation,
while ours is across invocations. They are not the same quantity.

Everything measured before 2026-08-23 sits on the far side of two epoch breaks:
the memory embedder was resident on the card, and the measurement protocol in
Held did not exist.

## Held

- One node, one GB10. No ray, no tensor parallel above 1.
- The checkpoint pinned in `docs/model-card.md`.
- The container image and its vLLM and flashinfer commits. A change to any of
  them is a new epoch and reopens every figure above.
- The cell: `pp 2048 · tg 128 · depth 16384 · concurrency 1`. This is what the
  Objective is stated in. The experiment's `recipe.yaml` narrows the model
  baseline's grid to it — c1 only, and `runs: 7`, because a rule stated on
  interquartile range needs more than three values to evaluate.
- The measurement protocol, which is part of the recipe and therefore part of
  the epoch: `exact_tg` pins every request to exactly 128 generated tokens,
  `extra_body temperature=0` removes sampling variance, `post_run_cmd` resets
  the prefix cache between runs, and `no_adapt_prompt: true` stops llama-benchy
  rewriting the grid at warmup — without it `total_needed` shrinks by the
  template overhead, `max_start` becomes `1 + delta` instead of 1, and every run
  draws a different prompt. The trade is that the served prompt carries the
  template on top of the 18432 corpus tokens rather than hitting the nominal
  size exactly; this experiment wants reproducibility over nominal exactness.
  The memory stack's embedder is down for every run — it is a vLLM instance on
  the same card.
- Nothing is submitted to Spark Arena.

Everything else in the recipe is open to some round. What a given round holds
constant it says in its own Method.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | The three numeric fields the reference recipe differs on are the whole gap | lever spent |
| h2 | A flag is disabling the prefix cache | premise wrong — our own reset was |
| h3 | `tg128` measures a transient | refuted — no transient; the effect is KV growth |
| h4 | The draft's MoE backend is untuned and one alternative beats it | lever spent |
| h5 | Our recipe on the board's own grid reads above 116.03 | lever spent — 103.7, and the warm cache it rested on never existed |
| h6 | The checkpoint's `temperature 1.0` is costing decode on the board grid | lever spent — acceptance moved 3.07 → 3.22 and `tg` did not follow |

h1 is spent: its three fields moved `tg` 2.0 against a larger IQR of 11.3, and
`pp` moved 0.5% — inside this cell's own 1.02 max/min — which killed the
prefill-chunking mechanism behind them.

h5 delivered the Objective's second figure and it goes against us: **103.7 at
`d16384 c1` on arena's own grid, against 116.03.** It ran one clean 28-cell
sweep at `max_model_len 262144`, which is an epoch break from h1-h4. Its own
mechanism never fired — prefix cache read 0.0% on all 544 samples with no reset
in the recipe at all, and `pp`, `ctx pp` and `ttfr` all land on h2's *cold*
column to within 0.5%. So the round is spent by its rule but its hypothesis was
never tested, and "our protocol flatters us" is not what these numbers say.

Levers still open, in the order to take them. Reordered 2026-08-23 after the
architecture was read: this is a hybrid, 30 of its 40 layers are linear
attention with no KV, and only 10 are full attention.

1. **The prefix cache never hits** — 0.0% on every sample of every run, while
   the recipe asks for it. Phase 2 recomputes all 18446 tokens instead of
   reusing phase 1's 16400. A defect, not a tuning knob, and the largest single
   thing this experiment has found. h2.
2. **Is `tg128` a transient?** — 128 tokens is ~41 speculative cycles in ~1.1 s,
   and MTP acceptance is a running statistic. If the metric the board scores is
   partly warm-up, that reframes every figure here. Cheap, and it can invalidate
   what everything else is measured in. h3.
3. ~~**The draft path**~~ — closed by h4. The one exposed flag is the draft's
   `moe_backend`, and on SM121 `triton` is very nearly the only option that
   works: `batched_triton` cannot be constructed by vLLM's own factory,
   `flashinfer_trtllm` is refused by the kernel, and `flashinfer_cutlass` runs
   but lands inside the control's spread. What remains of the draft's cost is
   the 286 MB `lm_head` re-read, which is architectural and reaches no flag.
4. ~~**The board-comparable figure**~~ — measured by h5. It reads **103.7**,
   10.6% behind 116.03. The figure exists; what does not exist is an
   explanation for it, which is lever 5.
5. ~~**Sampling on the board grid**~~ — closed by h6. `temperature 0.6` was
   served and it worked: MTP acceptance rose 3.07 → 3.22. `tg` went 103.7 →
   105.12, +1.4% inside a cell whose own three values span 13%. The last
   untested field in the reference diff is spent, and it took the
   "`tg` ≈ 37 × acceptance" relation with it — see the Conclusion.

Reopened by h5:

- **The prefix cache still never hits.** h2 closed this on "our own
  `post_run_cmd` was disabling it". h5 carried no `post_run_cmd` and read 0.0%
  on all 544 samples anyway. The reset was sufficient to suppress hits, not
  necessary. The candidate residue is `no_adapt_prompt` and the fixed corpus,
  which h2 kept and h5 gave up: without them each of a cell's runs draws a
  different prompt start, so there is nothing to reuse. Not a lever for this
  Objective — h2 measured a working cache as worth +2.3% `tg`, inside the
  spread — but it is a live defect and it removes "the board measures warm" as
  an explanation for anything until someone shows arena's own runs hit.
- **`max_num_seqs 4` makes c5 and c10 unreadable at depth >= 8192.** Solved
  elsewhere, 2026-08-24: the `concurrency` experiment closed by raising
  `max_num_seqs` 4 → 10, taking `d16384 c10` from 48.9 to 141.5. decode-tg
  handed that field away explicitly, so there is no conflict — but note the
  shape of it: the campaign's c10 problem is now solved and decode-tg's own c1
  objective stands where h5 left it. Original note follows. Per-request
  `tg` dispersion runs to 377% IQR and 53x max/min because six of ten requests
  queue (`running max 4, waiting max 7`). The milestone targets c10 at d16384;
  that cell reads 48.9 and cannot be moved by decode tuning, nor compared to a
  board c10 produced under a different `max_num_seqs`. Establishing that is a
  recipe change and its own round, and it belongs to the milestone rather than
  to this Objective.

Demoted, with reasons:

- **Attention backend** — reaches 10 of 40 layers, and this build offers only
  FLASHINFER and TRITON_ATTN. Decode is also nearly flat with depth on the
  board, and depth is what attention governs. The vLLM #37754 crash report cites
  GQA=16; this checkpoint is GQA 8, so it does not transfer unchecked.
- **Speculative depth** — settled. Measured per-position acceptance
  0.87/0.76/0.61 makes N=3 optimal by ~2% over N=2, and N=4 loses.

The sampling config is not a lever for the **Ours** figure — the protocol pins
`temperature 0` itself. It is a lever for the **board-comparable** figure, which
arena leaves to the served generation config. Corrected 2026-08-24; this
previously read "no longer a lever" without the distinction, and h5 showed the
served value is 1.0.

## Conclusion

**Closed as exhausted, 2026-08-24.** Six rounds, twenty-one runs, and the
recipe is unchanged. `recipe-new.yaml` is `recipe.yaml` byte for byte, because
no field earned a place in it.

### Why exhausted rather than an h7

h6 resolved *lever spent*, and the skill's spent branch opens a new round only
if a hypothesis exists that aims at the same Objective, respects Held, and is
motivated by a row already measured. There is no such hypothesis left. Every
candidate was checked before this was written:

- **The reference diff is empty.** Six differences were listed in Strategy.
  `gpu_memory_utilization`, `max_model_len` and `max_num_batched_tokens` went to
  h1 and moved `tg` 2.0 against an IQR of 11.3. The sampling override went to h6
  and moved it 1.4% against a 13% cell. What remains is
  `--default-chat-template-kwargs preserve_thinking: true` and the
  `fix-qwen3.6-chat-template` mod. Neither is a decode lever: they change how the
  prompt is rendered and what the model is allowed to emit, not the rate at which
  it emits. No measured row motivates them, and inventing a round for them would
  be filling a slot.
- **The draft path** — closed by h4. Two of three alternatives cannot be
  constructed on SM121 at all and the third lands inside the control's spread.
  What is left of the draft's cost is the 286 MB `lm_head` re-read, which is
  architectural and reaches no flag.
- **Attention backend and KV dtype** — closed by depth-curve. They act on 10 of
  40 layers, which are exactly the depth-dependent ones, and the depth curve is
  flat enough to bound both at a few percent across the whole legal context
  range.
- **Speculative depth** — settled. Per-position acceptance 0.87/0.76/0.61 makes
  N=3 optimal by ~2% over N=2, and N=4 loses.
- **The prefix cache** — a live defect, not a lever for this Objective. h2
  measured a working cache at +2.3% `tg`, inside the spread. It is a latency
  finding and it belongs to whoever fixes the harness.
- **`max_num_seqs`** — never this Objective's field; c1 has one sequence. The
  `concurrency` experiment took it and won there.

The Objective's own closing condition is also met, on its own terms: no lever in
Strategy remains open, and two consecutive rounds — h5 and h6 — failed to move
the standing best.

### What it cost and what it bought

Twenty-one runs across six rounds: h1 eight, h2 five, h3 two, h4 four, h5 one,
h6 one. Roughly a dozen hours of box time, two of them in h6 alone. No recipe
field moved.

What it bought is a map of what does not work, which is the thing this campaign
was short of:

1. **The board-comparable figure exists and it goes against us.** 103.7 at
   `d16384 c1` on arena's own unmodified grid (h5), 105.12 with sampling matched
   to the reference recipe (h6), against the board's 116.03. We are behind
   there, and we now know it by measurement rather than by assertion.
2. **The 13% gap between our internal 119.6 and that board figure is still
   unexplained, and three of the four candidates are now eliminated.** Not warm
   cache — the prefix cache reads 0.0% under every protocol we have run, seven
   times confirmed. (This read "nine times" until 2026-08-27, and the count was
   inflated: two of the counted runs, `depth-curve/h1/run-0005` and `run-0006`,
   logged one hit-rate sample each, and the engine's first sample is always
   0.0%, so they assert nothing. `measure.py` now gates at n >= 2. Count
   samples, not runs.) Not MTP acceptance — h5 measured it *higher* than greedy, and
   h6 raised it further to no effect. Not the served sampling config — h6. What
   remains conflated is the prompt (`adapt_prompt`'s random start against our
   fixed corpus), the absence of `exact_tg`, and mid-sweep thermal state. All
   three are protocol, not recipe, and separating them means diverging from
   arena's grid — which makes the result no longer board-comparable. That is the
   wall this experiment ends against.
3. **Decode throughput is not proportional to MTP acceptance length at fixed
   depth.** h6 raised acceptance 3.07 → 3.22 and `tg` moved 1.4%; the relation
   predicted 108.8 within the lane, or 118.8 against depth-curve's constant of
   36.9. The quotient fell from 33.8 to 32.6 while acceptance rose. That
   relation has been steering lever choices across this campaign and it now has
   a counterexample. It remains useful for *normalising away* prose-driven bumps
   in a depth ladder, where acceptance varies because the corpus varies. It is
   not a lever: buying acceptance does not buy throughput.
4. **The spread is speculation, and it is the instrument's dominant term.**
   Removing MTP collapses `tg` standard deviation 8.6 → 0.24 while `pp` does not
   move. Every `tg` figure in this tree is drawn from a distribution MTP widens,
   and MTP stays because it is worth 36% of decode and 3.8x on prefill.
5. **Two protocol facts the tree now runs on.** `no_adapt_prompt` plus a fixed
   corpus is what makes a run reproducible (h1). Degeneration is a first-class
   check, with a 100-word sliding-window repeat ratio rather than whole-output
   uniqueness (h3).

### What is now known to be closed

For this epoch — image `2026082102`, vLLM `e85d1b69`, flashinfer `4927c0e1` — the
following are closed as decode levers at `tg128 @ d16384 c1` and should not be
reopened without a new epoch or a new measured row:

    gpu_memory_utilization, max_model_len, max_num_batched_tokens   h1
    prefix cache as a throughput lever                              h2
    tg128 as a warm-up transient                                    h3
    the draft's moe_backend                                         h4
    the served generation config / sampling                         h5, h6
    kv-cache-dtype, attention-backend                               depth-curve
    speculative depth                                               settled at N=3

Standing best under our own protocol, unchanged by this experiment: **119.6**
(h1 run-0008), re-based to 117.8 by depth-curve under the per-cell corpus
offset. Standing board-comparable figure: **105.12** (h6 run-0001).

### The open defect this hands on

The prefix cache reads 0.0% on every sample of every run in this tree, under
every protocol, with `--enable-prefix-caching` set and confirmed in the engine's
own config line. h2 attributed it to our `post_run_cmd`; h5 ran without one and
read 0.0% anyway. It is not worth a decode round — h2 priced it at +2.3% `tg` —
but it is the largest single unexplained thing this experiment found.

That paragraph closed on three claims that do not hold. Corrected 2026-08-27:

- It said **nine confirmations**. Seven. Two of the counted runs,
  `depth-curve/h1/run-0005` and `run-0006`, logged one hit-rate sample each, and
  the engine's first sample is always 0.0%, so they assert nothing. `measure.py`
  now gates at n >= 2. Count samples, not runs. See the store record establishing
  that the engine's first hit-rate sample is always 0.0%.
- It named **`adapt_prompt` as the leading candidate for the residue**. A
  correction written earlier on 2026-08-27 retired that on the ground that "MTP
  alone drives the reading to 0.0% by controlled A/B", and concluded "there is no
  residue to explain". **That retirement is withdrawn, later the same day.** MTP
  is not sufficient. `decode-tg/h1/run-0001/recipe.yaml` and
  `decode-tg/h2/run-0005/recipe.yaml` are byte-identical across the whole `vllm
  serve` command — MTP depth 3 on triton in both, `--enable-prefix-caching` in
  both, no `post_run_cmd` in either, same grid at `pp2048 · tg128 · d16384 · c1 ·
  runs 7` — and differ only in `book_url`, `exact_tg`, `extra_body` and
  `no_adapt_prompt`. They read 0.0% and 69.2%. The four rows on disk:

      MTP on,  pinned,   reset       0.0%   (h2 arm A, run-0001..run-0004)
      MTP on,  pinned,   no reset   69.2%   (h2 run-0005)
      MTP on,  unpinned, no reset    0.0%   (h1 run-0001)
      MTP off, unpinned, no reset   42.1%   (h1 run-0003)

  h2's Amendment A/B was unpinned in **both** arms, so it never isolated MTP —
  what it measured is an interaction. The 0.0% needs MTP *and* an unpinned
  prompt, and a pinned corpus recovers cross-run hits with MTP still on. So the
  residue question is **open**, and `no_adapt_prompt` is the better-supported
  half of it, not the retired one.
- It said the defect **removes "the board measures warm" as an explanation for
  anything**. False for the board's non-MTP entries, which read roughly 47% hit
  rate for free. The claim holds only where MTP is on. See the `stack:llama-benchy`
  record establishing the 47% free-hit figure for non-MTP entries; the raw id it
  cited was deleted and replaced, and ids churn on every correction, so records
  here are named by what they say.

Second, smaller: a harness logging defect that writes one byte-identical
duplicate `request_end` line for a cell, seen three times (concurrency h3
`06-d100000c2`, and twice in h6). Any analysis counting request records must
deduplicate.

Corrected 2026-08-27. This read "seen four times now" and counted concurrency h1
run-0003 among them. It does not belong. Verified against `bench_fbb28a3df00f`,
that cell carries zero duplicate lines; its 30 ends against 29 first-tokens are
real damage — request 27 returned `total_tokens: 1` at `decode_seconds: 0.0`,
costing a sample and throwing a `pp` outlier of 817.95 against siblings at 580.
Three genuine sightings remain. The discriminator: a double-flush has every
record at full `total_tokens`, damage does not. See the store records separating
the writer double-flush from real sample damage.

### Two corrections this experiment owes its own documents

Added 2026-08-27. The Strategy above is left as written; these sit beneath it.

- **The board prefill deficit never existed.** Strategy reads their prefill at
  this cell as 1414.86 ± 7.14 against our 630.0 — 2.25x — and concludes "that is
  where a 2.25x can plausibly come from". h2's Amendment corrected it: the
  comparison was cold against warm, and it was not the same quantity either. We
  were never behind on prefill. Measured the way theirs is, ours is 2593.0. The
  phantom 2.25x is what motivated the `max_num_batched_tokens` and
  `max_model_len` lever choices. See the store records retiring the board prefill
  deficit, which hold the cold-against-warm arithmetic.
- **Triton JIT is ruled out for one cell, not for the experiment.** Strategy
  says the compilations "fire inside llama-benchy's warmup requests, before the
  timed runs". That is true of h1's own cell. It is false in general, and — this
  bullet corrected a second time, 2026-08-27 — **a per-test warmup is not what
  bounds it: JIT fires inside the measurement window even in cells that ran
  one.** The bullet first read that the refuting compilations came "in cells run
  with `--skip-coherence` and no per-test warmup". `concurrency/h1/HYPOTHESIS.md`
  says the opposite: "Only the c1 cell ran a per-test warmup and the coherence
  test; c10, c5 and c2 ran with `--skip-coherence`" — and the nine triton kernels
  in run-0001 and the eight in run-0003 fired inside **c1**, the warmed cell;
  only "two more" landed in c10. `decode-tg/h4/run-0004` is a single-cell c1 run
  — no recipe in this tree sets `skip_coherence` — so it warmed too, and still
  logged seven compilations during its **first timed request**, with latency
  spiking to match. What was wrong is the scope of the claim; what is still wrong
  is treating warmup as the fix.
