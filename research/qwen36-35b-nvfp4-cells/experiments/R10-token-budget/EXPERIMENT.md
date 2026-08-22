# R10 — the token-budget round at c4 and c16

objective: measure what raising `max_num_batched_tokens` is worth once R07 and R09 both found the budget gating admission, and settle whether residency is what sets the aggregate ceiling. `tg128 @ d16384`, c4 and c16, runs=7, one engine start.
claim: stated as arithmetic rather than as a story. At d16384 a request's prefill is 16384 tokens, so a scheduler step at 8192 fits *half* of one prefill and at 32768 fits *two whole ones* — a 4x admission rate, and that is the entire intervention. Decode is not involved: sixteen resident sequences drafting 3 MTP tokens each need ~64 tokens per step, three orders of magnitude under either budget. The budget has never gated decode in this campaign; it gates the rate at which requests are let in. 32768 does not admit all sixteen either — that would take 262144 — so even the raised setting is admission-rate-limited at c16.
variables: `max_num_batched_tokens` raised 8192 → 32768, a MUTATION, not folded into `recipe.yaml`, with every row it produces named as tuned. `concurrency` 4 and 16 in one invocation.
confirms / refutes: `peak_throughput` at c16 above 500 (+13.6%) reads **H_gate** — the gate is a steady-state one and residency is the binding constraint, predicting ~590. Below 470 (+6.8%) reads **H_ramp** — the budget throttled only the ramp and R07's ~440 stands. 470–500 is indeterminate and will be reported as indeterminate. Fourteen further numeric bands were declared. Nothing here can be scored: the board has no c16 figure and c4 sits behind the unresolved units dispute. Two zero-cost ride-alongs: capture MTP acceptance from the engine log, and **read llama-benchy 0.4.0's own definition of `tg_throughput`** — the campaign had been inferring that metric's meaning for nine rounds and nobody had read the source.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_860b43edd154 | 2026-08-22T08:35:21Z | mnbt 32768 at c4 and c16, one engine start, runs=7 each | c4 tg 147.25 (peak 284), c16 tg 53.45 (peak 515); ctx_tg 126.35 and 54.54; scheduler at c4 reads (4,0) in 13 of 13 loaded samples, at c16 Running median 11 / Waiting median 5 |

## conclusion 2026-08-22T08:53:50Z
**The round's biggest result cost no box time, and it is a rebuke to nine rounds of
inference.** The ride-along that was supposed to be a nicety is the headline:
`results.py` lines 194 and 352 define `batch_tg_throughput = observed_decode_tokens /
(max_last_token − min_first_token)` and select it whenever `concurrency > 1`. **At
`c>1` the headline field is a BATCH AGGREGATE**, not a per-request rate. R02's units
reading, R07's 4.53x alternative, and the `aggregate = per-request x c` convention
used from R02 to R09 all fall together — the convention double-counts an
already-aggregate metric, which is the whole of why it kept exceeding
`peak_throughput`.

The standings follow immediately, and the campaign's thinnest win is no longer thin:
`tg128 @ d16384 c4` goes 52.85 → 147.25, **1.13x → 3.15x**, with the worst of seven
runs still 2.94x. It reproduces R09's raised-budget figure of 143.08 to +2.9% from a
separate engine start with a different scheduler width, so that startling figure was
real and `max_num_seqs` comfortably above `c` is neutral. `ctx_tg @ d16384 c4` goes
2.04x → 4.56x. And the two "units disputed" cells resolve as honest **losses** — c2
0.51x and c5 0.21x against the board's own Qwen3.6-35B-A3B-NVFP4-on-vLLM entries.
Same model, same runtime, same quant, same metric, so that gap is entirely config,
and this round shows what most of it is.

The declared hypothesis lands on **H_gate**, but only just: `peak_throughput` at c16
measured 515 against a 500 line, clearing it robustly on the median though not on
every run. The proportionality it predicted holds well — residency at peak went
11.89 → 14.31 of 16 (+20.4%) while `peak_throughput` went 440 → 515 (+17.0%), and
scaling R07's figure by the residency ratio predicts 530 against 515 measured. **Residency
is what sets the aggregate ceiling**, which is the cleanest thing the round
establishes about the hardware.

⚠ But three occupancy predictions missed together, and the round records why: the
scheduler reads Running median 11 against a predicted 13–16 and Waiting median 5
against 0–3. c16 is better and still gated — exactly what the round's own arithmetic
said before it ran, after which the round wrote a prediction band that ignored that
arithmetic. **The mechanism section was right and the prediction table was wrong, in
the same document**, because the bands were set by scaling R07's numbers while the
model that generated them sat one paragraph above. c4, by contrast, is a clean (4,0)
in 100% of loaded samples — the gate is genuinely gone there, which is why c4 gets
the big number and c16 does not.

The trade-off is explicit and belongs on every row the mutation produces. What got
better: aggregate throughput, decisively, at both concurrencies. What got worse:
latency. The counter-intuitive ttfr prediction held — 39389 ms against R07's 29751,
+32.4% — because a larger budget batches more prefill work together, so each request's
first token comes later even though the batch as a whole finishes sooner. **c16 is a
39-second time-to-first-response cell: excellent for aggregate work, useless for
latency.** Variance also rose at c4 (σ/med 3.25% against R09's 1.10% at the shipped
budget). MTP acceptance is flat when the budget moves, at both concurrencies (3.07 /
69.1% at c16, 3.02 / 67.3% at c4), so **the entire effect is scheduling** — and with
R09's c4-versus-c5 result, acceptance is now ruled out as an explanation for anything
the scheduler does. The mutation was NOT folded.

⚠ Superseded on its mechanism, not on its numbers. This round's explanation for
every `c>1` result — "the `c>1` gap is admission stagger, and it is 83–93% of what
remains" — was **refuted by R13 with the instrument**: at mnbt 98304 the scheduler
reads `Waiting: 0` in 100% of loaded samples and the span ratio barely moves. R13c
confirmed it independently. The ratio is real and charged to the metric; calling it
*admission* is what is withdrawn, and the replacement is prefill-completion stagger.
R10's account of the ctx-versus-Phase-2 sign flip ("the `ctx_` phase does no prefill,
so it never staggers much") was withdrawn at the premise by the phase-label
correction: Phase 1 prefills `depth` tokens. R07's "ctx margin grows monotonically
with concurrency" is dead here too — the sign flips at c4 and c5 on the token budget
alone. Implication for the next hypothesis: take the raised budget to the two cells
the campaign is losing, c2 and c5.
