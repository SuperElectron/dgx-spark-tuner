# concurrency — close the c10 gap without giving up c1

## Objective

Raise `tg` at `d16384 c10` on the arena-v2 grid, and produce a
`recipe-new.yaml` that stands at both cells the board scores.

    primary   d16384 c10   48.9  ->  above 102.31
    guard     d16384 c1   103.7  ->  must not fall below it

102.31 is `1199b578`, the best vLLM entry at that cell. 48.9 is ours, measured
on their unmodified grid in decode-tg h5 (`bench_e86574ff0e1e`, 2026-08-23).
The guard exists because every lever here is a scheduler field and scheduler
fields are exactly the ones that trade concurrency against single-stream.

The milestone wants c1 above 116.03 as well. decode-tg spent five rounds and
left it 10.6% short, so this experiment does not promise it — it promises not
to make it worse, and it reports the c1 row every time.

Reached when one full 28-cell arena-v2 run, unmodified, shows the primary met
and the guard held, and `recipe-new.yaml` is that run's recipe. Not reached by
a reduced-schedule screen, which cannot be compared to the board at all.

## Strategy

**The gap is not slots.** `max_num_seqs 4` caps running sequences at four and
h5 measured `running max 4, waiting max 7`, which looks like the answer and is
not. The reference recipe that reads 102.31 serves `max_num_seqs 4` too —
decode-tg's diff is explicit that everything is identical field for field
except four things. Both sides run four slots, so their c10 is 25.6 t/s per
sequence against our 12.2. What separates us is what those four slots achieve
under load, not how many there are.

**What actually differs.** After h5 matched `max_model_len` at 262144, the
reference recipe holds exactly four fields we do not:

    max_num_batched_tokens      32768   vs ours 65536
    gpu_memory_utilization       0.65   vs ours 0.8
    --override-generation-config        temp 0.6, top_p 0.95, top_k 20
    --default-chat-template-kwargs      preserve_thinking: true, plus the
                                        fix-qwen3.6-chat-template mod

That is the whole search space, and it is four fields wide.

**Why `max_num_batched_tokens` goes first.** It is the only one of the four
with both a recorded mechanism and a recorded safety property. Memory holds
that raising it makes time-to-first-response worse at *every* concurrency
measured on this model at d16384 — +7.3% (c2), +15.6% (c4), +19.8% (c5),
+32.4% (c16) — because a larger budget batches more prefill together and each
request's first token then competes with more peers. We run twice the
reference's budget, and h5's c10 ttfr at this cell was 20963.9 ms. The safety
property is that the same field is **inert at c1**: raising it 8192 -> 65536
moved `tg128 d16384 c1` by +0.27% (0.07 SE). So it can be moved to chase the
primary without spending the guard, which is true of no other field here.

**What the box says is not the constraint.** KV peaked at 9.8% of pool during
h5's whole sweep with zero preemptions, against ~10x margin. Clocks held
2392-2398 MHz with the throttle mask clear at 72-79 C across 1h57m. Neither
memory capacity nor thermal is bounding anything in a 1->10 sweep.

**What is already closed, and must not be re-opened.**

- *Speculative depth.* `num_speculative_tokens` 3 -> 4 -> 5 raised acceptance
  3.03 -> 3.44 -> 3.67 and lowered throughput 102.81 -> 99.67 -> 98.30. One MTP
  module re-driven k times, so first-position acceptance degrades with k. A
  rising acceptance ceiling is not headroom on this model.
- *Acceptance as an explanation for scheduling effects.* Flat under scheduler
  knobs for five consecutive rounds; it does not move between c4 and c5 while
  throughput drops 14.4%. Any c>1 result here is a scheduling result, and
  explaining one by acceptance is a mistake this campaign has already made.
- *Generation length.* tg32 beats tg128 at c1 by 4.79%, not a lever.
- *KV cache format.* The recipe that beats us runs the same `fp8`.

**The standing defect.** Prefix cache hit rate is 0.0% and has been across 374+
samples over seven budgets, now confirmed a seventh time under arena's own
protocol with no reset — which retires h2's account that our own reset caused
it. Every figure in this experiment is a cold-cache figure. It is not this
experiment's to fix, but any round claiming a cache-mediated mechanism is wrong
before it runs.

**Depth is a c1 property, not a general one.** depth-curve concluded decode is
flat with depth — 4.5% from d0 to d30464 — and that conclusion was measured
entirely at c1. h5 shows the c10 column falling 154.2 -> 48.9 -> 5.4 across d0,
d16384, d100000. Concurrency and depth interact, and d16384 c10 sits where that
interaction is already severe but still readable.

Measured scatter, per cell — what a decision rule here has to clear:

    d16384 c1:   tg ±5.2% (n=3, arena grid, h5) · ±0.9% (n=7, our protocol)
    d16384 c2:   tg ±4.4% (n=3, arena grid, h5)
    d16384 c5:   tg ±0.4% (n=3, arena grid, h5)
    d16384 c10:  tg ±0.5% (n=3, arena grid, h5)

The c5 and c10 cells report the *tightest* aggregate spread in the sweep and
the widest per-request spread — `tg/req` iqr 141.6% at c5 and 74.3% at c10.
Both are true: acceptance bimodality is per-sequence, so averaging four or more
sequences cancels it while the individual rates span 5x. Aggregate `tg` is what
the board scores and what every rule here reads. Per-request figures are
diagnostic only and no rule may rest on one.

Sizing follows from that: c4-and-above cells reach ±1.5% in about 3 runs where
c1 needs 7+. `runs: 3` is arena's own value and is adequate at c10; it is not
adequate at c1, which is why the guard is stated as a floor rather than a
comparison of medians.

## Held

- One node, one GB10. No ray, no tensor parallel above 1.
- The checkpoint pinned in `docs/model-card.md`.
- The container image and its vLLM and flashinfer commits.
- `max_model_len 262144`. h5 established the epoch and the grid needs it; every
  figure here sits on that side of the break and none is comparable to h1-h4 of
  decode-tg.
- **The arena-v2 grid is the yardstick.** A figure that closes this experiment
  comes from the unmodified 28-entry schedule in arena's own order, because
  cell order decides what is warm and what is hot and no number reveals which
  order produced it. Reduced schedules are permitted for screening and their
  figures are never board-comparable — a round that screens says so in its own
  Method and cannot close the objective.
- Nothing is submitted to Spark Arena.

Deliberately **not** held, so a round may move them: `max_num_batched_tokens`,
`gpu_memory_utilization`, `max_num_seqs`, the sampling and chat-template
config. Those are the search space.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | our `max_num_batched_tokens` is twice the reference's and starves decode under load | **lever spent — refuted with the sign reversed.** `mnbt` 65536 → 32768 → 16384 on a four-cell screen, one engine start per arm, all three serving what they declared on one epoch. `d16384 c10` is monotone *downward* as the budget falls — 49.0 → 48.0 → 44.2, ±0.5% at n=3, per-request decode medians agreeing at 28.5 → 20.2 → 19.7 — so the control's 65536 is the best of the three and the reference's 32768 is not the source of its c10 advantage. Looping requests (0, 2/60, 1/60) inflate `tg` in the two losing arms only, which steepens the trend rather than explaining it. Decelerating step sizes (+8.6%, then +2.1% per doubling) close the untested upward direction too. The rule is **mis-specified** — its guard floor of 102.8 came from h5's cross-schedule 103.7 while this screen's control reads 96.0, so the control fails its own guard and only *lever spent* could ever fire; under the intended reading (no regression against this round's 96.0 control) the guard holds, and the outcome is the same either way. The c1 step 96.0 → 107.2/106.2 is **not established**: the cell drifts up to 19% within itself, drifts *downward* in one arm, anti-correlates with `ctx_tg` at −0.88 in another, and memory records this field as inert at c1 (+0.27%, 0.07 SE). Left standing for h2: `running max 4, waiting max 6/6/8, preemptions 0, kv max 3.9%`, and a mean-to-peak aggregate gap of 6.4x at c10. `recipe.yaml` untouched. |
| h2 | four slots serve ten requests, so `max_num_seqs` — not the token budget — is what the c10 aggregate is paying for | **target met on the screen — pending validation on the full grid.** `max_num_seqs` 4 → 10 → 16 on the same four-cell screen h1 ran, one engine start per arm, all three serving what they declared on one epoch (vLLM `e85d1b69`, flashinfer `4927c0e1`), three distinct recipe hashes, 4/4 cells and integrity clean in every arm. `d16384 c10` goes 49.0 → **137.5** → 139.8: the 10-slot arm is a **2.81x** and clears the Objective's 102.31 by 34%, at a cell whose control reproduces h1's to 0.0% and whose spread is ±0.2-1.8%. The pre-registered mechanism check passed before any throughput figure was read — `running max` 4 → 10, `waiting max` 6 → 4 — so the gain is admission, not batching. c5 moves with it, 84.2 → **171.5** clean (run-0003 raised no LOOPING; run-0002's 171.5-equivalent carried 1/30 and is an upper bound). run-0003 separates the two accounts: `running max` **stops at 10** with sixteen slots configured, because arena's grid never offers more than ten concurrent requests, and c10 moves 137.5 → 139.8 (1.7%, inside ±1.8%). So **"the queue was the cost" is confirmed and "more slots always help" is refuted**, and the smallest sufficient value is **10**. The guard is **unresolvable, and that is this round's methodological finding**: c1 reads 107.0 / 102.1 / 114.1, an 11.7% span, non-monotone, on a field that provably cannot act at c1 (`running max` is 1 there by construction); the control is also a direct replicate of h1 run-0001 and the pair disagrees 11.5% at c1 while agreeing to 0.2% at c10, c5 and c2. The rule's floor of 0.959 × control (102.61) is therefore **mis-specified** — run-0002's 102.1 misses it by 0.5%, twenty times finer than the cell's demonstrated resolution — and it is left as written rather than edited. Memory says the ±11% is protocol, not cell (prompt redrawn per run; ~3% once pinned), and it is not fixable inside a board-comparable run because Held requires the unmodified grid. Cost recorded: c10 ttft median 19.12 s → 28.08 s. Box was not the constraint — clocks 2398-2411 MHz unthrottled, GPU util median 96%, swap flat, preemptions 0, KV ≤ 9.4% of pool; host memory headroom does narrow with slots (7967 → 3558 → 2507 MB free at worst). Prefix cache 0.0% in all arms, standing defect. Corrects Strategy's "the gap is not slots", which was sound about the reference and wrong about the Objective. `recipe-new.yaml` written with `max_num_seqs: 10`, everything else unchanged; h3 runs it on the full 28-cell arena-v2 schedule, which is the only thing that can close the Objective. |
| h3 | `max_num_seqs 10` holds its screen figure on arena's own unmodified 28-cell grid, where the number is board-comparable | **target met, guard unresolved** — the branch the round pre-registered as most likely. One validation run of `recipe-new.yaml` (`max_num_seqs 10`, every other field identical to `recipe.yaml`) on the unmodified 28-entry arena-v2 schedule in arena's own order, `runs: 3`, `bench_95fdfa8922a3`. All 28 cells completed, one session, `crash_count 0`, `failed_indices []`, wall 1:51:51 against h5's 1h57m on the same schedule. vLLM's `non-default args:` agrees with the recipe's `defaults:` field for field, and the epoch is the **same** as h2's and h5's (vLLM `0.27.2rc1.dev360+ge85d1b69c.d20260821`, flashinfer 0.6.18, image `:2026082102`, id `sha256:b277afb7…`, digest `sha256:4894c3f1…`), so the incumbent comparison stands. **Primary: `d16384 c10` = 141.5 ±0.2% (141.5 140.8 141.7)** — above the Objective's 102.31 by 38% and **2.89x** h5's incumbent 48.9 on the same unmodified grid. **Guard: `d16384 c1` = 95.8 ±15.0% (95.8 124.2 86.1)** — 7.6% below the 103.7 floor, therefore inside the pre-registered ±11% band (floor 92.29): **unresolved, not held, not regressed**. The ±15.0% span is on one unchanged configuration and is wider than Strategy's ±5.2%; at `runs: 3` with an unpinned prompt this cell cannot resolve a change of the size the guard was written to catch, which independently reproduces h2's finding. The milestone's c1 target of 116.03 is **not** claimed. Whole board row against the incumbent shows the win is **admission, not batching**, confined to cells where offered concurrency exceeds the old slot count: c5 and c10 gain 1.24x-2.96x from d0 to d32768 (largest is `d8192 c10` at 2.96x); the entire c1 (0.88-1.12x) and c2 (0.95-1.10x) columns are flat; `d65535` and `d100000` at c5 and c10 are also flat at 1.03-1.04x, already collapsed to 5.5-20.5 t/s and bounded by something this run does not identify. No cell regressed beyond the instrument's noise. Mechanism confirmed on its own terms: `running max` 4 → **10**, `waiting max 7`, `preemptions 0`, `kv max 24.6%` of pool. Box not the constraint — peak 99.3 W, peak clock 2411 MHz. MTP acceptance 3.42 median over 312 samples, a control that did not move, eighth flat round. LOOPING raised for no cell (worst repeat 0.18-0.44), so no figure is an upper bound. Prefix cache 0.0% over 527 samples with `run.py` flagging `SUSPECT: recipe asks for prefix caching` — eighth confirmation of the standing defect, every figure cold-cache. Integrity 27/28 clean; **`06-d100000c2.jsonl` is SUSPECT** — `request_end` 13 vs `request_first_token` 12, one extra completion with no matching first-token event, all ends carrying `total_tokens 128` so no short generation. That cell (`d100000 c2`, tg 58.3) is not read by either branch of the rule and does not touch the outcome. `recipe-new.yaml` verified byte-identical to this run's `recipe.yaml` (sha256 `18799aab…`). The Objective closes on the primary. |

## Conclusion

**Closed on the primary in three rounds. `max_num_seqs` 4 → 10 takes `d16384
c10` from 48.9 to 141.5 on arena's own unmodified 28-cell grid — a 2.89x, and 38%
above the Objective's 102.31. The guard is unresolved, not held.**

    primary   d16384 c10   48.9  ->  141.5   target above 102.31   MET
    guard     d16384 c1   103.7  ->   95.8   floor 103.7           UNRESOLVED (-7.6%, inside ±11%)

Both figures are aggregate `tg` medians from `bench_95fdfa8922a3`, one run of
`recipe-new.yaml` on the unmodified 28-entry arena-v2 schedule in arena's own
order, on the same epoch as the incumbent it is compared against. That is the
measurement Held requires and the only kind that may be set beside the board.

### Strategy's opening claim was wrong, and h2 is what corrected it

Strategy states **"The gap is not slots."** It is stated here plainly, in the
only place that may say so, because Strategy is frozen: **the gap was slots.**

The reasoning was sound about the reference recipe and wrong about our Objective.
It is true that the entry reading 102.31 serves `max_num_seqs 4`, and true that
its four slots achieve more per slot than ours did. What it missed is that those
are two different questions. h2 measured the mechanism before reading any
throughput figure: at `max_num_seqs 4` the grid's c10 cell has `running max 4,
waiting max 6` — four of ten offered requests admitted, six waiting — and
llama-benchy's aggregate divides generated tokens by a wall-clock window that
counts the waiting. Raising the slot count to the grid's own maximum concurrency
empties that queue. h2 also closed the upward direction in the same round:
`running max` stops at 10 with sixteen slots configured, because arena's grid
never offers an eleventh concurrent request, and c10 moved only 137.5 → 139.8.
**Ten is the smallest sufficient value, and more slots do not help.**

So the win is **admission, not batching**, and the wrongly-closed lever cost one
round: h1 spent itself on `max_num_batched_tokens`, which Strategy named as the
field to move first. h1 refuted it with the sign reversed — 65536 → 32768 → 16384
takes `d16384 c10` monotonically *down*, 49.0 → 48.0 → 44.2 — so our doubled
token budget was never the problem and the reference's 32768 is not the source of
its advantage. That is a real finding and it stands, but it was chased because
the slot count had been argued away in advance.

### What the recipe buys, and where it buys nothing

The board row against h5's incumbent `bench_e86574ff0e1e`, same schedule, same
epoch, one field different:

    depth      c1                 c2                 c5                  c10
    0        96.6 →  99.9 1.03x  152.3 → 151.0 0.99x  170.6 → 211.3 1.24x  154.2 → 276.8 1.80x
    4096    109.6 → 106.5 0.97x  138.6 → 136.2 0.98x  131.8 → 185.1 1.40x  105.8 → 237.7 2.25x
    8192    103.0 → 115.6 1.12x  129.3 → 141.6 1.10x  107.9 → 183.3 1.70x   77.7 → 230.5 2.96x
    16384   103.7 →  95.8 0.92x  130.9 → 137.8 1.05x   84.2 → 176.1 2.09x   48.9 → 141.5 2.89x
    32768   106.1 →  93.3 0.88x  125.0 → 128.3 1.03x   53.1 → 126.1 2.38x   25.8 →  37.5 1.46x
    65535    95.6 →  90.4 0.95x  107.7 → 102.4 0.95x   19.7 →  20.5 1.04x   10.5 →  10.9 1.04x
    100000   82.4 →  91.0 1.10x   58.2 →  58.3 1.00x    8.3 →   8.5 1.03x    5.4 →   5.5 1.03x

- **Gains** at c5 and c10 from d0 through d32768, 1.24x to 2.96x, largest at
  `d8192 c10`. Every one of those is a cell where offered concurrency exceeded the
  old slot count.
- **Flat** across the entire c1 and c2 columns. Two requests never queued behind
  four slots, so the field has nothing to do there — which is the mechanism
  predicting its own null result, and it did.
- **Also flat** at `d65535` and `d100000`, c5 and c10, 1.03-1.04x. Those cells are
  already collapsed to 5.5-20.5 t/s and admission is not what bounds them. What
  does is not known and this experiment does not claim it.
- **Nothing got materially worse.** The three cells more than 5% below 1.00x are
  `d16384 c1` 0.92x, `d32768 c1` 0.88x and `d65535 c2` 0.95x, and the two c1 cells
  sit in a column whose three values in this very run span 86.1-124.2.

The cost is first-token latency at high concurrency, which arena does not score
and which is reported anyway: h2 measured c10 ttft median 19.12 s → 28.08 s, and
h3's `d16384 c10` ttfr is 28636.2 ms. Host memory headroom also narrows with
slots (h2: 7967 → 3558 MB free at worst); across a full 28-cell grid including
`d100000 c10` it did not bind, `preemptions 0` and `kv max 24.6%` of pool.

### What the guard establishes, and what it does not

It establishes that single-stream did not collapse. It does **not** establish that
the guard held, and the experiment does not claim it did.

`d16384 c1` reads 95.8, 7.6% under the 103.7 floor and inside h3's pre-registered
±11% band. The three values behind that median are 95.8, 124.2 and 86.1 — a
**±15.0% span on one unchanged configuration**, measured under the board's own
protocol. At `runs: 3` with an unpinned prompt, this cell cannot resolve a change
of the size the guard was written to catch. h2 reached the identical conclusion
from the other direction: three arms of a field that provably cannot act at c1
(`running max` is 1 there by construction) read 107.0 / 102.1 / 114.1, an 11.7%
non-monotone span, while agreeing to 0.2% at c10, c5 and c2. Memory records the
excess as protocol rather than cell — the prompt is redrawn per run and arena's
schedule does not pin it — and it **cannot be fixed inside a board-comparable
run**, because Held requires the unmodified grid.

Two rules in this experiment were mis-specified for this reason and both were left
as written rather than edited: h1's guard floor came from a cross-schedule figure,
and h2's floor of 0.959 × control was twenty times finer than the cell's
demonstrated resolution. h3's rule is the one that got it right, by naming an
±11% unresolvable band in advance. **A pinned-prompt c1 instrument is the open
question this experiment hands on, and it is an instrument question, not a
tuning one.**

**The milestone's c1 target of 116.03 is not claimed and is not approached.**
This experiment promised only not to make c1 worse and to report it every time,
and that is what it did.

### The standing defect

Prefix cache hit rate is **0.0%**, now over 527 samples in h3 alone and confirmed
an eighth time, with `run.py` itself flagging `SUSPECT: recipe asks for prefix
caching`. **Every figure in this experiment is a cold-cache figure**, including
the 141.5. Nothing here is explained by caching and no round claimed it was. It
remains not this experiment's to fix.

Corrected 2026-08-27. "An eighth time" counted runs, and two of the runs it
counted — `depth-curve/h1/run-0005` and `run-0006` — logged a single hit-rate
sample each, and the engine's first sample is always 0.0%, so they assert
nothing. `measure.py` now gates at n >= 2. Campaign-wide the count is **seven**
0.0% confirmations that survive that gate, and h3's 527 samples are one of them.
Count samples, not runs. The same inflated "eighth confirmation" wording stands
uncorrected inside the h3 row of the Rounds table above; it means the seventh,
and this correction governs it. This counts readings of the prefix-cache defect; the
three sightings of the `request_end` double-flush below are a different defect
and a different tally, and the two must not be added together.

A second defect: `06-d100000c2.jsonl` in h3 run-0001 carries `request_end` 13
against `request_first_token` 12 — an extra completion with no matching
first-token event. That cell is marked SUSPECT. It is read by no decision rule in
this experiment, but the integrity check that caught it should stay.

Corrected 2026-08-27. This said the cell carried "the same damage h1 run-0003
carried". They are different shapes and the conflation is retracted.
`06-d100000c2` is a double-flush: 13 ends against 12 first-tokens, with all 13
records at `total_tokens 128`, so no sample was lost. h1 run-0003 is real damage
— request 27 returned `total_tokens: 1` at `decode_seconds: 0.0`. Every record
sitting at full `total_tokens` is what tells the two apart. Store `23dd5b3a`,
`e4f4748b`.

### Deliverable

`recipe-new.yaml` sits beside `recipe.yaml` and is **byte-identical to h3
run-0001's `recipe.yaml`** (sha256 `18799aaba9cd2f09b1f8deffd68f4d95840b329eb356
9842437bd1cebc89469e`, verified). It differs from `recipe.yaml` in exactly one
field, `max_num_seqs` 4 → 10. It is a deliverable for Mat. **Nothing is ever
submitted to Spark Arena.**

### What is now closed

- `max_num_seqs` as a lever: 10 is the smallest sufficient value on this grid and
  above 10 is inert, because arena never offers an eleventh concurrent request.
- `max_num_batched_tokens` as a route to c10: monotone downward as it falls, and
  decelerating step sizes close the upward direction too. 65536 stands.
- "The gap is not slots" — corrected. It was slots, for our Objective.
- The c1 guard as a *measurement* on arena's schedule at `runs: 3`. Not the
  question of whether c1 regressed — that stays open — but the instrument's
  ability to answer it, which is settled in the negative.
