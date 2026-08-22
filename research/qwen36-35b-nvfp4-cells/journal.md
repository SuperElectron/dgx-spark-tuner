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

## Round 5 hypothesis — tg128 @ d131072 c1 (the stretch point)

The deepest cell the campaign will attempt, and the first one queued in advance
as a probable LOSS. tg128 @ d131072 c1 is topped at 81.60 by Nemotron Lightning
NVFP4 — the same holder as tg128 @ d32768 (115.53), so this is a competitor that
scales its own depth curve well rather than a weak sole entry. The queue's
pre-campaign estimate for us is 55-70, which would lose by 15-30%. The round is
queued anyway, for the depth curve rather than for the cell, and it is NOT to be
tuned for: the recipe stays exactly as it has been for five rounds and only the
probe moves.

**The round brief's 55-70 estimate is one of two competing hypotheses, and this
round discriminates between them.** That estimate predates R3. It is worth
stating both plainly, with distinct predicted bands, so the measurement decides.

Hypothesis A — the naive memory-bandwidth model, which is what 55-70 rests on.
A decode step at c1 reads the weights (~1.7 GB of active NVFP4 parameters, fixed)
plus the KV cache for the current depth. sparkrun's own VRAM estimates pin the KV
cost at exactly 40 KB/token on this config (1.25 GB at a 32768 window, 2.81 GB at
73728 — the same constant to three figures). So the depth-dependent read is
0.62 GB at d16384, 2.50 GB at d65536, and 5.00 GB at d131072. If step time scales
with (weights + KV), then relative to our d16384 figure of 102.2 the model
predicts 102.2 x 2.32/6.70 = 35 at d131072, and predicts 56 at d65536.

**Hypothesis A is already refuted by our own d65536 point.** It predicted 56
there; R3 measured 108.15. The model is not off by noise, it is off by a factor
of two, and it fails in the direction that matters. Whatever the attention kernel
is doing over a 2.5 GB KV cache, it is not paying naive bandwidth for it — the
MTP verify batch amortizes the read over ~4 tokens, and the 30 of 40 Gated
DeltaNet layers contribute no depth-dependent read at all. So the arithmetic that
produces 55-70 has been measured wrong once already at half this depth, and it
should not be used to set this round's band.

Hypothesis B — extrapolate our own measured points, which is the only method that
has worked on this box. R4's methodological lesson was explicit: the campaign's
sole accurate prediction (c2, 84.00 against a predicted 75-88) was the one built
by interpolating measured cells, and all three predictions built forward from the
model card were refuted upward. Our tg128 c1 depth series is 102.2 at d16384 and
108.15 at d65536 — flat within noise across 4x, which R3 read as the depth term
being smaller than c1 run-to-run variance over that whole range. Extrapolating
flatness across one more doubling gives 100-110.

**Numeric prediction: median 85-105, centre ~95.** That is hypothesis B with a
deliberate downward tilt, not flatness taken at face value. The tilt is there
because d131072 is the first depth at which the KV read (5.00 GB) clearly exceeds
the weight read (1.7 GB), and because the one phase that genuinely does scale with
depth — cold prefill — stopped falling inverse-linearly at d65536 and started
falling worse (ratio 0.40x rather than 0.50x per doubling), which is the quadratic
attention term becoming visible. Some of that should leak into decode out here
even if the last four depths gave no sign of it. But the honest position is that
there is no validated model on this box that produces a decline, so the band sits
high and the tilt is small.

If the median lands at 85-105 we WIN this cell against 81.60, by 1.04x to 1.29x —
a margin under 2x, so a win here triggers the mandatory verify repeat, and the
round should budget for a second invocation. If it lands at 55-70 the queue's
estimate was right, hypothesis A survives at this depth after failing at d65536,
and we take a clean loss that is worth more than the cell. Either outcome is
recorded exactly as measured.

Three more falsifiable claims, so the round can refute them:

- **ctx_tg128 @ d131072 comes in BELOW cold, by 12-22%** — predict 70-88. The
  sign change is established: ctx above cold at d8192/d16384, below at d32768
  (-27%) and d65536 (-17%). Two independent depths, two invocations. R4 showed
  the sign also moves with concurrency at fixed depth, so this is not a pure
  depth law and the prediction is an extrapolation of a pattern, not of a
  mechanism. Board figure for this cell was never scraped: held, not claimed.
- **pp2048 @ d131072 lands at 40-48.** Cold prefill has gone 1187.51 / 637.09 /
  295.71 / 118.59 across d8192-d65536, with the last ratio 0.40x. If the
  steepening continues the next ratio is at or below 0.40x, so at or below 47.4.
  A figure above 55 would mean the d65536 steepening was itself the artefact.
  ctx_pp2048 should continue its own gentler fall (6148.56 / 5910.22 / 5086.51 /
  4004.76): predict 2800-3400.
- **σ on the cold cell is wide, above 8% of the median.** This is c1, the bimodal
  MTP-acceptance regime; R1 ran σ to 22% and R3 to 9.6% there. Three runs cannot
  pin this and do not need to — the verdict is a margin question against 81.60.
  The ctx_ phase should again be far quieter, σ under 3% of its median, which
  would be the fifth consecutive observation of that.

Config. Mutation: NONE. Incumbent recipe.yaml, new probe. `-o
max_model_len=139264` raises the window from the recipe default 32768 to fit
depth 131072 + pp 2048 + tg 128 with headroom — the same probe-driven override
R1 and R3 used at 40960 and 73728, not a tuning change. Two config risks were
checked in advance rather than discovered at runtime: the model's native
`max_position_embeddings` is 262144, so 139264 needs no rope scaling and is not
an extrapolated-context measurement; and at 40 KB/token the KV cache for that
window is 5.31 GB against the ~75 GB sparkrun reported free in R3 and R4, a 14x
context multiplier, so an engine OOM at startup is not expected. If the engine
nevertheless fails to start, that is a config failure to fix once and journal,
not a box failure.

Probe: -b tg=128 -b depth=131072 -b concurrency=1 -b runs=3 -o
max_model_len=139264 (pp=2048 rides along by default, so the pp2048 and both
ctx_ phases are measured in the same invocation).

Cost note in advance: this is the campaign's most expensive round per run, and
the cost is dominated by cold prefill of the context before a single token is
generated. The instrument for that is ttfr, not the pp2048 metric — pp2048 is a
normalized per-prompt-token figure, not the wall rate at which the depth context
is filled. R3's ttfr at d65536 was 17.28 s cold and 16.38 s cached; at d16384 it
was 3.23 s. That series is slightly worse than linear in depth, so predict ttfr
35-45 s cold at d131072 and a whole-round benchmark time of roughly 400-600 s
against R3's 150.8 s. Expensive but not prohibitive, and the expense is itself an
argument against ever returning to this depth to tune it.

## Round 5 outcome — bench_076db52d341c (2026-08-22)

| Cell | median | (mean) | σ | runs |
|---|---:|---:|---:|---|
| tg128 @ d131072 c1 | 77.13 | (79.63) | 7.17 | 72.37 / 89.39 / 77.13 |
| ctx_tg128 @ d131072 c1 | 76.66 | (76.64) | 10.16 | 89.06 / 76.66 / 64.19 |
| pp2048 @ d131072 c1 | 42.59 | (42.57) | 0.02 | 42.55 / 42.59 / 42.59 |
| ctx_pp2048 @ d131072 c1 | 2803.17 | (2803.01) | 2.43 | 2799.96 / 2805.91 / 2803.17 |

**Verdict: LOSS. The campaign's first, and it is recorded as one.** tg128 @
d131072 c1 came in at median 77.13 against Nemotron Lightning NVFP4's 81.60 —
0.95x, short by 5.5%. The cell was queued as a probable loss, run once for the
depth curve, and deliberately not tuned for. recipe.yaml is untouched. Nothing
here is to be re-run to chase the cell; the round bought a curve, and the curve
is below.

The loss is narrow enough to be worth stating precisely, because a narrow loss
invites exactly the wrong follow-up. One of the three runs, 89.39, would have
beaten 81.60 by 1.10x on its own. That is not a result — it is the top of a
bimodal draw in the noisiest regime this campaign measures, and the discipline
that made the c4 win trustworthy (medians, not best runs) is the same discipline
that makes this a loss. σ is 7.17, 9.3% of the median. Three runs at c1 cannot
resolve 5.5%, so the honest statement is "we lost this cell, by about 5%, with a
run-to-run spread wider than the margin" — not "we nearly won it".

**Both competing hypotheses were refuted, and they were refuted from opposite
sides.** The hypothesis named two bands before the run and let the measurement
choose. Hypothesis A, the naive weights-plus-KV bandwidth model that the queue's
55-70 estimate rested on, predicted 35 (or 55-70 as the queue's softer version).
Hypothesis B, extrapolating our own flat d16384-d65536 depth response with a
small downward tilt, predicted 85-105, centre ~95. Measured: 77.13. That sits
*between* the two bands, roughly equidistant — about 10% above the top of the
queue's estimate and about 9% below the bottom of mine.

That is the most useful outcome the round could have had, and it is the first
time this campaign has been refuted DOWNWARD. Rounds 1, 2 and 3 all predicted a
slowdown and measured the opposite; R4's one accurate prediction came from
interpolating measured points. R5 interpolated measured points too — and this
time the extrapolation was too optimistic, because it extrapolated a flatness
that was about to end.

**The depth term finally bites, and the round locates where.** The tg128 c1 depth
series now reads 102.2 at d16384, 108.15 at d65536, 77.13 at d131072: flat within
noise across the first 4x, then a 29% fall across the next 2x. R3 read the
flatness correctly — the depth-dependent term was smaller than c1 noise over
d8192-d65536 — but the natural extension of that reading, that it stays smaller,
is now false. Somewhere between d65536 and d131072 the KV term stops being
negligible against the fixed ~1.7 GB weight read. At 40 KB/token that puts the
crossing near a 2.5-5.0 GB KV read, which is the region where the KV read first
exceeds the weight read. The architecture argument from R3 was right about the
mechanism and wrong only about where it runs out: 30 of 40 layers being
fixed-state Gated DeltaNet buys three doublings of free depth, not unlimited
depth.

It is worth being precise about what "the depth term bites" is NOT. It is not the
naive bandwidth model coming good. That model predicted 35 at this depth and 56
at d65536, and it was wrong by a factor of two at d65536 and is still wrong by a
factor of 2.2 here. Whatever amortizes the KV read — the MTP verify batch
spreading it over ~4 tokens is the obvious candidate — is still amortizing it. The
decline is real and the naive arithmetic still does not describe it.

**MTP acceptance degrades badly at this depth, which is a mechanism the round saw
directly rather than inferred.** The engine's own SpecDecoding metrics, sampled
live during the run, went from a mean acceptance length of 3.81 and 93.6% draft
acceptance early in the round to 2.43 and 47.7% once the deep contexts were in
play. Per-position acceptance fell from 1.000/0.962/0.846 to 0.608/0.451/0.373.
With `num_speculative_tokens=3`, halving the acceptance rate roughly halves the
tokens-per-verify-step, and that is a decode-throughput cost that has nothing to
do with KV bandwidth. This is the first time the campaign has watched the MTP
acceptance distribution move rather than inferring it from σ, and it is a
better candidate for the 29% fall than the memory argument above. It also
explains why σ stays wide at c1: the acceptance draw is what is bimodal.

**The ctx_ prediction was refuted on magnitude, and a five-round regularity
broke.** Predicted: ctx below cold by 12-22%, and quieter — σ under 3% of its
median, which would have been the fifth consecutive such observation. Measured:
ctx_tg 76.66 against cold 77.13, a gap of -0.6%, which is nothing; and σ 10.16,
13.3% of the median, which makes the prefix-caching phase NOISIER than the cold
phase (9.3%) for the first time in the campaign. Its runs span 64.19 to 89.06.

Both halves of that matter. The inversion did not deepen with depth — it
disappeared, after -27% at d32768 and -17% at d65536, which continues the trend
R3 already noticed (the inversion was shrinking, not growing) and takes it to
zero. And the quietness of the ctx_ phase, which R3 and R4 had confirmed at four
depths and three concurrencies and which RESULTS.md leaned on as "the cheapest
place in this campaign to measure a real effect", does not survive to d131072.
The tidy explanation for the quietness — that removing prefill removes the
variance — cannot be right, because the prefill is removed here too and the
variance is larger than ever. Open question 4 should now be read as being about
MTP acceptance variance, not about prefill: at this depth the acceptance draw
dominates both phases, and the cached phase has no prefill work to average it
against.

**The three quantitative side-predictions all held, and they are the round's
tight measurements.** pp2048 @ d131072 predicted 40-48, measured 42.59 — and the
predicted continued steepening is there: the cold-prefill ratio per doubling has
gone 0.50x, 0.50x, 0.40x, now 0.359x, which is the quadratic attention term
growing exactly as R3 first saw. σ 0.02 (0.05% of the median) makes this the
tightest measurement in the whole campaign. ctx_pp2048 predicted 2800-3400,
measured 2803.17, at the very bottom of the band; its own ratio is 0.70x, the
steepest fall yet in a series that had been gentle (6148.56 / 5910.22 / 5086.51 /
4004.76 / 2803.17). And cold σ was predicted above 8% of the median: 9.3%.
ttfr was predicted at 35-45 s cold and came in at 48.10 s — a 7% miss, high, and
the one side-prediction that slipped its band.

Telemetry, sampled alongside the round (900 samples at 1 Hz, archived as
`experiments/bench_076db52d341c/telemetry.log`). SM clock 2398 MHz median,
2379-2411 across the window, against the same 3003 MHz ceiling — essentially
identical to R4's 2392 MHz, which is the first time the clock figure has
reproduced across sessions and puts R1's outlying 2554 MHz reading in doubt
rather than the other two. Temperature peaked at 79 °C, the campaign's highest
(R4 peaked at 72 °C) — this was by far the longest sustained load — and power
peaked at 95.77 W, essentially R4's 95 W. The clock is flat through the
temperature rise, so even at 79 °C there is no thermal throttling: the 80%-of-
ceiling clock remains a policy figure. Open question 5 can be downgraded — the
clock is stable session to session, at 2392-2398 MHz. No clock, power-policy,
driver or kernel setting was touched, and none ever will be from this loop.

Config and epoch notes. No mutation; incumbent recipe.yaml, new probe, with
`-o max_model_len=139264` as the probe-driven override. Both config risks named
in the hypothesis were checked in advance and neither materialized: the model's
262144 native `max_position_embeddings` means d131072 is not an extrapolated-
context measurement, and sparkrun's VRAM estimate put the KV cache at exactly the
predicted 5.31 GB against 75.0 GB available (14.1x context multiplier), so the
engine started clean on the first attempt. The 40 KB/token constant used in the
hypothesis reproduced to three figures. Epoch unchanged: `state.yaml` records
`container_image_longterm_ref: ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`,
pinned, identical to R1/R3/R4 — note that sparkrun's console line says it is
distributing `:latest`, which resolves to the pinned longterm ref, so the console
text is not evidence of an epoch change and the state.yaml field is what to read.
Page cache again could not be cleared (no passwordless sudo), uniform as ever.

**Process failure, recorded because it cost a wasted engine start.** The first
invocation of this round was launched WITHOUT `-b depth=131072`. sparkrun does not
error on a missing probe dimension — it silently defaults depth to 0 and would
have measured a completely different cell at full cost. It was caught by reading
the `Benchmark args:` block that sparkrun echoes before `Benchmark ID:`, which
showed `depth: [0]`; the run was killed during engine startup, the box was checked
clean of leftover containers, and the round was relaunched correctly as
bench_076db52d341c. The aborted invocation (bench_8e4471b42bec) produced no
measurements and is not archived. The lesson generalizes to every round in this
campaign: the echoed `Benchmark args:` block is the only confirmation that the
probe is the intended cell, and it must be read before letting a run proceed.

Cost: one benchmark invocation, 397.6 s of llama-benchy task time against R3's
150.8 s at half the depth, plus an engine start and roughly 20 minutes of
corpus/context preparation before the engine saw its first request — call it
~45 minutes of wall clock and ~50 minutes of box time including the wasted start.
Roughly 60k harness tokens, higher than R4's ~55k because of the aborted
invocation and the live engine-log diagnosis. Four cells measured, one scoreable,
and that one lost. That is the honest ratio for a stretch round, and it is the
argument for never returning to this depth: d131072 costs ~8x R3's box time per
round and the cell is not winnable without tuning the campaign refuses to do.

## Round 6 hypothesis — the tg32-vs-tg128 control @ d16384 c1, runs=7

The campaign's first round run purely as a CONTROL. No new cell, no new depth,
no mutation: both probes have been measured before, and the round exists to
decide whether one of those measurements was ever real. R1 measured tg32 @
d16384 c1 at median 129.32; our tg128 @ d16384 c1 baseline is 102.2, carried in
from qwen36-35b-quant round 0. Same depth, same concurrency, same config —
and the SHORTER generation came out 27% FASTER, which the amortization argument
says should be impossible. `tg t/s` is tokens over the decode span, so a 32-token
generation amortizes whatever fixed per-request cost sits at the head of decode
(prefill handoff, MTP warmup) over 4x fewer tokens. Every reading of that
predicts tg32 BELOW tg128, and R1 got the opposite at all three of its depths.

The two measurements have never sat under one engine start. That is the whole
defect this round repairs: **tg=32 and tg=128 at d16384 c1 in ONE invocation,
runs=7 each**, so both cells see the same engine, the same page-cache state and
the same thermal window, and the only thing that differs between them is the
number of tokens generated.

runs=7, not 3, and that is not caution — it is the round's premise. c1 is the
bimodal MTP-acceptance regime this campaign has documented five times over: σ ran
to 22.72 at c1 in R1 against 0.07-0.75 at c4/c5 in R4. R1 proved directly that
three runs cannot rank anything here — its own d8192 cell spanned 73.07 to
128.35, a spread wider than the gaps between its three cell medians. A 3-run
median drawn from a σ≈18 distribution is itself an estimator with a sampling
spread near ±14, which is half the size of the 27-point gap this round is
supposed to explain.

### Three candidate mechanisms, and what separates them

**H1 — undersampling. The gap is a 3-run artefact and does not survive.** Both
of the numbers in dispute are 3-run medians from the campaign's widest
distribution. Note the arithmetic that makes this the default reading: variance
alone cannot move a MEDIAN. If tg32 and tg128 sample the same underlying decode
rate with different spreads, their 7-run medians should converge regardless of
how much noisier tg32 is. Under H1 the two medians land within ~5% of each other
and R1's 129.32 falls.

**H2 — acceptance decays along a generation, so the gap is real.** MTP
acceptance is highest at the head of a generation, where the drafted continuation
is most strongly conditioned on the prompt. R5 watched per-position acceptance
directly and saw it at 1.000 / 0.962 / 0.846 before the deep contexts pulled it
to 0.608 / 0.451 / 0.373. If acceptance decays with generation position, a
32-token generation samples only the high-acceptance head while a 128-token
generation averages the head against a slower tail — and that shifts the median
genuinely, not just the spread. Under H2 tg32 stays materially above tg128 at
runs=7, by more than 10%.

**H3 — the tg128 baseline is depressed.** The 102.2 figure is inherited from a
different experiment series and has never been re-measured in this campaign.
Under H3 tg128 re-measures ABOVE 102.2 and the gap closes from the other side.

H1 and H3 are not exclusive and both point at the same defect; H2 is the one
that would make R1's number a finding rather than a draw.

### Numeric predictions

- **tg128 @ d16384 c1: median 100-115, centre ~107.** The centre is not 102.2.
  R3 measured 108.15 at d65536 and R5's depth curve says the response is flat
  within noise from d16384 to d65536 — so if the depth term is negligible over
  that range, 102.2 and 108.15 are two draws of the same quantity and its centre
  is nearer 105 than 102.
- **tg32 @ d16384 c1: median 108-125, centre ~116.** Below R1's 129.32, above the
  tg128 centre. This is H1 with a partial concession to H2: most of the 27% is
  expected to be undersampling, some of it may be real.
- **The gap, which is the actual verdict: +5% to +10%, tg32 over tg128.**
  This is the number to read in the morning. The discriminator is explicit:
  a gap at or above 20% confirms H2 and makes generation length a real lever;
  a gap at or below 3% confirms H1 and retires R1's 129.32 as a lucky draw.

### What this round buys for open question 2, for free

The -12% reproduction gap against the board's best vLLM NVFP4 entry (116.03)
rests entirely on that inherited 102.2. This round re-measures exactly that cell
at runs=7 under the campaign's own engine. **If tg128 lands at or above 116.03
the reproduction gap never existed and was undersampling all along.** At the
predicted centre of 107 the gap narrows from -12% to about -8% but does not
close, which would say the shortfall is real and belongs to the config or the
box rather than to a thin sample. Either way the answer goes in the outcome
explicitly. Note the cell itself is the crowded one (top 188.47, LFM2.5-350M
BF16) and is NOT expected to be taken — nothing here is tuned for it.

### Side-predictions, so the round can be refuted on more than one axis

- **σ is WIDER at tg32 than at tg128, in relative terms — predict tg32 above 12%
  of its median, tg128 8-12%.** This is the acceptance-variance story's own
  prediction and it is independent of the medians: a 32-token generation
  completes in roughly 8-32 verify steps against 32-128 for tg128, so it averages
  the bimodal acceptance draw over 4x fewer trials. If tg32 instead comes back
  the QUIETER of the two, the variance mechanism this campaign has leaned on
  since R2 is wrong about where the averaging happens.
- **pp2048 is identical in both arms, 630-645.** The prefill work does not depend
  on how many tokens are generated afterwards, and this figure has read 637.09
  (c1), 634.04 (c2), 643.31 (c4) at this depth. It is therefore a within-round
  CONTROL on box state: if the two arms' pp2048 rows differ by more than ~2%,
  something drifted mid-invocation and the tg comparison is contaminated.
- **ttfr is identical in both arms, 3000-3500 ms** (R1's tg32 arm read 3230.01
  at this depth), for the same reason. Second control on the same fact.
- **ctx_ phases sit at or slightly ABOVE cold in both arms, within ±8%.** At
  d16384 c1 R1 read ctx 130.16 against cold 129.32 (+0.6%); the below-cold
  inversion belongs to d32768 and deeper. Predict the quietness holds here too —
  ctx σ under 5% of its median — because the quietness only broke at d131072
  (R5), where R5 argued the acceptance draw had come to dominate both phases.

Config. **Mutation: NONE.** Incumbent recipe.yaml, and for only the second time
in the campaign no `max_model_len` override is needed — d16384 + pp 2048 + tg 128
fits the recipe default 32768 with room. Telemetry is sampled alongside, because
this round's second target is open question 2 and every past argument about that
gap has leaned on the box's clock; R4 and R5 agree at 2392-2398 MHz and a third
sample under a different load shape is nearly free.

Probe: `-b tg=32,128 -b depth=16384 -b concurrency=1 -b runs=7`
(pp=2048 rides along by default, so both `pp2048` and both `ctx_` phases are
measured in the same invocation — 8 cells from one engine start).

Cost note: 14 runs at the campaign's cheapest depth. R1 ran 9 runs across three
depths in 349 s; this is more runs at a shallower average depth, so predict
250-400 s of benchmark time and one engine start.

Per R5's process failure: the `Benchmark args:` block sparkrun echoes before
`Benchmark ID:` will be read before the run is allowed to proceed, and it must
show `tg: [32, 128]`, `depth: [16384]`, `concurrency: [1]`, `runs: 7`.

## Round 6 outcome — bench_dd3afc9e1c94 (2026-08-22)

All four cells under ONE engine start, runs=7 each, one invocation:

| Cell | median | (mean) | σ | σ/median | runs |
|---|---:|---:|---:|---:|---|
| tg32 @ d16384 c1 | 116.43 | (120.77) | 11.55 | 9.9% | 110.44 / 140.72 / 108.96 / 109.88 / 130.18 / 116.43 / 128.77 |
| tg128 @ d16384 c1 | 111.11 | (112.27) | 2.91 | 2.6% | 109.31 / 116.58 / 111.11 / 112.38 / 109.47 / 116.66 / 110.36 |
| ctx_tg32 @ d16384 c1 | 122.97 | (120.70) | 8.44 | 6.9% | 107.83 / 126.00 / 133.96 / 112.15 / 122.97 / 115.96 / 126.01 |
| ctx_tg128 @ d16384 c1 | 104.85 | (103.90) | 9.73 | 9.3% | 104.85 / 107.08 / 92.47 / 89.15 / 111.91 / 102.51 / 119.32 |

**Verdict on the control: H1 wins. The 27% gap was undersampling.** R1's tg32 @
d16384 read 129.32 against a tg128 baseline of 102.2 — a 26.5% advantage for the
shorter generation. Under one engine start at runs=7 the same comparison reads
116.43 against 111.11: **+4.79%.** Four fifths of the effect was never there.
tg32 fell 10.0% from its 3-run figure and tg128 rose 8.7% from its inherited
one, and the two moved toward each other exactly as the sampling argument in the
hypothesis said they must — variance cannot shift a median, so two medians drawn
from the same quantity with different spreads have to converge once the sample
is large enough to find them.

**And the residual 4.79% is smaller than it looks, because the round's own
controls priced the systematic.** Both prefill controls came in offset in the
same direction and by the same amount: pp2048 reads 623.13 in the tg32 arm
against 634.99 in the tg128 arm (-1.90%), and ttfr reads 3298.58 against 3237.23
(+1.90%). That work is IDENTICAL in the two arms — the prefill does not know how
many tokens will be generated afterwards — so a 1.9% arm-to-arm offset is pure
systematic, presumably the tg32 arm running first into a marginally colder box.
Subtract it and the residual generation-length advantage is **~2.9%**, which
lands precisely on the hypothesis's own H1 threshold ("a gap at or below 3%
confirms H1"). **H2 — MTP acceptance decaying along a generation, which would
have made generation length a real tuning lever — is not supported at any useful
magnitude.** R1's 129.32 is retired as a lucky draw.

The three numeric predictions were the campaign's second accurate set, and again
they were built by interpolating our own measured points rather than reasoning
forward from the architecture:

- tg128 predicted 100-115, centre ~107 — measured **111.11**, inside the band,
  above centre. The centre was deliberately set above the inherited 102.2 on
  R3/R5's flatness reading, and that adjustment was the right call.
- tg32 predicted 108-125, centre ~116 — measured **116.43**, essentially on the
  centre.
- The gap predicted +5% to +10% — measured **+4.79%**, a fifth of a point below
  the bottom of the band. Called a miss, and a miss by a hair on the side that
  makes the round's conclusion stronger, not weaker.

### Open question 2: the reproduction gap was two-thirds undersampling

This is the round's second finding and it comes free. The -12% gap rests entirely
on the inherited 102.2 for tg128 @ d16384 c1. Re-measured here at runs=7 under
this campaign's own engine: **111.11 against the board's best vLLM NVFP4 entry of
116.03 — a gap of -4.24%, not -12%.** Two of the seven runs (116.58 and 116.66)
clear 116.03 outright, so the board's figure sits at the top of our own run
distribution rather than outside it.

The honest statement is therefore: **most of the reproduction gap never existed,
and what remains is small and not obviously a defect.** A -4.2% median shortfall
against a single published entry, with our distribution straddling that entry, is
what two boxes under the same fleet-wide clock policy should look like. Open
question 2 should be closed as "largely resolved — was undersampling", not
carried forward as an unexplained deficit. Note the cell itself is the crowded
one (overall top 188.47, LFM2.5-350M BF16) and remains far out of reach; nothing
here was tuned for it and nothing is claimed against it.

### The noise prediction: direction right, both magnitudes wrong, and the miss
### is the round's most interesting result

Predicted tg32 σ above 12% of its median and tg128 σ at 8-12%. Measured 9.9% and
**2.6%**. The DIRECTION held emphatically — tg32 is 3.8x noisier than tg128 in
relative terms, which is the averaging story's own prediction, since a 32-token
generation completes in roughly 8-32 verify steps against 32-128 for tg128 and so
averages the bimodal acceptance draw over 4x fewer trials. But the tg128 figure
refutes something the campaign has believed since R1.

**"c1 is the noisy regime" is false as stated.** Five rounds have treated
concurrency as the variable that controls variance: σ 14-22% at c1 in R1, 9.6% at
c1 in R3, 9.3% at c1 in R5, against 0.15-1.4% at c2/c4/c5 in R2 and R4. Here is a
c1 cell at 2.6%. Lining up every c1 cold measurement the campaign has taken:

| cell | σ/median |
|---|---:|
| tg128 @ d16384 c1 (this round) | 2.6% |
| tg32 @ d16384 c1 (this round) | 9.9% |
| tg128 @ d65536 c1 (R3) | 9.6% |
| tg128 @ d131072 c1 (R5) | 9.3% |
| tg32 @ d16384 c1 (R1) | 14.2% |
| tg32 @ d8192 c1 (R1) | 21.4% |

The pattern is not concurrency. It is **number of verify steps per measurement,
and acceptance quality**. Long generations at shallow depth — many verify steps,
and R5 measured acceptance at 93.6% with per-position 1.000/0.962/0.846 in
exactly that regime — give a quiet c1 cell. Short generations average over too
few steps; deep contexts collapse acceptance to 47.7% and make each step's draw
itself wide. Concurrency was a proxy for the first of those all along: raising c
multiplies the sequences averaged per step, which is the same lever as
lengthening the generation.

Practical consequence, and it is a planning consequence: **runs=3 is adequate for
tg128 at d16384 c1** (σ 2.6% means three runs pin it to a few percent), and
inadequate for tg32 anywhere and for tg128 at d65536 and deeper. R8's premise —
runs=7 at d16384 AND d65536 to settle whether the depth response is flat — is
strengthened, because the d16384 half is now known to be quiet and the d65536
half is known to be noisy, so the comparison's error budget is dominated by one
side and R8 can spend its runs accordingly.

### Open question 4 gets its cleanest evidence yet, and it kills the depth reading

**The ctx-vs-cold sign flips with GENERATION LENGTH, at one depth, one
concurrency, inside one engine start.**

| arm | cold | ctx | ctx vs cold |
|---|---:|---:|---:|
| tg32 | 116.43 | 122.97 | **+5.62%** |
| tg128 | 111.11 | 104.85 | **-5.63%** |

Same invocation, same depth, same concurrency, same thermal window — the only
difference is 32 tokens versus 128 — and the sign reverses with almost identical
magnitude. Every previous observation of this effect was confounded: R3's was
across depths and invocations, R4's was across concurrencies. This one is not
confounded by anything. R4 already said to stop treating open question 4 as a
depth question; this round says to stop treating it as a depth question OR a
concurrency question. The sign moves with all three, which means the driver is
something all three modulate, and prefill-vs-decode mix and MTP acceptance are
the only candidates left standing.

The prediction here was refuted on the tg128 arm: predicted ctx at or above cold
in both arms, within ±8%, on the basis that the below-cold inversion belonged to
d32768 and deeper. It held for tg32 (+5.6%) and inverted for tg128 (-5.6%).

**The ctx quietness broke again, and R5's explanation for the break does not
survive.** ctx_tg128 σ is 9.3% of its median against cold's 2.6% — the cached
phase is 3.5x NOISIER than the cold one. R5 saw the same reversal at d131072 and
attributed it to depth: the acceptance draw dominating both phases out where
acceptance has collapsed. That cannot explain this one, which happens at d16384
where acceptance is high and the cold phase is the quietest c1 measurement the
campaign has ever taken. The regularity "removing prefill removes the variance"
held for four rounds and has now failed twice for two different reasons; it
should be retired rather than patched. ctx_tg32 is the one arm that behaves as
the old rule expects (6.9% against cold's 9.9%, quieter).

### The controls, which did their job

pp2048 and ttfr were written into the hypothesis as within-round controls on box
state, with a contamination threshold of ~2%. They came in at 1.90% on both,
i.e. the control PASSED but only just, and the offset it exposed is the same
order as the effect being measured — which is why the round subtracts it above
rather than ignoring it. Writing the controls down in advance is what made the
4.79% figure readable as ~2.9%; without them the round would have reported a
5% generation-length effect that is mostly a warm-up artefact. pp2048 in the
tg32 arm is also 3x noisier (σ 8.72 vs 2.77), consistent with that arm running
across a settling box.

Absolute pp2048 levels reproduce the campaign's flat d16384 series: 637.09 (R1
c1), 634.04 (c2), 643.31 (c4), now 623.13 / 634.99. The tg32 arm's 623.13 sits
just below the predicted 630-645 band; the tg128 arm's 634.99 is inside it.
ttfr 3237-3299 ms is inside the predicted 3000-3500 and matches R1's 3230.01 at
this depth.

### Standings effect

tg32 @ d16384 c1 remains a WIN and its claimed figure is REVISED DOWN, from
R1's 3-run 129.32 (4.60x) to this round's 7-run 116.43 — **4.14x against the
incumbent 28.11**. The worst of the seven runs, 108.96, still clears the
incumbent by 3.88x, so there is no draw of these runs that loses the cell. A
revision that lowers our own number is the correct outcome of a control round and
RESULTS.md carries the 7-run figure from here.

ctx_tg32 and ctx_tg128 at this depth still have no scraped board figure and are
held, not claimed. R5b remains the cheapest standings gain in the queue.

Telemetry, sampled alongside (315 samples, archived as
`experiments/bench_dd3afc9e1c94/telemetry.log`): SM clock 2398 MHz median,
2372-2411, against the same 3003 MHz ceiling; temperature peaked at 69 °C and
power at 94.72 W. That is the THIRD consecutive session to read 2392-2398 MHz
(R4 2392, R5 2398), under a load shape quite different from R5's — short and
shallow rather than long and deep — and it confirms the clock as a flat policy
figure at ~80% of ceiling. R1's 2554 MHz is now outnumbered three to one and
should be treated as a bad reading. Open question 5 stays downgraded. No clock,
power-policy, driver or kernel setting was touched.

Config and epoch. **Mutation: NONE**, and no `max_model_len` override — d16384 +
pp 2048 + tg 128 fits the recipe default 32768, with sparkrun reporting 66.88 GiB
of KV cache available and a 95.9x context multiplier. Epoch unchanged:
`state.yaml` records `container_image_longterm_ref:
ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, identical to R1/R3/R4/R5,
so every cross-round comparison above is within one epoch. Page cache again could
not be cleared (no passwordless sudo), uniform across rounds as always. The
`Benchmark args:` echo was read before the run was allowed to proceed, per R5's
process lesson, and confirmed `tg: [32, 128]`, `depth: [16384]`,
`concurrency: [1]`, `runs: 7` — no repeat of R5's silent depth default.

Cost, and it is the campaign's best ratio. **124 s of measurement grid time**
against a predicted 250-400 s — the one prediction that missed low, because 14
runs at the shallowest depth in the campaign are cheap and the estimate was
anchored on R1's three-depth sweep. Total invocation about 7 minutes of wall
clock: engine start 06:16-06:19, grid 06:19:28 onward, complete before 06:23.
One engine start, no wasted invocations, roughly 45k harness tokens. Four cells
measured, one board cell re-claimed at a corrected figure, one open question
largely closed and a second one sharpened — for a third of R3's box time and a
fifteenth of R5's. **Control rounds are the cheapest rounds this campaign runs
and this queue has been under-scheduling them.**

## Round 7 hypothesis — the concurrency tail: tg128 @ d16384, c8 and c16

Earned by R2, rewritten twice — once by R4 (which took the knee question away
from it) and once here. What is left is the tail. R4 measured c1/c2/c4/c5 and
found the knee between c2 and c4; c8 and c16 are the two points that say what
happens after the knee, and there are only two questions worth asking of them:
**where does per-request throughput collapse, and is the aggregate still
climbing?** Those are different questions with different answers and the round
records both metrics for both points, because R2's units correction is what
makes this round legible at all — llama-benchy's `tg t/s` is PER-REQUEST, and
`peak_throughput` is the aggregate. Every c>1 row in this campaign is a
per-request row.

### The mutation, and why the curve stays internally comparable without a re-run

The campaign recipe carries `--max-num-seqs 4`. A c8 probe is twice the
scheduler width and a c16 probe is four times it, so on the unmutated recipe
half or three quarters of each batch would sit in the queue and the measurement
would be of the queue, not of the box. R4 already settled what to do: matching
the scheduler width to the probe concurrency is worth **+5.5%** at c5, and the
mechanism it exposed is chunked prefill — the queued request's prefill gets
chunked into ongoing decode steps and `pp2048` falls to 581.44 against a flat
634-643 everywhere else at this depth. So this round runs **one matched arm per
point**: `-o max_num_seqs=8` at c8 and `-o max_num_seqs=16` at c16. Two
invocations, two engine starts, because `max_num_seqs` is an engine setting and
cannot vary within one.

**This is a MUTATION and it is journaled as one. It is NOT folded into
recipe.yaml** — the campaign config stays `--max-num-seqs 4`, exactly as R4's
mns-5 arm stayed out of it.

The obvious worry is that mixing scheduler widths makes the curve incomparable.
It does not, and the reason is worth writing down because it also settles
whether c4 and c5 need re-measuring. The invariant that matters is not
"max_num_seqs is the same at every point" — it is **max_num_seqs >= concurrency
at every point**, i.e. nothing queues. Check it against the curve:

| c | mns | mns >= c? |
|---:|---:|---|
| 1 | 4 | yes |
| 2 | 4 | yes |
| 4 | 4 | yes, exactly |
| 5 | 4 | **NO — this is the arm R4 discarded** |
| 5 | 5 | yes, exactly |
| 8 | 8 | yes (this round) |
| 16 | 16 | yes (this round) |

Every point the curve actually uses already satisfies it. The one point that
did not — c5 at mns 4 — is precisely the arm R4 measured, diagnosed and set
aside in favour of the mns-5 arm. **So no earlier point needs re-measuring**,
and the claim being made across the whole curve is "no request ever waits for a
scheduler slot", not "one engine config throughout". RESULTS.md will carry the
`max_num_seqs` in every c>1 row so the reader can check that for themselves
rather than taking it on trust.

### Mechanism, and the numeric prediction

Two mechanisms pull in opposite directions past the knee.

**Batching amortization (says the aggregate keeps climbing).** Decode at c1 is
weight-bandwidth-bound: R5's engine read ~1.7 GB of active weights per step to
produce one token's worth of work. Batching divides that fixed read across more
sequences, which is the entire reason the aggregate rose 102 -> 168 -> 211 ->
241 across c1/c2/c4/c5 while per-request fell. Nothing in that argument stops at
c5.

**MoE expert coverage (says it flattens).** This is a 35B-A3B model — about 3B
active parameters per token, chosen by the router. At c1 one token's routing
touches a small slice of the expert set. At c16, sixteen independent sequences
route independently in the same step, and the union of experts touched
approaches the whole set. The per-step weight read therefore GROWS with batch
size in a way it does not for a dense model, and the amortization argument above
quietly stops being true somewhere in this range. That is the specific reason to
expect this tail to flatten harder than a dense model's would.

The estimator the campaign trusts is interpolation of its own measured points —
it produced the only two accurate predictions the campaign has made (R4's c2,
R6's pair). Fitting `aggregate ~ a + b*ln(c)` through the c2 (168.0) and c5
(240.6) points gives b = 79.7, a = 112.8, hence:

- **c8: per-request median 30-38, centre ~34. Aggregate 240-304, centre ~278.**
- **c16: per-request median 16-22, centre ~19. Aggregate 256-352, centre ~334.**

The bands are wide on purpose: the two mechanisms above disagree by more than
the fit's own error, and the log fit encodes only the first of them.

**The discriminator, which is the number to read in the morning:** compare the
c16 aggregate against the c8 aggregate.

- If **c16 aggregate is 15% or more above c8's**, the tail is still climbing at
  16-way and concurrency remains a live lever for aggregate work — the
  amortization story wins and the MoE-coverage argument is not binding yet.
- If **c16 aggregate is within ~8% of c8's**, the aggregate has SATURATED by c8,
  c16 buys nothing but latency, and the MoE-coverage story is the reading.
- Between those, the round says "still climbing but weakly" and does not
  pretend to have separated the mechanisms.

Per-request collapse gets its own statement: it has fallen 102 -> 84 -> 53 ->
48 so far, which is far shallower than 1/c. If per-request at c16 comes in at or
below the strict-1/c line from c1 (111.11/16 = 6.9), the box has stopped
amortizing anything and is simply time-slicing; predicting well above that, at
16-22, is predicting that amortization is still doing real work even at the
tail.

### Side-predictions, so the round can be refuted on more than one axis

- **pp2048 sits at 620-645 at BOTH points.** This is the R4 control, and here it
  is a check on the mutation itself: with the scheduler width matched, no
  prefill should be chunked into decode, so prefill should return to the flat
  d16384 series (637.09 / 634.04 / 643.31 / 623.13 / 634.99 / 640.21). **If
  pp2048 falls below 600 at either point, matching the width did NOT eliminate
  the interference** and R9's premise changes — the interference would then be a
  batch-size effect rather than a queueing effect.
- **σ under 2% of the median at both points.** Every c>1 cell in this campaign
  has been very quiet (σ 0.07-1.18 absolute at c2/c4/c5), and R6 explained why:
  σ is set by how many MTP verify steps a measurement averages over, and raising
  c multiplies the sequences averaged per step. c8 and c16 average over more
  than anything measured so far, so they should be the quietest cells yet. This
  is also why **runs=3 is the correct budget here** — R6's planning result says
  runs=7 is for tg32 and for d65536+, neither of which this round touches.
- **ctx_ sits ABOVE cold at both points, by +3% to +8%.** R4 measured ctx above
  cold at c4 (+6.6%) and at c5 under both widths (+5.7%, +6.5%); this round
  extends the same concurrency axis and should follow it. Open question 4 has
  refuted this campaign's ctx predictions before and may again — a sign flip
  here would be the fourth axis on which the sign moves.
- **ttfr grows with c and the growth is the queueing signature.** c4 read
  10167 ms and c5 read 11866/12088. Predict **c8 18000-26000 ms** and **c16
  36000-56000 ms** — roughly linear in c, because with the width matched every
  request's prefill competes for the same prefill bandwidth.

### Standings expectation

Honest and stated in advance: **probably none.** docs/arena-recipe.md was
expanded by a board scrape that added figures for fifteen cells including c2 and
c5, but it carries **no c8 or c16 figures at all** — the scrape covered c1, c2,
c4 and c5 only. Unless that changes, both rows will read "not scraped — cannot
be scored", exactly as R4's did before the scrape landed. This round is bought
for the curve, not for the board, and nothing will be invented to make it look
otherwise.

One free standings correction does land, though, and it belongs to this round
because it is the same curve: the scrape DID fill in c2 (325.44) and c5 (428.95),
which RESULTS.md still records as "not scraped". Those two rows get their real
incumbents and their real verdicts here.

Config. **MUTATION: `-o max_num_seqs=<c>`, matched per point.** No
`max_model_len` override — d16384 + pp2048 + tg128 fits the recipe default
32768. Epoch expected unchanged; `state.yaml` will be checked for
`container_image_longterm_ref` per round.

Probe: `-b pp=2048 -b tg=128 -b depth=16384 -b concurrency=8 -b runs=3 -o
max_num_seqs=8`, then the same with 16/16. Per R5's process lesson the
`Benchmark args:` echo is read before either run is allowed to proceed, and must
show `depth: [16384]` — sparkrun does not error on a missing `-b depth`, it
silently defaults it to 0.

Cost prediction: two engine starts (~3 min each) and a grid that is 6 runs
total, but each run at c8/c16 does 8x/16x the generation work of a c1 run at the
same depth. R4's c2+c5 grid took its time from the c5 arm; predict **300-600 s
of grid time across the two invocations** and 15-25 minutes of wall clock.

## Round 7 outcome — bench_0954971b5dfa (c8) + bench_a769c1142e15 (c16), 2026-08-22

Two invocations, one matched arm each, runs=3, `-o max_num_seqs=<c>`:

| cell | median | (mean) | σ | σ/median | runs |
|---|---:|---:|---:|---:|---|
| tg128 @ d16384 c8 (mns 8) | 43.51 | (43.47) | 0.22 | 0.51% | 43.51 / 43.72 / 43.18 |
| tg128 @ d16384 c16 (mns 16) | 40.47 | (40.46) | 0.06 | **0.15%** | 40.47 / 40.52 / 40.38 |
| ctx_tg128 @ d16384 c8 (mns 8) | 47.75 | (47.78) | 0.05 | 0.10% | 47.75 / 47.74 / 47.85 |
| ctx_tg128 @ d16384 c16 (mns 16) | 45.61 | (45.56) | 0.08 | 0.18% | 45.44 / 45.61 / 45.63 |

**The headline is a refutation, and it is the campaign's fourth upward one: the
concurrency tail is not flat.** Per-request throughput fell 43.51 -> 40.47
across a DOUBLING of concurrency — **-7.0%** — after falling 37% across the
single step from c2 to c4. Both numeric predictions missed, both high, and the
c16 one missed by 84%: predicted 16-22 per-request, measured 40.47. The
discriminator written into the hypothesis is answered emphatically in favour of
"still climbing" (below), and the MoE-expert-coverage mechanism that predicted a
hard flattening is **not binding anywhere in this range**.

### The aggregate needs care, and this is the round's most important finding

The campaign's convention has been `aggregate = per-request x c`. That convention
**breaks between c8 and c16**, and the round caught it because it recorded both
estimators, which is exactly what it was sent to do.

| c | mns | per-request | `c x tg` | `peak_throughput` | ratio |
|---:|---:|---:|---:|---:|---:|
| 1 | 4 | 111.11 | 111.1 | 119.0 | 1.07 |
| 2 | 4 | 84.00 | 168.0 | 182.0 | 1.08 |
| 4 | 4 | 52.85 | 211.4 | 291.0 | 1.36 |
| 5 | 5 | 48.12 | 240.6 | 265.0 | 1.10 |
| 8 | 8 | 43.51 | 348.1 | 355.0 | **1.02** |
| 16 | 16 | 40.47 | 647.6 | 440.0 | **0.68** |

`peak_throughput` is by construction a PEAK, so it bounds the sustained
aggregate from above. Through c8 the two estimators agree and `peak` sits at or
slightly above `c x tg`, exactly as a peak should. At c16 `c x tg` **exceeds the
peak by 47%**, which is impossible for a sustained figure. So **647.6 is not the
c16 aggregate and this round does not claim it.**

The engine log says why, and it is a config finding rather than a physics one.
`--max-num-batched-tokens 8192` was NOT raised alongside `max_num_seqs`. At
d16384 every request's prefill must be chunked into 8192-token batches, and the
scheduler admits only what fits that token budget — so the 16 requests never all
resided at once. Sampled across the whole grid (42 scheduler log lines):
**Running median 9.0 of 16, Waiting median 6.0, running max 16.** `tg_throughput`
measures a request's decode rate *while it is running*, so multiplying it by the
nominal concurrency counts requests that are queued. The corroborating ratio is
in the data twice over: `peak_throughput / peak_req_throughput` is 355/50.5 =
**7.0** at c8 (near-full occupancy of 8) and 440/37.0 = **11.9** at c16 (74%
occupancy of 16).

So the honest c16 aggregate is **400-480 tok/s**, best single figure ~440 by the
peak estimator, against **348-355** at c8. RESULTS.md carries it that way, with
the invalid 647.6 shown struck through rather than deleted, so nobody
re-derives it.

**Matching `max_num_seqs` to the probe was necessary and not sufficient.** R4
found the sequence-count queue; this round found a second queue behind it, on
the token budget. That is a clean, cheap follow-up (R10 below) and it is the
completed version of this round's mutation, not a new idea.

### The discriminator, answered

The hypothesis asked one question of these two points: **is the aggregate still
climbing at 16-way?** Thresholds were written down in advance — 15% or more above
c8 means still climbing and concurrency remains a live lever; within ~8% means
saturated by c8.

**Measured: 440 against 355, +24%.** Above the threshold, so the verdict is
**still climbing**, and it is still climbing despite the engine only managing 9
of 16 resident sequences. The batching-amortization story wins and the
MoE-expert-coverage story — the round's own reason to expect this MoE's tail to
flatten harder than a dense model's — is not binding by c16. It may still be
true further out; nothing here tests c32.

The per-request statement is the sharper one. Strict time-slicing (no
amortization at all) would put c16 at 111.11/16 = 6.9. Measured 40.47 is **5.9x
above that line**, so batching is still doing most of the work it does at c1.
The per-request curve is not a decay law — it is a STEP between c2 and c4 and
then a shallow slope:

| step | per-request change | concurrency change |
|---|---:|---:|
| c1 -> c2 | -24.4% | 2x |
| c2 -> c4 | **-37.1%** | 2x |
| c4 -> c5 | -8.9% | 1.25x |
| c5 -> c8 | -9.6% | 1.6x |
| c8 -> c16 | **-7.0%** | 2x |

Two doublings, -37.1% and -7.0%. R4 called the c2-c4 region a "knee" and read it
as the start of a decline; it is better read as a **one-time step**, and the
engine log now offers a mechanism for it.

### MTP acceptance measured against concurrency — first time in this campaign

The c16 engine log was captured through the whole grid and archived
(`experiments/bench_a769c1142e15/engine-serve.log`, 42 SpecDecoding samples).
Under heavy load (samples drafting >500 tokens):

| regime | mean acceptance length | avg draft acceptance | per-position |
|---|---:|---:|---|
| c1 @ d16384 (R5's reading) | 3.81 | 93.6% | 1.000 / 0.962 / 0.846 |
| c16, all samples | 3.29 | 76.2% | 0.899 / 0.762 / 0.635 |
| c16, heavy-load samples | **2.94** | **64.5%** | 0.809 / 0.635 / 0.490 |

R5 watched acceptance collapse with DEPTH. This is the first time the campaign
has watched it move with CONCURRENCY, and it is a candidate mechanism for the
c2-c4 step: losing the high-acceptance MTP regime is a one-time cost, paid once
as the batch fills, and once paid the remaining scaling is ordinary batching.

**But state the confound, because it is serious.** A c16 measurement averages
acceptance over 16 concurrent prompts and therefore reports close to the
POPULATION MEAN of a distribution this campaign has known to be bimodal since
R2. A c1 measurement reports a single DRAW from it. R5's 93.6% came from a
runs=3 c1 cell with σ 9.6% — plausibly a high draw. So "acceptance falls with
concurrency" and "c1 figures sit above the population mean" predict the same
observation, and this round cannot separate them. That is also the tidiest
available explanation for why c8 and c16 are the **quietest cells the campaign
has ever measured** (σ 0.51% and 0.15%): they average the acceptance draw over 8
and 16 sequences, which is precisely R6's variance mechanism applied to
concurrency. R6 said concurrency was a proxy for verify-steps-averaged; this
round shows the proxy working at the top of the range.

### Side-predictions

- **pp2048 620-645 at both points: HELD, and the control did real work.**
  Measured 631.25 (σ 0.31) at c8 and 628.74 (σ 0.70) at c16, inside the band and
  inside the flat d16384 series (637.09 / 634.04 / 643.31 / 623.13 / 634.99 /
  640.21). This was written as the check on the mutation itself, and it passes:
  **matching the scheduler width eliminated R4's chunked-prefill interference**,
  which depressed pp2048 to 581.44 at c5/mns4. The interference is a QUEUEING
  effect, not a batch-size effect — at c16 the batch is 4x larger than R4's and
  prefill is undisturbed. That is a direct, unplanned strengthening of R9's
  premise.
- **σ under 2% at both: HELD emphatically.** 0.51% and 0.15%. c16 is the
  campaign's tightest tg measurement, beating R5's pp2048 as the quietest cell
  of any kind. runs=3 was the right budget and even that was generous.
- **ctx above cold by +3-8%: direction HELD, magnitude MISSED high at both
  points.** +9.7% at c8 (47.75 vs 43.51) and +12.7% at c16 (45.61 vs 40.47). No
  sign flip: open question 4's sign has now been positive at c4, c5, c8 and c16
  and negative only at c2 on this axis. The magnitude is also GROWING with
  concurrency, monotonically — +6.6% (c4), +6.5% (c5), +9.7% (c8), +12.7% (c16) —
  which is the first orderly trend anyone has found in this question. And the
  ctx quietness rule holds here for the seventh and eighth time (σ 0.10% and
  0.18%, both below their cold arms).
- **ttfr: MISSED LOW at both points.** Predicted 18000-26000 ms at c8 and
  36000-56000 at c16; measured 16554 and 29751. Both below their bands, the same
  direction as the throughput misses.

### Standings, and the round's second finding

**Neither cell can be scored.** docs/arena-recipe.md carries no c8 or c16 figures
— the scrape covered c1, c2, c4 and c5 only — so both rows read "not scraped",
exactly as the hypothesis said in advance. Nothing was invented.

The free correction the hypothesis promised did land: the scrape filled in c2
(325.44) and c5 (428.95), which RESULTS.md still recorded as "not scraped".
**Recording them exposed a problem, and it is bigger than the two rows.**

The board's c>1 tg figure appears to be an AGGREGATE, not a per-request rate,
which is the opposite of the assumption every c>1 comparison in this campaign
has rested on. The evidence is the shape of the board's own numbers for a fixed
model across concurrencies:

| series | c1 | c2 | c5 | shape |
|---|---:|---:|---:|---|
| board, LFM2.5-350M BF16 | 188.47 | 325.44 | 428.95 | 1.00 / 1.73 / 2.28 |
| board, Qwen3.6-35B-A3B-NVFP4 vLLM (like-for-like) | 116.03 | 163.27 | 225.46 | 1.00 / 1.41 / 1.94 |
| **ours, aggregate** | 111.11 | 168.0 | 240.6 | 1.00 / 1.51 / 2.17 |
| **ours, per-request** | 111.11 | 84.00 | 48.12 | 1.00 / 0.76 / 0.43 |

The board's figures RISE with concurrency for a fixed model. Per-request
throughput cannot rise with concurrency on a fixed engine. And the like-for-like
row — our exact model, runtime and quant — tracks our aggregate series closely
(1.41 vs 1.51, 1.94 vs 2.17) and is nothing like our per-request series.

**What this touches: the campaign's only marginal win.** `tg128 @ d16384 c4` is
claimed at 1.13x by comparing our per-request 52.85 against the board's 46.68.
If the board figure is an aggregate, the right comparison is our 211.4 against
46.68 — **4.53x**, a much larger win. The DIRECTION of that claim is safe under
either reading; the MARGIN is not established, and the campaign should stop
quoting "1.13x, verified" as though the units are settled.

The counter-evidence is honest and unresolved: 46.68 as an aggregate at c4 means
Gemma-4-26B-A4B-NVFP4 managed 11.7 tok/s per request, which is very slow. The c4
cell is also thin (8 entries) and populated by large models, while c2/c5 are
crowded (130/120) and topped by a 350M — so the magnitude gap between the cells
may be population, not metric.

**This round does NOT resolve it and does not rewrite the c4 verdict.** It is
recorded as new open question 7 and queued as R5c — a zero-box-time board check,
which is the same cheap, high-value shape as R5b. Per this round's instructions
the board was not re-scraped.

### Telemetry

Sampled through the c16 grid (420 samples, archived as
`experiments/bench_a769c1142e15/telemetry.log`): SM clock **2392 MHz median**,
2353-2411, against the same 3003 MHz ceiling; temperature peaked at 75 °C, power
at 94.72 W with a 59.6 W median. That is the **fourth consecutive session** to
read 2392-2398 (R4 2392, R5 2398, R6 2398), and it is the strongest version of
the reading because c16 is by far the heaviest load the campaign has put on the
box: 16-way concurrency did not move the clock, the temperature (75 °C, between
R6's 69 and R5's 79), or the power ceiling (94.72 W, matching R4's 95 and R6's
94.7 to within a watt). **The box is not power-limited and not thermally limited
even at 16-way** — the clock is flat policy at ~80% of ceiling, full stop. Open
question 5 can be closed rather than merely downgraded. No clock, power-policy,
driver or kernel setting was touched.

### Config and epoch

**MUTATION: `-o max_num_seqs=8` (c8 arm) and `-o max_num_seqs=16` (c16 arm).**
Confirmed live in the engine's own non-default-args line (`'max_num_seqs': 16`).
**NOT folded into recipe.yaml** — the campaign config stays `--max-num-seqs 4`,
as R4's mns-5 arm did. RESULTS.md carries the `max_num_seqs` in every c>1 row so
the reader can check the mns >= c invariant without taking it on trust.

No `max_model_len` override; d16384 + pp2048 + tg128 fits the recipe default
32768, with sparkrun reporting 75.0 GB for KV and a 60.0x context multiplier.
Epoch unchanged: both `state.yaml` files record
`container_image_longterm_ref: ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`,
identical to R1/R3/R4/R5/R6, so every cross-round comparison above is within one
epoch. Page cache again could not be cleared (no passwordless sudo), uniform
across rounds. The `Benchmark args:` echo was read before each run was allowed to
proceed, per R5's process lesson, and confirmed `depth: [16384]`, `tg: [128]`,
`concurrency: [8]` then `[16]`, `runs: 3` — no repeat of R5's silent depth
default.

### Cost

**638.6 s of grid time** (c8 218.9 s, c16 419.7 s) against a predicted 300-600 s
— just over the top of the band, and the c16 arm alone accounts for the miss.
Two engine starts, no wasted invocations, roughly 25 minutes of wall clock from
23:33 to 23:47 box time, about 55k harness tokens. Four cells measured, none
scoreable; the round's value is the curve, the aggregate-estimator failure, the
first acceptance-vs-concurrency measurement, and the board-metric problem — none
of which is a board cell.

Cheapest observation of the round, and worth repeating: **recording two
estimators of the same quantity cost nothing and caught a silent error.** The
c16 aggregate would have been reported as 647.6 — a 47% overstatement, and a
headline of "5.8x the c1 aggregate" — if the round had recorded only the metric
the queue asked for. The instruction to record BOTH is what made the round
correct.

## Round 8 hypothesis — the depth-flatness control: tg128 @ d16384 AND d65536, c1, runs=7, one engine start

Earned by R3 and rewritten twice — once by R6, once here. R3 measured 108.15 at
d65536 against a d16384 baseline and read the difference as noise; R6 then
re-measured d16384 at runs=7 and got 111.11, which shrank the gap this round is
chasing from 5.8% to **2.7%**. R6 also closed the half of R8 that was about the
reproduction gap, so this round is NOT sold on that and does not pretend to buy
it. What is left is the one thing R6 could not do: **put both depths under ONE
engine start and one thermal state**, which removes engine-start variation and
thermal drift as explanations for the depth comparison. Everything the campaign
knows about depth at tg128 c1 currently rests on three separate invocations
(R6 for d16384, R3 for d65536, R5 for d131072).

### The two claims this round has to keep apart

"Depth is flat across d16384-d65536" and "deeper is faster" are different
claims, and only the first is physically available. Per-step decode work is
non-decreasing in context length — every extra KV token is extra read, never
less. So the true curve is monotone non-increasing in depth, and any measured
rise is a sampling artefact by definition, not a finding. The round is set up
to say "flat", "falling", or "we cannot resolve it", and it will not say
"deeper is faster" whatever the medians do.

### Mechanism, and why flat is the plausible reading

Three architectural facts make the depth-dependent term small over this range.
**30 of the 40 layers are Gated DeltaNet** — a fixed-size recurrent state, so
their per-step work does not grow with context at all. Only **10 layers hold
KV**, and they hold it in **FP8**. And the KV itself is tiny against the box:
~2.81 GB at d65536 against ~75 GB reserved for cache, so nothing is evicted,
nothing is recomputed, and prefix caching is unstressed.

The naive bandwidth arithmetic still says the fall should be visible, and it is
worth writing down precisely because the campaign has now watched it fail twice.
Against a fixed ~1.7 GB active-weight read per decode step (R5's figure), KV adds
~0.70 GB at d16384 and ~2.81 GB at d65536, so total read goes 2.40 -> 4.51 GB, a
1.88x rise that a pure-bandwidth model turns into a **-47% fall**. R3 measured
+5.8%. That model was wrong by ~2x at d65536 and by 2.2x at d131072, so it is
not the estimator this round trusts — but it is the reason the round is worth
running at all: if the true fall is anywhere near even a quarter of the naive
figure, seven runs at each depth will see it.

### The resolution budget, declared before the run

This is the part that decides what the round is allowed to conclude. R6 priced
σ at **2.6% of the median** for tg128 @ d16384 and R3 priced it at **9.6%** at
d65536. At runs=7 the standard error of a median is roughly 1.25σ/√n, i.e. ~1.2%
at d16384 and ~4.5% at d65536, so the gap between the two medians carries an
uncertainty of about **±4.7%** at one sigma. **The round therefore cannot
resolve a 2.7% gap and is not claiming it will.** What it can do is rule out a
large fall: a -10% or worse depth penalty would be ~2σ and would show.

Thresholds, written down now so the reading is not chosen after the numbers
arrive:

- **|gap| <= 6%** — depth is FLAT across this range within the round's own
  resolution. Reported as flat regardless of sign; a positive sign is not
  reported as "deeper is faster".
- **d65536 more than 6% BELOW d16384** — the depth term bites earlier than R5
  placed it, R3's flatness reading was partly a lucky draw, and the depth curve
  in RESULTS.md needs rewriting.
- **d65536 more than 6% ABOVE d16384** — monotonicity is violated under one
  engine start, which cannot be physics. The explanation would have to be the
  MTP acceptance draw, and the engine log is being captured to check exactly
  that.

### Numeric predictions

- **tg128 @ d16384 c1: median 106-116, centre ~111.** This reproduces R6's
  111.11 under a different engine start. It is also this round's session-level
  control: if it lands outside that band, the two depths in this invocation are
  still comparable to each other but the round has learned that session-to-session
  drift is larger than the effect being chased, which is itself worth knowing.
- **tg128 @ d65536 c1: median 100-112, centre ~107**, i.e. 0% to -6% against the
  d16384 arm. A 7-run median at this depth replaces R3's 3-run 108.15 as the
  campaign's claimed figure whichever way it moves.
- **ctx_tg128 @ d65536 c1: median 84-96, centre ~90**, replacing R3's 89.76.
- **ctx_tg128 @ d16384 c1: median 98-112**, around R6's 104.85.

### Side-predictions, so the round can be refuted on more than one axis

- **pp2048 @ d16384 lands at 620-645.** The identical-work control R6 and R7
  both used. It has now read 637.09 / 634.04 / 643.31 / 623.13 / 634.99 /
  640.21 / 631.25 / 628.74 across six invocations, so a miss here means the
  session is unusual and everything else in it should be read with that in mind.
  **pp2048 @ d65536 lands at 112-125**, around R3's 118.59.
- **ctx_pp2048: 5750-5950 at d16384 and 3900-4100 at d65536**, around the
  5772-5967 series and R3's 4004.76.
- **The σ ratio between the depths survives one engine start.** Predict d16384
  σ 2-5% and d65536 σ 6-13%. This is a real test of R6's variance mechanism
  rather than a restatement of it: if the deep arm's σ collapses to the shallow
  arm's inside one engine start, then R3's 9.6% was session noise and not a
  property of the depth, and R6's "anything at d65536+ needs 7 runs" pricing is
  wrong. If it survives, the pricing is confirmed on an independent sample.
- **ctx sits BELOW cold at both depths.** R6 measured -5.63% at d16384 (tg128,
  c1) and R3 measured -17% at d65536. This round is the first time open question
  4's sign has been read across two depths **inside one invocation**, which is
  worth more than either prior observation: every previous cross-depth reading
  of that sign was confounded by a separate engine start. Predict -3% to -18% at
  both, with the deeper arm more negative. A sign flip at either depth is the
  fifth axis on which that sign has moved.
- **ttfr: 3100-3400 ms at d16384 and 16000-18500 ms at d65536**, around R6's
  3237 and R3's 17282.
- **MTP acceptance is captured at both depths from the engine log**, as R5 and
  R7 did. This is free and it is the cheap half of open question 6: R5 saw
  acceptance fall from 93.6% at d16384-ish depth to 47.7% under d131072 load,
  but across invocations. Two depths under one engine start gives the first
  unconfounded acceptance-vs-depth reading the campaign has, and if the d65536
  arm's acceptance is materially below the d16384 arm's it becomes the leading
  candidate for whatever depth term does exist.

### Standings expectation

**No new cell.** Both depths are already measured cells. What the round can do
is REVISE two claimed figures from 3-run medians to 7-run medians, which is
exactly what R6 did to tg32 @ d16384 and which cost that cell 10% of its
claimed margin:

- `tg128 @ d65536 c1` — claimed 108.15 vs incumbent 16.48, **6.56x**.
- `ctx_tg128 @ d65536 c1` — claimed 89.76 vs incumbent 20.70, **4.34x**, and it
  is the only `ctx_` cell in the campaign with a scraped board figure.

Both margins are enormous, so neither verdict can plausibly flip; the figures
themselves can move by ~10% and RESULTS.md will carry whatever the seven runs
say. `tg128 @ d16384 c1` is the crowded cell and was never a campaign target —
its row is kept for the reproduction gap only, and R6 already owns that number.

Config: recipe.yaml UNMUTATED apart from the context-length override the deep
arm requires. **`-o max_model_len=73728`** — d65536 + pp2048 + tg128 needs
67712, and 73728 is the figure R3 used at this depth, so the deep arm is
config-identical to R3. No `max_num_seqs` mutation: this is a c1 round and the
recipe's 4 already satisfies `mns >= c`.

Probe: `-b pp=2048 -b tg=128 -b depth=16384,65536 -b concurrency=1 -b runs=7 -o
max_model_len=73728`. Per R5's process lesson the `Benchmark args:` echo is read
before the run is allowed to proceed and must show `depth: [16384, 65536]` —
sparkrun does not error on a missing `-b depth`, it silently defaults it to 0.
`state.yaml` will be checked afterwards for `session_count: 1`, which is the
evidence that both depths really did share one engine start; R1 ran three depths
in one invocation and one session, so this is expected rather than hoped for.

Cost prediction: one engine start (~3 min), and a grid of 14 runs. R6's 14 runs
at d16384 cost 124 s and R3's 3 runs at d65536 cost 151 s, so the deep half
dominates: predict **400-550 s of grid time**, 12-18 minutes of wall clock, and
roughly 45-55k harness tokens.

## Round 8 outcome — bench_3d8149654d1b (2026-08-22)

One invocation, two depths, `session_count: 1` in `state.yaml` — **both depths
really did share one engine start and one thermal state**, which is the entire
thing this round was bought for.

| cell | median | (mean) | σ | σ/median | runs |
|---|---:|---:|---:|---:|---|
| tg128 @ d16384 c1 | **113.06** | (110.68) | 6.20 | 5.5% | 113.06 / 113.28 / 112.72 / **95.56** / 114.36 / 112.51 / 113.30 |
| tg128 @ d65536 c1 | **94.10** | (94.30) | 8.44 | 9.0% | 85.34 / 81.79 / 94.10 / 94.96 / 107.20 / 103.91 / 92.80 |
| ctx_tg128 @ d16384 c1 | 102.68 | (105.33) | 8.03 | 7.8% | 103.30 / 100.95 / **124.76** / 102.68 / 103.77 / 99.79 / 102.06 |
| ctx_tg128 @ d65536 c1 | 92.98 | (93.39) | 8.07 | 8.7% | 90.96 / 92.98 / 105.13 / 92.96 / 77.33 / 93.64 / 100.71 |

**THE HYPOTHESIS IS REFUTED AND SO IS R3. Depth is NOT flat across
d16384-d65536 — it falls 16.8%.** 113.06 -> 94.10 on medians, 110.68 -> 94.30 on
means, both far outside the ±6% band this round declared in advance as its own
resolution limit and roughly 3.5σ on the pre-declared error budget. The round
was set up to be able to say "flat", "falling", or "cannot resolve"; it says
**falling**, unambiguously, and the pre-declared threshold is what makes that
statement worth anything.

### What this costs the campaign, stated plainly

R3's 108.15 at d65536 was **a lucky 3-run draw**, exactly as R1's 129.32 turned
out to be. Seven runs under one engine start put the cell at **94.10 — 13.0%
below R3's figure**, and R3's three runs would have had to be drawn from the top
of this round's distribution (107.20, 103.91 and one more) to produce it. This
is the **second time** a 3-run median in this campaign has been retired by a
7-run one, and both times the 3-run figure was too high.

So the campaign's headline reading of R3 — "the depth-dependent term is smaller
than c1 noise across d8192-d65536" — **is wrong and is retired here.** What was
actually true is narrower and less interesting: three runs at c1 could not
resolve the depth term, and the campaign mistook that for the term being absent.
Open question 3 said exactly this about depth curves at runs=3 and was right.

### The depth curve is monotone after all, which is what physics required

| depth | tg128 c1 median | vs previous | per doubling | source |
|---:|---:|---:|---:|---|
| 16384 | **113.06** | — | — | R8, 7 runs, this invocation |
| 65536 | **94.10** | **-16.8%** (4x) | -8.8% | R8, 7 runs, this invocation |
| 131072 | 77.13 | -18.0% (2x) | -18.0% | R5, 3 runs, separate invocation |

The campaign spent five rounds on a curve that read "flat, flat, then a cliff".
It is not a cliff — it is a **monotone decline that steepens**, -8.8% per
doubling over the first stretch and -18.0% over the last. Every measured rise
this campaign has reported with depth is now gone, which is the outcome the
hypothesis said was the only physically available one: per-step decode work is
non-decreasing in context length, so the true curve cannot rise, and a measured
rise was always going to turn out to be sampling. **The round predicted the sign
of its own refutation** — it just predicted a smaller effect (0 to -6%) than the
-16.8% it found, so the numeric prediction MISSED LOW and the reasoning behind
it held.

The d131072 point is still a 3-run median from a separate invocation and should
be read with everything above in mind. Its σ was 9.3%, so it carries the same
weakness R3's did, and the honest statement is that the last leg of the curve is
the least trustworthy part of it.

### The naive bandwidth model: right sign, still wrong magnitude by 2.7x

The hypothesis wrote the arithmetic down before the run so it could be scored.
Against a fixed ~1.7 GB active-weight read per decode step, FP8 KV over 10 of 40
layers is 0.62 GB at d16384 and 2.50 GB at d65536 (sparkrun's own estimate: 2.81
GB at max_model_len 73728). Total read 2.32 -> 4.20 GB is 1.81x, which a
pure-bandwidth model turns into **-44.8%**. Measured **-16.8%**.

So the naive model is **wrong by 2.7x in magnitude and right in sign**, where in
R3's reading it was wrong in sign as well. The architecture argument survives
and is doing real work — 30 of 40 layers are fixed-state Gated DeltaNet whose
per-step cost does not grow with context at all, and the 10 KV layers store FP8
— but it explains why the fall is a THIRD of the naive figure, not why it is
zero. It was never zero.

### The variance prediction held, and it is the reason to trust this round

Predicted d16384 σ 2-5% and d65536 σ 6-13%. Measured **5.5% and 9.0%** — the
deep arm is genuinely the noisy one, inside ONE engine start, so R6's pricing
("anything at d65536+ needs 7 runs") is confirmed on an independent sample and
is not an artefact of session-to-session drift. That matters here more than
usual, because it is the same mechanism that explains why R3 went wrong: at
9.0% σ, three runs at this depth have a median whose standard error is ~6.5%,
and R3 landed 13% high.

The shallow arm's 5.5% needs one qualification, and it is interesting rather
than embarrassing: **six of its seven runs span 112.51-114.36 — a 1.6% spread,
σ 0.65 — and the seventh reads 95.56.** Excluding that one draw the median is
113.17 and σ is 0.6%, which would be the quietest c1 cell the campaign has
measured. The outlier is not excluded from anything above; the median is the
verdict and 113.06 is what is claimed. But the shape is the campaign's clearest
look yet at the bimodality it has asserted since R2: this is not a spread, it is
a mode plus one low draw, and it is exactly why medians are the verdict here.

### Open question 4 — R3's deep inversion did NOT reproduce

The first same-invocation, cross-depth reading of the ctx-vs-cold sign the
campaign has:

| depth | cold | ctx | ctx vs cold | prior reading |
|---:|---:|---:|---:|---|
| 16384 | 113.06 | 102.68 | **-9.2%** | R6: -5.63% |
| 65536 | 94.10 | 92.98 | **-1.2%** | R3: -17% |

The sign held at both depths (ctx below cold, as predicted), but the **magnitude
ordering is backwards from the prediction** — the round predicted the deeper arm
would be more negative and it is the shallower one, and the deep arm's -1.2% is
outside the predicted -3% to -18% band entirely. **R3's -17% at d65536 does not
reproduce**; under one engine start that cell is level with cold, which is what
R5 found at d131072 (-0.6%) and what the campaign has now seen twice.

The sequence over five depths is +, +, -27%, -1.2%, -0.6%, with the two figures
that made the "inversion deepens at depth" story (-27% at d32768, -17% at
d65536) both being 3-run readings from separate invocations, and the one of them
that has been re-measured properly having collapsed to nothing. **The deep
inversion should be treated as unreproduced until d32768 is re-run at runs=7.**
The shallow-depth sign remains real and unconfounded — R6 flipped it with
generation length alone in one invocation, and this round reproduces its
negative tg128 half at -9.2% against R6's -5.63%.

The ctx quietness rule is broken again, for the third time: ctx σ 7.8% against
cold 5.5% at d16384. It should stay retired, as R6 said.

### Side-predictions

- **pp2048 @ d16384 620-645: HELD at 628.66** (σ 3.25), inside the flat series
  that now reads 637.09 / 634.04 / 643.31 / 623.13 / 634.99 / 640.21 / 631.25 /
  628.74 / 628.66 across seven invocations. **The session control passes**, which
  is what licenses reading the -16.8% as a depth effect rather than a bad night.
- **pp2048 @ d65536 112-125: HELD at 119.54** (σ 0.32) against R3's 118.59 —
  a 0.8% reproduction of a figure from a different engine start.
- **ctx_pp2048: HELD at both.** 5856.93 at d16384 (band 5750-5950) and 4013.59
  at d65536 (band 3900-4100, R3 read 4004.76 — 0.2% apart).
- **ttfr: HELD at both.** 3269.39 ms at d16384 (band 3100-3400, R6 read 3237.23)
  and 17144.32 ms at d65536 (band 16000-18500, R3 read 17281.66). After R7 missed
  both its ttfr bands low, this round hit both.
- **tg128 @ d16384 106-116: HELD at 113.06**, and this is the round's second
  control. It reproduces R6's 111.11 from a different engine start to within
  1.8%, so the shallow anchor of the depth comparison is solid and the deep arm
  is where the campaign's number was wrong.
- **tg128 @ d65536 100-112: MISSED LOW at 94.10**, by 5.9% below the band.
- **ctx_tg128 @ d65536 84-96: HELD at 92.98.** **ctx_tg128 @ d16384 98-112:
  HELD at 102.68.**

Eight side-predictions, seven held. The one that missed is the headline.

### PROCESS FAILURE — the acceptance measurement was not taken

The hypothesis promised MTP acceptance at both depths from the engine log, as
R5 and R7 both captured, and called it "the cheap half of open question 6".
**It was not captured.** sparkrun tore the container down at Step 3/3 and
`/tmp/sparkrun_serve.log` went with it; llama-benchy's own per-run logs carry no
SpecDecoding lines. So the round has no acceptance figures and the one
unconfounded acceptance-vs-depth reading it was in a position to take is lost.
Nothing was invented to fill the gap.

This is a real cost, because acceptance is now the leading candidate mechanism
for a depth term that has just turned out to be three times smaller than
bandwidth predicts and to steepen with depth. **The fix is procedural and cheap:
capture the engine log DURING the grid, not after** — R7 did exactly that and it
produced that round's best finding. Queued as R8b, which needs no new benchmark
if it rides along with any future deep round.

### Standings

**No new cell, and two claimed figures revised — one down hard.**

- `tg128 @ d65536 c1`: **108.15 -> 94.10**, so the margin over the incumbent
  16.48 falls from **6.56x to 5.71x**. Still one of the campaign's two widest
  wins, and the worst of the seven runs (81.79) is still 4.96x, so the verdict
  is nowhere near flipping. The figure was simply overstated by 13%.
- `ctx_tg128 @ d65536 c1`: **89.76 -> 92.98**, margin over 20.70 rising from
  **4.34x to 4.49x**. Worst run 77.33 is still 3.74x. This remains the only
  `ctx_` cell in the campaign with a scraped board figure.
- `tg128 @ d16384 c1` (the crowded cell, never a target): two independent 7-run
  medians now exist, 111.11 and 113.06, 1.8% apart. RESULTS.md carries the
  **pooled median of all 14 runs, 112.62**, which puts the reproduction gap
  against the board's best vLLM NVFP4 entry at **-2.9%**, narrower again than
  R6's -4.2%. Three of the fourteen runs clear 116.03.

The direction of every claim in RESULTS.md is unchanged. One margin got 13%
smaller and it is now written as it measured.

### Telemetry

900 samples through the round (`experiments/bench_3d8149654d1b/telemetry.log`):
SM clock **2398 MHz median**, 2366-2411, against the same 3003 MHz ceiling;
76 °C peak, 95.11 W peak. **Fifth consecutive session** at 2392-2398 (R4 2392,
R5 2398, R6 2398, R7 2392, R8 2398). Open question 5 stays closed. No clock,
power-policy, driver or kernel setting was touched, and no `apt` was run.

### Config and epoch

recipe.yaml UNMUTATED. The only override is the context length the deep arm
requires, **`-o max_model_len=73728`** — config-identical to R3 at this depth,
which is what makes the 108.15 -> 94.10 revision a like-for-like correction
rather than a config difference. No `max_num_seqs` mutation; this is c1 and the
recipe's 4 already satisfies `mns >= c`. sparkrun reported 2.81 GB of KV against
75.0 GB available and a 26.7x context multiplier, so nothing was memory-bound.

Epoch unchanged: `container_image_longterm_ref:
ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, identical to
R1/R3/R4/R5/R6/R7. The `Benchmark args:` echo was read before the run was
allowed to proceed, per R5's process lesson, and confirmed
`depth: [16384, 65536]`, `tg: [128]`, `concurrency: [1]`, `runs: 7`. Page cache
again could not be cleared (no passwordless sudo), uniform across rounds.
`completed_indices` covers both schedule entries, `failed_indices: []`,
`crash_count: 0`.

### Cost

**322.5 s of grid time** (07:00:20 to 07:05:42 box time) against a predicted
400-550 s — under the band, and the deep half dominated it as expected (69.6 s
for 7 runs at d16384, 252.9 s for 7 at d65536). One engine start, no wasted
invocations, about 11 minutes of wall clock, roughly 50k harness tokens. Four
cells measured, none new, two claimed figures revised.

**The round's value, in one line: it cost five minutes of box time to find that
one of the campaign's two widest wins was overstated by 13% and that its
five-round "depth is flat" reading was an artefact of three-run sampling.** The
same instrument that produced the error — a 3-run median at a noisy depth —
had already been flagged by R6, and running seven runs at both depths under one
engine start is what turned a suspicion into a correction. Controls are what
made it safe to believe: pp2048 landed inside a series it has now held across
seven invocations, and the shallow arm reproduced R6 to 1.8%, so the fall
belongs to the depth and not to the night.

## Round 9 hypothesis — the chunked-prefill interference control: tg128 @ d16384, c4 and c5, three arms

Earned by R4, and it is the last mechanism in this campaign that was **inferred
rather than measured**. R4 saw `tg128 @ d16384 c5` come in at 45.60 against a c4
figure of 52.85 — a 13.7% deficit — and explained it by chunked prefill: with
`--max-num-seqs 4` the fifth request cannot get a scheduler slot, and with
`--enable-chunked-prefill` on its prefill is chunked into the ongoing decode
steps rather than waiting outside the engine, so four decoding sequences share
every step with prefill work. The supporting evidence was the prefill row:
`pp2048 @ d16384` reads 637.09 / 634.04 / 643.31 at c1 / c2 / c4 and falls to
581.44 at c5 under mns 4, the only depressed prefill figure at this depth in the
whole campaign, restored to 640.21 the moment mns is raised to 5.

That is a good story and the campaign has been leaning on it since. It has two
holes, and this round exists to close them.

### Hole 1 — the 13.7% deficit was never measured inside one invocation

R4's c5 arm and the c4 figure it was compared against come from **different
benchmark invocations** (R4's `bench_0ef7af8997ce` carried c2 and c5; the 52.85
is R2's pooled figure from `bench_f58c56da6658`). So the deficit itself is a
cross-invocation comparison, carrying engine-start variation and thermal drift
on top of the effect. R8 has just shown what that is worth: it refuted R3's
five-round flatness reading purely by putting two conditions under one engine
start, and the figure it retired was 13% wrong — almost exactly the size of the
effect being explained here.

**This round measures c4 and c5 in ONE invocation** (`-b concurrency=4,5`), so
the deficit is a within-engine-start quantity for the first time.

### Hole 2 — chunked prefill was never actually turned off

Nobody has run this model with `--enable-chunked-prefill` disabled. The
mechanism was read off prefill rows; the flag was never moved.

Moving it is not a `-o` probe argument. `-o` overrides recipe *defaults*, i.e.
the template placeholders, and `--enable-chunked-prefill` is a hardcoded flag in
the recipe command. Arm B therefore runs from a **candidate recipe copy**,
`recipe-nochunk.yaml`, identical to `recipe.yaml` except that the flag reads
`--no-enable-chunked-prefill`. Verified before writing this: vLLM
0.27.2rc1.dev360+ge85d1b69c in the epoch image builds its boolean engine args
with `argparse.BooleanOptionalAction`, so `--no-enable-chunked-prefill` is the
correct spelling and will parse.

### The constraint that forces a third arm

`SchedulerConfig.verify_max_model_len` in this image raises outright when
chunked prefill is off and `max_num_batched_tokens < max_model_len`:

    max_num_batched_tokens (8192) is smaller than max_model_len (32768).
    This effectively limits the maximum sequence length to
    max_num_batched_tokens and makes vLLM reject longer sequences.

The campaign recipe carries `--max-num-batched-tokens 8192` and
`--max-model-len 32768`, so **arm B cannot run at the campaign's token budget at
all.** It needs `-o max_num_batched_tokens=32768`. The auto-raise vLLM applies
when the budget is left unset does not help us — it only fires when
`max_num_batched_tokens` was never passed, and the recipe always passes it.

That means the naive two-arm design (campaign config vs. chunked prefill off)
would vary **two** things at once — the flag AND the token budget — and R7 has
already shown the token budget is a live lever in its own right: at c16 it gated
admission and held only 9 of 16 sequences resident. A two-arm result would be
uninterpretable. So the round runs **three arms**, and what it compares is not
three throughput numbers but three *deficits*:

| arm | recipe | max_num_batched_tokens | chunked prefill | what it buys |
|---|---|---:|---|---|
| **A0** | `recipe.yaml` | 8192 (campaign default) | ON | reproduces R4's condition, with c4 and c5 inside ONE engine start |
| **A1** | `recipe.yaml` | **32768** | ON | the matched control for B — isolates the token budget |
| **B** | `recipe-nochunk.yaml` | **32768** | **OFF** | the actual test |

Define **D = (c5 − c4) / c4** on per-request tg128 medians, computed *within each
arm's own invocation*. D0, D1, D2 are the three deficits. This is a contrast of
contrasts: engine-start variation and thermal drift move c4 and c5 together
inside an arm and therefore cancel to first order in D, which is exactly the
weakness that made R4's inference unsafe and exactly what R8 demonstrated the
value of fixing.

### What each outcome means, decided now

Let **R = (D0 − D2) / D0**, the fraction of the campaign-config deficit that
disabling chunked prefill recovers.

- **R ≥ 0.60** — R4's mechanism is CONFIRMED. Mixed prefill-into-decode batching
  is what costs the 13.7%, and the campaign's chunked-prefill story survives its
  first direct test.
- **R ≤ 0.25** — R4's mechanism is REFUTED. The journal will say so plainly and
  the story goes into RESULTS.md as an inference that did not survive
  measurement. The deficit would then be an ordinary consequence of five
  requests sharing four slots, and the prefill depression a symptom rather than
  the cause.
- **0.25 < R < 0.60** — partial; reported as partial, not rounded to whichever
  side is tidier.

And the middle arm splits the credit:

- **D0 ≈ D1** — the token budget contributes nothing; whatever B shows belongs
  to the chunked-prefill flag alone.
- **D0 ≫ D1** — the 8192 budget was doing the damage, not chunking per se. R4's
  mechanism would then be *right about the symptom and wrong about the lever*,
  and R10's token-budget story gets a second data point at a much smaller
  concurrency than c16.

### Resolution budget, declared before the run

This is the best-powered round the campaign has run, and it is worth saying why.
σ at these operating points is tiny: R4 measured 0.26 at c5 (0.57% of median)
and 0.07 at c5/mns5 (0.15%); R2 measured 0.43 and 0.75 at c4 (0.8%); R7 measured
0.51% at c8 and 0.15% at c16. R6's variance mechanism explains it — raising c
multiplies the sequences averaged per MTP verify step. At σ ≈ 0.6%, a 3-run
median has a standard error near 0.4%, so **D carries an uncertainty of roughly
±1%** and the effect under test is 13.7%. runs=3 is not merely adequate here, it
is generous, and per R6's pricing nothing in this round is tg32 or deeper than
d16384, so no arm needs seven.

The round can therefore resolve **R to about ±0.1**, which is far finer than the
0.25/0.60 thresholds above. If it comes back unable to decide, something has
gone wrong with the measurement rather than with the question.

### Numeric predictions

**Arm A0** — the reproduction:
- `tg128 @ d16384 c4`: **51–55**, centre ~52.9 (R2 pooled 52.85).
- `tg128 @ d16384 c5`: **43–48**, centre ~45.6 (R4's figure).
- **D0 = −10% to −17%**, centre −13.7%.
- `pp2048 @ c4`: **623–650** (the flat series). `pp2048 @ c5`: **555–605**,
  i.e. DEPRESSED — R4 read 581.44. If the c5 prefill row comes back inside the
  flat series, R4's supporting evidence has failed to reproduce and the round
  has already learned something before arm B runs.
- `ctx_tg128 @ c4`: **54–58** (R2 pooled 56.36); `ctx_tg128 @ c5`: **46–50**
  (R4 48.18). ctx ABOVE cold at both, per R7's monotone-with-concurrency trend.

**Arm A1** — chunked prefill still on, budget raised to 32768:
- `pp2048 @ c5` is the discriminator. At mnbt 32768 a d16384 prefill (16384 +
  2048 = 18432 tokens) fits in a single batch, so nothing is *split*; it is
  still *mixed* into decode steps. If R4's depression is about the 8192 chunk
  boundary specifically, predict **615–650, recovered**. If it is about mixed
  batches per se, predict **555–605, still depressed**. I expect the latter,
  because R7 saw pp2048 undisturbed at 628.74 at c16 where the batch is 4x
  larger — which made that interference a queueing effect, not a batch-size one.
- `tg128 @ c5`: **43–49**. `tg128 @ c4`: **51–55** (c4 has no queued request, so
  the budget should not touch it; if c4 moves, the budget is doing something
  this round did not anticipate).
- **D1 = −8% to −17%**, centre −13%.

**Arm B** — the test:
- If the mechanism is right: `tg128 @ c5` **50–55**, `pp2048 @ c5` **615–650**,
  **D2 = −1% to −6%**, R ≈ 0.6–0.95.
- If the mechanism is wrong: `tg128 @ c5` **43–48**, D2 ≈ D0, R ≈ 0.
- `tg128 @ c4`: **48–55**. c4 never queues a request, so with mns 4 ≥ c 4 there
  is nothing for chunked prefill to interleave and the flag should be close to
  a no-op here. **This is arm B's own control**: if c4 moves materially between
  A1 and B, the flag is changing something other than queued-prefill
  interleaving — most likely prefill batching efficiency — and D2 cannot be read
  as cleanly as the thresholds assume.

### Side-predictions, so the round can be refuted on more than one axis

- **The engine log settles the queueing claim directly, which R4 could not.**
  Capture `Running: N reqs, Waiting: M reqs` through the grid the way R7 did.
  Predict **Running median 4 / Waiting median 0 at c4** and **Running median 4 /
  Waiting median 1 at c5** in every arm. If Waiting is 0 at c5 the fifth request
  is not queueing at all and the entire premise — R4's and this round's —
  collapses. This is the instrument the mechanism has been missing since R4 and
  it costs nothing.
- **MTP acceptance is captured from the same log (R8b rides along).** R5 watched
  acceptance move with depth, R7 with concurrency; nobody has watched it move
  between c4 and c5, and a c4→c5 acceptance drop would be a *rival* explanation
  for the deficit that has nothing to do with prefill. Predict acceptance
  roughly flat between c4 and c5 within an arm (both are moderate-load points,
  R7 read 64.5% under heavy c16 load and R5 read 93.6% at c1). A material drop
  is a finding.
- **vLLM will warn on arm B.** The image logs "This model does not officially
  support disabling chunked prefill. Disabling this manually may cause the
  engine to crash or produce incorrect outputs." Predict the warning appears and
  the engine runs anyway. If arm B crashes, that is the round's answer for D2 —
  the mechanism is untestable on this stack — and it will be recorded as a
  crash, archived with a `-crash` suffix, not retried unchanged.
- **ttfr**: predict **~10100–10300 ms at c4** (R2 read 10167 / 10151) and
  **11500–12500 ms at c5** (R4 read 11866 at mns 4). If arm B recovers the
  deficit, its c5 ttfr should FALL relative to A0's — the fifth request stops
  paying for interleaved prefill — which is a second, independent axis on which
  the mechanism can be checked.
- **σ under 1% of the median on every tg row**, per R6's pricing at c ≥ 4. A
  σ above 2% anywhere means this round's error budget is wrong and R must be
  re-priced before it is read against the thresholds.
- **Telemetry**: predict SM clock **2392–2398 MHz** median, the figure five
  consecutive sessions have now agreed on. Open question 5 is closed; this is a
  cheap consistency check, not a question.

### Standings expectation

**No new cell, and nothing claimed.** c4 is the campaign's only marginal win and
this round re-measures it — under R7's units dispute its margin is either 1.13x
(per-request) or 4.53x (aggregate) and R5c has not landed, so the row is not
being rewritten either way. c5 has a scraped board figure (428.95 top, 225.46
best vLLM NVFP4) and is likewise stuck behind the same dispute. Every row this
round produces goes into RESULTS.md **labelled with the arm it was measured
under**, because two of the three arms are MUTATIONS and it must be impossible
to read an A1 or B number as a campaign-config number.

If A0's c4 figure disagrees materially with R2's pooled 52.85, that is a
revision the round makes and RESULTS.md carries it — R6 and R8 both revised
headline figures downward and both were right to.

### Config, and what is a mutation

- **A0**: `recipe.yaml`, UNMUTATED. No `-o` at all. d16384 + pp2048 + tg128 needs
  18560 and the recipe default `max_model_len 32768` covers it, so no context
  override is required. mns stays at the recipe's 4 — which is the *point*, since
  the queued fifth request is the phenomenon.
- **A1**: `recipe.yaml` + `-o max_num_batched_tokens=32768`. ONE mutation.
- **B**: `recipe-nochunk.yaml` (`--no-enable-chunked-prefill`) +
  `-o max_num_batched_tokens=32768`. TWO mutations, which is why A1 exists.

**Neither mutation is folded into `recipe.yaml`.** The campaign config stays
`--max-num-batched-tokens 8192 --enable-chunked-prefill --max-num-seqs 4`, and
`recipe-nochunk.yaml` is a candidate copy that later rounds must not inherit by
accident.

Probe, identical in all three arms:
`-b pp=2048 -b tg=128 -b depth=16384 -b concurrency=4,5 -b runs=3`. Per R5's
process lesson the `Benchmark args:` echo is read before each run is allowed to
proceed and must show `depth: [16384]` and `concurrency: [4, 5]` — sparkrun does
not error on a missing `-b depth`, it silently defaults it to 0. `state.yaml`
gets checked for `session_count: 1` in each arm, which is the evidence that c4
and c5 really did share one engine start.

**Three engine starts, and the round says so.** The three arms cannot sit in one
invocation because A1 and B need different engine configurations, and B needs a
different serve command entirely. What the design buys is that the *quantity
being compared* — D — is measured within a single engine start in each arm, so
engine-start variation enters only as a second-order term on the difference of
deficits, not as a first-order term on a difference of throughputs. That is
strictly stronger than what R4 had and it is the most that can be bought without
a recipe that takes the flag as a template variable.

Cost prediction: three engine starts (~3 min each) and three grids of 6 runs.
R4's c2+c5 grid at runs=3 cost 173.3 s and R7's c8 grid cost 218.9 s, so predict
**180–260 s of grid time per arm, 550–750 s total**, 25–35 minutes of wall clock,
and roughly 55–70k harness tokens.

## Round 9 outcome — bench_5399a85d7aec-a0 (arm A0) + bench_d9fdc68576f2-a1 (arm A1) + bench_12f458ba7348-crash (arm B), 2026-08-22

Two arms measured, one arm impossible. Both measured arms carry
`session_count: 1`, so in each of them c4 and c5 shared one engine start and one
thermal state — which was the whole point of the design.

**Arm A0 — `recipe.yaml` UNMUTATED (mnbt 8192, chunked prefill ON, mns 4):**

| cell | median | (mean) | σ | σ/med | runs |
|---|---:|---:|---:|---:|---|
| tg128 @ d16384 c4 | **52.64** | (52.48) | 0.58 | 1.10% | 51.70 / 52.64 / 53.10 |
| tg128 @ d16384 c5 | **45.05** | (45.19) | 0.28 | 0.62% | 45.05 / 44.93 / 45.58 |
| ctx_tg128 @ c4 | 54.98 | (54.87) | 0.19 | 0.35% | 54.60 / 55.04 / 54.98 |
| ctx_tg128 @ c5 | 48.04 | (47.80) | 0.44 | 0.92% | 47.19 / 48.04 / 48.19 |
| pp2048 @ c4 | 640.70 | (640.61) | 0.32 | — | 640.18 / 640.94 / 640.70 |
| pp2048 @ c5 | 579.98 | (579.49) | 3.37 | — | 579.98 / 575.14 / 583.36 |

**Arm A1 — `recipe.yaml` + `-o max_num_batched_tokens=32768` (chunked prefill ON):**

| cell | median | (mean) | σ | σ/med | runs |
|---|---:|---:|---:|---:|---|
| tg128 @ d16384 c4 | **143.08** | (143.14) | 3.97 | 2.77% | 138.31 / 143.08 / 148.03 |
| tg128 @ d16384 c5 | **81.73** | (76.64) | 8.16 | **9.98%** | 83.06 / **65.12** / 81.73 |
| ctx_tg128 @ c4 | 121.42 | (120.38) | 3.28 | 2.70% | 121.42 / 123.78 / 115.95 |
| ctx_tg128 @ c5 | 79.53 | (80.05) | 1.14 | 1.43% | 81.62 / 78.99 / 79.53 |
| pp2048 @ c4 | 669.28 | (671.15) | 2.94 | — | 669.28 / 668.87 / 675.30 |
| pp2048 @ c5 | 596.78 | (597.15) | 0.96 | — | 598.47 / 596.22 / 596.78 |

### Hole 1 is CLOSED, and it closes in R4's favour

**D0 = −14.4%** (45.05 against 52.64), against the −13.7% R4 computed across two
separate invocations. The deficit is real, it is not an artefact of comparing
two engine starts, and this is the first time it has been measured as a
within-invocation quantity. R4 got the number right for a reason it could not
demonstrate at the time.

R4's supporting evidence reproduces just as tightly. `pp2048 @ c5` reads
**579.98 against R4's 581.44 — 0.25% apart** — while `pp2048 @ c4` reads 640.70,
inside the flat 623-643 d16384 series that has now held across nine invocations.
The cached counterpart repeats too: 5182.08 at c5 against 5888.97 at c4, the
same one-sided depression R4 saw (5236.80 against 5810-5967). Every A0
prediction landed inside its band, both ttfr bands included (10205.51 against
10100-10300 predicted, 11847.76 against 11500-12500).

So the phenomenon R4 described is solid. What was never solid was the
explanation, and that is where this round stops.

### THE MECHANISM COULD NOT BE TESTED, AND THE ROUND SAYS SO PLAINLY

**Arm B did not run.** `--no-enable-chunked-prefill` is a real flag and it parsed
correctly — the engine accepted it, emitted the predicted warning ("This model
does not officially support disabling chunked prefill"), and then **refused to
start**:

    pydantic_core.ValidationError: 1 validation error for VllmConfig
      Assertion failed, Chunked prefill is required for mamba cache mode 'align'.

This is architectural, not a tuning accident. `mamba_cache_mode` is `"align"`
whenever prefix caching is enabled — vLLM's own docstring says so ("align ... is
the default when prefix caching is enabled") — and `"align"` requires chunked
prefill. The campaign recipe runs `--enable-prefix-caching`, and **30 of this
model's 40 layers are Gated DeltaNet**, i.e. mamba-class layers whose recurrent
state is what that cache mode governs.

The consequence is worth stating carefully, because it is the round's real
answer. **On this stack, chunked prefill cannot be disabled without also
disabling prefix caching.** The only runnable "arm B" would change the cache
strategy for three quarters of the layer stack at the same time as the flag
under test, and would destroy every `ctx_` row in the process. A mechanism test
whose control condition alters 75% of the layer stack's caching behaviour cannot
attribute its result to chunked prefill. So:

- **D2 is unmeasured. R is unmeasured. The 0.25 / 0.60 thresholds this round
  declared in advance never got to be applied.** Nothing was invented to fill
  the gap.
- **R4's inferred chunked-prefill interference mechanism is neither confirmed
  nor refuted. It remains an inference**, and after this round it is an
  inference that is now known to be *untestable by the obvious route* — which is
  a more useful state than "untested", because it stops the campaign from
  queueing this same round again.

The round was set up to say "confirmed", "refuted", or "partial". It says
**none of those**, and the honest fourth answer is the one it reports.

The prediction that vLLM "will warn on arm B and the engine runs anyway" was
**half right and the wrong half mattered**: the warning fired exactly as
predicted, and then a *second*, unrelated validator killed the engine. Predicting
the warning was easy; predicting the mamba constraint required reading a part of
the config the round never looked at. Cost: one engine start, no measurements,
archived as `bench_12f458ba7348-crash` with the traceback and the candidate
recipe. Not retried unchanged, per the standing rule.

### THE UNPLANNED FINDING, and it reaches the campaign's only marginal win

Arm A1 existed purely as arm B's matched control. With arm B dead it has no
control duty left, and what it found instead is more consequential than what the
round set out to test.

**The campaign's own token budget was gating admission at c4.** From the engine
logs, sampled through each grid:

| arm | cell | Running median | Waiting median | observed (Running, Waiting) pairs |
|---|---|---:|---:|---|
| A0 (mnbt 8192) | c4 | 3.0 | 0.0 | (0,0) **(2,2) (3,1)** (4,0) |
| A0 (mnbt 8192) | c5 | 3.0 | **1.0** | (0,0) (1,0) (1,4) (2,3) (3,0) (3,2) **(4,1)** |
| A1 (mnbt 32768) | c4 | **4.0** | 0.0 | (0,0) **(4,0) only** |
| A1 (mnbt 32768) | c5 | 3.0 | 0.0 | (0,0) (2,0) (3,0) (3,1) (4,0) (4,1) |

Two things fall out of that table.

**First, the c5 queueing claim is now DIRECTLY OBSERVED rather than inferred.**
At A0 c5 the scheduler sits at `Running: 4, Waiting: 1` — the fifth request
genuinely waits for a slot, exactly as R4 said and exactly as this round
predicted (Waiting median 1.0 at c5, 0.0 at c4). R4 reasoned its way to this
from a prefill row; the scheduler has now been asked directly and agrees. That
half of R4's story is confirmed even though the mechanism half could not be
tested.

**Second, and this is the part R4 got wrong: c4 queues too.** R4's account says
"at c4 every prefill happens in one batch up front and the decode phase is
clean". A0's c4 log carries `(2,2)` and `(3,1)` — two requests running with two
waiting — so at the campaign's own configuration **c4 never reached full
occupancy either**, and raising the token budget alone turns c4 into a clean
`(4,0)` for the entire grid. R7 found this gate at c16 and queued it as R10 on
the assumption it was a high-concurrency problem. It is not. **It bites at c4,
which is the cell holding the campaign's only marginal win.**

### The throughput consequence is NOT claimed, and open question 9 is why

The naive reading of arm A1 is a 2.7x win: 52.64 → 143.08 per-request at c4 by
changing one number. **That reading is wrong and the round refuses it**, on
exactly the check R7 wrote into open question 9 — compute both estimators at
every new operating point.

| arm | cell | tg × c | peak_throughput | verdict |
|---|---|---:|---:|---|
| A0 | c4 | 210.6 | 272 | consistent (below the peak) |
| A0 | c5 | 225.2 | 276 | consistent |
| A1 | c4 | **572.3** | **297** | **INVALID — exceeds the peak by 93%** |
| A1 | c5 | **408.7** | **289** | **INVALID — exceeds the peak by 41%** |

A sustained figure cannot exceed a peak. At arm A1 the identity breaks at *both*
concurrencies, so **arm A1's per-request numbers are not comparable to any other
row in this campaign and are claimed against nothing.** What the bounding
estimator actually says is much more modest: `peak_throughput` rises **272 → 297
at c4 (+9.2%)** and **276 → 289 at c5 (+4.7%)**.

So the honest summary of arm A1 is: raising the token budget **fixed the
occupancy** (direct evidence, the scheduler log) and moved the aggregate bound by
**single-digit percent** (direct evidence, `peak_throughput`), while the
per-request metric moved by an amount that cannot be reconciled with either.
**The campaign does not yet understand what `tg_throughput` measures at c > 1**,
and this round is the second consecutive one to trip over it. That is a
measurement problem, not a physics result, and it is now the most valuable thing
in the queue.

**D1 = −42.9%** is recorded for completeness and should be trusted no further
than the numbers it is built from, i.e. not very far.

### MTP acceptance is flat, which kills the rival explanation (R8b rode along)

Captured live from both engine logs, the way R7 did and the way R8 failed to.
Heavy-load samples (>200 drafted tokens in the window):

| arm | cell | mean acceptance length | avg draft acceptance |
|---|---|---:|---:|
| A0 | c4 | 2.99 | 66.2% |
| A0 | c5 | 3.09 | 69.8% |
| A1 | c4 | 2.95 | 65.1% |
| A1 | c5 | 2.85 | 61.7% |

**Acceptance does not move between c4 and c5** — the spread across all four
cells is 61.7-69.8%, and at arm A0 the *slower* cell (c5) has the *higher*
acceptance. The round predicted "roughly flat" and it is flat. This matters
because it removes the one rival mechanism that could have explained the deficit
without any reference to prefill: MTP acceptance decay is **not** what makes c5
slower than c4. R5 watched acceptance move with depth and R7 watched it move
with concurrency at c16; between c4 and c5 it does not move at all, so whatever
costs 14.4% is a scheduling effect, not an acceptance effect. That is a genuine
narrowing of the mechanism space, bought for free, and it is the one part of
R4's story this round could still test.

### Side-predictions

- **Waiting median 0 at c4 / 1 at c5: HELD** at arm A0, and it is the round's
  cleanest result. (Running median came in at 3.0 rather than 4 in three of four
  cells because the samples include grid ramp-up and ramp-down; the loaded-state
  pairs are what the table above reports.)
- **pp2048 @ c4 623-650: HELD** at 640.70 (A0) and 669.28 (A1 — above the band,
  and the band was written for the campaign config).
- **pp2048 @ c5 555-605: HELD** at 579.98 (A0) and 596.78 (A1). Note that the
  A1 discriminator the hypothesis set up — "if the depression is about the 8192
  chunk boundary it recovers to 615-650, if it is about mixed batches it stays
  depressed" — **came out on the mixed-batch side**: at mnbt 32768 a d16384
  prefill fits in one batch and c5's prefill is *still* depressed, 596.78 against
  669.28 at c4. That is the round's one piece of positive evidence about R4's
  mechanism, and it points the way R4 said, but it is a single side-prediction
  and it is not a substitute for the arm that could not run.
- **ttfr: HELD at both A0 points** (10205.51 in a 10100-10300 band; 11847.76 in
  11500-12500).
- **σ under 1% on every tg row: MISSED.** A0 obliged (0.35-1.10%) but **A1 c5
  came in at 9.98%** — runs 83.06 / **65.12** / 81.73, the mode-plus-one-low-draw
  shape R8 documented. The round's ±1% error budget for D therefore holds for D0
  and does **not** hold for D1, which is a further reason not to lean on D1.
- **Telemetry: HELD.** 700 samples in A0 and 395 in A1, both at **SM clock 2398
  MHz median** (2379-2411 and 2333-2411), 75/76 °C peak, 95.25/97.10 W peak. The
  **sixth and seventh consecutive sessions** agreeing with R4's 2392. Open
  question 5 stays closed. No clock, power-policy, driver or kernel setting was
  touched and no `apt` was run.

### Standings

**No new cell, and nothing claimed.** c4 and c5 both sit behind R7's unresolved
units dispute (open question 7), which R5c has not yet settled, so no row was
rewritten in either direction.

One flag is added to RESULTS.md rather than a revision: **the campaign's only
marginal win, `tg128 @ d16384 c4`, was measured under a configuration that does
not reach full occupancy at c4.** A0's engine log is the evidence. That does not
change the measured number (52.64 here reproduces R2's pooled 52.85 to 0.4%) and
it does not change the verdict's direction; it means the cell has headroom the
campaign has not characterised, and that the "which units" question and the
"which occupancy" question now both hang over the same row.

### Cost

Three engine starts, two grids of six runs, one engine that refused to start.
**Grid time 442.5 s** (A0 223.4 s: 114.0 + 109.4; A1 219.1 s: 111.5 + 107.6),
inside the predicted 550-750 s only because the third arm never reached its
grid. Roughly 40 minutes of wall clock — the A1 engine start alone took ~6
minutes, materially longer than A0's because the larger token budget forces
torch.compile over a `(1, 32768)` range and a longer FlashInfer autotune — and
about 70k harness tokens.

**The round's value, in one line: it proved R4's deficit is real inside a single
engine start and its queueing claim is real in the scheduler's own log, showed
that R4's mechanism cannot be tested on this stack at all, and found by accident
that the campaign's token budget was starving the very cell its only marginal
win sits in.** Two of those three were not what the round was for.

## Round 10 hypothesis — the token-budget round: tg128 @ d16384, c4 and c16 at `max_num_batched_tokens 32768`, runs=7, one engine start

Earned twice over. R7 found `--max-num-batched-tokens 8192` gating admission at
c16 and queued this round as a high-concurrency repair. R9 then found the same
gate biting at **c4**, which is the cell holding the campaign's only marginal
win, so the round is repriced: it runs both concurrencies, and it reports **both
throughput estimators at every point** because R9 watched `per-request x c`
break at c4 as well as at c16.

### What is already paid for, and what this round still owes the box

R9's arm A1 (`bench_d9fdc68576f2-a1`) is already the c4 half at
`max_num_batched_tokens 32768`, and it was read in full before any box time was
spent this round. It is **not** re-run. What it says, with both estimators:

| arm | cell | tg | peak_thr | peak/peak_req | pp2048 | ttfr |
|---|---|---:|---:|---:|---:|---:|
| A0 (mnbt 8192, mns 4) | c4 | 52.64 | 272 | 3.78 of 4 | 640.70 | 10205.51 |
| A1 (mnbt 32768, mns 4) | c4 | 143.08 | **297** | 3.88 of 4 | 669.28 | 11798.88 |
| R7 (mnbt 8192, mns 16) | c16 | 40.47 | 440 | **11.89 of 16** | 628.74 | 29751.25 |

So the box owes this round the **c16 point at the raised budget**, and nothing
else that R9 already bought.

It is run in ONE invocation with a **c4 arm alongside it**, at
`-o max_num_seqs=16 -o max_num_batched_tokens=32768`. That c4 arm is not a
re-run of A1: A1 carried `max_num_seqs 4`, this carries 16. It costs roughly
260 s on a ~980 s grid and buys two things the round cannot get otherwise —
a **within-invocation** c4-vs-c16 comparison at one budget and one thermal
state (R8's lesson: this campaign's cross-invocation comparisons have twice
been wrong by more than the effect under test), and an independent second look
at A1's startling 143.08 from a separate engine start. If `max_num_seqs`
comfortably above `c` is neutral, the c4 arm reproduces A1; if it does not,
A1's figure was a fluke and R9's most consequential unplanned finding needs
re-reading.

### Why runs=7, against the standing guidance

R6 priced tg128 @ d16384 at runs=3 and that pricing is right **for `tg`**. It
is the wrong estimator to price this round on. `tg x c` is already known to be
invalid at both of this round's concurrencies, so the round's verdict rests
entirely on `peak_throughput` — and `peak_throughput` is the noisy one:
**σ 5.0% at R7's c16 (440, runs 440/418/472) and σ 8.6% at R9's A1 c4 (297,
runs 297/333/271)**, against `tg`'s 0.14% and 2.77% in the same measurements.
At 5-9%, three runs give a standard error near 3-5%, which is the same size as
the effect being tested. Two 3-run medians have already had to be retired this
campaign and both were too high. **The sampling budget belongs to the estimator
the round actually depends on**, so: runs=7.

### The mechanism, stated as arithmetic rather than as a story

At d16384 a request's prefill is 16384 tokens. A scheduler step with
`max_num_batched_tokens 8192` therefore fits **half** of one prefill; at 32768
it fits **two whole ones**. That is a 4x admission rate, and it is the entire
intervention.

Decode is not involved. Sixteen resident sequences drafting 3 MTP tokens each
need about `16 x 4 = 64` tokens per step — three orders of magnitude under
either budget. **The token budget has never gated decode in this campaign; it
gates the rate at which requests are let in.** 32768 does not admit all sixteen
at once either — that would take 262144 — so even the raised arm is
admission-rate-limited at c16. The round tests whether 4x closes the residency
gap, not whether the gate is removed.

That distinction produces the round's discriminator, and it is declared here:

- **H_ramp** — the budget throttled the *ramp* and the replacement of finished
  requests, but steady-state aggregate was near its ceiling anyway. Prediction:
  `peak_throughput` at c16 moves by single digits, the way c4 moved +9.2%
  (272 -> 297), residency improves, and R7's "~440" stands.
- **H_gate** — with sixteen requests in flight there is *always* a replacement
  prefill competing for the budget, so the gate is a steady-state one and
  residency is the binding constraint. Prediction: `peak_throughput` rises
  roughly in proportion to residency, 440 x (16/11.89) ≈ **590**, and c16
  becomes the largest aggregate figure the campaign has.

**Threshold, written down before the run: `peak_throughput` at c16 above 500
(+13.6%) reads H_gate; below 470 (+6.8%) reads H_ramp; 470-500 is
indeterminate and will be reported as indeterminate.** c4's measured +9.2% sits
in the H_ramp band, which is what a shallow queue should look like, so the two
concurrencies are allowed to answer differently — that would itself be the
result.

### Numeric predictions

| quantity | baseline | predicted | reasoning |
|---|---|---|---|
| c16 residency (peak/peak_req) | 11.89 of 16 | **14-16** | 4x admission rate |
| c16 `Running` median (engine log) | 9 | **13-16** | primary evidence, as R7 and R9 |
| c16 `Waiting` median | 6 | **0-3** | ditto |
| c16 `peak_throughput` | 440 | **480-620**, centre 550 | see discriminator |
| c16 `tg_throughput` | 40.47 | **60-160** | wide on purpose — nobody knows what it measures at c>1 |
| c16 `tg x c` vs peak | 647.5 vs 440, INVALID | **INVALID again, by more** | pre-declared, not a finding |
| c16 pp2048 | 628.74 | **640-700** | c4 rose +4.5% on the same change |
| c16 ttfr | 29751 | **28000-40000** | betting AGAINST the naive fall |
| c16 σ on tg | 0.14% | **0.5-5%** | raised budget inflated σ at c4 and c5 |
| c4 (mns 16) tg | A1's 143.08 | **129-157** | reproduction check |
| c4 (mns 16) `peak_throughput` | A1's 297 | **270-325** | reproduction check |
| MTP acceptance @ c16 | 2.94 / 64.5% | **2.7-3.2 / 58-72%** | R8b rides along |
| SM clock median | 2392-2398 | **2392-2398** | eighth session |
| grid time | — | **1050-1500 s** | R7's c16 419.7 s scaled 7/3, plus c4 |

The ttfr prediction is the one worth flagging, because the obvious reasoning
gets it backwards. A 4x faster ramp ought to bring first responses sooner. But
R9 measured the opposite when it raised the budget at c4: ttfr went **up**,
10205 -> 11799 (+15.6%), because a larger budget batches more prefill work
together and each individual request's prefill then competes with more of its
peers. This round bets on the R9-informed direction, flat to higher.

### What is NOT in scope, and what rides along free

`max_num_batched_tokens 32768` is a **MUTATION**. It is not folded into
`recipe.yaml`, and every RESULTS.md row it produces says so in the cell name —
a tuned row and an untuned row must never sit in that table looking alike.

Nothing here can be scored. The board has no c16 figure at all, and c4 sits
behind the unresolved units dispute (open question 7, R5c). **No verdict on any
board cell will be written by this round in either direction.**

Two ride-alongs, both zero box time, both taken while the grid runs:

- **R8b** — tail the engine log through the grid and capture MTP acceptance,
  the way R7 and R9 did and R8 failed to.
- **Open question 10** — read llama-benchy 0.4.0's own definition of
  `tg_throughput`. It is the most valuable item in the queue, it costs nothing,
  and this round is a c>1 round whose numbers cannot be interpreted without it.
  The campaign has been inferring this metric's meaning for nine rounds; the
  source is the instrument and nobody has read it.

## Round 10 outcome — bench_860b43edd154 (2026-08-22)

One invocation, `session_count: 1`, so c4 and c16 shared one engine start and one
thermal state. Seven runs at each. Same pinned image epoch
(`dgx-vllm-eugr-nightly:2026082102`) as every round since R1.

| cell | tg (board metric) | (mean) | σ | σ/med | peak_thr | runs |
|---|---:|---:|---:|---:|---:|---|
| tg128 @ d16384 c4 | **147.25** | (145.67) | 4.78 | 3.25% | **284** | 148.47 / 143.25 / 137.11 / 147.25 / 142.81 / 147.40 / 153.39 |
| tg128 @ d16384 c16 | **53.45** | (53.34) | 0.28 | 0.52% | **515** | 53.38 / 53.27 / 52.70 / 53.48 / 53.51 / 53.45 / 53.59 |
| ctx_tg128 @ c4 | 126.35 | (126.54) | 1.64 | 1.30% | 290 | 129.54 / 127.05 / 126.27 / 124.87 / 124.17 / 126.35 / 127.55 |
| ctx_tg128 @ c16 | 54.54 | (54.52) | 0.10 | 0.18% | **566** | 54.58 / 54.54 / 54.68 / 54.38 / 54.41 / 54.48 / 54.58 |
| pp2048 @ c4 | 672.59 | — | 0.88 | — | — | — |
| pp2048 @ c16 | 667.00 | — | 1.75 | — | — | — |

### THE ROUND'S BIGGEST RESULT COST NO BOX TIME, and it is a rebuke to nine rounds of inference

The ride-along was supposed to be a nicety. It is the headline.
**llama-benchy 0.4.0's `results.py`, lines 194 and 352:**

    run_metric_tg_throughput = self._calculate_metric(
        agg_batch_tg_throughputs if concurrency > 1 else agg_tg_speeds)
    run_metric_tg_req_throughput = run_metric_tg_throughput if concurrency == 1 \
        else self._calculate_metric(agg_tg_speeds)
    ...
    tg_duration = max_last_token - min_first_token
    observed_decode_tokens = sum(... for r in valid_results)
    batch_tg_throughput = observed_decode_tokens / tg_duration

**At `c>1`, `tg_throughput` is a BATCH AGGREGATE.** Total decode tokens across
every request in the batch, divided by the span from the *first* request's first
token to the *last* request's last token.

**Open question 10 is ANSWERED, and R2's units correction is retired.** R2's
proof was "at c1 `tg_throughput == tg_req_throughput` exactly, therefore tg is
per-request". Line 195 shows the c1 equality is an *assignment* — the two names
are bound to the same object when `concurrency == 1`. It is a tautology. It was
always going to hold, for any definition whatsoever of the `c>1` branch, and the
campaign built nine rounds of `c>1` interpretation on it. The lesson is not
"R2 was careless"; R2 checked something real. The lesson is that **a consistency
check that cannot fail is not evidence**, and the source was three minutes away
the whole time.

**Open question 7 is ANSWERED too, as a side effect.** sparkrun's arena upload
ships llama-benchy's own CSV, and `llama_benchy.py`'s row builder maps
`t_s <- tg_throughput` with `_CSV_HEADERS` naming the column. The board's
headline decode figure is therefore **the same field we already record**. Every
`c>1` comparison this campaign made was like-for-like all along.

So both prior readings were wrong, and they were wrong in opposite directions:
R2's "ours is per-request, theirs is per-request" and R7's "theirs is aggregate,
so multiply ours by `c`". The truth is **"both are the same aggregate, so
multiply nothing"** — and `per-request x c` was never the aggregate, it was an
aggregate multiplied by `c` a second time. That is why it kept exceeding
`peak_throughput`: not a subtle scheduling artefact, just double-counting.
**Two rounds of open question 9 diagnosis were chasing an arithmetic error.**

### The mechanism, and why this metric is so violently config-sensitive

`tg_duration` includes admission stagger. So a starved token budget is charged
to the board metric **twice** — once by holding fewer sequences resident, and
again by stretching the denominator. Measured directly, as
`batch span / single-request decode span` over every archived `c>1` run:

| config | c2 | c4 | c5 | c8 | c16 |
|---|---:|---:|---:|---:|---:|
| mnbt 8192 | 1.61 | 2.54 | 2.38 | 2.08 | 2.06 |
| mnbt 32768 | — | **1.57** (R10) | 2.39 (R9) | — | **2.89** (R10) |

It is never 1.0, so requests never run in lockstep, and at c4 raising the budget
cuts it from 2.54 to 1.57. **That single number is the whole c4 result.**

It also explains the thing R7 could not: why the board's figure RISES with
concurrency for LFM2.5-350M (188.47 / 325.44 / 428.95) while ours FALLS. A 350M
model prefills d16384 almost instantly, so its stagger is nil and its aggregate
climbs the way batching says it should. Our 35B model at mnbt 8192 staggers by
2-2.5x and the dilution beats the batching gain. **Same metric, different
prefill cost.** R7's counter-evidence dissolves the same way: 46.68 as an
aggregate at c4 is not implausibly slow, it is exactly the regime our own 52.85
sits in.

### STANDINGS — the campaign's thinnest win is no longer thin

**`tg128 @ d16384 c4`: 52.85 -> 147.25, i.e. 1.13x -> 3.15x** against the same
incumbent 46.68, at runs=7. The worst of the seven runs, 137.11, is still 2.94x.
This reproduces R9's arm A1 (143.08, three runs, `max_num_seqs 4`) to **+2.9%
from a separate engine start with a different scheduler width** — so A1's
startling figure was real, and `max_num_seqs` comfortably above `c` is neutral.
By the campaign's own "verify a win with a repeat before keeping" rule, this
mutation is **verified**.

`ctx_tg128 @ d16384 c4` goes 56.36 -> 126.35 against a board figure of 27.68
(from R5b's scrape), i.e. **2.04x -> 4.56x**.

And the two cells that were "UNITS DISPUTED" resolve as **losses**: c2 is 84.00
against the board's own Qwen3.6-35B-A3B-NVFP4-on-vLLM 163.27 (**0.51x**) and c5
is 48.12 against 225.46 (**0.21x**). Same model, same runtime, same quant, same
metric — so that gap is entirely **config**, and R10 has just shown what most of
it is. Recording a loss honestly here is worth more than the disputed label was.

### THE HYPOTHESIS: H_gate, but only just, and the occupancy predictions MISSED

The pre-declared threshold was `peak_throughput` at c16 **above 500 reads H_gate,
below 470 reads H_ramp**. Measured **515** (runs 524 / 515 / 495 / 512 / 530 /
498 / 541, σ 3.0%, SE ~1.1%), so the median clears the line robustly even though
one run does not. **H_gate.**

And the proportionality it predicted holds well. Residency at peak went
**11.89 -> 14.31 of 16** (+20.4%) and `peak_throughput` went **440 -> 515**
(+17.0%). Scaling R7's 440 by the residency ratio predicts 530 against 515
measured — **2.8% apart**. Residency really is what sets the aggregate ceiling,
which is the cleanest thing this round establishes about the hardware.

**But three predictions missed, they missed together, and they say the round
oversold its own intervention.** The scheduler log — the primary instrument,
same one R7 and R9 used — reads `Running` median **11** against a predicted
13-16, and `Waiting` median **5** against a predicted 0-3:

| arm | Running med | Waiting med | full-occupancy samples |
|---|---:|---:|---:|
| R7 c16 (mnbt 8192) | 9 | 6 | 4 of 41 = 10% |
| **R10 c16 (mnbt 32768)** | **11** | **5** | **14 of 66 = 21%** |
| R10 c4 (mnbt 32768) | 4 | 0 | **13 of 13 = 100%** |

So c16 is **better and still gated**. That is exactly what the round's own
arithmetic said before it ran — 32768 admits two 16384-token prefills per step,
and sixteen would need 262144 — and the round then wrote a prediction band that
ignored its own arithmetic. **The mechanism section was right and the prediction
table was wrong, in the same document.** Worth remembering: the numeric bands
were set by scaling R7's numbers, when the model that generated them was sitting
one paragraph above.

c4, by contrast, is a clean `(4,0)` in **100%** of loaded samples — the gate is
genuinely gone there, and that is why c4 gets the big number and c16 does not.

`tg_throughput` at c16 also missed low: **53.45** against a predicted 60-160.
Given the units result, that band was built on a misunderstanding of the metric
and should not be credited as a near-miss.

### ttfr: the counter-intuitive prediction HELD

Predicted **28000-40000** at c16 against the naive expectation of a large fall,
on the strength of R9's c4 observation that raising the budget made ttfr *worse*.
Measured **39389** against R7's 29751 — **+32.4%**, at the top of the band and
in the predicted direction. Raising the budget batches more prefill work
together, so each request's first token comes later even though the batch as a
whole finishes sooner. **c16 is now a 39-second time-to-first-response cell:
excellent for aggregate work, useless for latency, and any row it produces
should say so.**

### MTP acceptance is FLAT, which localises the gain (R8b rode along again)

Captured live from the engine log through the grid. Heavy-load samples
(>200 drafted tokens):

| arm | acceptance length | draft acceptance |
|---|---:|---:|
| R7 c16 (mnbt 8192) | 3.10 | 70.0% |
| **R10 c16 (mnbt 32768)** | **3.07** | **69.1%** |
| R9 A1 c4 (mnbt 32768) | 2.95 | 65.1% |
| **R10 c4 (mnbt 32768)** | **3.02** | **67.3%** |

Prediction 2.7-3.2 / 58-72%: **HELD**. Acceptance does not move when the token
budget moves, at either concurrency. **The entire effect is scheduling.** R9
established the same thing for the c4-vs-c5 deficit; between them, MTP
acceptance is now ruled out as an explanation for anything the scheduler does.

### Open question 4 gets a new and awkward data point

The ctx-vs-cold sign **flips at c4 when only the token budget changes**: +4.4%
at mnbt 8192 (R9 A0), **-14.2%** at mnbt 32768. And R7's tidy finding that the
ctx margin grows monotonically with concurrency (+6.6 / +6.5 / +9.7 / +12.7% at
c4/c5/c8/c16) does not survive either — at mnbt 32768 it reads -14.2% at c4 and
**+2.0%** at c16.

The span story accounts for it without new machinery: the `ctx_` phase does no
prefill, so it never staggers much and has little to gain; the cold phase is the
one carrying the stagger, so removing the stagger lets cold overtake ctx. But it
means the driver of this sign is now known to be moved by depth, by concurrency,
by generation length **and by a pure scheduler knob** — so the sign is not a
property of prefix caching at all. It is a property of how staggered the cold
arm happens to be. That is the most economical account anyone has offered here
in eight rounds and it should be attacked rather than adopted.

### Side-predictions

- **c4 reproduction: HELD on both estimators.** tg 147.25 in a 129-157 band,
  `peak_throughput` 284 in a 270-325 band.
- **pp2048 @ c16 640-700: HELD** at 667.00, +6.1% on R7's 628.74 at identical
  concurrency and scheduler width, so the lift is the budget alone. pp2048 @ c4
  reads 672.59, matching R9's A1 669.28 to 0.5%.
- **σ on tg at c16 0.5-5%: HELD** at 0.52%.
- **`tg x c` invalid again: HELD**, pre-declared and therefore not a finding —
  855.2 against a peak of 515. It is invalid for the arithmetic reason above.
- **Telemetry: HELD.** 1489 samples, SM clock **2398 MHz** median (2353-2411),
  78 °C peak, 96.72 W peak — the **eighth consecutive session** agreeing with
  R4's 2392. Open question 5 stays closed. No clock, power-policy, driver or
  kernel setting was touched, and no `apt` was run.
- **Grid time 1050-1500 s: MISSED LOW** at **923.4 s** (c4 219.6 s, c16 703.8 s).
  One engine start, ~19 minutes wall, ~75k harness tokens.

### The mutation is NOT folded into recipe.yaml, and here is the argument

Verified wins normally get folded. This one is held back deliberately, and the
reason is not caution about the number:

**Folding it would break the campaign's own baseline mid-series.** At d16384 a
16384-token prefill is two chunks at mnbt 8192 and one chunk at 32768, so the
change is not inert at c1 either — it can move `pp2048` and `ttfr` there. The c1
series (R6's 111.11, R8's 113.06, pooled 112.62) is the anchor every depth and
concurrency comparison in this campaign hangs from, and it was measured at
mnbt 8192. Folding without re-measuring that anchor would silently create a new
epoch and invalidate cross-round comparability, which is precisely the failure
the skill's epoch rule exists to prevent.

So: **recipe.yaml is untouched**, every R10 row in RESULTS.md names its
configuration, and the fold decision is queued as **R11** — re-measure the c1
anchor under mnbt 32768, and fold only if c1 is unchanged. That is one cheap
invocation and it is now the highest-value round in the queue, because a verified
2.8x on the campaign's most contested cell is waiting behind it.

### The round's value, in one line

**It closed the two units questions from the source rather than by inference,
withdrew a 4.53x claim the campaign nearly kept, turned its thinnest win from
1.13x into a verified 3.15x, recorded two honest losses that had been hiding
behind a "disputed" label, and showed at c16 that its own intervention only
half-works — which its own pre-run arithmetic had already said.**

## Round 12 hypothesis — the raised budget at the two lost cells: tg128 @ d16384, c2 and c5 at `max_num_seqs 5` + `max_num_batched_tokens 32768`, runs=7, one engine start

Earned by R10, and it is the highest-value round left in the campaign for one
reason: **these are the only two cells with a known, scoreable, like-for-like
target that the campaign currently LOSES.** c2 is 84.00 against 163.27 and c5 is
48.12 against 225.46 — both held by the board's own
`Qwen3.6-35B-A3B-NVFP4` on vLLM. Same model, same runtime, same quant, and
since R10 read llama-benchy's source, the same metric. There is no population
difference to hide behind and no units question left to argue: **the gap is
config, and R10 found the lever.**

The lever moved `tg128 @ d16384 c4` from 52.85 to 147.25 — 1.13x to 3.15x —
by changing nothing but the scheduler's token budget. Nobody has run c5 with
BOTH `max_num_seqs` and `max_num_batched_tokens` raised (R9's arm A1 raised the
budget but left `max_num_seqs 4`, so the fifth request still queued for a
*slot*), and nobody has run c2 raised at all.

### The arithmetic, and why it predicts c2 and c5 differently

At d16384 a request's prefill is 16384 tokens, so a scheduler step admits
`floor(mnbt / 16384)` whole prefills. That is the entire intervention, and it is
integer-valued:

| c | steps to admit the whole batch at mnbt 32768 | steps at mnbt 8192 |
|---:|---:|---:|
| 2 | **1** (2 fit exactly) | 4 |
| 4 | 2 | 8 |
| 5 | **3** (2+2+1) | 10 |
| 16 | 8 | 32 |

**c2 is the one cell in the campaign where the whole batch is admitted in a
single scheduler step.** Nothing waits for budget and nothing waits for a slot,
so its admission stagger should approach the c1 floor of 1.00. c5 is the
opposite: it is the first concurrency where the batch does NOT divide evenly
into the budget, so a lone third step trails the batch and stretches
`max_last_token`. The round therefore predicts the two points move by
**different** amounts, in a stated order.

This matters because `tg_throughput` is `sum(decode tokens) / (max_last_token −
min_first_token)` — the board metric is charged for that stagger directly.
Measured stagger across the campaign: 1.00 (c1), 1.61 (c2), 2.54 (c4), 2.25
(c5 at mns 5), 2.06 (c16), all at mnbt 8192; and 1.57 at c4, 2.89 at c16 with
the budget raised.

### The discriminator, declared before the run

- **H_stagger** — the budget's benefit is set by how cleanly the batch divides
  into it, so the gain is *not* a constant multiplier. Prediction:
  `stagger(c2) < 1.35` (below c4's 1.57, approaching the c1 floor) **and**
  `stagger(c5) > 1.80` (worse than c4, because of the trailing third step).
- **H_uniform** — the budget buys a roughly constant multiplier regardless of
  concurrency, the way a naive reading of R10 would have it. Prediction: both
  staggers land within ±0.20 of c4's 1.57, and both cells move ~2.8x from their
  mnbt-8192 figures (c2 → ~235, c5 → ~134).

**Threshold: both stagger conditions must hold to read H_stagger. If either
lands in the other camp the result is reported as mixed, not forced.**

### Numeric predictions

Built by decomposing the metric as `tg = c × tg_req / stagger` and estimating
`tg_req` from the campaign's own per-request series (c1 112.62, c4 57.8, c16
9.65 at the raised budget — roughly `c^-0.48`), rather than by scaling R10's
percentages. R10's post-mortem was that its bands were set by scaling the
previous round's numbers while the generating model sat one paragraph above;
this round uses the model.

| quantity | baseline | predicted | reasoning |
|---|---|---|---|
| c2 `tg_throughput` | 84.00 (mnbt 8192) | **135-170**, centre 148 | `2 × ~81 / ~1.10` |
| c2 stagger | 1.61 | **1.00-1.20** | whole batch in one step |
| c2 `tg_req_throughput` | 67.6 | **75-88** | c1 × 2^-0.48, minus nothing — decode is clean |
| c2 `peak_throughput` | 182 | **190-225** | c4 rose 272 → 284-297 on the same change |
| c5 `tg_throughput` | 48.12 (mns 5, mnbt 8192); 81.73 (mns 4, mnbt 32768) | **100-155**, centre 125 | `5 × ~52 / ~2.1`; cross-checks to 130 from A1 × slot-fix × stagger-fix |
| c5 stagger | 2.25 | **1.85-2.30** | trailing third admission step |
| c5 `tg_req_throughput` | A1's 39.1 | **46-58** | A1 was slot-starved; mns 5 releases it |
| c5 `peak_throughput` | 265 (mns5, 8192); 289 (A1) | **285-330** | |
| c2 pp2048 | 634.04 | **655-695** | R10 read 672.59 at c4 on the raised budget |
| c5 pp2048 | 640.21 | **650-695** | R4's chunked-prefill depression should not recur |
| c2 ttfr | 5657.58 | **5600-7200** | betting AGAINST a fall, per R9/R10 |
| c5 ttfr | 12088.40 | **11500-15000** | ditto |
| σ/med on tg | 1.4% (c2), 0.15% (c5) | **0.5-5%** both | the raised budget inflated σ at c4 (3.25%) and at R9's A1 c5 (9.98%) |
| c2 scheduler `Running`/`Waiting` | — | **2 / 0, 100% of loaded samples** | the round's primary instrument |
| c5 scheduler `Running`/`Waiting` | 4 / 1 at mns 4 | **5 / 0 median**, but not 100% | one step trails |
| MTP acceptance | 3.02-3.07 / 67-69% | **2.9-3.2 / 62-72%** | R8b rides along; R9 and R10 both found it flat under scheduler changes |
| SM clock median | 2392-2398 | **2392-2398** | ninth consecutive session |
| grid time | — | **400-650 s** | R10's c4 was 219.6 s for 7 runs |

### The standings call, made in advance and honestly

**c2 is a coin flip and the round declines to predict its sign.** The 135-170
band straddles 163.27; the centre, 148, is 9% short. Clearing it requires the
stagger to go essentially all the way to 1.00, which is exactly what the
one-step arithmetic permits and nothing has yet demonstrated. Call it 30%.

**c5 is predicted to remain a LOSS**, and not a close one: the centre 125 is
0.55x of 225.46 and even the top of the band is 0.69x. If c5 clears 225.46 the
round's whole model of this metric is wrong and that is worth more than the win.

**A near-miss at c2 is still the campaign's most valuable measurement**, because
it would price precisely how much of the remaining gap is stagger and how much
is raw per-request decode — the two terms the board's LFM2.5-350M incumbent
separates trivially and we do not.

### Discipline for this round, restated because it has bitten twice

- **BOTH ESTIMATORS AT EVERY POINT.** `tg_throughput` and `peak_throughput` side
  by side, and `tg_req_throughput` for the stagger. Never `tg × c` — R10 settled
  that it double-counts.
- **runs=7, not 3.** These are headline numbers with scoreable targets. Two
  3-run medians have already had to be retired this campaign (R1's tg32, R3's
  d65536) and both were too high.
- **These are MUTATIONS.** `recipe.yaml` stays untouched; the fold decision is
  R11's, not this round's. Every RESULTS.md row names its configuration.
- **Read the `Benchmark args:` echo before letting the run proceed.** R5 lost an
  engine start to a silently-defaulted depth.
- ONE invocation, so both concurrencies share an engine start and a thermal
  state. Serial — nothing else touches the box.
- No arena submission. No box system settings touched. No `apt`.

## Round 12 outcome — bench_ac37f5b64487 (2026-08-22)

One invocation, `session_count: 1`, `crash_count: 0`, so c2 and c5 shared one
engine start and one thermal state. Seven runs at each. Same pinned image epoch
(`dgx-vllm-eugr-nightly:2026082102`) as every round since R1. Config:
`-o max_num_seqs=5 -o max_num_batched_tokens=32768`, both **MUTATIONS**.

| cell | tg (board metric) | (mean) | σ | σ/med | peak_thr | tg_req | stagger | residency | runs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| tg128 @ d16384 c2 | **140.77** | (139.09) | 8.84 | 6.28% | **181** | 79.73 | **1.13** | 1.93 of 2 | 136.81 / 141.96 / 142.90 / 137.35 / 140.77 / 122.33 / 151.51 |
| tg128 @ d16384 c5 | **128.93** | (129.67) | 2.34 | 1.81% | **290** | 43.72 | **1.70** | 4.92 of 5 | 131.97 / 131.10 / 132.67 / 128.93 / 126.06 / 128.70 / 128.25 |
| ctx_tg128 @ c2 | 127.09 | (127.70) | 4.01 | 3.16% | 167 | 74.45 | 1.17 | 1.93 of 2 | 127.09 / 126.39 / 130.08 / 127.44 / 124.45 / 123.15 / 135.29 |
| ctx_tg128 @ c5 | 104.75 | (104.28) | 1.16 | 1.11% | 290 | 44.47 | 2.12 | 4.83 of 5 | 104.91 / 104.75 / 103.60 / 103.18 / 105.64 / 105.32 / 102.59 |
| pp2048 @ c2 | 658.93 | — | 2.76 | — | — | — | — | — | — |
| pp2048 @ c5 | 677.44 | — | 0.94 | — | — | — | — | — | — |

`tg` and `peak_thr` are reported side by side at every point, as the round
required. `tg` sits under `peak_thr` at both concurrencies (140.77 < 181,
128.93 < 290), so the two estimators are consistent and nothing here repeats
R7's or R9's break.

### STANDINGS — both cells are still LOSSES, and both are transformed

| cell | was | now | incumbent (board's own Qwen3.6-35B-A3B-NVFP4, vLLM) | was | now |
|---|---:|---:|---:|---:|---:|
| tg128 @ d16384 c2 | 84.00 | **140.77** | 163.27 | 0.51x | **0.86x** |
| tg128 @ d16384 c5 | 48.12 | **128.93** | 225.46 | 0.21x | **0.57x** |

**+67.6% at c2 and +168% at c5, from a scheduler knob.** Neither clears its
target, and neither is recorded as anything but a loss. But the campaign's two
worst cells are now within 14% and 43% of a like-for-like incumbent, where they
were 49% and 79% short this morning.

### THE ROUND'S MOST VALUABLE NUMBER: the remaining gap decomposes, and it is almost all stagger

`tg = c × tg_req / stagger`, so a hypothetical zero-stagger run of the same
engine is just `c × tg_req`. That is a bound the round can compute from its own
export, and it splits the residual gap in two:

| cell | ours | zero-stagger bound | incumbent | stagger's share of the gap | decode's share |
|---|---:|---:|---:|---:|---:|
| c2 | 140.77 | **159.46** (0.98x) | 163.27 | **83%** | 17% |
| c5 | 128.93 | **218.60** (0.97x) | 225.46 | **93%** | 7% |

**Our per-request decode rate is within 3% of what the incumbent's headline
figure requires, at both concurrencies.** The board's Qwen3.6-35B-A3B-NVFP4 on
vLLM is not decoding faster than this box in any meaningful sense. What it is
doing is admitting its batch with almost no stagger, and we are not.

This is precisely the measurement the hypothesis said would be worth more than
a win, and it is the first time the campaign has priced the config gap into two
named terms instead of calling it "config".

### THE DISCRIMINATOR: MIXED, by the round's own pre-declared rule

Declared before the run: H_stagger needs `stagger(c2) < 1.35` **and**
`stagger(c5) > 1.80`; H_uniform needs both within ±0.20 of c4's 1.57.

- `stagger(c2) = 1.13` — **holds**, comfortably, and it is the lowest `c>1`
  stagger the campaign has ever measured.
- `stagger(c5) = 1.70` — **misses**, by 0.10.

**H_uniform is refuted outright** (c2's 1.13 is 0.44 from 1.57, more than double
its tolerance). **H_stagger is not confirmed on its own terms, and is reported
as mixed rather than forced**, which is what the round wrote down.

But the *ordering* H_stagger predicted from the integer arithmetic —
one admission step at c2, two at c4, three at c5 — held exactly:

    stagger:  c2 1.13  <  c4 1.57  <  c5 1.70

**Where the c5 threshold went wrong is instructive, and it is the same error
R10 confessed to.** The 1.80 floor assumed c5's trailing third step costs what a
full step costs. It does not: that step admits **one** prefill, not two, so it is
roughly half a step. The round's own table said "2+2+1" and its threshold priced
it as "2+2+2". **The mechanism section was right and the numeric band was wrong,
in the same document** — R10 wrote that sentence about itself six hours ago and
this round earned it again. The bands keep being set by scaling rather than by
the model sitting one paragraph above.

### peak_throughput DID NOT MOVE AT c2, and that localises the whole effect

| cell | peak_thr at mnbt 8192 | at mnbt 32768 | change | `tg` change |
|---|---:|---:|---:|---:|
| c2 | 182 | **181** | **−0.5%** | **+67.6%** |
| c4 (R10/R9) | 272 | 284 | +4.4% | +179% |
| c5 | 265 (mns 5) | **290** | +9.4% | **+168%** |

**At c2 the sustained hardware ceiling is unchanged to within half a percent
while the board metric rises by two thirds.** The token budget bought nothing
from the GPU; it bought a shorter denominator. R10 argued this at c4 where the
ceiling still moved 4.4%; c2 is the clean version, and it is now the campaign's
sharpest single demonstration that `tg_throughput` is a *scheduling* measurement
with a throughput's units.

It also means c2 has nearly exhausted this lever: at `stagger` 1.13 and a flat
ceiling, there is no more span to recover. c5 has not — see R13 below.

### PROCESS FAILURE — the scheduler log was NOT captured, and R8b failed a second time

The round set out to read `Running: N reqs, Waiting: M reqs` from the engine log
as its primary occupancy instrument, the way R7, R9 and R10 did, and to capture
MTP acceptance alongside (R8b). **Both were lost.** The capture used
`ssh <box> docker logs -f <container>`, which returns only the container's CUDA
entrypoint banner — **vLLM's serve output does not go to the container's stdout
on this image.** 15 lines captured, 0 scheduler samples, 0 SpecDecoding samples.
By the time this was noticed sparkrun had torn the container down and
`/tmp/sparkrun_serve.log` was gone with it, exactly as in R8.

**Nothing was invented in its place.** `Running`/`Waiting` medians and MTP
acceptance are **unmeasured** for this round and no figure is quoted for either.

What survives is the secondary instrument R7 used for corroboration and it is in
the export rather than the log: `peak_throughput / peak_req_throughput` reads
**1.93 of 2** at c2 and **4.92 of 5** at c5 — 96.5% and 98.4% residency. That is
consistent with near-full occupancy at both points and consistent with the
stagger figures, but it is corroboration, not the direct reading.

**The correct capture is `docker exec <container> tail -f
/tmp/sparkrun_serve.log`, not `docker logs`.** Archived as
`engine-capture-FAILED.log` so the next round can see what the wrong command
produces. R8b is now outstanding for a third time and should be verified live —
grep the capture for `Running:` within a minute of the grid starting — before
any round relies on it again.

### ctx_ vs cold: R10's account gets two new points, and its MECHANISM is contradicted by the instrument

The ctx phase is **BELOW cold at both concurrencies** — 127.09 vs 140.77
(−9.7%) at c2 and 104.75 vs 128.93 (−18.7%) at c5. At mnbt 8192 the same cells
read −5.4% and **+6.5%**, so **the c5 sign FLIPS on the token budget alone**,
reproducing exactly what R10 saw at c4 (+4.4% → −14.2%). Three cells now flip or
deepen the same way on the same knob. The *phenomenon* R10 described is real and
this round is its second independent confirmation.

**But R10's stated reason for it does not survive.** R10's account was "the
`ctx_` phase does no prefill, so it never staggers much and has little to gain;
the cold phase carries the stagger." The stagger ratio is measurable in both
phases and says the opposite — **the `ctx_` phase staggers MORE than cold,
consistently, at every raised-budget point in the campaign:**

| cell | cold stagger | ctx stagger |
|---|---:|---:|
| c2 (R12) | 1.13 | **1.17** |
| c4 (R10) | 1.57 | **1.80** |
| c5 (R12) | 1.70 | **2.12** |

And the `ctx_` phase is slower on the *other* term too: `tg_req` 74.45 vs cold's
79.73 at c2. So the cached phase is behind on both factors, which no
"it has no prefill work" story explains. **Open question 4 gets a sharpened
version: why does removing prefill work make the batch stagger worse?** R10 asked
for its account to be attacked rather than adopted; the attack lands on the
mechanism, not on the observation.

### Side-predictions: 11 held, 5 missed, 3 unmeasured

- **c2 `tg` 135-170, centre 148: HELD** at 140.77.
- **c5 `tg` 100-155, centre 125: HELD** at 128.93 — 3% from the centre, and it
  was built by decomposing the metric rather than by scaling R10's percentages.
  Both headline bands held, which has not happened before in this campaign.
- **c2 stagger 1.00-1.20: HELD** at 1.13. **c5 stagger 1.85-2.30: MISSED LOW**
  at 1.70 (see the discriminator).
- **c2 `tg_req` 75-88: HELD** at 79.73. **c5 `tg_req` 46-58: MISSED LOW** at
  43.72 — the same direction as the stagger miss, and the two are not
  independent.
- **c2 `peak_throughput` 190-225: MISSED LOW** at 181, and the miss is the
  round's best result — see above. **c5 285-330: HELD** at 290.
- **pp2048 both bands HELD**: 658.93 at c2 (655-695) and 677.44 at c5 (650-695).
  R4's chunked-prefill depression at c5 (581.44) does not recur — it reads 677.44,
  the highest cold prefill figure at this depth in the campaign, and above the
  flat 623-643 mnbt-8192 series exactly as R9's and R10's raised-budget arms were.
  **Session control passes**, which is what licenses reading the tg figures at all.
- **ttfr both bands HELD, in the counter-intuitive direction again**: 6069.14 at
  c2 (5600-7200, +7.3% on 5657.56) and 14484.92 at c5 (11500-15000, +19.8% on
  12088.40). **Raising the budget makes time-to-first-response WORSE at every
  concurrency the campaign has tried it at** — c4 +15.6%, c16 +32.4%, now c2 and
  c5. Any row from this configuration should say so.
- **σ/med 0.5-5%: c5 HELD** at 1.81%, **c2 MISSED HIGH** at 6.28% — the noisiest
  `c>1` cell the campaign has measured, with runs spanning 122.33 to 151.51 and
  the familiar mode-plus-one-low-draw shape. **runs=7 earned its keep here.**
- **Scheduler `Running`/`Waiting` at both cells, and MTP acceptance:
  NOT MEASURED.** See the process failure.
- **Telemetry: HELD.** 585 samples, SM clock **2398 MHz** median (2314-2411),
  76 °C peak, 97.29 W peak — the **ninth consecutive session** agreeing with R4's
  2392. Open question 5 stays closed. No clock, power-policy, driver or kernel
  setting was touched, and no `apt` was run.
- **Grid time 400-650 s: MISSED LOW** at **359 s** (c2 123 s, c5 236 s). One
  engine start, ~9 minutes wall, ~65k harness tokens.

### The standings call was made in advance and it was right

The hypothesis put c2 at 30% to clear 163.27 and predicted c5 would remain a
clear loss. c2 came in 13.8% short and c5 43% short. **No verdict was written
after the fact and no band was widened to fit.**

### Mutations NOT folded into recipe.yaml

`recipe.yaml` is untouched. Every R12 row in RESULTS.md names its configuration.
The fold decision remains **R11's** — re-measure the c1 anchor at mnbt 32768 —
and R12 strengthens the case for running it, because the raised budget has now
moved four cells (c2, c4, c5, c16) and the campaign is carrying four headline
figures it cannot fold.

### The round's value, in one line

**It took the campaign's two worst cells from 0.51x and 0.21x to 0.86x and
0.57x on a scheduler knob, showed at c2 that the knob moves the board metric by
two thirds while moving the hardware ceiling by nothing, priced the entire
remaining gap as 83-93% admission stagger against a per-request decode rate
within 3% of the incumbent's — and lost its primary occupancy instrument to the
wrong `docker` subcommand.**
