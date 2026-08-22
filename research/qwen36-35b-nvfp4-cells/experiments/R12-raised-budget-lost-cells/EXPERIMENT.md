# R12 — the raised budget at the two cells the campaign loses

objective: take R10's lever to the only two cells with a known, scoreable, like-for-like target that the campaign LOSES — c2 at 84.00 against 163.27 and c5 at 48.12 against 225.46, both held by the board's own `Qwen3.6-35B-A3B-NVFP4` on vLLM. Same model, same runtime, same quant, and since R10 read llama-benchy's source, the same metric: there is no population difference to hide behind and no units question left to argue. The gap is config.
claim: at d16384 a scheduler step admits `floor(mnbt / 16384)` whole prefills, and that integer is the entire intervention. At mnbt 32768, **c2 is the one cell in the campaign where the whole batch is admitted in a single scheduler step** — nothing waits for budget and nothing waits for a slot, so its stagger should approach the c1 floor of 1.00. c5 is the opposite: the first concurrency where the batch does not divide evenly into the budget, so a lone third step trails and stretches `max_last_token`, which the board metric is charged for directly.
variables: `max_num_seqs` raised 4 → 5 and `max_num_batched_tokens` raised 8192 → 32768 together, both MUTATIONS, at c2 and c5 in one engine start, runs=7. Nobody had run c5 with both raised (R09's raised-budget arm left `max_num_seqs 4`, so the fifth request still queued for a slot), and nobody had run c2 raised at all.
confirms / refutes: **H_stagger** — the benefit is set by how cleanly the batch divides into the budget, so the gain is not a constant multiplier: needs `stagger(c2) < 1.35` AND `stagger(c5) > 1.80`. **H_uniform** — a roughly constant multiplier regardless of concurrency: both staggers within ±0.20 of c4's 1.57, both cells moving ~2.8x. Both stagger conditions must hold to read H_stagger; if either lands in the other camp the result is reported as mixed, not forced.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_ac37f5b64487 | 2026-08-22T09:14:20Z | max_num_seqs 5 + mnbt 32768 at c2 and c5, one engine start, runs=7 each | c2 tg 140.77 (peak 181, stagger 1.13, residency 1.93 of 2); c5 tg 128.93 (peak 290, stagger 1.70, residency 4.92 of 5); ctx_tg 127.09 and 104.75 |

## conclusion 2026-08-22T09:23:23Z
Both cells are still losses and both are transformed: c2 goes 0.51x → **0.86x** and
c5 goes 0.21x → **0.57x**, +67.6% and +168% from a scheduler knob. Neither clears its
target and neither is recorded as anything but a loss — but the campaign's two worst
cells are now within 14% and 43% of a like-for-like incumbent where they were 49% and
79% short.

The round's most valuable number is the decomposition of what remains. Since
`tg = c × tg_req / stagger`, a hypothetical zero-stagger run of the same engine is
just `c × tg_req`, and that bound splits the residual gap in two: at c2, 159.46
against an incumbent 163.27 (0.98x), and at c5, 218.60 against 225.46 (0.97x). **Our
per-request decode rate is within 3% of what the incumbent's headline figure
requires, at both concurrencies.** The board's entry is not decoding faster than this
box in any meaningful sense; it is admitting its batch with almost no stagger and we
are not. That is the first time the campaign priced the config gap into two named
terms instead of calling it "config".

The discriminator came out **MIXED** by the round's own rule. `stagger(c2) = 1.13`
holds comfortably and is the lowest `c>1` stagger the campaign has measured;
`stagger(c5) = 1.70` misses its 1.80 floor by 0.10. H_uniform is refuted outright,
H_stagger is not confirmed on its own terms and is reported as mixed rather than
forced. But the *ordering* the integer arithmetic predicted held exactly — 1.13 <
1.57 < 1.70. ⚠ Where the c5 threshold went wrong is instructive and it is the same
error R10 confessed to: the 1.80 floor priced the trailing third step as a full step,
when it admits one prefill rather than two. The round's own table said "2+2+1" and
its threshold priced it as "2+2+2" — the mechanism section was right and the numeric
band was wrong, in the same document, for the second round running.

The trade-off is sharp and it localises the effect. `peak_throughput` at c2 did not
move at all (182 → 181, −0.5%) while `tg` rose 67.6%: the hardware is doing no more
work, so the entire gain is the batch span tightening, charged straight into the
board's metric. Variance got worse at c2 (σ/med 6.28% against 1.81% at c5), and the
mutations were NOT folded into `recipe.yaml`.

⚠ PROCESS FAILURE, recorded rather than buried: the scheduler log was not captured,
the second consecutive failure of that instrument. ⚠ Superseded on its mechanism.
This round's explanation — "the `c>1` gap is admission stagger, and it is 83–93% of
what remains" — was carried from R10 through R12 as the campaign's account of every
`c>1` result and was **refuted by R13 with the instrument**: at a higher budget the
scheduler reads `Waiting: 0` in 100% of loaded samples while the span ratio barely
moves. The ratio is real and charged to the metric; calling it *admission* is what is
withdrawn, and the replacement — established by R13b and R13c — is prefill-completion
stagger. R12's stagger asymmetry between the phases also broke at R13. The
per-request framing throughout is retired by R10's source read, and the `ctx_` labels
are the uncorrected ones. Implication for the next hypothesis: if a lone trailing
admission step is what costs c5, a budget large enough to admit the whole batch in
one step should remove it — which is what R13 was queued to test at mnbt 98304.
