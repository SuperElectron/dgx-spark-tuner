# h6 — the checkpoint's own `temperature 1.0` is costing decode on the board grid

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

LEVER SPENT, by the rule as written — `tg` median at `d16384 c1` is 105.12,
below the rule's 110.7 floor. The mechanism did fire: acceptance rose 3.07 →
3.22 and bought no throughput.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | `--override-generation-config` temperature 0.6 | the last untested field in the reference diff; tg is the median of n=3, max/min 1.132, values 105.12 94.43 106.91; accept len 3.22 median over 401 samples | d16384 c1 | 633.71 | 105.12 | 3243.59 ms | bench_44dd96bddd72 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.
One row per planned run. Figures blank until it is run.

## Hypothesis

Overriding the served generation config to `temperature 0.6` raises `tg` at
`d16384 c1` on the arena-v2 grid above h5's 103.7.

The mechanism is speculative acceptance. MTP proposes three tokens per step and
the target model accepts a prefix of them; how long that prefix is depends on
how sharply the target's distribution is peaked. A flatter target agrees with
the draft less often. h5 served the checkpoint's own
`generation_config.json` — the engine logged
`{'temperature': 1.0, 'top_k': 20, 'top_p': 0.95}` overriding vLLM's defaults —
and the reference recipe that reads 116.03 does not: it passes
`--override-generation-config` with `temperature 0.6`, same `top_p`, same
`top_k`. That is the last field in the Strategy diff that has never been varied
on this box, and it is the only remaining difference that is a *served* flag
rather than a property of the grid.

Arena does not pin sampling, so this is board-legal: the served generation
config is ours to set, and the recipe we are being measured against sets it.

Worth, if right: h5's mean acceptance length reads a median of **3.07 over 399
engine samples**, against a ceiling of 4.0. Closing half that headroom is
3.07 → 3.53, which is 15% more accepted tokens per target forward pass, and
decode here is target-pass-bound. 103.7 x 1.15 is ~119, which clears 116.03.

The honest ceiling is lower than that, because the arithmetic is optimistic in
both directions and one measurement argues against it: the per-position rates
measured at `temperature 0` in h1 were `0.87/0.76/0.61`, implying an acceptance
length of ~2.93 — *below* h5's 3.07. If greedy decoding already accepts less
than the checkpoint's stochastic sampling does, then acceptance is not what
separates 103.7 from 119.6 and this lever has little in it. That is precisely
why it is worth one run: it is the cheapest of the four candidates h5 left
conflated, it is a single flag, and it resolves either way.

## Method

### Variables to test

    --override-generation-config: temperature 0.6 (top_p 0.95, top_k 20 unchanged)

One run. `top_p` and `top_k` are transcribed at the checkpoint's own values so
that `temperature` is the only thing that moves; the reference recipe sets them
to the same numbers, so nothing is being smuggled in.

Order: nothing else varies, so there is no order.

### Constant for this round

Everything else in h5 run-0001's recipe, byte for byte: the same `serve`
command, the same `defaults:` including `max_model_len 262144`,
`gpu_memory_utilization 0.8`, `max_num_seqs 4`, `max_num_batched_tokens 65536`,
and the same 28-entry `schedule:` in the same order. **The schedule is
load-bearing** — it decides what is warm and what is hot, and `d16384 c1` must
stay at index 13 or the two runs are not comparable.

Copy `h5/run-0001/recipe.yaml` and add one flag. Do not re-transcribe it.

Grid, from the recipe's `benchmark:` block — arena-v2 unmodified:

    pp 2048 · tg 128 · depth 0/4096/8192/16384/32768/65535/100000
    concurrency 1/2/5/10 · runs 3

### What this round is and is not

This is the **board-comparable** lane, not the internal one. It inherits h5's
epoch (`max_model_len 262144`) and h5's protocol (no `exact_tg`, no fixed
corpus, no `no_adapt_prompt`, no `post_run_cmd`), and its figures are
comparable to h5 run-0001 and to nothing else in this experiment. Setting any
number here beside h1-h4 requires saying so.

### What it does not attempt

h5 left four things conflated in the 13.3% between our internal 119.6 and its
103.7: the prompt, `exact_tg`, sampling, and mid-sweep thermal state. This round
separates **one** of them, and only in the direction that matters — whether
turning the sampling knob the reference recipe turns moves our board figure. It
does not attempt to explain the other three, and a null result here does not
attribute the gap to them.

Two things h5 found are deliberately left alone:

- **The prefix cache reading 0.0%.** It is a real defect, but h2 measured a
  working cache as worth +2.3% `tg`, inside the spread. It cannot carry this
  Objective and chasing it here would cost a run for a latency figure.
- **c5 and c10 above d8192.** Unreadable under `max_num_seqs 4`; see
  `EXPERIMENT.md`. They will be produced by this run because the grid asks for
  them, and they are not to be read.

### Archive collision

sparkrun derives the bench id from the recipe. This recipe differs from h5's by
one flag, so it gets a different id and **will not overwrite h5 run-0001** —
which is what h5 did to the partial sweep before it. Record the id from
`state.yaml` in the Runs table above, and check before dispatching that it is
not `bench_e86574ff0e1e`.

### Running it

A 28-cell sweep is roughly two hours — h5's session ran 03:37 to 05:31 UTC. Run
it in the background; a foreground command dies at ten minutes.
`exit_on_first_fail` stays on. Memory is not a question: h5 peaked at 9.8% KV
usage with zero preemptions against a predicted 36%, and this round changes no
memory field.

## Decision rule

Read our own `d16384 c1` row, cell phase, and take the **median** of its three
`tg` values — not run.py's table column, which is an arithmetic mean of a rate.
`runs: 3` means no interquartile range exists at c1, so the rule is stated on
the median alone and sized against h5's measured max/min of 1.14 and median
standard error of 5.2%.

- **Target met** if the median exceeds **116.03**. The board comparison is then
  settled in our favour on the board's own terms.
- **Lever alive** if it exceeds **110.7** (h5's 103.7 plus 6.8%, one max/min
  half-width — the smallest move this cell can distinguish from h5) but does not
  reach 116.03. Sampling is then carrying real decode and there is a second
  value to try; `temperature 0.3` is the next row, not a new round.
- **Lever spent** if the median lands at or below **110.7**. Sampling does not
  govern decode here, the reference recipe's `temperature 0.6` is not what makes
  it 116.03, and the gap belongs to one of the three candidates h5 could not
  separate.

Sized so that an effect smaller than what h5's own scatter can resolve is read
as no effect. Note before any number exists: this cell's spread is wide enough
that a genuine 5% win would be reported as a spent lever. That is the cost of
`runs: 3`, it is inherent to arena's grid, and this round accepts it rather
than diverging from the grid to fix it.

## Conclusion

**Lever spent, by the rule as written.** `tg` median at `d16384 c1`, cell phase,
is **105.12** (n=3; 105.12, 94.43, 106.91; max/min 1.132). The rule's floor is
110.7 and its target is 116.03. 105.12 is below both, so the branch is *lever
spent*: the served sampling config does not govern decode on the board grid, and
`temperature 0.6` is not what makes the reference recipe read 116.03.

`bench_44dd96bddd72`, distinct from h5's `bench_e86574ff0e1e` as the round
required, so nothing was overwritten.

### The control this is read against

For reference, the control this is read against — h5 run-0001, same grid, same
schedule, same epoch, served generation config `temperature 1.0`. It is h5's
control row, carried here for comparison; it is a cross-round row and does not
belong in this round's script-written table above.

| | cell | pp t/s | tg t/s median | ttfr ms | accept len | bench |
|-|------|--------|---------------|---------|------------|-------|
| h5 run-0001 | d16384 c1 | 636.7 | 103.7 (n=3, max/min 1.14) | 3242.6 | 3.07 median | bench_e86574ff0e1e |

### The mechanism fired and bought nothing

This is a stronger refutation than a mechanism that fails to engage, and it is
the finding worth carrying out of this round.

    served temperature      1.0 (h5)   ->   0.6 (h6)
    MTP acceptance length   3.07       ->   3.22      +4.9%   (401 engine samples)
    tg median               103.7      ->   105.12    +1.4%
    pp                      636.7      ->   633.71    -0.5%
    ttfr                    3242.6 ms  ->   3243.59 ms  +0.0%

The flag took effect — the engine served `temperature 0.6, top_p 0.95,
top_k 20` — and acceptance moved in exactly the predicted direction and by
roughly the predicted kind of amount. Throughput did not follow. 1.4% sits
inside a cell whose own three values span 94.43 to 106.91, which is a 13% range;
the move is not distinguishable from drawing three more samples.

### This breaks the campaign's "tg ≈ 37 × acceptance" relation at fixed depth

decode-tg and depth-curve have both been steering on the idea that decode
throughput is set by accepted tokens per target forward pass, so that `tg`
divided by acceptance length is a near-constant of the machine. depth-curve h1
measured that constant at 37.0, 38.9, 38.5, 36.9, 35.1 across its ladder and
used it to normalise the depth curve. At `d16384` it read **36.9**.

That relation predicts, at fixed depth, that a 4.9% rise in acceptance is a 4.9%
rise in `tg`: 103.7 → 108.8. Taken against depth-curve's constant directly it
predicts 3.22 × 36.9 = **118.8**. We measured **105.12**. In this lane the
quotient is not constant either: it reads 33.8 at h5 and **32.6** here — it
*fell* 3.6% while acceptance rose 4.9%.

So: **at fixed depth, on the board grid, `tg` is not proportional to MTP
acceptance length.** Stated plainly because that relation has been choosing this
campaign's levers and it now has a counterexample.

Two honest qualifications, neither of which rescues the prediction:

- 118.8 is a cross-epoch, cross-protocol number. depth-curve's 36.9 was measured
  under our internal protocol at `max_model_len 32768`; this lane runs arena's
  grid at 262144. The relation may simply have a different constant per lane.
  But the h5→h6 comparison is *within* one lane, one epoch, one schedule, one
  changed flag — and it breaks there too, which is the part that matters.
- 1.4% and 4.9% are both small against this cell's scatter, so what is
  established is a bound, not a slope: whatever `tg` owes to acceptance at fixed
  depth, it is small enough that a 4.9% acceptance gain does not surface. The
  relation survives as a way to *explain away* the prose-driven bumps in a depth
  ladder, where acceptance varies because the corpus varies. It does not survive
  as a lever: buying acceptance did not buy throughput.

The mechanism this suggests is that decode here is bound by the per-step weight
read and the fixed overheads of the speculative cycle — the draft's 286 MB
`lm_head` re-read that h4 closed on, plus three draft passes — and one extra
accepted token in twenty does not move that. h1's per-position rates at
`temperature 0` (0.87/0.76/0.61, implying ~2.93) already hinted the acceptance
axis was short; this measures the payoff on it directly and it is ~0.3 `tg` per
0.01 of acceptance where the relation asks for ~1.1.

### Validity

The run is clean. `crash_count 0`, `failed_indices []`, all 28 cells in
`completed_indices`, one session of 1:56:02. The epoch is **identical** to h5
and to the rest of the tree — vLLM `0.27.2rc1.dev360+ge85d1b69c.d20260821`
(`e85d1b69cf2f1c6101cfc7c799bb0c457cacc4b3`), flashinfer
`4927c0e15cb63a2abb6df09019c39a172222f0eb`, image
`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102` @
`sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990`. No
epoch break, so the h5 comparison above is valid as a within-lane comparison.

Box state over the benchmark window: peak 99.6 W, peak clock 2405 MHz, swap flat
at 784 MB against its 793 MB baseline. Engine: running max 4, waiting max 7, KV
cache max 9.7%, zero preemptions. **The box was never bound** — nothing here was
measured against a limit of the machine.

Prefix cache hit rate: 0.0% max over 552 samples, and `run.py` flags it SUSPECT.
Ninth confirmation of the standing campaign defect. Every figure in this round is
cold-cache, as every figure in h5 was, so the comparison is like for like.

Four requests looped: 1/30 at `d65535 c5`, 1/60 at `d65535 c10`, 2/60 at
`d100000 c10`. All in cells this round already declared unreadable; the rule's
cell is untouched.

### One instrument defect, recorded not chased

Two cells each wrote **one byte-identical duplicate `request_end` line** —
`12-d4096c10` and `27-d100000c10`, both 61 ends against 60 first-token events.
Independently confirmed by two separate counts. This is a writer double-flush,
not a phantom request: a real extra request would have a first-token event and a
distinct payload. Neither cell is the rule's cell, so the verdict rests on clean
data.

This shape has now appeared four times — concurrency h1 run-0003, concurrency h3
`06-d100000c2`, and twice here. That is a harness logging defect worth recording
as a pattern, not a measurement error. Any analysis that counts request records
rather than deduplicating them will over-count by one per affected cell.

### The full board row, for the record

run.py's own mean column, all 28 cells. c5 and c10 at depth >= 8192 are
unreadable under `max_num_seqs 4` and are printed only because the grid asks for
them:

    depth        c1      c2      c5     c10
    d0         93.7   149.3   163.1   166.0
    d4096      97.9   144.7   129.4   106.8
    d8192     112.4   139.8   111.0    78.5
    d16384    102.2   136.4    80.7    49.8
    d32768     99.1   127.8    52.7    25.8
    d65535    102.8   105.2    19.6    10.5
    d100000    87.7    58.2     8.3     5.3

The c1 column tracks h5's within scatter, which is the expected result for a
round that changed one sampling flag.

### Was it worth running?

Yes. It was the cheapest of the four candidates h5 left conflated, it was a
single flag, and it resolved. It cost one run and it closes the sampling axis
*and* puts a counterexample under the acceptance relation — the second of those
was not what the round was bought for and is worth more than the first.

`temperature 0.6` does not earn a place in the recipe: +1.4% inside a ±13%
cell.
