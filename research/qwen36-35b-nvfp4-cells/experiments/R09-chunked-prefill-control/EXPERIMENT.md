# R09 — is chunked-prefill interference what costs the c5 deficit?

objective: test the last mechanism in the campaign that was inferred rather than measured. R04 saw `tg128 @ d16384 c5` come in 13.7% below c4 and explained it by chunked prefill mixing a queued fifth request's prefill into ongoing decode steps.
claim: two holes in R04's story. The deficit was never measured inside one invocation, and chunked prefill was never actually turned off. Both are closed here by comparing three *deficits* rather than three throughput numbers — `D = (c5 − c4) / c4` computed within each arm's own invocation, so engine-start variation and thermal drift move c4 and c5 together and cancel to first order.
variables: three settings. `recipe.yaml` unmutated at `max_num_batched_tokens 8192`; the same with the budget raised to 32768; and `recipe-nochunk.yaml` with chunked prefill removed, also at 32768. ⚠ A third setting was forced by the stack: `SchedulerConfig.verify_max_model_len` raises outright when chunked prefill is off and `max_num_batched_tokens < max_model_len`, so the chunked-prefill-off invocation cannot run at the campaign's own 8192 budget, and a naive two-invocation design would vary the flag AND the budget at once.
confirms / refutes: `R = (D0 − D2) / D0`, the fraction of the deficit that disabling chunked prefill recovers. `R ≥ 0.60` confirms R04's mechanism; `R ≤ 0.25` refutes it and makes the deficit an ordinary consequence of five requests sharing four slots; between them is reported as partial and not rounded to whichever side is tidier. The middle invocation splits the credit: `D0 ≈ D1` means the budget contributes nothing, `D0 ≫ D1` means the 8192 budget was doing the damage. Resolution was priced in advance at ±1% on D against a 13.7% effect, so runs=3 is generous here.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_5399a85d7aec-a0 | 2026-08-22T07:35:55Z | shipped recipe, mnbt 8192, chunked prefill on | c4 52.64, c5 45.05 → D0 = −14.4%; pp2048 640.70 / 579.98 |
| bench_d9fdc68576f2-a1 | 2026-08-22T07:55:17Z | mnbt raised to 32768, chunked prefill on | c4 143.08, c5 81.73 (σ/med 9.98%); pp2048 669.28 / 596.78 |
| bench_12f458ba7348-crash | 2026-08-22T08:02:24Z | chunked prefill removed, mnbt 32768 | REFUSED at engine init: "Chunked prefill is required for mamba cache mode 'align'". No measurements; traceback and candidate recipe archived. No `state.yaml` session — the engine never started |

## conclusion 2026-08-22T08:01:31Z
Hole 1 is closed and it closes in R04's favour. `D0 = −14.4%` (45.05 against
52.64) against the −13.7% R04 computed across two separate invocations: the deficit
is real, it is not an artefact of comparing engine starts, and this is the first
time it has been measured within one. R04's supporting evidence reproduces tightly
too — `pp2048 @ c5` reads 579.98 against R04's 581.44, 0.25% apart, while
`pp2048 @ c4` sits inside the flat d16384 series that has now held across nine
invocations. So the phenomenon R04 described is solid. What was never solid was the
explanation, and that is where this round stops.

**The mechanism could not be tested, and the round says so plainly.**
`--no-enable-chunked-prefill` parsed, the engine emitted the predicted warning, and
then a second unrelated validator killed it: `mamba_cache_mode` is `"align"` whenever
prefix caching is enabled, and `"align"` requires chunked prefill. This is
architectural — 30 of this model's 40 layers are mamba-class Gated DeltaNet whose
recurrent state that cache mode governs. **On this stack, chunked prefill cannot be
disabled without also disabling prefix caching**, and a control condition that alters
75% of the layer stack's caching behaviour cannot attribute its result to chunked
prefill. So `D2` and `R` are unmeasured, the pre-declared 0.25/0.60 thresholds never
got applied, and nothing was invented to fill the gap. The round was set up to say
confirmed, refuted or partial; it says none of those, and reports the honest fourth
answer. R04's mechanism remains an inference — but one now known to be untestable by
the obvious route, which is more useful than "untested" because it stops the campaign
re-queueing this round.

One rival mechanism was killed for free: MTP acceptance does not move between c4 and
c5 (61.7–69.8% across all four cells, and at the shipped budget the *slower* cell has
the *higher* acceptance). So whatever costs 14.4% is a scheduling effect, not an
acceptance effect. And one side-prediction points R04's way: at mnbt 32768 a d16384
prefill fits in a single batch, yet c5's prefill is still depressed (596.78 against
669.28), which is the mixed-batch side of the discriminator — a single side-prediction,
not a substitute for the arm that could not run.

The unplanned finding is the consequential one and it was not what the round was for.
The middle invocation existed purely as the matched control for the arm that died;
with that duty gone, it showed that **the campaign's own token budget was gating
admission at c4**. The trade-off across the two live settings: raising
`max_num_batched_tokens` 8192 → 32768 took c4 from 52.64 to 143.08 and c5 from 45.05
to 81.73, but cost variance badly — c5 at the raised budget read σ/med 9.98% against
0.62% at the shipped budget, on a mode-plus-one-low-draw shape, so the round's ±1%
error budget holds for `D0` and not for `D1`. Nothing was claimed and no standings row
moved; one flag was added instead — the campaign's only marginal win sits in a cell
measured under a configuration that does not reach full occupancy.

⚠ Superseded on the mechanism it could not test. R09b later ran the arm from the
legal side and **refuted** R04's chunked-prefill interference outright: the cause is
queueing at `c > max_num_seqs`, and chunked prefill in fact *protects* decode —
turning it off cuts `tg_req` 44% at c4 while improving stagger and ttfr. The
per-request framing of every figure here is retired by R10. The refused arm is
recorded permanently as a refusal rather than dropped, and it is the first of three
in the campaign. Implication for the next hypothesis: the token budget is the live
lever, and R10 should measure what raising it is worth at c4 and c16 under one engine
start.
