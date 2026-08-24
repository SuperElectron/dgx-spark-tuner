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
| h3 | `max_num_seqs 10` holds its screen figure on arena's own unmodified 28-cell grid, where the number is board-comparable | <pending> |

## Conclusion

<pending — written when the objective is reached or the levers are exhausted>
