# R02 — `tg128 @ d16384 c4`, the most contested board cell

objective: win the campaign's only genuinely contested cell — incumbent 46.68 (Gemma-4-26B-A4B-NVFP4) with 8 entries, the one place the board's number comes from a field rather than a lone straggler.
claim: a 35B-A3B MoE at c1 leaves the GPU badly underfed — 3B active parameters per token means the decode step is memory-bound on weight reads that four sequences share for free. Expect roughly 2–2.5x the c1 median of 102.2, with batching gains offset by MTP acceptance falling as one speculative draft has to satisfy four divergent sequences. Side-claim: c4 should be QUIETER than c1, because averaging four sequences per step damps a single lucky or unlucky speculative streak.
variables: none in the recipe — the incumbent recipe under a wider probe. `concurrency` raised 1 → 4, which the shipped `--max-num-seqs 4` fits exactly with no queueing; runs=3.
confirms / refutes: if the figure lands under ~93 (2x the incumbent) it gets a mandatory identical-configuration repeat before any win is claimed. If σ stays as wide at c4 as it was at c1, the noise is not MTP acceptance and the bimodality story needs rewriting.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_f58c56da6658 | 2026-08-22T04:39:22Z | c4, first invocation | tg 53.56 (σ 0.43), ctx_tg 56.40 (σ 0.16) |
| bench_f58c56da6658-verify | 2026-08-22T04:45:01Z | identical configuration, mandatory repeat | tg 52.69 (σ 0.75), ctx_tg 55.92 (σ 0.62) — reproduces to within 1.6% |

## conclusion 2026-08-22T04:48:47Z
WIN, verified. The pooled median over all six Phase-2 runs is 52.85 against the
incumbent 46.68 — **1.13x**, +13.2%. The margin sat well under 2x so the repeat was
mandatory, and it reproduced. The case does not rest on the median: the worst of the
six runs, 51.25, still clears 46.68 by 9.8%, so no draw of these runs loses the
cell. It is the campaign's narrowest win and the only one where the incumbent came
from a real field, which is presumably the same fact seen twice.

The noise side-claim was confirmed and is the strongest evidence yet for the
MTP-acceptance story: σ collapsed from 18.38 at c1 (14% of median) to 0.43 and 0.75
at c4 (under 1.5%), while the individual per-request rates *inside* those same c4
runs span 13.75 to 74.37, a 5.4x spread. Single sequences stay wildly bimodal;
averaging four per step is what makes the batch figure stable. The trade-off is
explicit and it is the cost side of the win: per-request throughput falls from 102.2
at c1 to 52.85 at c4 — 4x the concurrency buys about 2.1x, 52% scaling efficiency —
and e2e ttft rises from ~3.2 s to ~10.2 s. Neither is a board cell. The practical
consequence is that c4 cells need far fewer runs than c1 cells for the same
confidence.

⚠ Superseded on its central methodological finding, and the reversal is total. This
round concluded that llama-benchy's headline `tg t/s` is **per-request**, on the
evidence that `tg_throughput` and `tg_req_throughput` coincide exactly at c1 and
diverge at c4. R10 read llama-benchy 0.4.0's own source and retired that: at `c>1`
the headline field is a **batch aggregate**, `observed_decode_tokens / (max_last_token
− min_first_token)`. R5c then tested the aggregate reading against 34 archived `c>1`
records and it held 34 of 34. The derived convention "aggregate = per-request x c",
used from R2 to R9, is retired with it — it double-counts an already-aggregate
metric, which is why it kept exceeding `peak_throughput`. The 1.13x margin itself is
unaffected: the board's 46.68 is the same field, so the comparison was like-for-like
all along. The `ctx_` phase description is also corrected — read "Phase 1, the
context load" for "prefix-caching phase". Implication for the next hypothesis: probe
the concurrency curve either side of 4, and carry the (then still latent) units
question into it.
