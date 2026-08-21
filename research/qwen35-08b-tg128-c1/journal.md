# Journal — <experiment name>

Hypotheses before runs, lessons after them, a synthesis every ~5 rounds.
The last synthesis is the handoff every new session starts from.

## Round 0 — baseline

(reproduce the arena recipe verbatim; record the reproduction gap here)

## Round 1 — 2026-08-21

**Hypothesis:** `max_num_seqs=4` (recipe default) makes the scheduler
reserve batch slots for 4 concurrent sequences while the probe runs
exactly 1. Setting `-o max_num_seqs=1` should remove batching slack in
the decode path. Expected: small tg gain, +1–4 tok/s over 108.35.
Baseline: bench_59e87386d131 (108.35 ± 0.27).

**Round 1 outcome:** tg 108.90 ± 0.09 vs baseline 108.35 ± 0.27 — +0.55,
~1.9σ combined: not beyond noise, recipe unchanged. Two real lessons:
(1) pp jumped to 23195 ± 266, matching the arena's 23284 — round 0's
17777 ± 4733 contained one bad run (likely cold page cache); pp repro
gap is CLOSED, only the tg gap (-10.6%) remains. (2) tg σ collapsed
0.27→0.09 with max_num_seqs=1 — worth re-testing later stacked on a
real winner.

## Round 2 — 2026-08-21

**Hypothesis:** recipe serves --max-model-len 262144; KV/block tables and
scheduler are sized for 256k context while the cell needs ~2.2k. Setting
-o max_model_len=8192 shrinks KV bookkeeping and may enable tighter CUDA
graphs. Expected: +2-6 tg tok/s. Caveat (journaled for promotion): a
submitted recipe must serve the full arena grid depths, so this flag
must be re-raised or cell-scoped at promotion time.

## Round 2 outcome — max_model_len=8192 (bench_1851f83d3653)

tg 108.95 ± 0.23 vs incumbent 108.35 ± 0.27. +0.60, ~1.7σ combined — inconclusive, revert.
Notable: rounds 1 and 2 both nudged +0.55–0.60. Either both give a small real
overhead reduction, or day-to-day drift. If a clear winner emerges later, retest
these stacked on it.

## Round 3 hypothesis — --async-scheduling

At 0.8B, decode is CPU-overhead-bound (each step ~1ms of GPU work; scheduler +
API overhead eats the rest). vLLM V1's --async-scheduling overlaps CPU
scheduling with GPU execution — exactly the bottleneck class for tiny models.
This is a command-template flag, not a recipe default, so mutation = candidate
recipe copy (recipe-candidate.yaml) with the flag added; -o can't inject new
flags. Expect: +2–8 tg if not already default in this vLLM build; no-op if it is.

## Round 3 outcome — --async-scheduling (bench_eb6e39538b5e)

tg 108.96 ± 0.28. Again ~+0.6 over baseline, ~1.6σ — inconclusive alone, revert.

## Synthesis after 3 rounds — baseline is suspect

Three different mutations (max_num_seqs=1, max_model_len=8192, --async-scheduling)
all landed 108.90–108.96, tightly clustered, each ~+0.6 over baseline's 108.35.
Odds that three unrelated flags give identical gains: low. Simpler explanation:
round-0 baseline was a low outlier — it also showed the pp anomaly (17777 ± 4733
vs ~22–23k everywhere since), consistent with first-run interference (cold page
cache after model download, container image pull in same cycle).
Action: round 4 re-runs the incumbent recipe UNCHANGED to re-baseline. If it
lands ~108.9, epoch resets: incumbent reference becomes ~108.9 and the three
flags are true no-ops for this cell; next mutations must target bigger levers
(cuda graphs, attention backend, batched-tokens) to move toward 121.19.
