# h4 — the draft path is the fattest target left at c1

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

## Runs

One row per planned run. Figures blank until it is run.

| run | draft moe_backend | tg t/s | iqr | pp t/s | accept | engine backend line | bench |
|-----|-------------------|--------|-----|--------|--------|---------------------|-------|
| run-0001 | `triton` — control | | | | | | |
| run-0002 | `batched_triton` | | | | | | |
| run-0003 | `flashinfer_trtllm` | | | | | | |
| run-0004 | `flashinfer_cutlass` | | | | | | |

## Conclusion

Pending.
