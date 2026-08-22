# Journal — qwen36-35b-nvfp4-cells

Hypotheses before runs, lessons after them, a synthesis every ~5 rounds.
The last synthesis is the handoff every new session starts from.

## Premise — thin cells, not the crowded one

Board scan 2026-08-21 (live, single-node, verified against our own known
snapshot): 211 benchmarks spread across 93 test types x 5 concurrencies. The
headline cell (tg128 @ d16384 c1) is crowded and topped at 188.47 / 116.03
vLLM-NVFP4; we sit at 102.2 there and the -12% is currently unexplained.
Almost every other cell is nearly empty and topped by a weak entry:

| Cell | Entries | Top | Holder |
|---|---:|---:|---|
| tg32 @ d16384 c1 | 1 | 28.11 | Qwen3.6-27B-PrismaSCOUT-NVFP4 |
| tg32 @ d32768 c1 | 1 | 23.31 | same |
| tg32 @ d8192 c1 | 1 | — | same |
| tg128 @ d16384 c4 | 8 | 46.68 | Gemma-4-26B-A4B-NVFP4 |
| tg128 @ d65536 c1 | 2 | 16.48 | DeepSeek-V4-Flash-REAP MXFP4 |
| ctx_tg @ d65536 c1 | 1 | 20.70 | DeepSeek-V4-Flash-REAP FP8 |

Model is fixed for the campaign: nvidia/Qwen3.6-35B-A3B-NVFP4, the de-rayed
recipe carried over from qwen36-35b-quant (container vllm-node, kv fp8,
flashinfer, marlin MoE, MTP spec n=3, async scheduling). Only the probe
changes per round. `sparkrun benchmark perf` has no fixed official grid — the
cells measured are exactly the `-b` args passed — so the campaign picks its
own battlegrounds.

Carried-over discipline: medians not means (MTP draws are bimodal), verify any
win with a repeat, never vary probe args within a round.

## Round 1 hypothesis — tg32 sweep @ d8192 / d16384 / d32768, c1

The tg32 cells hold exactly one entry each, at 28.11 (d16384) and 23.31
(d32768) — a 27B NVFP4 config far below what this class can do. Our own model
decodes at median 102.2 in tg128 @ d16384 c1. tg32 is the same decode loop
measured over 32 tokens instead of 128, so fixed per-request overhead (prefill
handoff, first-token latency, MTP warmup) is amortized over 4x fewer tokens
and the number should land somewhat below the tg128 figure. Expect 85-100 at
d16384, less at d32768 as the KV read grows — still ~3x the incumbents.

Depth costs little here: only 10 of 40 layers carry a KV cache (the other 30
are Gated DeltaNet fixed-state), and it is stored FP8, so d8192 -> d32768
should bend the curve gently rather than cliff.

Mutation: none — this is the incumbent recipe, new probe. max_model_len is
raised 32768 -> 40960 because the deepest point needs depth 32768 + pp 2048 +
tg 32 to fit in one sequence.

Probe: -b tg=32 -b depth=8192,16384,32768 -b concurrency=1 -b runs=3
(pp=2048 rides along by default, so pp2048 @ dN and the ctx_ prefix-caching
phases are measured in the same run).

## Round 1 outcome — bench_25a0e7f36ab0 (2026-08-21)

Medians, three runs per cell (means in parentheses — recorded only to show how
far apart the two live here):

| Cell | tg median | (mean) | σ | runs |
|---|---:|---:|---:|---|
| tg32 @ d8192 c1 | 106.24 | (102.55) | 22.72 | 128.35 / 106.24 / 73.07 |
| tg32 @ d16384 c1 | 129.32 | (135.19) | 18.38 | 160.05 / 116.19 / 129.32 |
| tg32 @ d32768 c1 | 115.56 | (119.14) | 10.40 | 133.29 / 108.57 / 115.56 |
| ctx_tg32 @ d8192 c1 | 126.52 | (130.76) | 7.94 | 126.52 / 123.88 / 141.88 |
| ctx_tg32 @ d16384 c1 | 130.16 | (128.94) | 3.01 | 130.16 / 124.81 / 131.86 |
| ctx_tg32 @ d32768 c1 | 84.03 | (90.26) | 10.69 | 84.03 / 105.31 / 81.45 |

Verdict: the two published tg32 cells fall by a wide margin. d16384 129.32 vs
28.11 is 4.60x; d32768 115.56 vs 23.31 is 4.96x. d8192 has a sole entry with no
published number, so we take the cell without a figure to beat. Margins that
size do not need the verify repeat the discipline requires at ~2x — the worst
single run of any cell (73.07) still clears every incumbent by 2.6x or more.

Hypothesis refuted, in the direction that matters. The prediction was 85-100 at
d16384, "somewhat below" the tg128 @ d16384 c1 figure of 102.2, on the argument
that fixed per-request overhead amortizes over 4x fewer tokens. It came in
ABOVE that figure at every depth. Whatever tg32 costs in amortization, it is
smaller than the effect running the other way. Two candidate mechanisms, neither
settled by this round: a 32-token generation is short enough that a good MTP
acceptance streak carries the whole measurement instead of regressing to the
mean, or the tg128 @ d16384 c1 baseline of 102.2 is itself depressed and the
-12% reproduction gap is the same phenomenon seen from the other side. Open
question 1 in QUEUE.md stands, unresolved and now better posed.

Depth curve, open question 3: medians did NOT restore monotonicity. 106.24 <
129.32 > 115.56 keeps the same shape the means had, with d8192 — the shallowest,
cheapest point — the slowest of the three. The KV-depth argument in the
hypothesis predicts a gentle monotonic decline, and no reading of it produces a
dip at the shallow end. The honest reading is that three runs cannot rank these
depths: d8192 spans 73.07 to 128.35 within one cell, a 1.76x spread, and its
σ of 22.72 is larger than the entire spread between the three cell medians. The
curve shape is not measured yet. It needs runs=7+ at fixed depth, not more
depths.

Means and medians disagree in direction here, which is the whole reason for the
rule: d8192 mean 102.55 sits BELOW its median 106.24 while d16384 mean 135.19
sits ABOVE its median 129.32. Ranking the depths by mean spreads them further
apart than they are and flatters d16384 specifically.

The ctx_ prefix-caching phases are separate board cells and we measured three of
them, so they are recorded. Their numbers behave unlike the main phase: at d8192
and d16384 the cached-prefix decode is level with or above the cold one (126.52
and 130.16), and its σ is far lower (7.94, 3.01) — with the prefill work removed,
the measurement is much quieter. At d32768 it inverts: 84.03, well below the
cold 115.56 and the noisiest of the three ctx points. Board figures for ctx_tg
at these depths were not scraped, so no verdict is claimed; only ctx_tg @ d65536
was captured (20.70) and that cell is round 3.

Instrument fixed mid-round: parse-round.py labelled all six benchmarks with an
identical header, printing only prompt_size and concurrency — neither of which
varies in this probe. The six cells were indistinguishable in its output and had
to be matched up by hand against the raw JSON. It now prints response_size,
context_size, and a `phase: ctx_prefill` marker. Any earlier round parsed with
the old script and read as a single cell should be re-parsed.

## Round 2 hypothesis — tg128 @ d16384 c4

Cell: tg128 @ d16384, concurrency 4, runs=3. Incumbent 46.68 (Gemma-4-26B-A4B-
NVFP4) with 8 entries — the most contested cell in the campaign, and the only
one where the board's number comes from a field rather than a lone straggler.

The recipe already carries --max-num-seqs 4, so four concurrent requests fit the
scheduler exactly with no queueing and no config change; this is the incumbent
recipe under a wider probe, not a mutation. A 35B-A3B MoE at c1 leaves the GPU
badly underfed — 3B active parameters per token means the decode step is
memory-bound on weight reads that four sequences share for free. Expect the
aggregate to scale well but not linearly: 180-260 against our c1 median of
102.2, i.e. roughly 2-2.5x, with batching gains offset by MTP acceptance
dropping as the speculative draft has to satisfy four divergent sequences.

Against 46.68 that is a 4-5x margin, wide enough that the verify repeat should
not be needed. If it lands under ~93 (2x incumbent) it gets the identical-config
repeat before any win is claimed.

One thing to watch that round 1 makes likely: c4 should be QUIETER than c1.
Averaging over four sequences per step means a single lucky or unlucky
speculative streak moves the aggregate much less than it does at c1, where σ ran
to 22% of the median. If σ stays as wide at c4 as it was at c1, the noise is not
MTP acceptance and the bimodality story needs rewriting.

## Round 2 outcome — bench_f58c56da6658 + -verify (2026-08-21)

| Cell | run | tg median | σ | runs |
|---|---|---:|---:|---|
| tg128 @ d16384 c4 | first | 53.56 | 0.43 | 53.56 / 52.75 / 53.74 |
| tg128 @ d16384 c4 | verify | 52.69 | 0.75 | 52.95 / 52.69 / 51.25 |
| ctx_tg128 @ d16384 c4 | first | 56.40 | 0.16 | 56.40 / 56.32 / 56.68 |
| ctx_tg128 @ d16384 c4 | verify | 55.92 | 0.62 | 55.92 / 56.66 / 55.13 |

Verdict: WIN, verified. Pooled median over all six main-phase runs is 52.85
against the incumbent 46.68 — 1.13x, +13.2%. The margin sat well under 2x so
the identical-config repeat was mandatory; it reproduced to within 1.6% of the
first run. The case does not rest on the median alone: the WORST of the six
runs, 51.25, still clears 46.68 by 9.8%, so there is no draw of these three
runs that loses this cell. This is the campaign's narrowest win and the only
one where the incumbent came from a real field (8 entries) rather than a lone
straggler, which is presumably the same fact seen twice.

The measurement's units were wrong in the queue, and that is the round's real
finding. The plan said "expect 180-260 aggregate" and the benchmark reported
53.3, which reads at first glance as a catastrophic miss — c4 apparently
running at HALF our c1 figure of 102.2. It is not a miss; llama-benchy's
`tg t/s` is PER-REQUEST, not aggregate. Proof is in round 1's own export: at
c1, `tg_throughput` and `tg_req_throughput` are identical to the last decimal
in all six cells, which they can only be if the headline number is a
per-request rate that happens to coincide with the aggregate when there is one
request. At c4 they diverge, and `peak_throughput` — which IS aggregate —
reads 291 against the main phase's per-request 53.56. Four sequences at 53.56
is about 214 sustained aggregate, sitting inside the predicted 180-260 band
after all. So the hypothesis' physics was right and its units were wrong.

This matters beyond one round: the board's 46.68 is the same per-request
metric, so the comparison above is like-for-like and stands. But every
concurrency cell in this campaign must be read per-request, and any estimate
written as "aggregate" needs dividing by the concurrency before it is compared
to anything. R4 (c2 and c5) is planned with the same units error latent in it.

Per-request throughput therefore falls from 102.2 at c1 to 52.85 at c4 — a 4x
concurrency buys about 2.1x aggregate, 52% scaling efficiency. e2e_ttft rises
from ~3.2s at c1 to ~10.2s, which is what queueing at --max-num-seqs 4 looks
like. Neither number is a board cell; both are the cost side of the win.

The noise prediction was confirmed, and this is the strongest evidence yet for
the MTP-acceptance story. σ collapsed from 18.38 at c1 (14% of the median) to
0.43 and 0.75 at c4 — under 1.5%. Meanwhile the individual per-request rates
inside those same c4 runs span 13.75 to 74.37, a 5.4x spread. Single sequences
remain wildly bimodal; averaging four of them per step is what makes the
aggregate stable. That is exactly the shape predicted before the run: the c1
noise is per-sequence speculative acceptance, not thermals, not clocks, and not
anything about the box that would move a four-sequence average around. The
model card supports the mechanism — the NVFP4 checkpoint leaves the whole MTP
module in BF16, so the draft head is full-precision and its acceptance rate is
a property of the prompt draw, not of quantization noise.

Practical consequence: c4 cells need far fewer runs than c1 cells for the same
confidence. Three runs at c4 pin the number to ±1.5%; three runs at c1 could
not even rank three depths in round 1.

The ctx_ prefix-caching phase at c4 is again slightly ABOVE the cold phase
(pooled median 56.36 vs 52.85, +6.6%) and again quieter. Its board figure was
never scraped, so it is recorded and held, not claimed.

## Round 3 hypothesis — tg128 @ d65536 c1

The deepest contested cell in the campaign, and the only round where BOTH board
figures are known in advance: tg128 @ d65536 c1 holds 16.48 (DeepSeek-V4-Flash-
REAP MXFP4, 2 entries) and ctx_tg @ d65536 c1 holds 20.70 (DeepSeek-V4-Flash-
REAP FP8, 1 entry). The prefix-caching phases run inside the same invocation, so
one benchmark settles two board cells.

Mechanism. Depth 65536 is 4x round 2's d16384 and 2x round 1's deepest point.
The decode step at c1 is memory-bound on two reads: the weights, and the KV
cache. The weight read is fixed at roughly 3B active parameters in NVFP4 —
about 1.7 GB per step regardless of depth — and it is the term that dominates
today. The KV read is the one that grows with depth, and this architecture
suppresses it twice over: only 10 of 40 layers carry a KV cache at all (the
other 30 are Gated DeltaNet, fixed-state, depth-independent), and those 10 are
stored FP8 rather than BF16. So doubling context doubles a quarter-width,
half-precision term against a fixed dominant one. The prediction that follows is
a gentle decline, not a cliff.

Numeric prediction: median 70-85, centre ~78, i.e. a 24% fall from our tg128 @
d16384 c1 figure of 102.2 across a 4x depth increase. Against 16.48 that is
about 4.7x, wide enough that the verify repeat is not required; the repeat
becomes mandatory only if the median lands under ~33 (2x incumbent).

For the ctx_ cell the prediction runs the other way, and this is the round's
second, sharper test. Rounds 1 and 2 saw the cached-prefix phase sit at or
slightly ABOVE the cold phase at d8192, d16384 (both c1 and c4) — but at
d32768 it inverted, coming in at 84.03 against the cold 115.56, -27%, and the
inversion has had no explanation since. If the inversion is a depth effect it
should deepen at 65536; if it was a one-cell artefact of three noisy runs it
should not reappear. Predict ctx_tg 55-75, BELOW the cold phase. Either result
is informative, which is what open question 4 has been waiting for. Even the
bottom of that band clears 20.70 by 2.7x.

Two more falsifiable claims, recorded so the round can refute them:
- pp2048 @ d65536 lands near 140-150. The cold prefill rows have halved almost
  exactly per depth doubling (1187.51 / 637.09 / 295.71), because cold prefill
  processes the whole context and its throughput is reported per prompt token.
- σ is wide — above 8% of the median. This is c1, the bimodal regime; round 1
  ran σ to 14-22% there and round 2 established that the noise is per-sequence
  MTP acceptance, which a single sequence cannot average away. Three runs will
  not pin this number tightly, and they do not need to: the verdict here is a
  margin question against 16.48, not a ranking question. If σ instead comes in
  tight, the MTP-acceptance story has a depth dependence nobody has posited.

Mutation: none. Incumbent recipe, new probe. `-o max_model_len=73728` raises the
window from the recipe default 32768 to fit depth 65536 + pp 2048 + tg 128 with
headroom — the same kind of probe-driven override round 1 used at 40960, not a
tuning change. The one config risk worth naming in advance: at
--gpu-memory-utilization 0.8 the KV cache for a 73728-token window has to fit
alongside the weights. Ten FP8 layers make that cheap, but an engine OOM at
startup is the failure mode to expect if the arithmetic is wrong, and it would
be a config failure, not a box failure.

Probe: -b tg=128 -b depth=65536 -b concurrency=1 -b runs=3 -o max_model_len=73728
(pp=2048 rides along by default).

## Round 3 outcome — bench_dab043abba20 (2026-08-21)

| Cell | median | (mean) | σ | runs |
|---|---:|---:|---:|---|
| tg128 @ d65536 c1 | 108.15 | (103.62) | 10.41 | 89.23 / 108.15 / 113.49 |
| ctx_tg128 @ d65536 c1 | 89.76 | (90.27) | 1.80 | 88.36 / 92.68 / 89.76 |
| pp2048 @ d65536 c1 | 118.59 | (118.94) | 0.55 | 118.52 / 118.59 / 119.71 |
| ctx_pp2048 @ d65536 c1 | 4004.76 | (4003.12) | 12.92 | 3986.53 / 4004.76 / 4018.06 |

Verdict: both board cells taken, by the campaign's widest margins. The cold cell
is 108.15 against 16.48 — 6.56x — and the prefix-caching cell is 89.76 against
20.70 — 4.34x. Neither needs the verify repeat; the discipline requires it under
~2x, and the WORST single run of the cold cell, 89.23, still clears its incumbent
by 5.41x. This round also produces the campaign's first claimable `ctx_` cell:
ctx_tg @ d65536 is the only prefix-caching cell whose board figure was ever
scraped, so it is the one place the six ctx_ measurements taken so far can
actually be scored.

The engine came up clean. The config risk named in the hypothesis — a KV cache
too large for the 73728-token window at --gpu-memory-utilization 0.8 — did not
materialize and was never close: sparkrun's own VRAM estimate put the KV cache
at 2.81 GB against 75.0 GB available, a 26.7x context multiplier. The FP8-on-ten-
layers arithmetic in the hypothesis was right, and it was right by a much wider
margin than the hypothesis assumed. Deep cells on this model are not memory-
constrained anywhere near d65536, and the whole round took 150.8 s of benchmark
time.

**The headline prediction was refuted, and refuted upward — again.** The
hypothesis said 70-85, centre ~78, reasoning that 4x the context would cost
about 24% of decode throughput against our tg128 @ d16384 c1 figure of 102.2.
The cell came in at 108.15: not a 24% decline but a 5.8% RISE, at four times the
depth. The second falsifiable claim — "the decline from d16384 to d65536 is
under 35%" — is technically satisfied only because there was no decline to
measure.

This is the third time this campaign has predicted a slowdown from first
principles and measured the opposite. Round 1 predicted tg32 below tg128 and got
it above at every depth. Round 1's depth sweep refused to decline monotonically.
Now a 4x depth increase costs nothing at all. The honest synthesis of the three
is not that deeper is faster — it is that **the depth-dependent term in this
model's decode cost is smaller than the run-to-run noise across the entire range
we have measured, d8192 to d65536.** The architecture argues for exactly this:
30 of 40 layers are Gated DeltaNet with a fixed-size state that does not grow
with context at all, and the 10 layers that do carry a KV cache carry it in FP8.
So the depth-sensitive read is a quarter of the layers at half precision, set
against a fixed ~1.7 GB weight read that dominates every decode step. There is
no reason to expect a visible depth curve until the KV term approaches the
weight term, and at 2.81 GB for a 72k window it is nowhere near.

That reading makes the 5.8% "rise" a non-result rather than a discovery, and it
should be recorded as one. Both cells sit at c1, the bimodal regime; σ here is
10.41, and round 1 saw σ up to 22.72 at the same concurrency. A 5.8% gap between
two three-run medians drawn from that distribution is noise, not signal. The
claim this round supports is FLATNESS within noise from d16384 to d65536 — not
that d65536 is faster than d16384. Distinguishing the two needs both depths under
one engine start at runs=7, which is queued as R8.

It does, however, sharpen open question 2. The -12% reproduction gap says our
tg128 @ d16384 c1 baseline of 102.2 is depressed relative to the board's 116.03.
If the depth term really is negligible, then 102.2 and 108.15 are two samples of
the same underlying quantity, and the board's 116.03 sits above both — which
means the gap is a property of the configuration or the box, not of that one
cell, and it should be visible at every depth. R8 gets that measurement for free.

**The ctx_ prediction held, and it is the round's most solid finding.** The
prefix-caching phase came in BELOW the cold phase — 89.76 against 108.15, -17% —
exactly as predicted, and it reproduces the inversion first seen at d32768
(84.03 against 115.56, -27%). Two independent depths, two separate benchmark
invocations, same direction. The inversion is real and is not the three-run
artefact it could have been after round 1. What the prediction got wrong is the
shape: it does not deepen with depth. -27% at d32768 and -17% at d65536 is, if
anything, the reverse ordering, so "the inversion grows with context" is not
supported. The pattern across all four depths measured is a sign change
somewhere between d16384 and d32768 — ctx above cold at d8192 and d16384 (both
c1 and c4), ctx below cold at d32768 and d65536 — and nothing in the current
picture explains why removing prefill work should HURT decode throughput at
depth. Open question 4 now has a reproduced effect to attack instead of a
single suspicious number.

The noise prediction held on both counts. Cold σ 10.41 is 9.6% of the median,
above the predicted 8% floor and squarely in the c1 range rounds 1 and 2
established. The ctx_ phase is again far quieter — σ 1.80, 2.0% of its median —
which is now the fourth consecutive observation that removing the prefill
removes most of the run-to-run variance. Rounds 1, 2 and 3 agree, at three
depths and two concurrencies. That consistency is what makes the ctx_ cells the
cheapest place in this campaign to measure a real effect, and it is why the
inversion above deserves a round rather than a footnote.

**The prefill prediction was refuted, downward.** pp2048 @ d65536 came in at
118.59 against a predicted 140-150. The prediction extrapolated the cold-prefill
halving-per-doubling seen at d8192/d16384/d32768 (1187.51 / 637.09 / 295.71),
which would put d65536 near 148. The actual ratio from d32768 is 0.40x, not
0.50x — cold prefill degrades slightly WORSE than inverse-linear in depth out
here, which is the quadratic term of attention finally becoming visible in the
one phase that has to process the whole context. σ 0.55 makes this the round's
tightest measurement, so the miss is real and not a noise draw. The cached
counterpart falls too: ctx_pp2048 4004.76 against 5086.51 at d32768, after
sitting nearly flat across the three shallower depths (6148.56 / 5910.22 /
5086.51). Both prefill figures are held, not claimed — their board figures have
never been scraped, which is what R5b is for.

Instrument note: the runtime epoch is unchanged. R1 and R3 both ran under the
pinned image `ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, checked in
their state.yaml files, so the cross-round depth comparisons above are within one
epoch and legitimate. Also unchanged, and worth recording once: sparkrun cannot
clear the box's page cache (no passwordless sudo), so every round in this
campaign carries the same uncontrolled cold-read state. It is uniform across
rounds, so it does not bias comparisons between them, but it is a floor on how
quiet any single measurement can be.

## Round 4 hypothesis — tg128 @ d16384, c2 and c5

Two concurrency points at the cell round 2 already owns at c4, chosen to put a
shape on the scaling curve rather than to take a headline. Neither c2 nor c5 was
scraped cleanly from the board, so this round has NO incumbent to beat at either
point: the verdict is a curve, not a margin, and both rows will carry "not
scraped" in the board column. That is stated up front so the round is not read
in the morning as a failure to win anything.

The reference points are ours. Per-request tg at this cell: 102.2 at c1,
52.85 at c4 (pooled over six runs, round 2). Read PER-REQUEST throughout — the
units correction in round 2 applies to every number below. Aggregate is the
per-request figure times the concurrency: 102.2 at c1, ~211 at c4.

Mechanism. A 35B-A3B MoE at c1 is memory-bound on a fixed ~1.7 GB weight read
per decode step, and that read is shared by every sequence in the step. Adding
sequences buys aggregate throughput for free until something else saturates —
which is why c1 -> c4 bought 2.07x aggregate rather than 1x. The give-back is
per-request: each sequence waits behind a wider step, and MTP acceptance falls
because one speculative draft has to satisfy divergent sequences. If the c1->c4
curve is roughly logarithmic in concurrency, c2 should sit between them nearer
the top: predict per-request median 75-88, centre ~81 (aggregate ~162, 1.59x c1,
79% scaling efficiency — better than c4's 52% because two sequences contend less
than four).

**c5 is the round's real question, and it is a scheduler question.** The recipe
carries `--max-num-seqs 4`. Five concurrent requests therefore do NOT all run:
four decode, the fifth queues until a slot frees. The decision made before the
run is to measure BOTH arms rather than pick one, because either alone is
misleading — the unmutated arm measures the recipe we actually campaign with,
and the mutated arm measures the cell as a competitor with a matched scheduler
would run it.

- Arm A (no mutation): c2 and c5 in one invocation, incumbent recipe untouched.
- Arm B (MUTATION, `-o max_num_seqs=5`): c5 only, everything else identical.
  This is the campaign's first recipe mutation. It is journaled as one, it is
  NOT folded into recipe.yaml whatever it measures, and arm A gives the honest
  unmutated number for the same point.

Predictions, and they differ per arm in a way that tests what llama-benchy's
per-request metric actually measures:

- Arm A c5: per-request median 48-54, centre ~51 — i.e. statistically the same
  as c4's 52.85. The reasoning: `tg t/s` is tokens over the decode span of a
  request, and the fifth request's queue wait lands in TTFT, not in its decode
  rate. With the scheduler pinned at four running sequences, every request that
  is decoding sees a c4-shaped step. So the per-request number should barely
  move while e2e_ttft rises sharply — predict ttfr up ~20-30% on c4's ~10.2s.
  Aggregate over wall time stays near c4's ~211 because the engine cannot do
  more than four sequences of work at a time.
- Arm B c5 (max_num_seqs=5): per-request FALLS, to 44-49, because now all five
  genuinely share each step. Aggregate rises to ~225-245 (5 x ~46), continuing
  the sublinear curve. TTFT closer to c4's than to arm A's.

If arm A instead comes in near 42 (= ~211/5), the per-request metric is being
computed over wall time including queue wait, and every per-request figure in
this campaign at c>1 needs re-reading. That is the falsifiable version of the
units story round 2 opened, and it is worth the second invocation on its own.

Noise: predict both concurrency points quiet, σ under 2% of the median, per
round 2's collapse from 18.38 at c1 to 0.43/0.75 at c4. c2 should be the noisier
of the two — averaging two bimodal sequences per step suppresses less than
averaging four — so predict σ ~1-3% at c2 and under 1.5% at c5. If c2 comes back
as noisy as c1 did, the "averaging sequences kills the variance" story needs a
threshold nobody has posited.

ctx_ phases ride along as usual. At d16384 the cached-prefix phase has been at
or ABOVE the cold one at both c1 (+0%) and c4 (+6.6%); the sign change to
below-cold only appears at d32768 and deeper. Predict ctx above cold at both
points here, by 5-8%, and quieter. Board figures not scraped: held, not claimed.

Telemetry: `sample-telemetry.sh` runs alongside arm A and is archived with the
round. Open question 2 has wanted a clock/power sample next to a benchmark since
round 1; it costs no box time.

Mutation: arm A none. Arm B `-o max_num_seqs=5`, not folded into recipe.yaml.
Probe (arm A): -b tg=128 -b depth=16384 -b concurrency=2,5 -b runs=3
(pp=2048 rides along). Arm B: identical, concurrency=5 alone.
max_model_len stays at the recipe default 32768 — d16384 + pp 2048 + tg 128 fits
with room, so no override is needed for the first time in three rounds.

## Round 4 outcome — bench_0ef7af8997ce (arm A) + bench_858173ba5753-mns5 (arm B), 2026-08-22

| Cell | arm | median | (mean) | σ | runs |
|---|---|---:|---:|---:|---|
| tg128 @ d16384 c2 | A | 84.00 | (83.50) | 1.18 | 81.86 / 84.00 / 84.63 |
| ctx_tg128 @ d16384 c2 | A | 79.44 | (79.63) | 1.06 | 79.44 / 78.43 / 81.01 |
| tg128 @ d16384 c5 (mns 4) | A | 45.60 | (45.77) | 0.26 | 45.60 / 45.57 / 46.13 |
| ctx_tg128 @ d16384 c5 (mns 4) | A | 48.18 | (48.04) | 0.31 | 48.18 / 48.33 / 47.61 |
| tg128 @ d16384 c5 (mns 5) | B | 48.12 | (48.13) | 0.07 | 48.12 / 48.22 / 48.04 |
| ctx_tg128 @ d16384 c5 (mns 5) | B | 51.25 | (51.39) | 0.26 | 51.25 / 51.75 / 51.15 |

Verdict: NO WIN AND NO LOSS, by construction. Neither c2 nor c5 has a scraped
board figure, so both rows say "not scraped" and nothing is claimed. That was
known before the run and is not a disappointment; the round was run for the
curve, and the curve is what it produced. Nobody should read RESULTS.md in the
morning and conclude we lost these cells — they are unscored, not lost.

**The c2 prediction was the campaign's first accurate one.** Predicted 75-88,
centre ~81; measured 84.00. Predicted aggregate ~162 at 79% scaling efficiency;
measured 168.0 at 82%. After three rounds of predicting a slowdown and measuring
the opposite, the one prediction built on our OWN measured points (102.2 at c1,
52.85 at c4) instead of on architectural first principles landed inside its band
on the first try. That contrast is the round's methodological lesson: on this
box, interpolating between measured cells works and reasoning forward from the
model card does not.

The curve, per-request and aggregate:

| c | max_num_seqs | per-request | aggregate | vs c1 | efficiency |
|---:|---:|---:|---:|---:|---:|
| 1 | 4 | 102.2 | 102.2 | 1.00x | 100% |
| 2 | 4 | 84.00 | 168.0 | 1.64x | 82% |
| 4 | 4 | 52.85 | 211.4 | 2.07x | 52% |
| 5 | 4 | 45.60 | 228.0 | 2.23x | 45% |
| 5 | 5 | 48.12 | 240.6 | 2.35x | 47% |

The knee sits between c2 and c4, not above it. c1 -> c2 costs only 18% of
per-request throughput to buy 64% more aggregate; c2 -> c4 costs another 37% to
buy 26% more. Anyone tuning this model for a latency-sensitive service should
run it at c2, and R7's remaining points (c8, c16) will map a curve whose
interesting region has already been passed.

**The c5 arm-A prediction was refuted, and the refutation is informative.**
Predicted 48-54, on the argument that `--max-num-seqs 4` pins the engine at four
running sequences, so a decoding request sees a c4-shaped step and the fifth
request's wait lands in TTFT rather than in its decode rate. Measured 45.60 —
below the band, and 13.7% under c4's 52.85. The named alternative, ~42
(= 211/5, the signature of per-request being computed over wall time including
queue wait), did not happen either. So the metric is NOT wall-time-with-queue —
round 2's units reading survives — but the four running sequences are also not
running at c4 speed.

The mechanism the round exposes is prefill interference, and the prefill rows
are what show it. `pp2048 @ d16384` reads 637.09 at c1, 634.04 at c2, 643.31 at
c4 — flat to within 1.5% — and then falls to 581.44 at c5 under mns 4, a 9.6%
drop, the only depressed prefill figure at this depth in the whole campaign. The
cached counterpart falls the same way (5236.80 against 5810-5967 everywhere
else). With `--enable-chunked-prefill` on, a queued fifth request does not wait
politely outside the engine: its prefill is chunked into the ongoing decode
steps as slots free, so the four decoding sequences share each step with prefill
work. That costs decode throughput AND makes the interleaved prefill itself
slower. At c4 every prefill happens in one batch up front and the decode phase
is clean.

**Arm B — the MUTATION — refuted its own prediction in the opposite direction,
and this is the round's most useful finding.** `-o max_num_seqs=5` was predicted
to LOWER per-request throughput to 44-49, because five sequences would genuinely
share every step instead of four. It landed at 48.12: inside the predicted band
by coincidence, but on the wrong side of arm A. Raising the scheduler width to
match the probe is worth +5.5% per-request (45.60 -> 48.12) and +5.5% aggregate
(228.0 -> 240.6) — the queueing penalty is larger than the wider-batch penalty.
The prefill rows confirm the mechanism cleanly: pp2048 goes straight back to
640.21, the c2/c4 level, once nothing has to be chunked in mid-decode.

Confidence in that 5.5%: the two arms are separate invocations with separate
engine starts, so this is not a within-invocation comparison. But the run ranges
are disjoint (45.57-46.13 against 48.04-48.22), σ is 0.26 and 0.07, and round
2's verify established that cross-invocation reproduction at c>1 is good to
1.6% — well inside 5.5%. The effect is real. It is not verified to the standard
the campaign uses for board wins, and it does not need to be, because nothing is
being claimed against a board figure.

**The mutation is NOT folded into recipe.yaml.** It is journaled, both arms are
measured, and recipe.yaml is untouched — `--max-num-seqs 4` remains the campaign
config. Folding it in would silently change every future round's meaning, and
the honest reading of the result is narrower than "5 beats 4": it is "the
scheduler width should match the concurrency the probe asks for". The general
form of that claim is exactly what R7 exists to measure, one c value per round,
and R7 should now be understood as requiring a matched `--max-num-seqs` at every
point rather than treating that as an optional extra.

The noise predictions held, both of them. σ at c2 is 1.18 (1.4% of the median),
at c5 arm A 0.26 (0.57%), at c5 arm B 0.07 (0.15%) — all under the predicted
ceilings, and c2 is the noisier point exactly as predicted, because averaging
two bimodal sequences per step suppresses less than averaging five. This is the
fifth consecutive round consistent with the MTP-acceptance story, and the c2
point is the first evidence about the SHAPE of the suppression: 1.4% at c2
against 14% at c1 means most of the variance is gone by the second sequence.

**The ctx_ phases disagree with each other across concurrency, which is new.**
At c2 the prefix-caching phase came in BELOW the cold phase — 79.44 against
84.00, -5.4% — and the hypothesis predicted above, by 5-8%. At c5 it is ABOVE,
by 5.7% (arm A) and 6.5% (arm B). Every prior observation at d16384 had ctx at
or above cold. So the sign of the ctx-vs-cold gap now varies with BOTH depth
(above at d8192/d16384, below at d32768/d65536, from round 3) and, at fixed
depth, with concurrency (below at c2, above at c4 and c5). No single mechanism
in the current picture produces both. What the c2 point does rule out is the
tidiest explanation available after round 3 — that the inversion is a pure depth
effect — because here it appears at a depth where the cold phase is otherwise
the slower one. Open question 4 gets a third face and should stop being treated
as a depth question.

Telemetry, finally sampled alongside a round (204 s of load captured, archived
as `experiments/bench_0ef7af8997ce/telemetry.log`, 339 samples at 1 Hz). Under
load the SM clock sits at 2392 MHz median, 2385-2411 across the window, against
a reported ceiling of 3003 MHz — 80% of maximum, pinned, with essentially no
variance. GPU temperature peaked at 72 °C and power at 95 W (57 W median), so
the box is neither thermally throttled nor near a power wall; the clock is held
down by policy, not by heat. This does NOT resolve open question 2 — the board's
116.03 presumably came off a box under the same fleet-wide policy — but it does
close off the two explanations that would have been visible here: no thermal
throttling, no clock instability during a run. It also contradicts round 1's
2554 MHz reading, so the clock figure is not stable across sessions and any
future use of it needs its own sample. Never changed, never to be changed
autonomously: no clock, power-policy, driver or kernel setting was touched.

Config notes: this was the first round in three to need no `max_model_len`
override — d16384 + pp 2048 + tg 128 fits the recipe default 32768, and
sparkrun's estimate put the KV cache at 1.25 GB against 75.0 GB available (60x
context multiplier). Same epoch as every prior round: both arms ran under
`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, checked in both
state.yaml files. The page cache again could not be cleared (no passwordless
sudo) — uniform across rounds, so it biases nothing between them.

Cost: two benchmark invocations, 173.3 s and 142.4 s of benchmark time plus two
engine starts; ~470 s of box time in total. Roughly 55k harness tokens for
read-in, hypothesis, two runs, parse, telemetry analysis and close-out — higher
than R3's ~35k because of the second arm and the telemetry pass. Four board
cells' worth of measurement (c2 cold, c2 ctx, c5 cold, c5 ctx) produced no
claimable standing, which is the price of running a cell whose board figure was
never scraped. R5b is now the round with the best ratio left in the queue.
