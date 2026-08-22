# R25 — raising `num_speculative_tokens` above the inherited 3

objective: decide whether the MTP acceptance ceiling is the binding constraint on `tg` at `tg128 @ d16384 c1`, and whether a higher lookahead should be folded into `recipe.yaml`; runs=7, one engine start per invocation.
claim: `num_speculative_tokens: 3` has been in `recipe.yaml` since R1 and was never varied upward in eighteen rounds. With `k` drafted tokens plus one bonus token the ceiling on mean acceptance length is `k + 1`, so if acceptance is pressed against that ceiling, raising it should buy more accepted tokens per verify step and therefore more `tg`. ⚠ The round recorded before running that the premise is weaker at this cell than the campaign analysis claimed: the "89–93% of ceiling" reading comes from d32768 c1, while R11's only clean sample here reads 3.13, i.e. 78.3% of the 4.0 ceiling.
variables: `num_speculative_tokens` raised 3 → 4 → 5 (each needs its own candidate recipe; `--speculative-config` is a serve flag that `-o` cannot reach). Everything else shipped: mnbt 65536, mns 4, kv-cache-dtype fp8, `--moe-backend marlin`, `--attention-backend flashinfer`, prefix caching on. A ride-along afterwards varied `--moe-backend` to triton / flashinfer_trtllm / cutlass.
confirms / refutes: confirm at Phase-2 `tg` ≥ +10.0% over the same-session control. Refute at `tg` ≤ +2.0%, **or** at engine-reported mean acceptance length failing to rise above the control's median — the second clause refutes the premise directly and independently of `tg`. +2.0% to +10.0% is a declared dead zone: no fold, no standings row, no claim.

## runs
| bench dir | started (UTC) | setting under test | key result |
|---|---|---|---|
| bench_c9518e3e96a3-r25-arm1-spec3 | 2026-08-22T20:10:23Z | num_speculative_tokens 3 (shipped) | tg 102.81 (σ/med 7.64%), acceptance 3.03 = 75.8% of ceiling 4.0, draft acceptance 67.6% |
| bench_ddfac4b975ed-r25-arm2-spec4 | 2026-08-22T20:15:18Z | num_speculative_tokens 4 | tg 99.67 = −3.05%, acceptance 3.44 = 68.8% of ceiling 5.0, draft acceptance 61.0% |
| bench_93e361742c94-r25-arm3-spec5 | 2026-08-22T20:20:30Z | num_speculative_tokens 5 | tg 98.30 = −4.39%, acceptance 3.67 = 61.2% of ceiling 6.0, draft acceptance 53.4% |
| bench_be900399e857-r25-ridealong-moetriton-crash | 2026-08-22T20:25:43Z | `--moe-backend triton` | refused at engine init: not supported for NvFP4 MoE; the error enumerated the full legal set |
| bench_5eea211b9a30-r25-ridealong-moefitrtllm-crash | 2026-08-22T20:28:51Z | `--moe-backend flashinfer_trtllm` | refused at engine init: no kernel for this device (GB10) |
| bench_a062dab1eed0-r25-ridealong-moecutlass-crash | 2026-08-22T20:30:06Z | `--moe-backend cutlass` | refused at engine init: no kernel for this quantisation scheme |

## conclusion 2026-08-22T20:24:47Z
The ceiling binds as a mechanism and raising it does not pay. Mean acceptance length
rose monotonically — 3.03 → 3.44 → 3.67 against ceilings 4.0 / 5.0 / 6.0, +13.5%
from k=3→4 and +21.1% from k=3→5 — so the refute clause on acceptance did **not**
fire and the premise is confirmed as a mechanism. But Phase-2 `tg` **fell** at both
raised values, 102.81 → 99.67 (−3.05%) → 98.30 (−4.39%), which fires the
pre-declared refute clause on `tg`. Nothing was folded; `recipe.yaml` is untouched.

The trade-off is explicit and the engine named it at startup: this model has ONE MTP
module run `k` times, not `k` modules. What got better: more accepted tokens per
verify step. What got worse: the verify step costs more than the extra tokens are
worth, and the degradation shows in two places. Position-1 acceptance falls as `k`
rises — 0.865 → 0.840 → 0.818 — which a position-1 draft should not care about and
does, because the same layer is re-driven with changed draft context; and the added
positions are nearly worthless, position 4 accepting at 0.440 and position 5 at
0.284, each still paid in full with an extra draft forward pass. The pre-run
arithmetic prediction (3.64 at k=4, 4.05 at k=5, from a geometric model at p ≈ 0.84)
over-predicted both by 5.5% and 9.4% for exactly this reason.

⚠ The campaign analysis' "acceptance sits at 89–93% of ceiling" is corrected on the
record: those figures are from d32768 c1. At this cell the shipped configuration sits
at 75.8%, and every raised arm sits *lower* as a fraction of its own ceiling.
Raising the ceiling moves acceptance further from it, not closer. `num_speculative_tokens: 3`
is no longer an inherited default — it is measured, and it is at or above the
optimum here.

The ride-along closes a second inherited lever. All three `--moe-backend`
alternatives were refused at engine init before a token was generated, for three
different reasons, so they are unavailable rather than slower: `triton` is illegal
for NVFP4 MoE (the round's own error — the shipped recipe runs triton inside
`--speculative-config`, but the MTP draft module is not NVFP4 and takes a different
path), `flashinfer_trtllm` has no GB10 kernel, and `cutlass` has no kernel for this
checkpoint's quantisation scheme. `marlin` is the engine oracle's own choice for
this model on this device. `flashinfer_cutlass`, `flashinfer_cutedsl`,
`flashinfer_b12x`, `humming` and `emulation` are left untested on the record; the
first three share the device gate that refused `flashinfer_trtllm`. Implication for
the next hypothesis: both MTP lookahead and the MoE backend are closed as levers, so
further headroom has to come from somewhere other than the inherited defaults.
