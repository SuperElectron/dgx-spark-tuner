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

## Round 4 outcome — re-baseline (bench_59e87386d131 re-run, archived as -rebaseline)

tg 108.67 ± 0.17. Lands inside the 108.35–108.96 spread. Conclusion: incumbent
reference is a BAND, ~108.7 ± 0.3 across runs; max_num_seqs=1, max_model_len=8192,
--async-scheduling are all no-ops for this cell. Note: sparkrun reuses benchId for
identical recipe+params, so the re-run reused bench_59e87386d131 — archived
separately as experiements/bench_59e87386d131-rebaseline/.
Decision rule from here: keep only if tg mean > 109.5 (clears band + drift).
Micro-flags can't close a 12% gap to 121.19. Next: big levers.

## Round 5 hypothesis — ngram speculative decoding

tg128 c1 is pure greedy decode of book-corpus continuations. vLLM V1 supports
lossless ngram (prompt-lookup) speculation: draft tokens copied from prompt
matches, verified in one batched step. With pp=2048 of book text and on-topic
continuation, acceptance should be decent; each accepted draft token is nearly
free decode throughput. Greedy + spec decode = identical outputs (lossless), so
benchmark validity holds. Mutation (candidate recipe, new template flag):
  --speculative-config '{"method":"ngram","num_speculative_tokens":4,"prompt_lookup_max":4,"prompt_lookup_min":2}'
Expect: anywhere from -3 (overhead, low acceptance) to +30 tg. High variance,
high ceiling — the first lever with headroom to actually reach 121.19.

## Round 5 outcome — ngram spec decode (bench_4f9da10931e0) — KEEP

tg 112.61 ± 1.94 (+3.9 over 108.7 band, clears >109.5 rule). pp also up
(24986 — spec config doesn't touch prefill; likely run variance). σ grew 10x:
throughput now depends on per-prompt ngram acceptance — expected. Folded
--speculative-config into recipe.yaml. Incumbent = 112.61. Gap to 121.19: 8.6.

## Round 6 hypothesis — deeper speculation (n=8, lookup max 8)

Acceptance was good enough to net +3.9 despite verify overhead. Raising
num_speculative_tokens 4→8 and prompt_lookup_max 4→8 raises the per-step
ceiling; cost is wasted verify FLOPs on rejection — cheap at 0.8B (GPU idles
anyway at c1). Expect +2–8 tg if acceptance holds; regression if rejections dominate.

## Round 6 outcome — spec n=8 (bench_0b93f5cfe862) — revert

tg 111.68 ± 1.75, −0.9 vs incumbent 112.61. Deeper drafts don't pay: rejections
waste verify steps, ttfr degraded (117 vs 104). n=4 stays. Fine-tuning n further
(3, 5) parks until orthogonal levers exhausted — σ~2 makes small deltas invisible.

## Round 7 hypothesis — --async-scheduling stacked on spec decode

Round 3 showed async-scheduling as no-op pre-spec-decode. But ngram drafting adds
per-step CPU work (prompt lookup), raising scheduler overhead — overlap may pay
now. Risk: some vLLM versions reject async + spec decode combo; if launch fails,
that's the lesson, run dir stays. Mutation: add --async-scheduling to candidate.

## Round 7 outcome — async + CPU ngram (bench_03b5a04e760a) — crash

Engine died at config validation: "async scheduling is only supported with
EAGLE/MTP/Draft Model/NGram GPU/DSpark kind of speculative decoding". Lesson:
CPU ngram blocks async scheduling; a GPU ngram drafter exists in this build.
Killed the waiting sparkrun task, removed the container by hand.

## Round 8 hypothesis — ngram_gpu spec method (+ async-scheduling)

The validation error advertises "NGram GPU" as async-compatible. GPU ngram
drafting moves prompt-lookup onto the GPU and unlocks async scheduling — two
wins in one flag if it works: same lossless speculation, less CPU per step,
overlapped scheduling. Mutation: method "ngram" → "ngram_gpu" plus
--async-scheduling. If method name invalid → fast config error, journal, fall
back to testing ngram_gpu alone next.

## Round 8 outcome — ngram_gpu + async (bench_bf8f0926acb8) — needs verification

Mean tg 124.88 but per-run values 153.7 / 114.9 / 106.0 (σ 20.7). Run 1 also had
ttfr 361ms vs 115ms after — looks like warmup/compile artifact inflating run 1,
OR genuine prompt-dependent acceptance swing. Runs 2–3 sit at incumbent level.
Not keepable on this evidence. Action: repeat the identical candidate (same probe
args, runs=3) for 3 more samples; decide on the 6-run picture. benchId will
collide → archive as -verify.
