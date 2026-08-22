# R07 — the concurrency tail at c8 and c16

objective: say what happens after the knee R04 found between c2 and c4 — where per-request throughput collapses, and whether the aggregate is still climbing. Cell `tg128 @ d16384`, runs=3, one matched invocation per point.
claim: two mechanisms pull in opposite directions past the knee. **Batching amortisation** says the aggregate keeps climbing: decode at c1 is weight-bandwidth-bound on a fixed ~1.7 GB read per step, and batching divides that across more sequences, which is why the aggregate rose 102 → 168 → 211 → 241 across c1/c2/c4/c5. **MoE expert coverage** says it flattens: at c16, sixteen sequences route independently in the same step and the union of experts touched approaches the whole set, so the per-step weight read GROWS with batch size in a way a dense model's would not. Fitting `aggregate ~ a + b*ln(c)` through the c2 and c5 points predicts c8 per-request 30–38 and c16 per-request 16–22.
variables: `concurrency` raised to 8 and 16, with `max_num_seqs` matched to the probe at each point (`-o max_num_seqs=8`, `-o max_num_seqs=16`) — R04 established that matching the scheduler width to the probe is worth +5.5% and that leaving it unmatched measures the queue rather than the box.
confirms / refutes: the discriminator is the c16 aggregate against the c8 aggregate. 15% or more above means the tail is still climbing and concurrency stays a live lever; within ~8% means saturated by c8 and the MoE-coverage story is the reading. Side-prediction and control on the mutation itself: `pp2048` sits at 620–645 at both points — if it falls below 600, matching the width did NOT eliminate the interference and it is a batch-size effect rather than a queueing one.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_0954971b5dfa | 2026-08-22T06:30:51Z | c8 with max_num_seqs 8 | tg 43.51 (σ/med 0.51%), ctx_tg 47.75, peak_throughput 355 |
| bench_a769c1142e15 | 2026-08-22T06:37:32Z | c16 with max_num_seqs 16 | tg 40.47 (σ/med 0.15%), ctx_tg 45.61, peak_throughput 440; scheduler Running median 9.0 of 16, Waiting median 6.0 |

## conclusion 2026-08-22T06:47:07Z
The concurrency tail is not flat, and the round is the campaign's fourth upward
refutation. Per-request throughput fell only 7.0% across a doubling of concurrency
(43.51 → 40.47), after falling 37% across the single step from c2 to c4. Both numeric
predictions missed high, the c16 one by 84%. The discriminator is answered
emphatically: 440 against 355 is +24%, above the "still climbing" threshold, so
batching amortisation wins and the **MoE-expert-coverage mechanism is not binding
anywhere in this range** — it may still be true further out, but nothing here tests
c32. The per-request statement is sharper still: strict time-slicing would put c16 at
111.11/16 = 6.9, and 40.47 is 5.9x above that line. R04's "knee" is better read as a
one-time step between c2 and c4 followed by a shallow slope (−24.4%, −37.1%, −8.9%,
−9.6%, −7.0%).

The round's most important finding is a config one, and it is what the round was sent
to catch by recording both aggregate estimators. The campaign's convention
`aggregate = per-request x c` **breaks between c8 and c16**: at c16 `c x tg` = 647.6
exceeds `peak_throughput` = 440 by 47%, which is impossible for a sustained figure.
The engine log says why — `--max-num-batched-tokens 8192` was not raised alongside
`max_num_seqs`, so at d16384 every prefill must be chunked into 8192-token batches
and the scheduler admits only what fits. The 16 requests never all resided at once,
and `peak_throughput / peak_req_throughput` corroborates it twice: 7.0 at c8
(near-full occupancy of 8) against 11.9 at c16 (74% of 16). So 647.6 is not claimed;
the honest c16 aggregate is 400–480, best figure ~440. **Matching `max_num_seqs` to
the probe was necessary and not sufficient** — R04 found the sequence-count queue,
this round found a second queue behind it on the token budget.

The trade-off across the tail: aggregate work keeps rising (355 → 440) while
per-request throughput and latency both degrade, and c8/c16 are the quietest cells
the campaign has ever measured (σ/med 0.51% and 0.15%) because they average the
bimodal acceptance draw over 8 and 16 sequences. MTP acceptance was measured against
concurrency for the first time — 3.29 mean length / 76.2% draft acceptance at c16 all
samples, 2.94 / 64.5% under heavy load, against R05's 3.81 / 93.6% at c1 — which is a
candidate mechanism for the c2→c4 step: losing the high-acceptance regime is a
one-time cost paid as the batch fills. ⚠ The round states its own confound: a c16
measurement reports close to the population mean of a distribution known to be
bimodal, while a c1 measurement reports a single draw, so "acceptance falls with
concurrency" and "c1 figures sit above the population mean" predict the same
observation and this round cannot separate them.

⚠ Superseded on both of its metric claims. The per-request framing was retired by
R10 from llama-benchy's source: at `c>1` the headline field is a batch aggregate, so
the `c x tg` column double-counts an already-aggregate metric — which is the whole of
why it kept exceeding `peak_throughput`, and it was wrong from R02, not merely from
c16. R5c then confirmed the aggregate reading against 34 archived records, 34 of 34.
This round's own inference from that — "the board's `c>1` figure is an aggregate and
ours is per-request, so our c4 win is really 4.53x" — was withdrawn by R10: both are
the same field. "The ctx-vs-cold margin grows monotonically with concurrency" was
also dead by R10, since the sign flips at c4 and c5 on the token budget alone. c8 and
c16 have no board figures at any budget and are unscoreable. Implication for the next
hypothesis: raise `max_num_batched_tokens` alongside `max_num_seqs` and see what full
residency is worth — which is R10.
