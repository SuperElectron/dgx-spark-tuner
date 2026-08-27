# h4 — the draft path is the fattest target left at c1

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

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
One row per planned run. Figures blank until it is run.

## Hypothesis

The MTP draft runs on an unquantized Triton MoE kernel because nothing else was
ever tried. One of the three other backends this build offers beats it, and the
gain shows up in `tg` at the Objective's cell.

The draft is expensive for a reason the architecture makes plain. The MTP module
is excluded from quantization — `exclude_modules: ["mtp*"]` — so every one of its
tensors is BF16, and it cannot use the NVFP4 Marlin path the target uses. It
falls through to vLLM's *unquantized* dispatcher, which is a different kernel
family with its own option list. Our engine log names it:

    Using TRITON Unquantized MoE backend out of potential backends:
      ['FlashInfer TRTLLM', 'FlashInfer CUTLASS', 'TRITON', 'BATCHED_TRITON']

So `moe_backend: triton` inside `--speculative-config` is not a tuned choice. It
is the default of a dispatcher we reach only because the draft is unquantized,
and three alternatives have never been measured on this box.

Worth, if right: the draft is ~30% of the speculative cycle. Per cycle the
target reads ~2.55 GB and the three draft steps ~1.25 GB, of which 0.86 GB is
the shared 286 MB `lm_head` read once per draft step. A backend that cuts the
draft's expert GEMM time by a quarter is worth roughly 7% of decode — larger
than anything h1 measured, and it costs four runs.

What this round cannot fix: the `lm_head` re-read itself. It is architectural,
not flag-exposed, and it is the larger half of the draft cost. If the backends
land within noise of each other, that is the finding — the draft's cost is its
vocabulary projection, not its experts, and nothing in the recipe can reach it.

## Method

### Variables to test

    speculative-config moe_backend: triton, batched_triton,
                                    flashinfer_trtllm, flashinfer_cutlass

One arm each, nothing else moves. The target's own `--moe-backend marlin` is
held: this round is about the draft.

The three alternatives are named as our engine printed them, lowercased with
spaces as underscores. **A backend that will not initialise is a result, not a
failure** — record what the engine said and move to the next arm. The
unquantized dispatcher offers them for this build, but nothing guarantees they
support a 256-expert top-8 BF16 GEMM at 1-4 tokens on SM121.

### Constant for this round

Everything in Held, and the full protocol: `exact_tg`, `extra_body
temperature=0`, `no_adapt_prompt`, the per-cell fixed corpus, `post_run_cmd`
resetting the cache between runs.

`num_speculative_tokens` stays at 3. It is settled — measured per-position
acceptance 0.87 / 0.76 / 0.61 makes N=3 optimal by ~2% over N=2, and N=4 loses.

Grid, the Objective's cell:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

run-0001 is a fresh control rather than a reuse of h2 run-0001 (112.3 at this
protocol). Both would be valid, but the arms are worth judging against a control
measured in the same sitting.

### What to record

Per arm: `tg` median and IQR, `pp`, `ttfr`, peak power and peak clock, and the
engine's own backend line — `Using X Unquantized MoE backend` — as proof the
flag took effect rather than being silently ignored. An arm whose log still says
TRITON did not test anything.

Also record mean acceptance length from the engine log. A backend change should
move the draft's *speed* and leave acceptance alone, since acceptance is a
property of the model and the text. If acceptance moves, the arm changed what is
being predicted, not just how fast it is predicted, and its `tg` is not
comparable.

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

Of the three alternatives the dispatcher advertises, two cannot run here at all
and the third is not better:

| arm | backend | tg | vs control |
|-----|---------|----|-----------|
| run-0001 | `triton` (control) | 119.3, iqr 4.5% | — |
| run-0002 | `batched_triton` | never served | factory `TypeError` |
| run-0003 | `flashinfer_trtllm` | never served | kernel refuses SM121 |
| run-0004 | `flashinfer_cutlass` | 116.5, iqr 2.5% | −2.8 |

run-0004 is the only measured alternative and it lands 2.8 below the control,
against a larger control IQR of 4.5% (~5.4 tok/s). That is inside the spread:
not a loss, not a win, no difference to read. The hypothesis — that one of the
three beats `triton` — is refuted for the two that cannot start and unsupported
for the one that can.

Acceptance behaved exactly as the method required it to. Control steady-state
3.11–3.32, run-0004 3.05–3.35, first-sample 3.81 in both from the same
low-volume startup window. The backend changed how the draft is computed and
left what is drafted alone, so the `tg` figures are comparable and the null
result is a real null rather than an artifact of drafting something different.

### run-0002 — `batched_triton` crashed at init

The flag was honoured, then the kernel would not construct. vLLM's own factory
is at fault, not the recipe:

    unquantized_fused_moe_method.py:158 _setup_kernel
      -> oracle/unquantized.py:414 make_unquantized_moe_kernel
        experts = experts_cls(...)
    TypeError: BatchedTritonExperts.__init__() missing 2 required
               positional arguments: 'max_num_tokens' and 'num_dispatchers'

`make_unquantized_moe_kernel` builds `experts_cls` without the two arguments
`BatchedTritonExperts` requires. No recipe field supplies them, so this backend
is unreachable in this build — not slow, not misconfigured. The dispatcher
offers it, the constructor rejects it.

Selection is proved: non-default args carried `speculative_config
{... 'moe_backend': 'batched_triton'}`, and `Using BATCHED_TRITON Unquantized
MoE backend` printed one second after `Loading drafter model...`, while the
target held `MARLIN` on the NvFp4 path. The engine never served a request, so
there are no SpecDecoding samples and no `results.yaml`.

Per the decision rule this arm was never measured and does not count toward
"lever spent".

Instrument note: `run.py` did not detect the dead engine. It polled a server
that had already exited for ~12 minutes with no timeout, holding the box.
`exit_on_first_fail` covers a failed request, not an engine that dies at init.

### run-0003 — `flashinfer_trtllm` refused the device

A cleaner failure than run-0002. The dispatcher offered the backend, the kernel
declined the hardware:

    oracle/unquantized.py:284 _return_or_raise
    ValueError: Unquantized MoE backend FlashInfer TRTLLM does not support
                the deployment configuration since kernel does not support
                current device cuda.

Not a bug — a supported-hardware check returning false on SM121. The engine
never served a request. Recorded and, like run-0002, it does not count toward
"lever spent".

The dispatcher lists what it *could* build, not what this device can run. Two
of four listed options are unreachable here for two different reasons: one the
factory cannot construct, one the kernel refuses. That leaves
`flashinfer_cutlass` as the only untested alternative to the `triton` default.

### What this closes, and what it points at

The dispatcher lists what it *could* build, not what this device can run. Two
of four options are unreachable for two unrelated reasons — one a defect in
vLLM's own factory, one an explicit hardware check. `triton` is not the default
because it was chosen; it is the default because on SM121 it is very nearly the
only thing that works.

So h4's own fallback reading is the one that survives: the draft's cost is its
`lm_head` re-read, not its expert GEMM. That is architectural — 286 MB read
once per draft step, three steps per cycle, ~30% of the speculative cycle — and
no recipe flag reaches it. h4 was the last recipe-level lever in decode-tg.

### Where the decision rule contradicted itself

The rule says "**Lever spent** if all three alternatives land within the spread
of the control, *or fail to initialise*", and then says "an arm that crashes at
init ... does not count toward 'spent' — it was never measured." Those cannot
both hold for run-0002 and run-0003.

Recorded, not edited. The practical reading is that the second clause guards
against calling a lever spent on a transient failure — a flaky start, a bad
build — and neither of these is that. A constructor missing required arguments
and a kernel declining the device are permanent properties of this image, not
runs that failed to happen. They are closed for this epoch and reopen only if
the image changes.

### Notes for the next round

- Cache hit rate was 0.0% on every arm, by design: `post_run_cmd` resets it
  between runs and h4 held that constant. So every figure here is cold, and
  none of them is comparable to the warm standing best of 119.6.
- run-0004 logged seven Triton JIT compilations during the first request, and
  its first-request latency spiked accordingly. Warmup is supposed to absorb
  these. Not chased here; it is a property of the instrument, not the lever.
- `run.py` did not notice a dead engine on run-0002 and polled it for ~12
  minutes, and its engine-log capture sits only on the success path, so
  run-0002 and run-0003 both had to have their crash logs recovered by hand
  from the container. Both are instrument defects, both are now scheduled for
  repair before the next round runs.
