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
