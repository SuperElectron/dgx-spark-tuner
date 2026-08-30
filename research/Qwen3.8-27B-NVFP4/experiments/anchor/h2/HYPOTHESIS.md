# h2 — `max_num_batched_tokens`, the field h1 caught gating admission

## Verdict

<one line, filled at conclusion: TARGET MET / LEVER ALIVE / LEVER SPENT — the
number that decided it>

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | max_num_batched_tokens: 16384 -> 32768 | h1: engine ran 10 / waited 9 with max_num_seqs 256, so mnbt gated admission against a per-request prefill of 18432; 32768 is the twin's own value | d16384 c10 | 129.36 | 14.37 | 151281.3 | bench_40cfbf2570f2 |
| run-0002 | max_num_batched_tokens: 16384 -> 65536 | run-0001 at 32768 drained the queue (waiting 0 in 52% of c10 frames) but bought only +28%; 65536 tests whether the residual admission ramp 5/5->7/3->9/1->10/0 is still costing aggregate tg | d16384 c10 | 127.37 | 36.56 | 157259.87 | bench_c724e36d03cb |
| run-0003 | max_num_batched_tokens: 16384 -> 131072 | run-0002 at 65536 removed the admission ramp and took the cell 14.37 -> 36.56, still climbing. CRASHED: box lost 10m18s after engine start, during the FlashInfer autotune for the new budget. sshd and tailscaled died with it, so a whole-host loss, not an engine exception — the signature of host memory exhaustion on unified memory. No engine log, no archive, no figures | d16384 c10 | — | — | — | — |
| run-0004 | max_num_batched_tokens: 16384 -> 98304 | run-0002 at 65536 read 36.56 and was still climbing; 98304 was the largest budget below the one that killed the box. CRASHED THE SAME WAY, but this time instrumented: engine completed KV sizing (50.8 GiB, 1433737 tokens, max concurrency 5.47x) then died inside the FlashInfer fp4_gemm autotune — a single ~20 GB step allocation took host available from 20431 MB to 620 MB between two 10s polls, then 119 NV_ERR_NO_MEMORY driver failures | d16384 c10 | — | — | — | — |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Raising `max_num_batched_tokens` off 16384 lifts `tg128 @ d16384 c10` above
22.5 t/s, because at 16384 the cell cannot batch at all.

Mechanism, measured in h1 and not inferred: the engine held max running 10 /
max waiting 9 while `max_num_seqs` resolved to 256, so seats were never the
constraint. One request's prefill here is depth+pp = 18432 tokens, which does
not fit a 16384 budget — so requests are served head-of-line, and h1 saw that
signature: per-request tg spanning 10x, thirty ttfr values in ten discrete
arrival tiers. This is the twin's first delta: `sub1786821875313` runs 32768
and reads 63.05.

Worth, if right: full admission needs c*(depth+pp) = 184320 tokens, and the
tree holds that the budget saturates near where that fits in about two
scheduler steps (~92160) and is flat past it — so the arms bracket the knee.
The roofline ceiling at c10 is 84 t/s against an Objective of 72.5, so this
lever alone can carry the round if the collapse is purely admission.

## Method

### Variables to test

    max_num_batched_tokens: 32768, 65536, 131072

Order: ascending. 32768 first — it is the twin's own value, so it is the arm
that tests the twin's recipe rather than our theory of it. Stop early only if
an arm exceeds 72.5.

### Constant for this round

Everything else in `recipe.yaml`. `max_num_seqs` stays unset, as the two
fastest like-for-like board entries leave it. `max_model_len` stays 262144
even though h1 flagged it — the engine computes max concurrency 7.12x there,
below the offered 10 — so this round moves one field; it is h3's arm if this
one does not close the Objective.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 16384 · concurrency 1, 10 · runs 3

Not the 28-cell grid: h1 has placed us on it and this round needs one cell.
c1 rides along as a null control — the tree holds this lever structurally
inert at c1, so an arm that moves c1 is measuring something else.

Recorded, not scored: running/waiting frames per arm, engine start time (each
new budget costs a torch.compile rebuild), ttfr (it worsens at every budget
increase on this stack), MTP acceptance.

## Decision rule

Read on the **median** at `tg128 @ d16384 c10`, best arm.

- **Target met** — ≥ 72.5 t/s.
- **Lever alive** — 22.5 to 72.5 t/s, *and* the best arm is 131072. The budget
  is still buying and h2 gets more arms above 131072.
- **Lever spent** — under 22.5 t/s at every arm, or the best arm is 32768 or
  65536 with the arms above it within 3% of it. Either the collapse is not
  admission, or the budget has saturated below the target; h3 opens on
  `max_model_len` 131072 instead.

Sizing: 22.5 is 2x h1's 11.22. Our own measured c10 band is 0.9% of median
(h1, three runs), so 3% is a comfortable multiple of it and 2x is far outside
anything scatter can produce. The imported 15% prior is retired for c10.

## Conclusion

<pending>

Budget: 15 lines — the verdict, the deciding figure, what varied, one line of
why. Everything else goes to the memory store.
