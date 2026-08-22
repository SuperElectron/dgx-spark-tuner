# R13b — is per-request MTP acceptance what the span ratio's floor is made of?

objective: close open question 7 — what the batch span ratio's ~1.50 floor is made of — by measuring per-request acceptance rather than inferring it from batch aggregates. R13 left acceptance dispersion as its only live candidate after the instrument refuted admission stagger.
claim: with five requests admitted in one scheduler step and each generating exactly 128 tokens, request *i* retires after its own `S_i` verify steps, so the span ratio is `max_i(S_i) x mean_i(1/S_i)` — **max over harmonic mean, zero free parameters**. ⚠ R13 compared the wrong statistic: its "1.44x spread against a measured 1.54" is max/**min**, and the quantity that enters the span is strictly smaller. Feeding R13's own widest logged 2.77–4.00 range into a single batch reaches only 1.19. And that grant is too generous, because those samples are 10-second batch aggregates from different runs and phases — between-run variation, the confound R13 admitted it could not remove. Within one batch, acceptance is an average over ~42 steps and sampling noise alone concentrates it to ~1.05. **So the prediction is that the round refutes its own candidate**, stated plainly because the campaign's rule is that the mechanism paragraph and the numeric band must be written together.
variables: no vLLM performance setting changes. The axis is the instrument: `--per-request-spec-decode-metrics` enabled at `detailed`, which records ordered per-step accepted/proposed arrays in the response. ⚠ **The queue's instrument was wrong and that is the round's first result**, settled from the image at zero box cost: the field is real and settable, but the docstring puts its output *in the response*, not in the engine log where the queue said to look. Running the queued round would have answered nothing.
confirms / refutes: the pre-declared statistic `max(S) x mean(1/S)` over the five requests. Below **1.20** REFUTES acceptance dispersion as the mechanism.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| r13b-perreq-probe | not recorded — see note below | per-request acceptance at c5, mnbt 98304, seven batches — a Python probe, not a sparkrun grid | `max(S) x mean(1/S)` median **1.085** against an observed span ratio of **1.499**; `corr(start stagger, ms per verify step)` = **−0.980** |

⚠ This directory has **no `state.yaml`**, and that is not an omission: R13b ran no
llama-benchy grid, so no sparkrun benchId exists and the archive is named for the
round rather than a benchId. It therefore carries **no `created_at`, `started_at` or
`ended_at`** — the only dating available is the journal's, which places the round on
2026-08-22, and no start or end time is invented here. Provenance is in
`PROVENANCE.md`: the data came from `scripts/r13b-probe.py` and
`scripts/r13b-analyse.py` rather than from the usual harness, and
`recipe-r13b-perreq.yaml` is an **instrument, not a candidate** — it must never be
folded into `recipe.yaml`, because the flag's overhead was never measured.

## conclusion 2026-08-22
**The candidate is refuted, and the round said so before it ran.** MTP acceptance
dispersion is not what the span ratio is made of: the pre-declared statistic reads a
median 1.085 across seven batches against an observed 1.499, below even the 1.19
ceiling the hypothesis computed from R13's own widest logged spread. Acceptance
dispersion acting alone accounts for **17% of the excess span**, and the other 83% is
something else.

**And the round found what it actually is — a third mechanism, not either of the two
on the table.** The probe measured it directly rather than inferring it:
`corr(start stagger, time per verify step) = −0.980` on Phase 2 and −0.986 on Phase 1,
across 35 requests, against `corr(verify steps, decode duration) = +0.142`. Decode
duration is not set by how many verify steps a request needs; it is set by **when the
request started decoding**. The first request to finish prefill decodes at 88.5 ms
per verify step while every other request in the same batch decodes at 55–58 ms — a
**1.57x penalty borne by exactly one request**, and it is the one the batch decode
span is measured from. The mechanism is plain once seen: the batch's five prefills do
not complete together, so the first to finish begins decoding while the other four
are still prefilling and its verify steps are co-scheduled with chunked-prefill work.
First-token spread is 1.26 s median against a clean decode of ~2.3 s, and
`1 + 1.26/2.30 = 1.548` reproduces the observed 1.499 to 3% with no fitted parameter.
**Call it prefill-completion stagger, or the first-starter penalty. Do not call it
admission stagger** — that name is refuted and this is not it.

This is fully consistent with `Waiting: 0`, which is why R13 could not see it.
Nothing queues; all five requests are `Running`. But **`Running` counts a request
that is still prefilling the same as one that is decoding**, and the engine log has
no column that separates them. R13's instrument was not wrong, it was blind to the
distinction the question turned on. It also explains R13c's curve: a larger budget
means fewer prefill chunks and a tighter first-token spread, so the span ratio keeps
falling to 65536 with nothing waiting at any budget — then floors, because the
prefill work still has to be done and cannot be made simultaneous by any budget.

⚠ The trade-off in the mechanism itself is that **the three terms are substitutes,
not addends, and the counterfactuals say so.** Removing the first-starter penalty
alone *raises* the span ratio to 1.634, because the span is then set by the last
starter instead. The stagger is the irreducible term; the interference redistributes
it. The three percentages must not be quoted as a partition. The one clean statement
is the counterfactual with both stagger terms removed: span would be 1.085, all of it
acceptance.

What this retires beyond R13 is a whole line of reasoning rather than a single
number: **every sentence in the campaign offering acceptance as the reason a `c>1`
batch's span is wide, and every proposal to buy the answer with more acceptance
telemetry.** Two distinct errors are retired with it and both generalise — the wrong
statistic (max/min rather than max/harmonic-mean) and the wrong samples (between-run
aggregates rather than within-batch; measured within one batch, per-request
acceptance max/min is 1.167 median over 35 requests). ⚠ Do not confuse this with
R06's variance result, which survives untouched: R06 is about the run-to-run σ of a
median over many verify steps, where acceptance genuinely drives it, while this is
about the within-batch spread across five simultaneous requests. Same word, different
quantity, opposite verdict. Implication for the next hypothesis: the mechanism chain
is closed — token budget → residency → prefill-completion stagger → batch span →
every `c>1` number — and what remains is auditing the standings rows that still rest
on three runs.
