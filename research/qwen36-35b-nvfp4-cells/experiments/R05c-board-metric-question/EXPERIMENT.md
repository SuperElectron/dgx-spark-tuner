# R05c — is the board's `c>1` decode figure per-request or a batch aggregate?

objective: settle which quantity the arena board's headline decode number is, because the campaign's only marginal win — `tg128 @ d16384 c4` — read 1.13x under one reading and 4.53x under the other.
claim: queued by R7 to be answered from the board's methodology page or from one model with entries spanning c1 through c8+. R10 reached the answer first and by a better instrument — llama-benchy 0.4.0's own source — so R5c spent its budget instead on an independent test of R10's conclusion against data R10 did not use.
variables: none. This is a desk round: no box was touched, no benchmark was run, no board page was re-scraped. The axis varied was the *reading* of the metric, tested against 34 archived `c>1` records spanning c2, c4, c5 and c16, five configurations, nine benchIds, including every arm of R2, R4, R7, R9, R9b, R10 and R12.
confirms / refutes: three structural predictions that the aggregate reading makes and the per-request reading does not — `tg_throughput > tg_req_throughput` at every `c>1` point, `tg_throughput <= peak_throughput` always, and `tg_throughput / tg_req_throughput <= c` always.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| _(none — desk round, zero box time; the 34 records tested are archived under other rounds)_ | — | — | — |

## conclusion 2026-08-22 (desk round; no run timestamps exist because nothing was run)
The board's headline decode number is a **batch aggregate** at `c>1`, and it is the
same field the campaign already records. `results.py:352` defines
`batch_tg_throughput = observed_decode_tokens / (max_last_token - min_first_token)`
and line 194 selects it whenever `concurrency > 1`; the CSV row builder maps
`t_s <- tg_throughput` and sparkrun uploads that CSV. All three structural
predictions held 34 of 34, with `tg_throughput / tg_req_throughput` ratios running
1.13x to 4.02x — the two fields are never the same number at `c>1`, so
`tg_throughput` cannot be the per-request figure. R7's 4.53x alternative was
withdrawn by R10 and is not revived here.

The double-count is visible in the archive too: the campaign's retired
`aggregate = per-request x c` convention exceeds `peak_throughput` in 14 of 34 rows,
which is impossible for a sustained figure. All fourteen are low-stagger arms. At
the campaign's original `max_num_batched_tokens 8192` the stagger was 2–2.5x, which
happened to keep the double-counted product under the peak and made a wrong
convention look sound. The convention was never right; it was merely not yet caught.

What got better: every `c>1` comparison the campaign made turns out to have been
like-for-like all along, and open question 7 is closed. What got worse: nothing in
the standings — no verdict, margin, standing or row value changed, and
`tg128 @ d16384 c4` keeps 1.13x on the campaign configuration and 3.15x on the
raised budget. The claim held, but not as R5c's own design intended: it was answered
free by a ride-along in a round queued for something else, which is the second time
this campaign got its biggest result from reading the instrument instead of running
it. One new caveat is attached: the cheap stagger proxy `stagger ≈ c / (tg / tg_req)`
agrees with R10's measured values at c2 and c4, but at c5 only when
`max_num_seqs >= c` — on the c5 runs at `max_num_seqs 4` it reads 3.85–4.08 against
R10's measured ~2.39. Use the proxy only at full residency, confirmed from the
scheduler's own `Running: N / Waiting: M` lines. Implication for the next
hypothesis: the metric dispute is closed, and the levers worth box time are the
scheduler settings, not the scoreboard.
