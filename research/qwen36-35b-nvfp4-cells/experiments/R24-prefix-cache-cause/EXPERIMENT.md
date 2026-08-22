# R24 — which vLLM setting holds the prefix cache at 0.0%

objective: identify the engine-side cause of a prefix cache that ships enabled and has never hit once in 220+ engine samples across 17 rounds, and price the fix; cell `tg128 @ d16384 c4`, runs=3, one engine start per invocation.
claim: the 0.0% hit rate is a flag interaction, not a resource limit — KV capacity (3.6% of pool), eviction, block alignment and the access pattern were all ruled out at the desk first. R9c had measured `--enable-prefix-caching` worth 2.414x end-to-end at this cell, so a cache that actually fired should be worth a large multiplier.
variables: one setting removed or changed per invocation against the shipped recipe — `kv_cache_dtype` moved fp8 → auto; `--speculative-config` deleted entirely; `num_speculative_tokens` lowered 3 → 1.
confirms / refutes: confirm at a hit rate > 50%; the discriminator, declared in advance, was that a working cache must move Phase 2 (which can hit the cache) and leave Phase 1 (which populates it) flat. Separately `tg` ≥ 210 was the band in which the analysis file's projected +42% would count as having held.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_647b25c13d9f-r24-arm1-control | 2026-08-22T19:34:02Z | shipped recipe, unchanged | cache 0.0% × 11 of 11; tg 169.89, pp 677.37, ttfr 12080.79 ms, peak 309 |
| bench_064550e26525-r24-arm2-kvauto | 2026-08-22T19:39:10Z | `--kv-cache-dtype auto` | cache 0.0% × 11 of 11 — not the cause; tg 179.15, pp 719.56 |
| bench_064fc6128314-r24-arm3-specoff | 2026-08-22T19:45:38Z | `--speculative-config` removed | cache 42.1% × 5, 36.4% × 1, 0.0% × 2 (pre-load) — the cause; tg 143.24, pp 2823.72, ttfr 2885.83 ms, peak 189 |
| bench_f6e4a4c51f71-r24-arm4-spec1 | 2026-08-22T19:54:57Z | `num_speculative_tokens: 1` | cache 0.0% × 12 of 12 — not a cheaper fix; tg 148.12, pp 681.94, ttfr 12003.69 ms |

## conclusion 2026-08-22T20:00:46Z
MTP speculative decoding is what holds the prefix cache at zero, and it is
all-or-nothing: deleting `--speculative-config` takes the hit rate from 0.0% to
42.1%, and nothing else does. `kv_cache_dtype` is exonerated. Lowering the
lookahead to one token is not a cheaper fix — it reproduces the shipped recipe's
`pp` and `ttfr` to within 0.7% and 0.6%, which is the cleanest possible negative
control. The pre-declared discriminator held exactly: with speculative decoding
removed, Phase-2 `pp` rose 4.17x (677.37 → 2823.72) and Phase-2 `ttfr` fell 4.19x
(12080.79 → 2885.83 ms), while Phase 1 moved +4.8% and −4.6% respectively, i.e.
flat. Nothing but a working prefix cache produces that signature.

⚠ The round's own confirm threshold was mis-set and is recorded as an error rather
than reinterpreted. It declared confirm at > 50%, and 42.1% therefore lands in the
declared dead zone — but 50% was unreachable by construction. vLLM's counter is
cumulative over both phases and Phase 1 is the uncached load by design, so with a
2096-token attention block the structural ceiling is 14672 / 34816 = 42.14%. The arm
hit its maximum to the log's one printed decimal. The error was in the declaration,
not in the arm.

The trade-off is the part that matters for the recipe, and it refutes the projection
this round was built on. The analysis file projected `tg` → ~247 (+42%) once the
cache worked; the round declared `tg` ≥ 210 as the band where that held. What got
better: prefill work collapsed — 4.17x on Phase-2 `pp` and 4.19x on `ttfr`. What got
worse: `tg` fell 15.7%, 169.89 → 143.24, with peak throughput 309 → 189. The
projection assumed the cache could be bought at no cost; the fix costs MTP, and on
the campaign's own identity the 26.6% shorter batch span is more than paid for by a
33.4% drop in per-request decode. The projection is refuted by measurement, and
nothing was folded into `recipe.yaml`. Implication for the next hypothesis: MTP
stays, so the only untested direction left on it is *up* — raise
`num_speculative_tokens` above the inherited 3 and see whether the acceptance
ceiling was ever the binding constraint.
