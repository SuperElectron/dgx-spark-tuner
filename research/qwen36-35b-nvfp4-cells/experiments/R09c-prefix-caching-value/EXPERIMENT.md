# R09c — why is `--enable-prefix-caching` worth a large multiplier when it never hits?

objective: explain the campaign's sharpest open mechanism. At `tg128 @ d16384 c4`, prefix caching ON reads `tg` 143.08 and OFF reads 62.13 — a 2.30x swing — while `peak_throughput` is 297 in both, identical to the token, `pp2048` moves 0.8%, total prompt tokens processed moves 1.7%, and the cache hit rate is 0.0% in both. No prefill work is saved and no hardware ceiling moves.
claim: the effect lives in how dispersed the four prefills finish, not in throughput. Under `mamba_cache_mode: align`, chunked prefill must break at `mamba_block_size` (2144) boundaries so states land on block edges, forcing the four prefills to interleave in fixed-size pieces and finish together. Under `none` the granularity is 32768 — larger than the whole 18432-token prefill — so the constraint is vacuous and prefills run greedily to completion one at a time. ⚠ **Two things were settled by reading the pinned image before an engine start was spent.** R09c as queued was NOT runnable: `vllm/config/vllm.py:2607-2618` refuses `mamba_block_size` unless prefix caching is on, so the queued arm would have died before the engine loaded. `--block-size` is the one legal lever that moves mamba granularity, and it reaches 32768 from the ON side.
variables: `mamba_block_size` raised 2144 → 32768 via `--block-size` with prefix caching ON (the test); against prefix caching ON at the default granularity, and prefix caching OFF, as the two endpoints. All at `mnbt 32768`, `mns 4`, c4, runs=7. ⚠ **THE CONFOUND, STATED UP FRONT:** `--block-size` moves the *attention* page size along with mamba granularity — under `align` they are the same number by construction and no flag separates them — so this tests granularity as a bundle, not mamba specifically, and the outcome must not claim otherwise. ⚠ Both endpoints are re-measured in this session rather than quoted from the archive, because R11 folded `mnbt 65536` and the recipe no longer reproduces R09/R09b's condition.
confirms / refutes: primary instrument is the span ratio, because that is where 86% of the effect lives. `R_span = span(G) / span(P)` above 1.70 confirms granularity as the mechanism; below 1.25 refutes it and the effect belongs to `align` itself. Between 1.25 and 1.70 both contribute and neither is claimed.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_30d6586cc70a-p-pc-on | 2026-08-22T13:38:08Z | prefix caching ON, mamba_block_size 2144 (control) | tg 146.32, tg_req 58.78, span 1.607, peak 287, ttfr spread 1516 ms |
| bench_76bccce3d8b3-g-block32768 | 2026-08-22T13:30:10Z | block size raised to 32768, caching ON | tg 54.05, tg_req 29.49, span 2.183, peak 291, ttfr spread 7460 ms; engine-log capture produced only three lines |
| bench_76bccce3d8b3-g-block32768-repeat | 2026-08-22T13:51:50Z | identical repeat, for the gate evidence and a 14-run pooled figure | tg 53.07, span 2.184, peak 286; pooled 14-run median 53.46 |
| bench_107f95223a60-n-pc-off | 2026-08-22T13:44:56Z | prefix caching OFF (control) | tg 60.60, tg_req 50.68, span 3.346, peak 289, ttfr spread 6269 ms |

## conclusion 2026-08-22T13:58:25Z
**A declared non-result rather than a finding, and the round reports it as one.**
`R_span` measured 1.359 — inside the dead zone the hypothesis itself named — so the
granularity hypothesis is neither confirmed nor refuted, and by the round's own rule
neither is claimed. Worse for the round and better for the record: the deciding
invocation turned out to be confounded in a way the hypothesis did not predict, and
the confound is large enough that it could not have settled the question even had it
landed cleanly.

What the round did buy is the endpoints, and that is its most reusable result. Both
reproduced closely from runs=3 to runs=7 inside one session on one idle box, instead
of being quoted across four hours and a config epoch: prefix caching ON +2.27%, OFF
−2.46%, with span ratios moving −0.68% and +0.94%. **So the prefix-caching effect is
real, bigger than R09b thought, and now rests on 14 runs instead of 6: `tg` 146.32
against 60.60 = 2.414x**, superseding R09b's "worth 57% of `tg`", which was two
three-run medians taken four hours and one engine start apart. The direction was
right and the size was a cross-invocation artefact of exactly the kind the campaign
had already refuted three times.

The mechanism decomposition closes exactly on the campaign's own identity, and it
shows the two effects are **opposites, not the same effect wearing different hats**.
Turning prefix caching off costs 83% batch span and 17% per-request decode. Raising
the block size with caching on costs 70% *decode* and 30% span. So the flag is not
buying cache hits (it never hits), is not buying hardware (0.7% on the ceiling), and
is not buying decode rate — it is buying **prefill-completion alignment**, and that
is the whole of its 2.414x. In the caching-off arm one request in four returns its
first token at ~6.2 s while the other three return at ~12.3 s; with caching on the
same batch spans 10.6–12.2 s. The trade-off is therefore that the flag costs nothing
measurable and buys a tighter batch span — but the granularity lever that was
supposed to explain *why* is not separable from attention page size in this engine,
so the round leaves the mechanism one step short.

⚠ **A third refusal is recorded rather than dropped**, and it is the round's cheapest
result: the arm the queue specified would have died at config validation. It was
caught by grepping the validators out of the pinned image before any box time was
spent — R09's open-question-11 rule, and the third consecutive round it has paid. The
general lesson is the reusable half: an arm a validator will refuse should be caught
at the queue, not at the engine start. R09b's leading suspect is also corrected here,
by two orders of magnitude — `platforms/interface.py:911-918` overwrites the 16 with
the aligned attention block size, so the true contrast is 2144 → 32768, 15.3x, and
**no round ever ran under the 2048x condition; it never reached the engine.**

⚠ And the downward-reproduction systematic breaks. The campaign recorded 8 of 8
protected rows reproducing low, mean −1.88%, with a "p ≈ 3% on a coin" argument. Arm
P reproduced **+2.27% HIGH** — the first same-cell repeat in the campaign to do so —
while arm N reproduced −2.46% low in the same hour on the same box. Two measurements
minutes apart moving in opposite directions by about the same amount is what a
**±2.5% reproduction noise floor** looks like, not what a systematic looks like.
⚠ Superseded in turn by R23, which measured the arm-to-arm spread on identical
configurations at about ±5% — so R09c's ±2.5% floor is itself an underestimate,
though a symmetric one. Implication for the next hypothesis: the span floor is the
thing to attack, and it needs per-request measurement rather than batch aggregates.
