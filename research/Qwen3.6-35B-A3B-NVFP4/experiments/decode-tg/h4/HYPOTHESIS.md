# h4 — the draft path is the fattest target left at c1

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

LEVER SPENT — the only alternative that ran, `flashinfer_cutlass` at 116.5
tg, lands 2.8 below the 119.3 control, inside the control's 4.5% IQR.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | draft `moe_backend: triton` | control, measured in the same sitting as the arms; iqr 4.5%; accept 3.11–3.32; engine backend line `Using TRITON Unquantized MoE backend` | d16384 c1 | 636.2 | 119.3 |  | bench_bcde52479f68 |
| run-0002 | draft `moe_backend: batched_triton` | crash at init, no request served, none served for accept; engine backend line `Using BATCHED_TRITON Unquantized MoE backend` so selection is proved | d16384 c1 |  |  |  | bench_8a8ec2d89fe9 |
| run-0003 | draft `moe_backend: flashinfer_trtllm` | unsupported on device, no request served, none served for accept; engine backend line `ValueError: ... does not support current device cuda` | d16384 c1 |  |  |  | — |
| run-0004 | draft `moe_backend: flashinfer_cutlass` | iqr 2.5%; accept 3.05–3.35; engine backend line `Using FlashInfer CUTLASS Unquantized MoE backend` | d16384 c1 | 633.9 | 116.5 |  | bench_99d4f92d70a2 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

The MTP draft runs on an unquantized Triton MoE kernel because nothing else was
ever tried. One of the three other backends this build offers beats it, and the
gain shows up in `tg` at the Objective's cell. Mechanism: the MTP module is
excluded from quantization — `exclude_modules: ["mtp*"]` — so it cannot use the
target's NVFP4 Marlin path and falls through to vLLM's *unquantized* dispatcher,
which offers four backends and defaults to `triton` unexamined.

Worth, if right: the draft is ~30% of the speculative cycle, so cutting its
expert GEMM by a quarter is worth ~7% of decode — larger than anything h1
measured, for four runs. What this cannot reach is the `lm_head` re-read, the
larger half of the draft cost; if the backends tie, that is the finding.

## Method

### Variables to test

    speculative-config moe_backend: triton, batched_triton,
                                    flashinfer_trtllm, flashinfer_cutlass

Order: control first, then one arm per run, in the order listed. **A backend
that will not initialise is a result, not a failure** — record what the engine
said and move to the next arm.

### Constant for this round

Everything in Held, and the full protocol: `exact_tg`, `extra_body
temperature=0`, `no_adapt_prompt`, the per-cell fixed corpus, `post_run_cmd`
resetting the cache between runs. The target's own `--moe-backend marlin` is
held: this round is about the draft. `num_speculative_tokens` stays at 3.

Grid, the Objective's cell:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

## Decision rule

Sized against the spread this cell now shows under the pinned protocol — IQR
around 3%.

- **Target met** if an arm's median `tg` beats the control's by more than the
  larger of the two IQRs, with a stable verdict and unchanged acceptance. That
  backend becomes the recipe's draft backend.
- **Lever alive** if an arm beats the control by less than that but the engine
  log confirms the backend changed. Worth a re-run at higher `runs` before
  adopting anything.
- **Lever spent** if all three alternatives land within the spread of the
  control, or fail to initialise. Then the draft's cost is its `lm_head`
  re-read rather than its expert GEMM, which no recipe flag can reach, and
  decode-tg has one item left: the board-comparable arena-v2 figure.

An arm that crashes at init is recorded with the engine's error and does not
count toward "spent" — it was never measured.

## Conclusion

**Lever spent.** The draft's MoE backend is not a tuning lever on this box.
`flashinfer_cutlass`, the only alternative that ran, reads 116.5 (iqr 2.5%)
against the 119.3 control (iqr 4.5%, ~5.4 tok/s): inside the spread. Acceptance
was unmoved between the two arms that served, so the null is real, not an
artifact of drafting something different.

Two arms never served. `batched_triton` died in vLLM's own factory, a
constructor missing required arguments; `flashinfer_trtllm` was refused by a
kernel that declines SM121. Both are **permanent properties of this image**,
closed for this epoch and reopened only by an image change. The rule
**contradicted itself** on them, calling init failure both "spent" and "never
measured"; it was recorded as written, not edited.

Every figure here is **cold-cache** by design, so none of them — the 119.3
control included — is comparable to the warm standing best of 119.6. The
round's reasoning is in the memory store: every record carries `decode-tg/h4`
in its `basis`.
