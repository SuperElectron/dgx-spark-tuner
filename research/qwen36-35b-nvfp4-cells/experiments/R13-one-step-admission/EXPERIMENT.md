# R13 — the one-step admission round at `max_num_batched_tokens 98304`

objective: take the campaign's last cell with a live route to a win. R12 priced c5's remaining gap as 93% admission stagger, with our per-request decode rate already within 3% of what the incumbent's headline requires — so the question is whether admitting the whole batch in a single scheduler step closes it. `tg128 @ d16384`, c4 and c5, runs=7, one engine start.
claim: at d16384 a Phase-2 request costs 18432 tokens, so 98304 admits five in one step (`5 x 18432 = 92160`) and four in one step (73728). R12 reached its c5 point in three admission steps, so its prefill was split and interleaved with ongoing decode. c5's `tg_req` of 43.72 is the only point off the campaign's own `c^-0.48` per-request series — 16% below it, where c2 and c4 sit on it. If that interleaving is what costs the 16%, one-step admission should return c5 to the series.
variables: `max_num_seqs` 5 and `max_num_batched_tokens` raised 32768 → 98304, both MUTATIONS; `recipe.yaml` untouched and `max_model_len` left at 32768, which the pre-flight established was permitted. c4 rides along for ~220 s as a second independent point on the same admission model under the same engine start.
confirms / refutes: **H_span_only** — the budget buys only a shorter denominator and per-request decode is untouched: `tg_req(c5) ≤ 46.0`, giving ~202 and still a LOSS. **H_span_plus_decode** — un-splitting the prefill also lifts decode back onto the series: `tg_req(c5) ≥ 48.0`, giving ~241 and a WIN. Between 46.0 and 48.0 is reported as mixed and not forced. Sixteen further bands declared, including `pp2048` as a session control that must land or the `tg` figures are not readable, and scheduler `Running`/`Waiting` at 5/0 and 4/0 in ≥95% of loaded samples. The standings call was made in advance: **c5 at 40% to clear 225.46**, c4 at >90% to improve its margin.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_433eeaf9827e | 2026-08-22T10:26:26Z | mnbt 98304 + mns 5 at c4 and c5, one engine start, runs=7 each | c4 tg 174.68 (tg_req 66.76, stagger 1.53, peak 310); c5 tg 164.27 (tg_req 50.50, stagger 1.54, peak 303); ctx_tg 170.59 and 160.67; `Waiting: 0` in 23 of 23 loaded samples |

## conclusion 2026-08-22T10:38:15Z
One win widened, one record margin, and c5 is still a loss. `tg128 @ d16384 c4` goes
3.15x → 3.74x and `ctx_tg @ d16384 c4` goes 4.56x → 6.16x, the campaign's widest
margin at the time. **c5 remains a LOSS and is recorded as one**: 164.27 against the
like-for-like 225.46 is 0.73x, improved from 0.57x and short by 27% — and the fuller
statement is that the c5 cell is topped by LFM2.5-350M BF16 at 428.95, so even
clearing 225.46 would not have taken the cell.

**The discriminator holds and the round's own mechanism is refuted anyway.**
`tg_req(c5) = 50.50` clears the 48.0 line, so H_span_plus_decode holds cleanly:
per-request decode did lift when the prefill stopped being split, essentially back
onto the series. But the round predicted that lift would arrive alongside a stagger
collapse to 1.00–1.15, and the stagger did not collapse — 1.53 at c4 and 1.54 at c5,
against R10's 1.57 and R12's 1.70, with c4's barely moving. Both `tg_req` figures
rose by exactly the same factor, +15.5%, at two different concurrencies with the span
ratio nearly untouched. **That is not what an admission-stagger lever looks like.**
The round got its numbers from the term it treated as secondary and nothing from the
term it was designed around.

The instrument says so directly, and this is the fourth attempt at it — R08, R09 and
R12 all planned the engine-log capture and shipped without it. Here it produced 453
lines, 48 `Running:` samples and 34 SpecDecoding samples, verified live before the
round leaned on it: **`Waiting: 0` in 100% of loaded samples at both concurrencies**,
10 of 10 at c4 and 13 of 13 at c5. The scheduler is admitting the entire batch, and
the stagger is still 1.54. So whatever stretches the span is not requests waiting for
admission — there is nothing waiting. **Most of what the campaign has been calling
admission stagger since R10 is not admission.** The name was inherited from the
configuration that first produced it and stopped being accurate somewhere before this
round.

The trade-off across the budget: raising it to 98304 bought +15.5% per-request decode
at both concurrencies and widened two margins, at the cost of noise (σ/med 4.41% at
c4 against R12's 1.81% at c5) and of a longer time to first response, since a
92160-token step is long. Neither mutation was folded; the fold decision stays R11's.
R09b was confirmed a third time at a third budget — `Prefix cache hit rate: 0.0%` in
all 48 samples with the flag ON, now 162 engine samples across three budgets — so
nothing in the round's gains is a caching effect.

⚠ Superseded, on three counts. This round's headline standings figures — "3.74x and
6.16x" — were superseded by R13c the same night: same configuration, second engine
start, pooled 14-run medians read **3.67x and 6.15x**, and R13d then took the widest
margin to 6.21x at mnbt 131072. The margins survive; the decimals were a single draw.
The round's cost note that "each new `max_num_batched_tokens` value costs a full
torch.compile rebuild" was corrected by R13c at no cost — start time tracks the SIZE
of the budget, not its novelty, so sweeping the flag is affordable. And the round's
closing candidate for the residual span, **MTP acceptance dispersion across the
batch**, was REFUTED by R13b, which measured it per request rather than inferring it:
dispersion acting alone gives a span ratio of 1.085 against an observed 1.499, 17% of
the excess against a pre-declared refute threshold of 1.20. Two distinct errors are
retired with it — the wrong statistic (max/min rather than max/harmonic-mean) and the
wrong samples (10-second batch aggregates from different runs and phases, rather than
within one batch). Implication for the next hypothesis: sweep the budget across its
whole range at one concurrency to find the knee, and measure acceptance per request
rather than inferring it.
