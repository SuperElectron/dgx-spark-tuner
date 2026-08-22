# R09b — the chunked-prefill mechanism test, bought at the price of prefix caching

objective: run the invocation R09 could not — chunked prefill genuinely OFF — and decide whether R04's inferred interference mechanism is what costs the c5 deficit. `tg128 @ d16384`, c4 and c5, runs=3, one engine start per setting.
claim: R04 inferred that a queued fifth request's prefill is chunked into ongoing decode steps, so prefill and decode interleave and both are charged for it. R09 confirmed the deficit is real inside one invocation and reproduced the depressed prefill row to 0.25%, but could not turn the chunking off — `mamba_cache_mode 'align'` requires it. Disabling prefix caching drops the cache mode to `none`, which unblocks the flag. ⚠ The price is stated plainly before the run: the `ctx_` rows are forfeit in both settings, and **nothing here transfers to the campaign config**, which runs prefix caching ON. A refutation is the more useful outcome and the round expects one — R07 already found that matching `max_num_seqs` at c8 and c16 left `pp2048` dead inside the flat series, which prefers queueing over chunking.
variables: prefix caching turned OFF in both invocations (a price, not the test), `max_num_batched_tokens` 32768, `max_num_seqs 4`; then chunked prefill ON in one and OFF in the other. Both are three flags from the campaign config, not one.
confirms / refutes: `R_x = D_x(chunk OFF) / D_x(chunk ON)` on within-invocation c5-versus-c4 deficits. **H_chunk CONFIRMED** if `R_pp < 0.25` AND `R_req < 0.60`; **REFUTED** if `R_pp > 0.60`, in which case the rival account is plain queueing. Anything else is reported as mixed, not forced. **VALIDITY GATE, declared in advance:** `ctx_pp2048 < 1200` in both invocations or the round is VOID — with caching genuinely off there is no cache for Phase 1 to hit.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_9379c15468ec-a-chunk | 2026-08-22T09:36:43Z | prefix caching off, chunked prefill ON | c4 tg 62.13 (tg_req 51.49, stagger 3.32), c5 tg 50.28; pp2048 663.93 / 597.78; D_pp −9.96% |
| bench_10496035f7fd-b-nochunk | 2026-08-22T09:51:47Z | prefix caching off, chunked prefill OFF | c4 tg 52.92 (tg_req 28.74, stagger 2.17), c5 tg 45.28; pp2048 655.82 / 584.04; D_pp −10.95% |

## conclusion 2026-08-22T09:57:32Z
**H_chunk is REFUTED on the round's own pre-declared rule**, and the primary
instrument does not merely fail to clear the bar — it points the wrong way.
`R_pp = 1.099`: the c5-versus-c4 prefill deficit is *slightly larger* in the engine
that is physically incapable of chunking a prefill into a decode step. `R_req` (0.607)
and `R_tg` (0.757) both land on the refuting side too. R04's mechanism does not
survive, and the rival account R07 already preferred does: the deficit is **plain
queueing** — a fifth request against `max_num_seqs 4` waits for a slot and depresses
the measured prefill rate however its prefill is scheduled.

The strongest single thing here is that the deficit is an invariant. `D_pp` across
four configurations spanning the token budget, prefix caching, the mamba cache mode
and chunked prefill itself sits in a 1.5-point band: −9.5%, −10.8%, −9.96%, −10.95%.

Second headline, and it inverts R04's framing: **chunked prefill PROTECTS decode, it
does not interfere with it.** Turning it off costs `tg` 14.8% at c4 and 9.9% at c5,
and halves the per-request decode rate at c4 (`tg_req` −44.2%) — while *improving*
admission stagger (3.32 → 2.17) and time-to-first-response (−17.2%). That is exactly
what an unchunked prefill does: it occupies a whole scheduler step and nothing
decodes during it, so first tokens arrive sooner and in tighter formation but every
request's decode is repeatedly frozen. R04's *observation* that chunking interleaves
prefill into decode is confirmed — it shows up cleanly in ttfr — but the flag is a
net win on `tg` at both concurrencies.

⚠ **The validity gate failed as written and was overridden — with documents, not
with reasoning.** `ctx_pp2048` measured 6106.93 / 5379.73 and 6008.87 / 5262.09,
indistinguishable from the caching-ON figures, so by the letter of the rule the round
is void. The override rests on three documents: the engine's own non-default args
read `'enable_prefix_caching': False` in both; vLLM's own counter reads
`Prefix cache hit rate: 0.0%` in all 22 samples of each; and llama-benchy's source
explains why the gate's premise was wrong. The gate tested a belief about the metric,
not a fact about the invocation, and the good instrument was in the engine log the
whole time and costs nothing.

**The round's most valuable finding cost no box time and inverts twelve rounds of
labels.** Chasing the failed gate into `llama_benchy/runner.py` turned up that the
`ctx_` rows are the CONTEXT-LOAD pass — the uncached one that *establishes* the cache
— while the rows the campaign had been calling "cold" are the second, cache-eligible
pass. The campaign had the two phases backwards since R01. And the two phases are
charged different token counts, 16384 against 2048, so their `pp` figures were never
comparable: the ~9x `ctx_pp` advantage read at every depth for twelve rounds is
`16384/2048`, not a cache effect. The third finding is the one that should worry the
campaign: **prefix caching has never hit on this benchmark** — 0.0% in all 114
sampled windows across two rounds with the flag ON, and total prompt tokens processed
differ by 1.7% between caching on and off, so no prefill work was ever saved.

⚠ Superseded on two figures, both by R09c. "`--enable-prefix-caching` is worth 57% of
`tg` at c4" was two three-run medians taken four hours and one engine start apart;
R09c re-measured both endpoints at runs=7 inside one session and read **2.414x**
(146.32 against 60.60) — the direction was right, the size was a cross-invocation
artefact. And this round's leading suspect for the mechanism — "prefix caching off
moves `mamba_block_size` from 16 to 32768, a 2048x change in Gated DeltaNet state
granularity" — is **wrong by two orders of magnitude**: `platforms/interface.py:911-918`
overwrites the 16 with the aligned attention block size, so the true contrast is
2144 → 32768, 15.3x, and no round ever ran under the 2048x condition. Implication for
the next hypothesis: find out why a flag that never hits the cache is nonetheless
worth a large multiplier — which is R09c.
