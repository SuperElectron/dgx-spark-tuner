# h2 — prefix caching never hits on this harness, but it forces mamba align mode and pays for it at depth

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

<one line, filled at conclusion: TARGET MET / LEVER ALIVE / LEVER SPENT — the
number that decided it>

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Turning `--enable-prefix-caching` off lifts `tg` at `tg128 (c10)` d8192 and
d16384, because the flag buys nothing on this harness while imposing a
context-scaling cost on this architecture.

The mechanism has two halves, both already measured rather than assumed.

*It buys nothing.* Prefix cache hit rate read **0.0% cumulative and 0.0% max in
every sample of all three h1 arms**, and 0.0%/0.7%/0.0% across all three `slots`
arms before them — six runs, zero hits. The cause is the harness, not the
engine: llama-benchy's generated prompts share no common prefix, so there is
nothing to hit (`a509844a`). `run.py` flags the figure SUSPECT on every run
precisely because the recipe asks for caching and the engine reports none.

*It costs something that grows with depth.* On this hybrid `Lfm2ForCausalLM`,
enabling prefix caching forces `mamba_cache_mode = align`. `c548c386` reads the
coupling out of vLLM source: `vllm/model_executor/models/config.py:600-638` sets
`mamba_cache_mode='none'` when prefix caching is disabled, so the align path is
never taken, and it *also* sets `mamba_block_size = max_model_len` instead of
`block_size`. Two things ride along with one flag.

Why this is a depth lever rather than a general one: the align path pads the
mamba page, and the padding is charged against context. h1 established that our
loss is shaped like a cost that scales with context — we win d0 by 111% and
d4096 by 50%, and lose d8192 and d16384 — and h1's own lever explained only part
of that shape, since clearing the d8192 queue did not carry d16384 at all.

**This round must measure its own premise, not assume it.** The
"Padding mamba page size by 300.00%" line and the 300% figure are carried in
from the handoff and have **not** been verified in any archive this experiment
produced. Read it out of `run-0001`'s engine log before reading any throughput
figure; if the line is absent or the percentage differs, say so, because the
whole cost half of the mechanism rests on it.

Worth, if right: d8192 needs 773.3 → 745.70, already cleared by h1's run-0002
but not reproducibly (the arms were inside the noise). d16384 needs 367.3 →
613.31, **+67%**. Nothing in the store sizes the align-mode penalty on any
model, so this round cannot claim the win is reachable — it can only say that
the cost is real, unmeasured, and paid for a cache that has never once hit. That
is a reason to measure, not a prediction of +67%.

## Method

### Variables to test

    enable_prefix_caching: on (control), off

    The recipe's `benchmark: prefix_caching:` key must move with the serve flag,
    or the harness and the engine disagree about what was tested.

Order: control first, then the arm. Two runs, not three — this is a binary flag.

### Constant for this round

`max_num_batched_tokens: 8192`, the baseline value. h1's verdict closed that
lever and its 32768 arm was not separable from control, so this round returns to
the baseline rather than compounding an unproven change. Everything else in
`../recipe.yaml`: `max_num_seqs: 16` (Held), `max_model_len: 32768`,
`gpu_memory_utilization: 0.8`, `--enable-chunked-prefill` on, `--kv-cache-dtype
fp8`, `--quantization fp8`, `--attention-backend FLASHINFER`,
`recipe_version: '1'`.

**A validator interacts with this round and must be respected.** `c548c386`
records that `vllm/config/scheduler.py:248-261` requires
`max_num_batched_tokens >= max_model_len` whenever chunked prefill is off. We
keep chunked prefill **on**, so 8192 remains legal with `max_model_len` 32768.
If the engine refuses the arm anyway, that is a finding — report it, do not
raise `mnbt` to work around it, because doing so would confound this round with
h1's lever.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0, 4096, 8192, 16384 · concurrency 10 · runs 3

**What this grid can and cannot read.** h1 measured within-arm CV at d8192 of
6.9–14.5% and ~7% run-to-run on a byte-identical recipe. Three values per cell
has no interquartile range. This grid therefore cannot resolve anything under
about 15% at d8192 or d16384, and the rule below is written to that limit rather
than to the 3% band h1 wrongly assumed. If the arm's effect is smaller than
that, the honest outcome is "not readable at this grid" and the round says so.

## Decision rule

Read at `tg128` concurrency 10, `tg` only, on the mean of the 3 values, arm
against this round's own control.

- **Target met** if the arm's `tg` exceeds **745.70 at d8192** *and* **613.31 at
  d16384** in the same run, with d0 above 1042.20 and d4096 above 750.01.
- **Lever alive** if the target is not met and the arm beats the control by more
  than 15% at d16384 — larger than the measured scatter, so readable — in which
  case the flag matters and the next run pairs it with the d16384 budget of
  ≈184320 that h1 never reached.
- **Lever spent** if the arm and control differ by less than 15% at d16384, or
  if the arm is lower than the control there. Prefix caching is then not the
  context-scaling cost we are looking for, and the ladder moves to h3.

A pre-declared validity gate, stated as a fact about the arm rather than a
belief about the metric (`b76d0937`): the arm is correctly configured only if
the engine log shows `mamba_cache_mode` not equal to `align`, or the
"Padding mamba page size" line present in the control and absent in the arm.
Confirm the arm from that line, never from a throughput figure. If both runs
report the same mamba cache mode, the flag did not do what `c548c386` says and
the round measured nothing.

## Conclusion

<pending>

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here. 15
lines is enough to name the verdict, the deciding figure, and one line of
why; it is not enough to re-derive the round.
