# Journal — qwen36-35b-nvfp4-cells

Hypotheses before runs, lessons after them, a synthesis every ~5 rounds.
The last synthesis is the handoff every new session starts from.

> ⚠️ **READ BEFORE ANY ROUND ENTRY BELOW: the `ctx_` PHASE LABELS ARE BACKWARDS
> IN ROUNDS 1 THROUGH 12.** Every round before R9b calls the `ctx_` rows "the
> prefix-caching phase" or "the cached phase". They are llama-benchy **Phase 1,
> the CONTEXT LOAD — the UNCACHED pass**, and the rows those rounds call "cold"
> are the cache-eligible ones. The two are also charged different prompt-token
> counts, so **no `ctx_pp`-versus-`pp` comparison in this journal is valid.**
> The findings are in **THE `ctx_` PHASE-LABEL CORRECTION** at the end of this
> file. Do not re-derive a reading from a round entry without it.

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

> ⚠ **CORRECTED.** "prefix-caching phases", "cached-prefix decode" and "with the
> prefill work removed" are all wrong: these are Phase 1, the UNCACHED context
> load, and it prefills `depth` tokens — 89% of what the phase below it does.
> The quietness is an unexplained observation; the explanation is withdrawn. See
> the phase-label correction at the end of this file.

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

> ⚠ **CORRECTED.** Read "Phase 1 (context load)" for "prefix-caching phase" and
> "Phase 2" for "cold". The `tg` comparison itself stands. See the phase-label
> correction at the end of this file.

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

> ⚠ **CORRECTED, TWICE OVER.** The phase labels are inverted (this is Phase 1,
> the uncached context load, against Phase 2). And this round's closing claim —
> that the `ctx_` cells are "the cheapest place in this campaign to measure a
> real effect" — is **WITHDRAWN**: it rests on a quietness whose explanation is
> void and on a prefill advantage that is entirely a denominator. The `-17%`
> inversion itself was separately refuted by R8 (`-1.2%` at runs=7).

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
5086.51).

> ⚠ **CORRECTED.** "The cached counterpart" is Phase 1, the context load, and it
> is charged `depth` tokens against the `pp2048` row's fixed 2048 — so the two
> series are not comparable and the `ctx_pp` series is not "nearly flat" for any
> physical reason. It is, however, the campaign's only HONEST prefill-rate curve:
> Phase 1 is charged the tokens it actually processes, so 6148.56 / 5910.22 /
> 5086.51 / 4004.76 / 2803.17 is the real prefill rate against depth, and the
> `pp2048` series is the same physics divided by a fixed 2048. Both prefill figures are held, not claimed — their board figures have
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

> ⚠ **CORRECTED.** Phase labels inverted throughout this passage; the `tg`
> comparisons and their signs stand. See the phase-label correction at the end.

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
variance is larger than ever.

> ⚠ **CORRECTED — and R5 was righter than it knew.** The tidy explanation is not
> merely broken by this data point; its premise is false. The `ctx_` phase is
> Phase 1, the uncached context load, and it prefills `depth` tokens. **No
> prefill is removed in either phase, here or anywhere.** R5 reached the right
> verdict ("cannot be right") from the wrong evidence. Open question 4 should now be read as being about
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

> ⚠ **CORRECTED.** "the cached phase" is Phase 1, the uncached context load. The
> sign-flip-with-generation-length result itself is a `tg` comparison and is
> untouched — it remains the cleanest unconfounded evidence in this question,
> even though the question's framing is now withdrawn.

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
  > ⚠ **CORRECTED.** Phase labels inverted. The monotone-with-concurrency trend
  > was separately killed by R10 (the sign flips on the token budget alone), and
  > the "quietness rule" is retired with its explanation withdrawn.
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

> ⚠ **CORRECTED.** Read "Phase 1 vs Phase 2" for "ctx vs cold" throughout. The
> measurement and its verdict — R3's deep inversion did not reproduce — are
> untouched.

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

> ⚠ **WITHDRAWN AT THE PREMISE.** The paragraph below is R10's mechanism for the
> sign flip and it is **false, not merely contradicted**. "The `ctx_` phase does
> no prefill" is wrong: `ctx_` is Phase 1, the context load, and it prefills
> `depth` tokens — 89% of what Phase 2 does. R12 attacked this account with the
> stagger instrument and R13 broke the regularity underneath it at a third
> budget; the premise means there was never a mechanism here to attack. The
> OBSERVATION — the sign flips on the token budget alone — survives all of it.

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

> ⚠ **THE SHARPENED QUESTION IS DISSOLVED, NOT ANSWERED.** R12 was right that
> R10's mechanism fails, and right to say so from the instrument. But its
> replacement question inherits R10's false premise: **no prefill work is
> removed in either phase.** `ctx_` is Phase 1, the context load, which prefills
> `depth` tokens against Phase 2's `depth + 2048`. There is nothing to explain.
> R13 then refuted the stagger asymmetry itself at `mnbt 98304` (Phase 1
> staggers LESS at both arms). Both halves are gone: the regularity empirically,
> the question at its premise. **Do not pose a third form of it.** The three
> stagger figures in the table above stand as measurements.

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

## Round 9b hypothesis — the chunked-prefill mechanism test, bought at the price of prefix caching: tg128 @ d16384, c4 and c5, TWO arms, runs=3, one engine start each

Earned by R9, and it is the **only remaining route** to the mechanism R4
inferred four rounds ago. R9 tried the obvious two-arm version and the engine
refused to start: `--no-enable-chunked-prefill` parses, the warning fires, and
then a validator kills it with **`Chunked prefill is required for mamba cache
mode 'align'`**. R9 recorded that as "untestable by the obvious route". This
round buys the way around it explicitly, and states the bill up front.

### The bill, read from the source before spending an engine start

R9's open question 11 asked for the validators to be read rather than guessed
at, after R9 spent a start learning one the expensive way. Done, from
`vllm/model_executor/models/config.py:600-638` and
`vllm/config/scheduler.py:248-261` in the pinned image:

    if cache_config.enable_prefix_caching:
        if mamba_cache_mode == "none": mamba_cache_mode = "align"
        if mamba_cache_mode == "align":
            assert scheduler_config.enable_chunked_prefill, (
                "Chunked prefill is required for mamba cache mode 'align'.")
        if mamba_block_size is None: mamba_block_size = cache_config.block_size
    else:
        mamba_cache_mode = "none"
        if mamba_block_size is None: mamba_block_size = model_config.max_model_len

    # verify_max_model_len
    if max_num_batched_tokens < max_model_len and not enable_chunked_prefill:
        raise ValueError(...)

So turning prefix caching OFF drops `mamba_cache_mode` to `none` and the
assertion is never reached — both arms will start. And `mnbt 32768` is exactly
`max_model_len 32768`, so the second validator passes at the boundary. **Both
arms are cleared by reading, not by trying.** That is the whole of what R9's
open question 11 asked for.

**But the source also names a THIRD thing this change moves, which R9 did not
know about.** With prefix caching on, `mamba_block_size = block_size` = 16.
With it off, `mamba_block_size = max_model_len` = **32768**. Turning prefix
caching off therefore changes the Gated DeltaNet state granularity for 30 of
this model's 40 layers by a factor of **2048**. That is not a footnote — it is
a bigger change to the layer stack than the flag under test.

**It is survivable for exactly one reason: it is COMMON TO BOTH ARMS.** Both
run at `mamba_cache_mode: none`, `mamba_block_size: 32768`, prefix caching off,
mnbt 32768, `max_num_seqs 4`. The single difference between them is
`--enable-chunked-prefill` vs `--no-enable-chunked-prefill`. So the
**difference of deficits** is clean even though neither arm's absolute figures
are comparable to anything the campaign has measured.

### What is forfeit, said plainly

**The `ctx_` rows are forfeit in both arms.** No prefix caching means no
cached-prefix phase, so `ctx_tg128` and `ctx_pp2048` here measure a second cold
pass and are not standings rows. They are not, however, waste — see the
validity gate below, where they become this round's proof that the flag took
effect.

**And nothing here transfers to the campaign config.** The campaign runs with
prefix caching ON. Whatever this round finds is a statement about the
**no-prefix-caching regime only**. R8 already demolished one cross-condition
inference this campaign made (R3's depth flatness, built from 3-run points
across separate invocations); the same reading applied here would be the same
error in a new place. The outcome section must repeat this, and the RESULTS
rows must name the configuration.

### The mechanism under test, stated as R4 stated it

R4 observed that at c5 with `max_num_seqs 4` the fifth request cannot get a
slot, and that `pp2048` fell to **581.44** against a flat 634-643 at c1/c2/c4 —
the only depressed prefill row at this depth in the campaign. R4 *inferred* the
cause: the queued request's prefill is **chunked into ongoing decode steps**, so
prefill work and decode work interleave and both are charged for it. Raising
`max_num_seqs` to 5 restored `pp2048` to 640.21, which is consistent but does
not isolate chunking — it removes the queueing instead.

R9 confirmed the deficit is real and not an engine-start artefact (**D0 =
−14.4%** inside one invocation, against R4's −13.7% across two) and reproduced
the depressed prefill row to 0.25% (579.98 vs 581.44). What R9 could not do is
turn the chunking off. This round does.

### The three deficits, and which one is the instrument

Every quantity here is a `c5`-versus-`c4` deficit **within one arm**, so the
engine start, thermal state and config are held fixed:

    D_x = (x(c5) − x(c4)) / x(c4)

R9's two measured arms, both with prefix caching ON, for reference:

| arm | c4 tg | c5 tg | **D_tg** | c4 tg_req | c5 tg_req | **D_req** | c4 pp2048 | c5 pp2048 | **D_pp** |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A0 (mnbt 8192) | 52.64 | 45.05 | **−14.4%** | 33.47 | 21.41 | **−36.0%** | 640.70 | 579.98 | **−9.5%** |
| A1 (mnbt 32768) | 143.08 | 81.73 | **−42.9%** | 57.89 | 39.06 | **−32.5%** | 669.28 | 596.78 | **−10.8%** |

**`D_pp` is the instrument, and the choice is made before the run.** Three
reasons, and they are the round's most important design decision:

1. **It is the quantity R4 actually observed.** R4's evidence was a depressed
   prefill row. Everything else in R4's story is inference from it.
2. **It is the only one that is stable across the budget change.** −9.5% and
   −10.8% across a config that moved `tg` by 2.7x. `D_tg` moved from −14.4% to
   −42.9% on the same change, so `D_tg` is measuring the scheduler's admission
   span (R10's result: `tg_throughput` is a batch aggregate divided by
   `max_last_token − min_first_token`), not the interference.
3. **It is quiet.** `pp_throughput` σ runs under 1% of its median across the
   campaign; R9's A1 `c5 tg` σ was 9.98% on three runs. With runs=3 the tg
   figures cannot resolve a 10% effect and the pp figures resolve a 2% one.

`D_req` is the secondary reading: it is per-request decode rate, so it is not
charged for admission stagger, and R4's interference should show in it. It sat
at −36.0% and −32.5% — notably stable too. `D_tg` is recorded because the board
metric is `tg` and every c>1 row must carry it, but **this round does not lean
on `D_tg` and says so in advance.**

### The discriminator, declared before the run

Let `R_x = D_x(arm B, chunk OFF) / D_x(arm A, chunk ON)`. Thresholds carried
over from R9, which pre-declared 0.25/0.60 and never got to apply them:

- **H_chunk CONFIRMED** — R4's mechanism is the cause — if **`R_pp < 0.25`**
  (the prefill depression largely vanishes when chunking cannot happen)
  **AND `R_req < 0.60`**.
- **H_chunk REFUTED** if **`R_pp > 0.60`**: the c5 prefill depression survives
  in an engine that is physically incapable of chunking a prefill into a decode
  step, so chunking is not what causes it. The rival account is then plain
  **queueing** — a fifth request waiting for a slot depresses the measured
  prefill rate however its prefill is scheduled — which is what R9 observed
  directly at the scheduler (`Running: 4, Waiting: 1` at c5, `Waiting: 0` at c4).
- **Anything else is MIXED and is reported as mixed, not forced.** R12 had a
  mixed discriminator and reported it as one; this round will do the same.

**A refutation is the more useful outcome here and the round expects it.**
R7 already found that matching `max_num_seqs` to the probe at c8 and c16 left
`pp2048` at 631.25 and 628.74 — dead inside the flat series — which R7 read as
"matching the scheduler width eliminated R4's interference, at 4x the batch
size, so the interference is a QUEUEING effect and not a batch-size effect".
That sentence already prefers queueing over chunking. This round tests it.

### THE VALIDITY GATE, and it must pass before any number is read

With prefix caching genuinely off there is no cache for the `ctx_` phase to hit,
so **`ctx_pp2048` must collapse** from the 5100-6200 the campaign reads with
caching on to roughly the cold value, and **`ctx_tg128` must land near cold**.

- **Gate: `ctx_pp2048` < 1200 in BOTH arms.** If it still reads thousands,
  prefix caching is not actually off, `mamba_cache_mode` is not `none`, and the
  arms are not what they claim to be — in which case the round is **VOID** and
  is archived as such with no verdict.
- Cross-check: the engine log's non-default args must show
  `'enable_prefix_caching': False` and the warning
  `Mamba cache mode is set to 'none' when prefix caching is disabled`.

This is a free instrument the queue entry did not anticipate: the forfeited
`ctx_` rows are the proof that the price was actually paid.

### Numeric predictions

Arm A is a control for arm B, but it is also the campaign's first look at
`mamba_cache_mode: none`, so it carries its own prediction. `align` mode
checkpoints SSM state at 16-token block granularity; `none` mode checkpoints at
32768. **Fewer state writes should make arm A FASTER than R9's A1**, which is
the same config plus caching.

| quantity | baseline (R9 A1, caching ON) | predicted | reasoning |
|---|---:|---|---|
| A: c4 `tg` | 143.08 | **140-175** | A1 plus whatever `mamba_cache_mode: none` is worth |
| A: c5 `tg` | 81.73 | **75-110** | A1's σ here was 9.98%, band widened accordingly |
| A: c4 `pp2048` | 669.28 | **660-760** | flat series is 623-643 at mnbt 8192; raised-budget arms read 669-677 |
| A: c5 `pp2048` | 596.78 | **590-690** | depressed if the mechanism is present in this regime at all |
| **A: `D_pp`** | −10.8% | **−7% to −14%** | the deficit must REPRODUCE in arm A or the round has nothing to divide by |
| **A: `D_req`** | −32.5% | **−25% to −40%** | |
| B: c4 `tg` | — | **125-170** | no chunking cannot help a single-shape c4 batch much |
| **B: `D_pp`** | — | **see discriminator** | the whole round |
| B: c4/c5 `ttfr` | 11799 / 11872 | **higher than arm A at c5** | an unchunked prefill blocks decode for a whole step |
| `ctx_pp2048`, both arms | 5405-6175 (caching on) | **< 1200** | **THE VALIDITY GATE** |
| `ctx_tg128` ≈ cold, both arms | — | **within ±10% of cold** | no cache to hit |
| scheduler `Running`/`Waiting` at c5 | 4 / 1 | **4 / 1 in both arms** | R9 observed this directly; mns 4 is unchanged |
| scheduler at c4 | 4 / 0 | **4 / 0 in both arms** | mnbt 32768 gave a clean `(4,0)` in R9's A1 and R10 |
| MTP acceptance | 2.95-3.02 / 65-67% | **2.8-3.2 / 60-72%** | R8b, THIRD attempt — flat under every scheduler change so far |
| SM clock median | 2392-2398 | **2392-2398** | tenth consecutive session |
| grid time | — | **400-650 s** total | R9's two measured arms cost 442.5 s across three starts |

### R8b rides along for the THIRD time, and the command is now known

R8 lost the engine log by waiting until the container was gone. R12 tailed it
from the start with `docker logs -f` and got 15 lines of CUDA entrypoint banner,
because **vLLM's serve output does not reach container stdout on this image**.
The correct capture is:

    ssh <box> docker exec <container> tail -f /tmp/sparkrun_serve.log

**and it will be verified live** — `grep -c 'Running:'` on the capture within a
minute of the grid starting. If the capture is empty the round proceeds anyway
(the tg and pp figures do not depend on it) but says so, rather than quoting a
number it does not have. Two rounds have already shipped without this
instrument and neither invented one.

### Discipline for this round

- **BOTH ESTIMATORS AT EVERY c>1 POINT.** `tg_throughput` and
  `peak_throughput` side by side, plus `tg_req_throughput` for the stagger.
  Never `tg × c` — R10 settled that it double-counts and R9 watched it break.
- **Medians, not means. σ and the individual runs reported at every cell.**
- **BOTH ARMS ARE MUTATIONS, and they are further from the campaign config than
  any mutation so far** — three flags move, not one. `recipe.yaml` stays
  untouched. Every R9b row in RESULTS.md names its configuration explicitly and
  must not be allowed to look like a campaign-config row.
- **Read the `Benchmark args:` echo before letting each run proceed.** R5 lost
  an engine start to a silently-defaulted depth.
- Two invocations, one per arm, because the flag lives in the recipe template
  and not in `-o`. Serial — nothing else touches the box.
- No arena submission — Mat has no Spark Arena login. No box system settings
  touched. No `apt`.

## Round 9b outcome — bench_9379c15468ec-a-chunk + bench_10496035f7fd-b-nochunk (2026-08-22)

Two invocations, one arm each, both `session_count: 1`, `crash_count: 0`. Three
runs at c4 and c5 in each. Same pinned image epoch as every round since R1.
Both arms: `--no-enable-prefix-caching`, `-o max_num_batched_tokens=32768`,
`max_num_seqs 4` (recipe default). Arm A `--enable-chunked-prefill`, arm B
`--no-enable-chunked-prefill`. **Both arms are MUTATIONS and neither is the
campaign config** — three flags away from it, not one.

**ARM B STARTED.** R9's blocker is cleared exactly as the source said it would
be: `enable_prefix_caching: False` drops `mamba_cache_mode` to `none`, the
`align` assertion is never reached, and the engine came up with
`enable_chunked_prefill: False` in its non-default args. The predicted
"does not officially support disabling chunked prefill" warning fired and
nothing killed the engine after it. **R9's untestable round is now tested.**

| arm | cell | tg | σ | σ/med | peak_thr | tg_req | stagger | residency | runs |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| **A** chunk ON | c4 | **62.13** | 0.70 | 1.13% | 297 | 51.49 | 3.32 | 4.10 of 4 | 60.88 / 62.13 / 62.53 |
| **A** chunk ON | c5 | **50.28** | 0.81 | 1.62% | 298 | 25.46 | 2.53 | 3.77 of 5 | 50.23 / 50.28 / 51.98 |
| **B** chunk OFF | c4 | **52.92** | 0.83 | 1.57% | 285 | 28.74 | 2.17 | 4.01 of 4 | 53.58 / 51.58 / 52.92 |
| **B** chunk OFF | c5 | **45.28** | 0.36 | 0.79% | 276 | 19.92 | 2.20 | 3.94 of 5 | 44.85 / 45.73 / 45.28 |

`pp2048`: A 663.93 (c4) / 597.78 (c5); B 655.82 / 584.04. `ttfr`: A 11560 /
12310; B 9575 / 11115. Both estimators are reported at every point and `tg` sits
under `peak_thr` everywhere, so nothing here repeats R7's or R9's break.

### THE DISCRIMINATOR: H_chunk is REFUTED, on the round's own pre-declared rule

`R_x = D_x(arm B) / D_x(arm A)`; confirm below 0.25, refute above 0.60.

| deficit | arm A (chunk ON) | arm B (chunk OFF) | **R** | verdict |
|---|---:|---:|---:|---|
| **`D_pp` (primary)** | **−9.96%** | **−10.95%** | **1.099** | **REFUTED** |
| `D_req` (secondary) | −50.55% | −30.67% | **0.607** | refuting side |
| `D_tg` (not leaned on) | −19.07% | −14.43% | 0.757 | refuting side |

**The primary instrument does not merely fail to clear the bar — it points the
wrong way.** The c5-versus-c4 prefill deficit is *slightly larger* in the arm
that is physically incapable of chunking a prefill into a decode step. All three
quantities land on the refuting side, and the primary one is unambiguous.

**R4's chunked-prefill mechanism does not survive this test**, and the rival
account R7 already preferred does: the deficit is **plain queueing**. A fifth
request against `max_num_seqs 4` waits for a slot, and it depresses the measured
prefill rate however its prefill is scheduled.

### THE DEFICIT IS AN INVARIANT, and that is the strongest thing here

`D_pp` across every configuration the campaign has measured it in:

| round | prefix caching | mnbt | chunked prefill | `D_pp` |
|---|---|---:|---|---:|
| R9 A0 | ON | 8192 | ON | −9.5% |
| R9 A1 | ON | 32768 | ON | −10.8% |
| **R9b A** | **OFF** | 32768 | ON | **−9.96%** |
| **R9b B** | **OFF** | 32768 | **OFF** | **−10.95%** |

**Four configurations spanning the token budget, prefix caching, the mamba cache
mode and chunked prefill itself, and the deficit sits in a 1.5-point band.** It
is not a property of any of those flags. It is a property of `c > max_num_seqs`,
which is the one thing all four arms share. R4 found a real effect and attached
it to the wrong cause; R9b removes the cause and the effect stays put.

### SECOND HEADLINE — chunked prefill PROTECTS decode, it does not interfere with it

R4's framing was that chunked prefill steals decode budget. Measured directly,
the sign is the other way round. Arm B against arm A, same engine minus the flag:

| quantity | c4 | c5 |
|---|---:|---:|
| `tg` | **−14.8%** | **−9.9%** |
| `tg_req` | **−44.2%** | **−21.7%** |
| stagger | 3.32 → **2.17** (better) | 2.53 → **2.20** (better) |
| `ttfr` | **−17.2%** (better) | **−9.7%** (better) |

**Turning chunked prefill off halves the per-request decode rate at c4 while
improving admission stagger and time-to-first-response.** That is exactly what
an unchunked prefill does: it occupies a whole scheduler step and no request
decodes during it, so first tokens arrive sooner and in tighter formation but
every request's decode is repeatedly frozen. The scheduler log says the same
thing without arithmetic — arm B's c4 sits at `(2,2)` in three of eight loaded
samples and never holds a stable `(4,0)`, where arm A's c4 alternates `(4,0)`
and `(3,1)`.

So R4's *observation* that chunked prefill interleaves prefill into decode steps
is confirmed — it shows up cleanly in `ttfr`, which is 17% worse at c4 with
chunking on. What is refuted is that this interleaving is what depresses the c5
prefill row. It is not, and the flag is a net win on `tg` at both concurrencies.

### THE VALIDITY GATE FAILED AS WRITTEN, and it is being overridden — with documents, not with reasoning

The hypothesis declared: `ctx_pp2048 < 1200` in both arms or the round is VOID.
Measured: **6106.93 / 5379.73 (arm A)** and **6008.87 / 5262.09 (arm B)** —
indistinguishable from the caching-ON figures. **By the letter of the rule this
round is void.** Overriding a pre-declared void condition after seeing the data
is exactly the move this campaign distrusts, so the override rests on documents
only:

1. **The engine's own non-default args, both arms: `'enable_prefix_caching':
   False`.** Primary, and it is not an inference.
2. **vLLM's own counter: `Prefix cache hit rate: 0.0%`** in all 22 samples of
   each arm.
3. **llama-benchy's source explains why the gate's premise was wrong** — see
   below. The gate tested a belief about the metric, not a fact about the arm.

**The gate was a bad instrument and the round says so rather than quietly
dropping it.** The good instrument was sitting in the engine log the whole time
and costs nothing: read `Prefix cache hit rate`.

### THE ROUND'S MOST VALUABLE FINDING COST NO BOX TIME, and it inverts twelve rounds of labels

Chasing the failed gate into `llama_benchy/runner.py:127-176` and `223-225`
(pinned 0.4.0) turned up this, and every `ctx_` row in RESULTS.md depends on it:

    if self.config.enable_prefix_caching and depth > 0:
        # Phase 1: Context Load      -> is_context_phase=True,  expected_ctx (16384)
        # Phase 2: Inference         -> is_context_phase=False, expected_pp  (2048)

**The `ctx_` rows are the CONTEXT-LOAD pass — the uncached one that *establishes*
the cache. The rows this campaign has been calling "cold" are the SECOND pass,
the cache-eligible one.** The campaign has had the two phases backwards since R1.

And the two phases are **charged different token counts** — 16384 against 2048 —
so their `pp_throughput` figures were never comparable to each other. The ~9x
`ctx_pp` advantage the campaign has read at every depth for twelve rounds is
`16384/2048`, not a cache effect. **Open question 4 has been comparing a
16384-token denominator against a 2048-token one and calling the ratio an
inversion.** Every ctx-versus-cold `pp` reading in this journal needs re-reading
in that light; the `tg` readings are unaffected by the token count but are still
mislabelled as to which phase is cached.

### THE THIRD FINDING, and it is the one that should worry the campaign

**Prefix caching has never hit on this benchmark.** `Prefix cache hit rate: 0.0%`
in all 22 samples of R9's A1 and all 92 samples of R10 — with the flag **ON**.
Independently: total prompt tokens processed by the engine, summed from vLLM's
own `Avg prompt throughput` windows, is **1,079,370 with caching on (R9 A1)
against 1,060,925 with caching off (R9b A)** — a 1.7% difference. **No prefill
work was ever saved.**

And yet the flag is worth a great deal. Arm A against R9's A1 — same budget,
same scheduler width, the flag being the only intended difference:

| quantity | R9 A1 (caching ON) | R9b A (caching OFF) | change |
|---|---:|---:|---:|
| `tg` c4 | 143.08 | **62.13** | **−56.6%** |
| `tg` c5 | 81.73 | **50.28** | **−38.5%** |
| `tg_req` c4 | 57.89 | 51.49 | −11.0% |
| stagger c4 | 1.62 | **3.32** | **+105%** |
| `peak_throughput` c4 | 297 | **297** | **0.0%** |
| `pp2048` c4 | 669.28 | 663.93 | −0.8% |

**The hardware ceiling is identical to the token and the prefill rate is within
0.8%, while the board metric falls by 57%.** This is R12's c2 result again in a
new place: the flag bought nothing from the GPU, it bought a shorter denominator.
The entire effect is the batch span.

**The mechanism is NOT explained and this round does not invent one.** With zero
cache hits and identical prefill work, why the four requests' decode windows
overlap under `mamba_cache_mode: align` and serialize under `none` is unknown.
What the source does say is that the flag never moves alone: prefix caching off
also sets `mamba_block_size` from 16 to **32768**, changing the Gated DeltaNet
state granularity for 30 of this model's 40 layers by a factor of 2048. That is
the leading suspect and it is a bigger change than the flag under test. Queued
as **R9c**.

**Planning consequence, and it is immediate:** R11 and R13 both run with prefix
caching ON, and both are fine — but nobody should describe the campaign's c>1
gains as "prefix caching working". It is not working. Something that rides
along with it is.

### Side-predictions: 8 held, 6 missed, 1 gate broken

- **`D_pp` arm A −7% to −14%: HELD** at −9.96%. The deficit reproduced in arm A,
  which is what gave the discriminator something to divide by.
- **`pp2048` arm A, both bands HELD**: 663.93 (660-760) and 597.78 (590-690).
- **`D_req` arm A −25% to −40%: MISSED LOW** at −50.55%.
- **`tg` arm A c4 140-175: MISSED CATASTROPHICALLY LOW** at 62.13, and c5
  75-110 **MISSED LOW** at 50.28. Both bands were built on the assumption that
  prefix caching is worth little because the campaign had never seen it hit.
  It had never seen it hit because nobody read the hit-rate counter. **The
  prediction was wrong for the same reason the validity gate was wrong**, and
  the round's best finding is the correction.
- **`tg` arm B c4 125-170: MISSED LOW** at 52.92, same cause.
- **arm B `ttfr` higher than arm A at c5: MISSED, and the sign is backwards** —
  11115 against 12310, i.e. **9.7% BETTER**. The reasoning ("an unchunked
  prefill blocks decode for a whole step") was right about the mechanism and
  wrong about which metric it helps. Unchunked prefill delivers first tokens
  sooner and decodes slower afterwards.
- **scheduler `(4,1)` at c5: HELD in arm A** (four `(4,1)` samples, reproducing
  R9's direct observation). **`(4,0)` at c4: MISSED in both arms** — arm A
  alternates `(4,0)`/`(3,1)`, arm B sits at `(2,2)` in three of eight loaded
  samples. R9's and R10's clean `(4,0)` at c4 needed prefix caching on.
- **MTP acceptance 2.8-3.2 / 60-72%: HELD**, and flat across all three arms:
  **3.01 / 66.9%** (R9 A1), **3.05 / 68.5%** (R9b A), **3.01 / 66.9%** (R9b B).
  Acceptance moves for neither prefix caching nor chunked prefill. **Fourth
  consecutive round to rule acceptance out of a scheduling result.**
- **R8b SUCCEEDED AT THE THIRD ATTEMPT.** `docker exec <container> tail -f
  /tmp/sparkrun_serve.log`, verified live with `grep -c 'Running:'` while the
  grid ran, exactly as the queue entry specified. 22 scheduler samples and 16-17
  heavy-load SpecDecoding samples per arm, archived as `engine-serve.log` in
  both dirs. **The command in R12's post-mortem is correct and is now proven.**
- **Telemetry: HELD.** 1200 + 339 samples, SM clock **2398 MHz** median in both
  arms (2340-2411 / 2346-2411), 76 °C peak both, 97.11 W / 96.65 W peak — the
  **tenth and eleventh consecutive sessions** agreeing with R4's 2392. Open
  question 5 stays closed. No clock, power-policy, driver or kernel setting was
  touched, and no `apt` was run.
- **Grid time 400-650 s: HELD** at **440.4 s** (A: 113.2 + 106.6; B: 112.8 +
  107.8). Two engine starts, ~26 min wall, ~85k harness tokens.

### STANDINGS: nothing is claimed, and that was known before the run

No R9b row is a standings row. Both arms are three flags from the campaign
config, the `ctx_` rows are the context-load pass rather than a cached phase,
and c4/c5 figures from an engine with prefix caching off are not comparable to a
board populated by engines that presumably have it on. The rows go into
RESULTS.md as **diagnostic, explicitly not scoreable**, and the campaign's
claimed cells are untouched.

**And the reading does not transfer.** Everything above is a statement about the
**no-prefix-caching regime**. The campaign config runs with prefix caching ON,
and this round has just shown that flag is worth 57% of `tg` at c4 — so the two
regimes are further apart than any pair the campaign has compared. Reading
"chunked prefill is a net win" or "the deficit is queueing" straight into the
campaign config would be precisely the cross-condition inference R8 demolished.
What DOES transfer is the four-configuration invariance of `D_pp`, because two of
those four points were measured with caching on.

### The round's value, in one line

**It ran the arm R9 could not start, refuted R4's four-round-old chunked-prefill
mechanism on a pre-declared primary instrument that pointed the wrong way,
showed the c5 deficit is invariant across four configurations and therefore
belongs to queueing, found that chunked prefill protects decode rather than
interfering with it — and, chasing a validity gate that failed, discovered that
prefix caching has never once hit on this benchmark and that the campaign has had
its two measurement phases labelled backwards since Round 1.**

## CAMPAIGN SYNTHESIS — the whole campaign, R1 through R13d, R11 (which folded the recipe), R13b (which closed the mechanism), R8c (which corrected a standings margin UPWARD), R21 (the three-run audit) and R22 (which ran last, closed the final scoreable cell, and found a POSITION BIAS in the campaign's arm-to-arm comparisons)

**Written after R12 on 2026-08-22 and REVISED eight times the same day: after
R13 / the `ctx_` phase-label correction / R5c / R13c; again after **R13d**;
again after **R11**, the only round that ever changed
`recipe.yaml`, to carry the config-epoch consequences of that change into the
handoff itself — the cross-condition rule below the epoch warning, the
`c1`-vs-`c>1` asymmetry of the budget lever, and the removal of the pre-fold
"not folded" language this section carried; a fifth time, post-**R9c**, to fold
its prefix-caching decomposition into every place it reaches; a sixth time,
post-**R13b**, whose deltas are listed in the boxed note below the thesis
paragraph; a seventh time, post-**R8c**, which retired the campaign's last deep
inversion and **broke this section's own four-for-four sampling warning**; and
an eighth time, post-**R21**, the
three-run audit, which re-measured four more unaudited rows and **moved all four
UPWARD**, making five consecutive upward corrections and settling what the
sampling warning should say; and a ninth and current time — **CURRENT AS OF
2026-08-22, post-R22**, which closed the campaign's last scoreable cell and
found the **position bias** described in the boxed note immediately below. All
boxed notes are directly below. R9c's
fifth-revision deltas were:**

> ### ⚠️⚠️⚠️ TENTH REVISION — CURRENT AS OF 2026-08-22, post-R23. READ THIS BEFORE THE R22 BOX BELOW, WHICH IT OVERTURNS.
>
> **R23 RAN THE A-B-B-A ROUND R22 ASKED FOR, AND THE POSITION BIAS IS REFUTED.**
> Four arms at `tg128 @ d16384 c1`, runs=7, budgets **8192 / 65536 / 65536 /
> 8192** in one sitting of five engine starts. The design makes position and
> configuration orthogonal: A and B each occupy mean position 2.5, so the
> configuration effect is drift-free, and the two same-config pairs measure
> position directly.
> **Position, measured four ways: `arm4 − arm1` = −4.40% (Phase 2) and +0.71%
> (Phase 1); `arm3 − arm2` = −0.91% (Phase 2) and +2.84% (Phase 1). Two up, two
> down, mean −0.44%, p = 1.0.** Pre-declared bands were ≥ +6.0% confirms,
> ≤ +2.0% refutes, with a stated dead zone between; three of four refute and one
> lands in the dead zone. ⚠ **The pattern does not reproduce even in the form
> that produced it** — the six adjacent different-config pairs in this session
> split **3 up / 3 down, mean −0.56%**, and the session's first adjacent pair is
> a **−5.02%** counterexample. **Thermal and clock explanations were measured,
> not assumed:** the box warmed 39 → 53 °C idle and 61 → 63 °C loaded across the
> session while under-load SM clock medians read **2398 / 2392 / 2398 / 2392 /
> 2392 MHz** — 0.25% of spread, uncorrelated with throughput, same 2314–2320 MHz
> floor everywhere, nothing throttled.
> **What this changes in the box below and everywhere else in this document:**
> R22's "+6.5%, 4 of 4" is **retired as a directional effect** and is best read
> as four draws from a cell whose σ/med runs 8–14%. **R13c's six-point budget
> curve is restored** to a noise-limited reading. **The "check which arm ran
> first" instruction is withdrawn**; what replaces it is weaker and symmetric —
> **the arm-to-arm spread on IDENTICAL configurations is about ±5%, in either
> direction**, so R9c's ±2.5% floor is still an underestimate but it is a floor,
> not a bias, and no past delta needs re-signing. R8c's "+6.36% budget effect"
> stays refuted; it was a draw rather than an ordering artefact.
> **R11's FOLD STANDS on a contrast that ordering cannot fake.** The drift-free
> configuration effect is **−1.76%** on Phase 2 (pooled 14 runs per budget in
> one session) against R11's pre-declared ±5% band, and **+4.91%** on Phase 1 —
> inside the same band by 0.09 points and ~0.9 SE, reported at the edge rather
> than rounded. Both phases inert, so R11's and R8c's conjunction rule is
> satisfied. **`recipe.yaml` is untouched.**
> **R23 also discharged the campaign's last standing "never been measured"
> caveat.** `tg128 @ d16384 c4` at `mnbt 65536 + mns 4` — the shipped recipe,
> no `-o` override — reads **179.34 = 3.84x** (`peak_throughput` 317.0) and
> `ctx_tg` **169.45 = 6.12x** (peak 305.0). It is the **only row in `RESULTS.md`
> that states what `recipe.yaml` produces at `c>1`.** ⚠ Do not read its +3.46%
> over R13c's `mns 5` row as `mns 4` winning: that is a cross-session delta
> inside the ±5% spread this same round measured on identical configs.
> **Smaller deltas:** the phase-pair audit goes **45 of 46 → 50 of 51** (five new
> pairs, 9.22–9.30 against a theory of 9.00); the power bound rises to
> **≤ 100.6 W** (100.54 W); the SM-clock agreement is now confirmed *within* one
> session across five starts; and **R6's "runs=3 is adequate at d16384 — the
> quiet regime" is dead at seven engine starts** (2.6 / 5.5 / 8.01 / 8.26 /
> 10.95 / 12.22 / 10.90%). ⚠ **One instrument miss, recorded:** R23 captured no
> engine log, so it contributes no residency, acceptance or prefix-cache
> samples.
> **Counts stay 8 won / 12 lost.** Full detail in the `Round 23 outcome` block.

> ### ⚠️⚠️ WHAT THE R22 REVISION CHANGES — ⚠ SUPERSEDED IN ITS FIRST ITEM BY R23, ABOVE
>
> **1. THE CAMPAIGN HAS A POSITION BIAS AND HAS BEEN READING IT AS PHYSICS.**
> R22 reversed R8c's arm order as a free control. **In 4 comparisons of 4, across
> two rounds and four engine starts, the arm that ran SECOND read higher** —
> +6.36, +0.37 (R8c, E→F) and +12.24, +6.89% (R22, H→G), **mean +6.5%**. The
> budgets were swapped between the two rounds, so no budget effect can produce
> that pattern; a position effect produces exactly it.
> **Consequence: R8c's "+6.36% from the folded budget on Phase 1" is REFUTED**,
> and with position controlled (first arm vs first arm) `max_num_batched_tokens`
> reads **−1.08%** and **+0.86%** — **inert at c1 on BOTH phases at d32768.**
> Together with R11's +0.27% at d16384, **budget inertness at c1 is now CLOSED**
> and R8c's Phase-1 exception is withdrawn.
> ⚠ **The bias itself is NOT ESTABLISHED** — 4 comparisons from 2 sessions is
> **p = 0.25** on a sign test, and the two phases within a session are not
> independent. But it is **NOT a clock effect** (mean SM clock 2395.7 vs 2395.4
> MHz, identical to 0.01%) and **NOT thermal drift in the obvious direction**
> (the second arm ran ~1 minute after the first, on a warmer box, and was
> *faster*). **The discriminating round is an A-B-B-A within one session** —
> budgets 8192 / 65536 / 65536 / 8192, ~25 min — **and it is now the
> highest-value item in the queue.**
> **What to do with it today:** **the knee at 65536 is SAFE** (a 6.5% bias
> cannot manufacture R13c's +233%), but **every arm-to-arm reading in this
> campaign at or below ~7% is now suspect**, R13c's six-point budget curve
> included, and **R9c's ±2.5% "reproduction floor" is an underestimate for
> first-versus-later position.** Never quote a small cross-invocation delta
> without checking which arm ran first.
>
> **2. THE LAST SCOREABLE CELL IS CLOSED, AS A LOSS.** `ctx_tg @ d32768 c1` —
> the 125-entry cell R8c left at a **1.002x dead heat** — was re-measured at
> runs=14 at both budgets. **The 1.002x is RETIRED** (117.65 → **109.41**,
> −7.00%, inside its band); the pooled 21-run median at the folded budget is
> **113.37 = 0.966x** and the pooled 24-run median at the pre-fold budget is
> **115.86 = 0.987x**. R22's **pre-declared claim rule** (pooled must beat
> 117.37 by >1 SE, i.e. clear 120.53) was **NOT MET by 6.1%**. ⚠ One arm read
> **122.80 = 1.046x** and was **NOT promoted** — a rule that only binds when
> convenient is not a rule. **Counts stay 8 won / 12 lost, and no remaining cell
> has a route to a win that box time can open.**
>
> **3. σ FIGURES FROM 7 RUNS ARE THEMSELVES DRAWS, AT ±50% OF THEMSELVES.** This
> document recorded σ/med **24.20%** at `tg32 @ d32768 c1` as "the noisiest cell
> in the campaign", from R8c arm F's 7 runs. **R22 re-measured the identical
> config at 11.39%** — a factor of 2.1. Retired claim 19 at full strength; stop
> naming noise records from a single arm.
>
> **4. Smaller deltas:** the phase-pair audit goes **43 of 44 → 45 of 46**
> (17.499 and 17.450 against a theory 17.00); MTP acceptance at d32768 now has
> **four independent engine starts** spanning 3.56–3.71 and 85.4–90.2%, and
> **the budget does not move it** (open question 3 still NOT closed — the
> endpoints remain R5's); the zero-hit prefix-cache run passes **220 samples**;
> the **residency instrument recovered at c1** (19 loaded samples, 19 of them
> `(1,0)`, both budgets) — R8c's arm-F failure was cadence luck, and **residency
> claims at c1 need runs=14, not runs=7**; and the hardware **power bound rises
> to ≤100.5 W** (100.47 W, the first reading over 100 W).

> **What the R9c revision changes, so a reader who knows the earlier text can
> find the deltas:** **open question 1** (premise wrong by two orders of
> magnitude; remaining half not benchmarkable), **open question 8** (the ~2%
> downward systematic weakened to a noise floor), **"what to run next" item 3**
> (done, do not re-queue), **the prefix-caching section below** — rewritten
> around the **83% batch span / 17% decode / 0.7% hardware** decomposition,
> which is the single most consequential correction of this revision — **the
> phase-pair audit** (37 of 38 → **41 of 42**; **43 of 44** after R8c; now **45 of 46** after R22), **two more retired claims**
> (items 20 and 21), **a refusals record** that did not exist before, and an
> **R9c cost-ledger row**.

**This revision replaces every earlier one; there is no
second synthesis and there must never be one. It is the ONE authoritative
handoff — read it instead of the round blocks, and read `RESULTS.md` for the
standings.**

> **⚠️ THE RECIPE CHANGED ON 2026-08-22. R11 folded
> `max_num_batched_tokens: 65536` into `recipe.yaml`, which had been untouched
> for thirteen rounds.** Everything below written as "campaign config" means the
> **pre-fold** recipe at `mnbt 8192`. No margin moved and nothing in the archives
> is invalidated — R11 measured the c1 anchor at the new value first and it did
> not move (112.92 vs 112.62, **+0.27%**), which is exactly what licensed the
> fold. But **"unmutated" means something different after today**, and a round
> that runs `./recipe.yaml` without `-o` flags now gets a different engine from
> every round before R11.
>
> **AND THE RULE THAT FOLLOWS, WHICH IS THE ONE THIS CAMPAIGN LEARNED THE HARD
> WAY.** Every row this campaign published was measured at `mnbt 8192`. A future
> round that runs the folded recipe and compares its number to one of those rows
> is making a **cross-condition comparison across separate engine starts** — the
> single move this campaign refuted more often than any other. **R6 over R1**
> (the tg32 generation-length effect: 26.5% across invocations, **4.79%** with
> both arms under one engine start), **R8 over R3** (depth is flat: level across
> invocations, **−16.8%** in one), **R9b over R4** (the chunked-prefill
> mechanism: the deficit survives with the flag physically off). All three were
> comparisons between numbers taken under conditions that differed in ways the
> comparer had not priced, and all three read a real effect that was not there.
> The fold makes exactly that difference the *default* rather than the exception.
> So: **do not compare a post-fold number to a pre-fold row.** Either re-measure
> the baseline in the same invocation as the new arm with an explicit
> `-o max_num_batched_tokens=8192`, or state the budget difference as an
> uncontrolled term and do not read a mechanism out of the gap. R11 itself is the
> worked example — it did not assume the flag was inert at c1, it measured the
> anchor at the new value before touching the file.

Seventeen rounds plus three no-box-time passes, one model, one box, one image
epoch. Written to be read by someone who was not here; it assumes none of the
rounds above have been read. Where a round's headline was later retracted, the
retraction is here rather than the headline — and this campaign retracted a lot,
including two of its own widest wins and its central mechanism.

> **SIXTH REVISION — CURRENT AS OF 2026-08-22, post-R13b. THIS IS THE ONE THAT
> CLOSED THE CAMPAIGN'S MECHANISM STORY.** R13b answered
> **open question 7**, the section's sharpest open mechanism, and the deltas are:
> the R13 bullet in *the central methodological result* (its trailing candidate
> is refuted), **open question 7 itself** (closed, with a third mechanism), the
> landed-items list below (a seventh entry), *what to run next* item 7 (done, do
> not re-queue), an **R13b cost-ledger row**, and — added by this pass —
> **a new section, `THE MECHANISM CHAIN`**, which is the reason the revision
> matters: R13b's floor is the same physical term as R9c's 83% batch span, so
> the budget lever, the residency curve, the prefix-caching flag and every `c>1`
> number in this campaign now hang off **one** cause instead of three unrelated
> ones. Also **retired claim 22** (the whole acceptance-dispersion line of
> reasoning, named so nobody resurrects it), a corrected tail on **retired claim
> 16**, a corrected tail on the **`Model` observation**, and a rewritten
> **HANDOFF**. No standing moves; R13b is a mechanism round and scored nothing.

> **SEVENTH REVISION — CURRENT AS OF 2026-08-22, post-R8c. THIS IS THE ONE THAT
> BROKE THIS SECTION'S OWN SAMPLING WARNING.** R8c ran two arms at
> `ctx_tg32` / `tg32 @ d32768 c1`, runs=7, and its deltas are: **retired claim 9**
> (the deep ctx inversion, now dead outright rather than unreproduced), the
> **widest-campaign-config-win** and **losses** bullets in the standings summary
> (two margins corrected, no cell moved), the **three-run warning** in *the
> central methodological result* — **rewritten, because R8c is a 3-run median
> that was too LOW by 28.5% and the four-for-four one-directional claim this
> section carried is withdrawn** — **rule (3)** of the four carried rules, which
> rested on that claim, a **new priority re-measure list** attached to the
> standings summary, *what to run next* item 5 (done) and a **new item 9** (the
> best scoreable prospect left), the **phase-pair audit** (41 of 42 → **43 of
> 44**), the **hardware power bound** (≤97.3 W → **≤99.5 W**), an **R8c
> cost-ledger row**, and a rewritten **HANDOFF**. **No standing changes side —
> still 8 won / 12 lost** — but `ctx_tg @ d32768 c1` is now **0.92x, not 0.72x**,
> and reads a dead heat on the folded recipe.

> **EIGHTH REVISION — CURRENT AS OF 2026-08-22, post-R21. THIS IS THE ONE THAT
> INVERTED THE CAMPAIGN'S OWN BELIEF ABOUT ITS SAMPLING ERROR.** R21 was the
> three-run audit: two arms, `runs=7`, each reproducing its row's original
> pre-fold configuration, working the priority re-measure list this section
> attached to the standings after R8c. **Four rows moved and all four moved
> UP** — `tg32 @ d8192 c1` +16.54%, `tg128 @ d131072 c1` +5.43%,
> `ctx_tg128 @ d131072 c1` +2.24%, `ctx_tg @ d8192 c1` +1.77%. Deltas: the
> **losses** bullet in the standings summary (`tg128 @ d131072 c1` **0.95x →
> 0.995x** — the recorded deficit was overstated by a factor of ten) and the
> **widest-campaign-config-win** bullet's `tg32 @ d8192` figure, the **priority
> re-measure list** (three of four rows cleared, the fourth declined on the
> record), the **three-run warning** in *the central methodological result* —
> extended, not rewritten, because R21 was built to test R8c's replacement
> reading and it held five for five — **rule (3)** of the four carried rules,
> *what to run next* items 5 and the re-measure pointer, an **R21 cost-ledger
> row and a revised best-value verdict**, and a rewritten **HANDOFF**. **No cell
> changed hands — still 8 won / 12 lost** — and no upward move flipped a loss to
> a win. What changed is that the campaign had been publishing a 5.5% deficit it
> did not have, and its one thin claim (`ctx_tg @ d8192 c1`, 1.07x over best
> vLLM+NVFP4) survived the audit and firms to **1.08x**.

> **NINTH REVISION — CURRENT AS OF 2026-08-22, post-R22. THIS IS THE ONE THAT
> FOUND A NUISANCE VARIABLE UNDERNEATH THE CAMPAIGN'S OWN ARM-TO-ARM
> ARITHMETIC.** R22 was the protection round R8c earned: two arms at
> `ctx_tg32` / `tg32 @ d32768 c1`, **runs=14**, both budgets, with the arm order
> **deliberately reversed** from R8c's as a free control. Its deltas are: the
> **losses** bullet in the standings summary (`ctx_tg @ d32768 c1` closed as a
> **LOSS**, the 1.002x dead heat retired), a **seventh entry** in *the central
> methodological result*, the **three-run ledger** (a sixth defended-row
> correction, −7.00%), the **σ section** (the campaign's noisiest-cell record
> shown to be a draw), **retired claims 23 and 24**, the **budget-lever table**
> in the HANDOFF (a fourth leg: inert at c1 on **both** phases at a second
> depth), **open question 8** (the reproduction floor is an underestimate),
> *what to run next* item 9 (done) and a **new item 10** (the A-B-B-A round,
> now the top of the queue), an **R22 cost-ledger row and verdict**, and a
> rewritten **HANDOFF**. **No standing changes side — still 8 won / 12 lost** —
> and the round claimed no cell. **Its value is the position bias**, which
> reaches every small cross-invocation delta in this file.

**The ten things that landed after the round-12 checkpoint, since they change
how the rest of this section reads:**

- **R13** widened the contested `c4` cell and set a record margin — and
  **refuted the campaign's own admission-stagger model** with the instrument it
  had spent four rounds failing to capture.
- **The `ctx_` phase-label correction** found the two measurement phases labelled
  backwards since R1 and charged different token counts, which makes the ~9x
  `ctx_pp` advantage read for twelve rounds a **denominator artefact**. Prefix
  caching never engaged at all — ⚠ **and R9c then showed that the flag is worth
  2.414x anyway, 83% of it batch span. Those two facts are consistent; the
  reconciliation is in item 2 of the numbered section below and a cold reader
  should read it before concluding either one is wrong.**
- **R5c** confirmed from 34 archived records that the board's `c>1` `tg` figure
  is a **batch aggregate**, closing the units question from a second direction.
- **R13c** put all six `c4` headline rows back on the box — **all six stood**,
  all six came in ~2% low, two were tightened to pooled 14-run medians, and the
  token-budget curve was found to **knee at 65536**.
- **R11**, the campaign's last round and the only one ever to change
  `recipe.yaml`, **settled the fold**. It measured `tg128 @ d16384 c1` at the
  knee value 65536 and found the token budget **inert at c1** — **112.92 against
  the 112.62 anchor, +0.27%**, with the Phase-1 partner inside its own noise — so
  the flag went into the recipe and **eight of the eighteen win rows are now the
  shipped config rather than a per-round `-o` flag**. Two by-products, both free:
  **open question 13 is answered** (the +15.5% per-request rise R13 saw at `c>1`
  is a *sharing artefact*, because at c1, where `tg` **is** `tg_req`, the same
  budget change moves it +0.27%), and **R6's "runs=3 is adequate at d16384" rule
  is refuted** — that cell has now read σ/med 2.6% / 5.5% / **8.01%** across three
  engine starts.
- **R13d** repeated the one cell R13c measured and
  deliberately would not promote — `ctx_tg @ d16384 c4` at `mnbt 131072 + mns 5`.
  The repeat read 170.16 against R13c's 175.40 (−2.99%), and the **pooled 14-run
  median 171.77 = 6.21x is now the campaign's widest margin**, taking the title
  from the mnbt 98304 row's 6.15x by 0.83%. R13c's 6.34x is retired as the high
  draw it looked like, the standings did not move (**still 8 won / 12 lost**),
  and the downward-reproduction systematic is now **8 of 8 same-sign, mean
  −1.88%**. It closed the last scoreable cell in the queue.
- **R13b** closed **open question 7**, the campaign's sharpest open mechanism,
  and **refuted its own candidate before finding the real one.** Per-request MTP
  acceptance — read from the **response body**, not the engine log, via
  `--per-request-spec-decode-metrics detailed` — would produce a span ratio of
  **1.085** against an observed **1.499**, so acceptance dispersion is 17% of the
  excess. The floor is **prefill-completion stagger**: the first request to
  finish prefill decodes at **88.5 ms/verify-step** against 55–58 ms for the rest
  of its batch, and the batch span is measured from it. Its probe reproduced
  R13's c5 cell from an **independent client** to **+1.75% / −1.46% / −2.63%** on
  `tg` / `tg_req` / span — the campaign's first cross-client reproduction, and
  tighter than several of its cross-invocation ones.
- **R8c** is the round that first **corrected a recorded loss upward**. Two arms at `ctx_tg32` / `tg32 @ d32768 c1`, runs=7. The campaign's
  **last surviving deep inversion is retired**: R1's −27.3% read **+0.9%** at
  runs=7 at R1's own condition and **+6.9%** on the folded recipe, so retired
  claim 9 is dead outright and **no deep `ctx_`-versus-Phase-2 inversion exists
  anywhere in this campaign's data**. Its protection half split exactly as
  pre-declared: `tg32 @ d32768 c1` **STANDS** (−5.14%; the standings now carry
  the pooled 10-run **112.59 = 4.83x**), while `ctx_tg32 @ d32768 c1` **failed
  its band UPWARD by 31.64%** — R1's 84.03 was a 3-run **low** draw, the cell is
  **0.92x rather than the 0.72x carried for the whole campaign**, and on the
  folded recipe it read **117.65 against a 117.37 incumbent: a dead heat,
  deliberately not claimed** on one measurement at 0.06 SE. **That is the
  campaign's largest single-figure retraction and it went the direction this
  section said retractions do not go** — see the rewritten three-run warning
  below. ⚠ **SUPERSEDED IN THREE PLACES BY R22, WHICH RAN THE PROTECTION ROUND
  R8c ASKED FOR: the 1.002x dead heat is RETIRED (117.65 → 109.41) and the cell
  is a LOSS at 0.987x; R8c's "+6.36% budget effect on Phase 1" is REFUTED as a
  position artefact; and the noisiest-cell record below is a sampling draw
  (24.20% re-measures at 11.39%). R8c's refusal to claim the cell was correct
  and is the reason the file did not carry a ninth win.** By-products that
  stand: budget inertness at c1 confirmed at a **second depth** on Phase 2
  (+0.37% against R11's +0.27%), the d32768 acceptance point measured at **two**
  engine starts (87.0% / 88.9%), audit pairs 43–44, and 23 more zero-hit
  prefix-cache samples.
- **R21 ran last, and it is the round that turned R8c's correction into a
  pattern.** It worked the priority re-measure list: two arms at `runs=7`, each
  reproducing its row's original pre-fold configuration with an explicit
  `-o max_num_batched_tokens=8192`, with the two near-zero-σ `pp` figures as the
  reproduction control (they moved **+0.35%** and **+0.30%**, so Arm A really is
  R5's invocation). **Four rows moved, all four upward.** Three stood inside the
  ±10% band and were pooled (`ctx_tg @ d8192 c1` → **127.64**,
  `tg128 @ d131072 c1` → **81.22**, `ctx_tg128 @ d131072 c1` → **77.52**); one
  failed the band upward at **+16.54%**, so R1's `tg32 @ d8192 c1` 106.24 is
  **RETIRED** and 123.81 replaces it outright. **The headline is a margin, not a
  cell:** `tg128 @ d131072 c1` has been carried as a 5.5% loss since R5 and is
  short by **0.47% — 0.11 SE.** It did not flip and is not claimed. ⚠ **And it
  must not be re-run:** 0.11 SE is unresolvable at any run budget this campaign
  can afford, and d131072 is the most expensive depth on the box. Two free
  by-products: the campaign's thin `ctx_tg @ d8192 c1` claim **survived** and
  firms to 1.08x, and **the last unaudited extreme in the phase-pair table
  collapsed** (+19.1% → +4.00% at d8192), so every extreme in that table has now
  been shown to be a 3-run artefact and none survived.
- **R22 ran last, closed the last scoreable cell as a LOSS, and found the thing
  that matters more than the cell.** Two arms at `ctx_tg32` / `tg32 @ d32768
  c1`, **runs=14**, both budgets, one engine start each. **The cell is closed:**
  R8c's 1.002x dead heat is **retired** — 117.65 re-measured at **109.41**
  (−7.00%, inside its band) — the pooled 21-run median at the folded budget is
  **113.37 = 0.966x**, the pooled 24-run median at the pre-fold budget is
  **115.86 = 0.987x**, and the **pre-declared claim rule was not met by 6.1%**.
  ⚠ **One arm read 122.80 = 1.046x, over the incumbent, and was NOT promoted**,
  because it is one arm at one position in one session and promoting the best
  arm of a round is the error the round existed to avoid. **The rule held when
  it cost us the cell, which is the only time a rule is worth anything.** Counts
  stay **8 won / 12 lost**, and no remaining cell has a route to a win that box
  time can open.
  **Its real output is the POSITION BIAS.** The order reversal was put in to
  rule out a nuisance variable and instead found it: in **4 comparisons of 4**,
  across two rounds and four engine starts, **the arm that ran SECOND read
  higher** (+6.36, +0.37, +12.24, +6.89%, mean **+6.5%**), with the budgets
  swapped between rounds so no budget effect can produce the pattern. ⚠ **It is
  not established** — 4 comparisons from 2 sessions, **p = 0.25** on a sign test
  — and that qualification travels with the finding everywhere it is used. It is
  **not a clock effect** (2395.7 vs 2395.4 MHz) and **not thermal drift in the
  obvious direction** (the second arm ran on a warmer box and was *faster*).
  Consequences: R8c's "+6.36% budget effect" is **refuted**, and
  position-controlled the budget is **inert at c1 on BOTH phases** (−1.08% /
  +0.86%), closing that question; **the knee at 65536 is SAFE** (a 6.5% bias
  cannot manufacture +233%); but **every arm-to-arm reading in this campaign at
  or below ~7% is now suspect.** Free by-products: audit pairs 45–46, four
  independent acceptance starts at d32768, the residency instrument recovered at
  c1, 42 more zero-hit cache samples, and the σ record shown to be a draw.

### What the campaign set out to do, and whether the thesis held

The premise (top of this file): the spark-arena board holds 211 benchmarks spread
over ~93 test types x 5 concurrencies, so the crowded cell everyone competes in
(`tg128 @ d16384 c1`, topped at 188.47) is the exception. Almost every other cell
holds one to eight entries and is topped by a weak one. The thesis was that a
strong model on a fixed, already-tuned config could take a spread of those thin
cells by **varying only the probe** — `sparkrun benchmark perf` has no official
grid, so the cells measured are exactly the `-b` args passed, and the
experimenter picks the battlegrounds. Model fixed at
`nvidia/Qwen3.6-35B-A3B-NVFP4` on the de-rayed recipe; `recipe.yaml` was not to
be tuned.

**The thesis held for six rounds and then quietly inverted, and that inversion is
the campaign's real story.**

It held where it was aimed: the thin `tg32` cells at c1 fell by 4-5x on the
untouched recipe, and the deep cells at d65536 fell by 4.5-5.7x. **All eight
cells we hold were first taken with `recipe.yaml` exactly as it started** — the
mutations widened two of them, they did not win any.

It failed in two distinct ways. First, thin does not mean weak — `ctx_tg` at
d8192/d16384/d32768 c1 are thin-looking on the surface but crowded underneath
(125-130 entries), and we lose all three. Every prefill cell is held by the Atlas
runtime by two orders of magnitude, so those were never reachable. Second, and
more important: **where the incumbent was our own model, the gap turned out to be
config, and probe-only variation could not touch it.** At c2 and c5 the board's
own `Qwen3.6-35B-A3B-NVFP4` on vLLM beat us 2-5x. R10, R12 and R13 then closed
most of that gap with a single scheduler flag the campaign had never moved — and
still did not take either cell. So from R9 onward the campaign's largest results
came from **mutations**, not from probes — `tg128 @ d16384 c4` went from 1.13x to
**3.71x** on `max_num_batched_tokens` alone.

`recipe.yaml` was untouched for thirteen rounds, deliberately (see R10's fold
argument), while **ten of the eighteen win rows depended on mutations that were
not in it** — the campaign's one unresolved tension. **R11 resolved it.** R13c
told it which value to test (**65536**, the knee), R11 measured the c1 anchor
there, found it inert, and folded. **Eight of those ten rows are now the shipped
config.** What still sits outside the recipe is the *scheduler width*: the c4
rows were measured at `mns 5` and the recipe ships `mns 4`. At c4 that is worth
≤2.9% on three measurements at mns 4/5/16, but **`mnbt 65536 + mns 4` has never
been measured** and no row should be quoted as what the recipe produces until it
is.

### The standings, wins and losses both — FINAL

Eight board cells won, twelve lost, and a long tail that cannot be scored because
the board publishes no figure for it. **Those counts did not move after the
round-12 checkpoint** — R13, R13c, R13d and the `ctx_` correction changed
figures, retired claims and added rows, but no cell changed side. The wins occupy
**eighteen rows** in `RESULTS.md`, because the two `c4` cells each carry a
campaign-config figure plus five token-budget points from R13c's curve. Full rows
with configurations in `RESULTS.md`; the shape of it:

- **Widest margin, and it is a mutation:** `ctx_tg @ d16384 c4` at
  `mnbt 131072 + mns 5`, **171.77 vs 27.68 = 6.21x**, pooled over 14 runs from two
  engine starts (R13c + R13d — ⚠ REVISED, this said `mnbt 98304`/6.15x before
  R13d repeated the 131072 cell). The 98304 row remains a win at 6.15x from two
  engine starts. Its neighbour at `mnbt 65536` reads 5.96x on 7 runs.
- **Widest CAMPAIGN-CONFIG win:** `tg128 @ d65536 c1` 94.10 vs 16.48 (**5.71x**),
  then `tg32 @ d32768 c1` ⚠ **115.85 vs 23.31 (4.97x**, pooled **24** runs —
  REVISED BY R22 from the pooled-10 **112.59 / 4.83x** this bullet carried after
  R8c; R1's 3-run 115.56 / 4.96x remains retired. At the folded budget the same
  cell reads **110.16 = 4.72x** on 21 pooled runs), `ctx_tg @ d65536 c1` 92.98
  vs 20.70 (**4.49x**), `tg32 @ d16384 c1` 116.43 vs 28.11 (**4.14x**).
- **The transformed cell:** `tg128 @ d16384 c4` — the only contested cell we won
  (8 entries, a real field) — **1.13x** on the campaign config, **3.67x** at
  `mnbt 98304` (pooled 14 runs), **3.71x** at the knee value 65536. Reproduced
  across four engine starts and three scheduler widths.
- **Losses:** `tg128 @ d131072 c1` ⚠ **0.995x — REVISED BY R21 from 0.95x. The
  recorded deficit was overstated by a factor of ten.** R5's 77.13 was a 3-run
  draw; seven runs at R5's own invocation read 81.32, the pooled 10-run median
  is **81.22 against 81.60 — short by 0.47%, which is 0.11 SE.** It is a dead
  heat we are on the wrong side of, it **did not flip, and it is NOT claimed** —
  same discipline as R8c's 1.002x and R22's 1.046x, ⚠ **both of which have since
  been shown right not to claim** — R22 re-measured that cell at runs=14 and it
  came in a loss. ⚠ **Do not re-run it:** 0.11 SE is not
  resolvable at any budget this campaign can afford (halving the SE needs 4x the
  runs, at the most expensive depth on the box), and the old 5.5% figure was
  exactly the kind of near-miss that invites a tuning round. It has now been
  priced out properly. `tg128 @ d16384` c2 and c5 against
  the board's own like-for-like entry: c2 0.51x → **0.86x**, c5 0.21x → 0.57x →
  **0.73x** across three budgets, and **still losses at every one of them**.
  `ctx_tg` c1 at d8192/d16384/d32768, ⚠ **0.615x** (REVISED BY R21 from 0.61x;
  the cell top at 207.60 was never in play, but the row's *other* comparison —
  **1.07x over best vLLM+NVFP4, the campaign's thinnest surviving claim** —
  went into R21 at ~35% risk of withdrawal, **survived, and firms to 1.08x** on
  the pooled 10-run 127.64)/0.64x/⚠ **0.987x — CLOSED BY R22, and it is a LOSS.**
  This cell has been revised twice in opposite directions and it is now the
  best-sampled cell in the campaign, at **45 runs across four engine starts.**
  R8c corrected R1's 3-run 84.03 **upward** to 0.92x; R22 then re-measured at
  **runs=14 at both budgets** and the dead heat did not survive. **R8c's 117.65
  reads 109.41 (−7.00%, inside its band), so the 1.002x is RETIRED**; the pooled
  21-run median at the folded budget is **113.37 = 0.966x** and the pooled 24-run
  median at the pre-fold budget is **115.86 = 0.987x**. R22's claim rule — pooled
  must beat the 117.37 incumbent by more than 1 SE, i.e. clear **120.53** — was
  **declared before the run and missed by 6.1%.** ⚠ **One arm read 122.80 =
  1.046x and was NOT promoted**, on the same rule: it is a single second-position
  arm, and **a rule that only binds when it is convenient is not a rule.** ⚠ **Do
  not go back** — 0.987x is **0.34 SE** on the 24-run figure, the same
  unresolvable position R21 priced out at d131072. All six prefill cells at
  c1, by 15x-200x. Nine of those twelve losses were scored for the first time by
  the synthesis pass, from a scrape R5b took on 2026-08-21 that no round ever
  carried into the standings.
- **Unscoreable:** c8 and c16 at any budget, every `c>1` prefill and context cell,
  `ctx_tg @ d131072 c1`, `pp2048 @ d65536 c1` (the board has zero entries at that
  depth — an empty cell, not a won one), and all sixteen R9b rows.

**c5 is the loss worth naming.** It was the only cell with a live route to a win,
it got a round of its own (R13), and it ended at 0.73x against the board's own
`Qwen3.6-35B-A3B-NVFP4` on vLLM — and 0.38x against the cell's actual top. Even
clearing the like-for-like incumbent would not have taken the cell.

✅ **THE PRIORITY RE-MEASURE LIST IS WORKED. R21 CLEARED THREE OF ITS FOUR ROWS
AND ALL THREE MOVED UP.** This list was written after R8c corrected a 3-run row
**upward by 31.64%**; R21 ran it at `runs=7` across two arms and every row it
touched came in high. What is left is one entry, and it is declined on the
record rather than pending.

1. ✅ **`ctx_tg @ d8192 c1` — DONE. 126.52 → 128.76, +1.77%, inside the band,
   pooled 10-run **127.64**.** It was run first because it was the direct
   sibling of the row R8c corrected — same phase, same `c1`, one depth
   shallower, the same three-run invocation (`bench_25a0e7f36ab0`) that produced
   the 84.03 which turned out 28.5% low. **The campaign's thinnest claim
   survived:** 1.07x over best vLLM+NVFP4 firms to **1.08x**. The 0.61x loss to
   the cell top was never in play and reads 0.615x.
2. ✅ **`tg128 @ d131072 c1` — DONE, and it is the round's headline. 77.13 →
   81.32, +5.43%, pooled **81.22**; the recorded loss goes 0.95x → **0.995x**.**
   The 5.5% deficit this file published was overstated by a factor of ten; the
   real gap is 0.47%, i.e. **0.11 SE**. It **did not flip** and is not claimed.
   ⚠ The cost/value call this entry asked for has been made and the answer is
   **do not go back**: 0.11 SE is unresolvable at any affordable run budget, and
   Arm A alone was 96% of R21's grid bill.
3. ✅ **`tg32 @ d8192 c1` — DONE, and it failed its band. 106.24 → 123.81,
   +16.54%, OUTSIDE ±10%, so R1's figure is RETIRED and 123.81 replaces it —
   not pooled, per the rule.** It was the campaign's worst-sampled standings row
   (R1 σ/med **21.4%**, a 1.76x spread inside one cell). **No margin moves** —
   the board publishes no figure for the cell — which is why it ranked third and
   not first.
4. ⚠ **`tg128 @ d16384` c2 (84.00) and c5 (48.12), the R4 pre-fold rows —
   STILL ON THREE RUNS, STILL PROVISIONAL, DECLINED DELIBERATELY.** Both lose by
   **more than 2x** and R21's largest correction was 16.5%; nothing in the
   observed range of sampling error closes a 2x gap. Both also already have
   7-run tuned successors at raised budgets (c2 → 140.77, c5 → 128.93 / 164.27),
   which are what the standings actually rest on. **These two figures survive
   only as the pre-fold baselines those successors are measured against and
   must not be quoted as measurements. If they are ever re-measured, expect them
   to come in HIGH** — they are unaudited, unflattering rows, which is precisely
   the class that has moved upward five times out of five.

**And R13c added a measured error bar on top of that:** every figure in this
campaign taken exactly once carries a **~2% downward** correction of unknown
origin — six of six protected rows reproduced low, mean −1.94%, which on a coin
is p ≈ 3%. ⚠ **R8c's Phase-2 arm is the ninth same-sign low reproduction
(−5.14%)** and does not change that reading; R9c had already weakened the
systematic to a ±2.5% noise floor, and −5.14% on a σ/med 15.82% cell is 0.8
standard errors. No verdict changes sign at that size, but no decimal should be
quoted as if it were exact.

⚠ **AND R22 PUT A FLOOR UNDER THAT WHICH IS HIGHER THAN THE ONE THIS SECTION HAS
BEEN QUOTING.** R9c's **±2.5% reproduction floor** was measured between arms
whose *positions* nobody was tracking. R22's order-reversal control found the
arm running **second** reading higher in 4 comparisons of 4, mean **+6.5%**.
The bias is **not established** (p = 0.25 on a sign test; see the R22 note at
the top of this section), but if it is real then **±2.5% is an underestimate for
any first-versus-later comparison**, and the honest working figure for a
cross-invocation delta is closer to ~7%. **Do not quote a small cross-invocation
delta in this file without checking which arm ran first.**

### THE CENTRAL METHODOLOGICAL RESULT — single-invocation controls kept overturning cross-invocation inference

This is what the campaign found out that generalises past this model, this box
and this board. **Seven times**, a conclusion drawn by comparing numbers from
*different benchmark invocations*, or inferred from the instrument instead of
read out of it, was overturned by a round that put the compared quantities under
**one engine start** or read the source. Four of those seven are below; R13's
refutation of the stagger model and R13c's reproduction sweep are the two the
round-12 checkpoint could not include, and R22's position bias is the seventh
and the one that reaches furthest — it says the *general* move, not one
instance of it, carries a term nobody was pricing.

- **R6 retired R1's `tg32 @ d16384 c1` figure.** R1 measured 129.32 against an
  inherited tg128 baseline of 102.2 and read a 26.5% generation-length effect.
  Both arms in one invocation at runs=7: 116.43 vs 111.11, **+4.79%**, and the
  round's own identical-work controls (pp2048 and ttfr, both offset 1.90% between
  arms) price ~1.9% of that as arm-to-arm systematic. Residual ~2.9%. Generation
  length is not a lever. 129.32 was a lucky draw.
- **R8 retired R3's `tg128 @ d65536 c1` figure and the whole "depth is flat"
  reading.** R3's 108.15 at d65536 sat level with the shallow baseline across
  invocations, and the campaign built five rounds on the depth term being smaller
  than noise. Both depths in one invocation at runs=7: 113.06 and **94.10**, a
  **-16.8%** fall, 3.5σ outside the ±6% resolution R8 declared before it ran. The
  claimed margin fell 6.56x -> 5.71x.
- **R9b refuted R4's chunked-prefill mechanism.** R4 explained the c5-vs-c4
  deficit as prefill being chunked into ongoing decode steps. R9b ran the same
  contrast with chunked prefill physically disabled: the deficit **survives,
  slightly enlarged** (`R_pp` = 1.099 against a pre-declared refute-above-0.60
  threshold). The deficit is an invariant of `c > max_num_seqs` across four
  configurations spanning the token budget, prefix caching, the mamba cache mode
  and the flag itself. It is plain queueing.
- **R10 retired R2's units reading, from the source rather than from a control.**
  R2 proved `tg_throughput` is per-request because it equals `tg_req_throughput`
  at c1. `results.py:195` shows that equality is an **assignment** — it is a
  tautology that could not fail, whatever the `c>1` branch does. At `c>1`,
  `tg_throughput` is a **batch aggregate**: total decode tokens over the span from
  the first request's first token to the last request's last token. Nine rounds of
  `c>1` interpretation rested on a check that could not fail.
- **R13 refuted the campaign's own "admission stagger" mechanism, using the
  instrument the campaign had lost three times.** From R10 to R12 this file said
  the `c>1` gap was admission stagger, and R12 priced it at 83% (c2) and 93%
  (c5). R13 raised the budget to 98304 — enough to admit a whole 5-request batch
  in one scheduler step — and the engine log read **`Waiting: 0` in 100% of
  loaded samples**. With literally nothing queueing, the span ratio fell only
  1.70 → 1.54 at c5 and 1.57 → 1.53 at c4. **Most of what four rounds called
  admission stagger is not admission.** R12's split is a description of the
  metric's arithmetic, not of a physical cause. R13c then confirmed it from a
  second direction: residency is full from 32768 up, yet the span ratio keeps
  tightening to 65536 with nothing waiting at either budget, and then stops dead
  at a floor of ~1.50. ⚠ **REVISED BY R13b, WHICH ANSWERED IT.** The candidate
  this section carried — MTP acceptance dispersion — is **refuted**: measured
  per request, it would produce a span ratio of **1.085** against an observed
  1.499, i.e. 17% of the excess. The residual is **prefill-completion stagger**.
  The batch's five prefills do not finish together; the first request to finish
  starts decoding while the others still prefill, and its verify steps cost
  **88.5 ms against 55–58 ms** for every other request in the same batch — and it
  is the request the batch decode span is measured from. `Waiting: 0` is true and
  irrelevant, because **`Running` counts a prefilling request and a decoding one
  the same**. See item 7 below.
- **R13c measured the cross-invocation error the whole campaign had been
  assuming.** Six protected `c4` rows, re-run from separate engine starts at
  runs=7 against a ±10% band declared before the run. **All six stood** — gaps
  −0.48% to −3.18% — which is the campaign's only systematic protection sweep and
  the reason its headline figures can be quoted at all. But **all six came in
  low**, mean −1.94%, six of six the same sign. Two candidates and R13c cannot
  separate them: a decode-side session effect on the night, or a
  first-measurement bias in a campaign that promotes the figure from the run that
  motivated the round. The `pp2048` session control passed at five of six arms,
  so no night-wide slowdown is visible — but `pp` is prefill and `tg` is decode,
  so a decode-only session effect would not show there.
- ⚠ **R22 found a nuisance term in the cross-invocation comparison itself, and
  it is the seventh instance because it generalises the other six.** Every
  entry above is a specific inference overturned; this one says the *method*
  carries a bias. R22 reversed R8c's arm order purely as a free control and
  found that **in 4 comparisons of 4, across two rounds and four engine starts,
  the arm that ran SECOND read higher** — +6.36, +0.37, +12.24, +6.89%, mean
  **+6.5%** — with the budgets swapped between the rounds, so no budget effect
  can produce the pattern. **R8c's "+6.36% from the folded budget on Phase 1" is
  refuted**; comparing first arm against first arm, the budget reads **−1.08%**
  and **+0.86%**, inert on both phases. ⚠ **This is a suggestion, not a result:
  4 comparisons from 2 sessions is p = 0.25 on a sign test and establishes
  nothing.** It is not a clock effect (2395.7 vs 2395.4 MHz) and not thermal
  drift in the obvious direction (the second arm ran warmer and faster). **The
  round that settles it is an A-B-B-A within one session, ~25 min, and it is the
  top of the queue.** What survives regardless: **the knee at 65536** and every
  other large effect, because a 6.5% bias cannot manufacture +233%. What is put
  in doubt: **every arm-to-arm reading at or below ~7%**, R13c's six-point
  budget curve included.

**And here is the part worth carrying forward as a warning — REWRITTEN BY R8c,
BECAUSE THE VERSION THIS SECTION CARRIED WAS ITSELF A SMALL-SAMPLE ARTEFACT,
AND THEN TESTED AND CONFIRMED BY R21.**

**What this paragraph used to say:** *every* 3-run median the campaign promoted
and later re-measured came in TOO HIGH — R1's tg32 by 11%, R3's d65536 by 13%,
R13's 174.68 and 170.59 by 2.9% and 1.3% — four for four, same direction, "not
chance", so treat any unrepeated flattering figure as high.

**What R8c did to it.** R8c re-measured a 3-run median that had never been
promoted, because it was a **loss**: `ctx_tg32 @ d32768 c1`, R1's 84.03. Seven
runs at R1's identical condition read **110.61 — the figure was 28.5% too LOW**,
the largest single-figure retraction in the campaign, and it had sat in the
standings as a 0.72x loss for eleven rounds because nobody re-measures a number
that is merely disappointing.

**So the corrected statement, and it is the one to carry:** ⚠ **a 3-run median
is unreliable in BOTH directions and by more than anyone here assumed.** At a
cell whose σ/med is ~9–15% the standard error is 6–10%, draws land on both
sides, and the campaign has now seen both tails — +11%, +13%, +2.9%, +1.3% and
**−28.5%**.

**And the irony is worth one sentence, because the campaign made the exact error
it was warning about.** The four-for-four "always high" pattern was never a
property of the sampling; it was a property of **which rounds got re-measured**.
Flattering draws become claims, claims get defended, defended figures get
audited — and the audit sample was therefore one-sided by construction. **The
campaign generalised from four re-measurements chosen by how flattering they
were, which is a small-sample inference drawn from a biased sample: the same
mistake, one level up, as promoting a 3-run median.** The half of the old
warning that survives is the mechanism, not the direction: **the sampling error
is symmetric; the error that SURVIVES in a document is whatever nobody had a
motive to check.** Any unrepeated figure should be assumed wrong by ~1 SE in an
unknown direction — and the ones nobody has any motive to re-measure are the
losses, which is exactly where R8c found the campaign's largest error.

**⚠ AND THEN R21 TESTED THAT READING ON PURPOSE, AND IT HELD FIVE FOR FIVE.
THIS IS THE PART THAT INVERTS WHAT THE CAMPAIGN SPENT THE NIGHT WORRYING
ABOUT.** R8c's replacement reading made a prediction: if the old "always high"
pattern described the *audit queue* rather than the sampling, then auditing the
rows nobody was defending should produce corrections in the **opposite**
direction. R21 did exactly that — four unaudited rows at `runs=7` — and **all
four came in high.** The full ledger of every re-measurement this campaign has
made, sorted by why the row was picked:

| why the row was re-measured | rows | corrections |
|---|---|---|
| **it was a CLAIM somebody was defending** | R1 `tg32@d16384`, R3 `d65536`, R13 ×2 pooled, R8c arm E `tg32@d32768`, ⚠ **R22 `ctx_tg32@d32768` mnbt 65536** | **−10.0%, −13.0%, −7.00%, −5.14%, −2.86%, −1.30%** — six for six DOWN |
| **nobody had audited it** | R8c `ctx_tg32@d32768`, R21 ×4 | **+31.64%, +16.54%, +5.43%, +2.24%, +1.77%** — five for five UP |

⚠ **R22 ADDED THE SIXTH DEFENDED ROW AND IT BEHAVED EXACTLY AS THE RULE SAID.**
R8c's 117.65 entered the file as an *unaudited* row and came in high; by the time
R22 ran, this section's own header was calling it "the single most likely place
for the standings to change", which made it a **defended** figure. R22 predicted
**112, band 103–122** on that reasoning alone, before running, and it read
**109.41**. **The direction was called in advance from the rule, and the rule is
now the only thing in this file that has predicted a re-measurement's sign
before the fact.**

**Eleven re-measurements, six down and five up, and the sign is predicted by
motive rather than by anything about sampling.** This is ordinary regression to the mean seen
from both ends at once and it needs no mechanism: every extreme 3-run draw moves
back toward the family value regardless of sign. What is not symmetric is
**which** errors survive in a results file. A flattering draw becomes a claim, a
claim gets defended, and a defended figure eventually gets audited back down. An
unflattering draw becomes a recorded loss and sits there for eleven rounds.

**The practical consequence, and it should be stated in these words: THE
CAMPAIGN HAS BEEN UNDERSTATING ITS OWN RESULTS.** For most of its life this
section warned that its numbers were probably too good — that flattering figures
were high and claims would shrink under audit. The systematic audit points the
other way. **Recorded losses and thin margins are the rows most likely to be
wrong, and they are most likely to be wrong in our favour.** That is the
opposite of the risk this campaign spent most of the night guarding against.
`tg128 @ d131072 c1` is the worked example: published as a 5.5% loss, actually
short by 0.47%.

⚠ **And do not now over-fit in the new direction, because that would be the same
mistake a third time.** Five upward corrections is still a **modest sample**,
drawn from one model on one box in one image epoch, and all five came from just
two rounds. The split is clean enough to act on and far too small to treat as a
law. **What is established is the mechanism — audit selection, not an asymmetry
in the sampling — and the mechanism is what generalises.** The direction is a
prior, not a rule: it says which rows to audit first and which way to expect
them to move, not what any particular row will read. A 3-run figure is still an
unrepeated draw, still wrong by ~1 SE, and **still capable of going either way
at any individual row.**

Practical form of the rule, for the next campaign: never infer from two numbers
taken under two engine starts if the design can put them under one; declare the
resolution budget and the reading thresholds **before** the run (R8, R9, R9b, R10
and R12 all did, and it is what made their refutations worth anything); and put
an identical-work control (`pp2048`, `ttfr`) in every multi-arm invocation, so the
arm-to-arm systematic is priced instead of assumed away. **And add the rule R13c
earned: schedule a protection round.** Re-measure the headline figures from a
separate engine start against a band declared in advance, and pool same-config
repeats rather than picking a draw. R13c cost 45 minutes and is the only reason
any figure in this file can be quoted with a number attached to its uncertainty.
Its corollary is that **a single 7-run median at a configuration measured once is
not a claim** — which is why R13c measured a 6.34x margin, wider than the
campaign's title-holder, and **deliberately did not promote it**. Promoting the
best first measurement of a cell is exactly what retired R1's and R3's figures.

### R6's sampling result: σ is set by verify steps and acceptance quality, NOT by concurrency

For five rounds the campaign believed "c1 is the noisy regime" and priced rounds
on concurrency. R6 measured a c1 cell at **σ 2.6%** — the quietest c1 cell in the
campaign — alongside a c1 cell at 9.9% in the same invocation. Lining up every
cold c1 measurement:

| cell | σ/median |
|---|---:|
| tg128 @ d16384 c1 (R6) | 2.6% |
| tg128 @ d16384 c1 (R8) | 5.5% (6 of 7 runs span 1.6%; one low draw) |
| tg32 @ d16384 c1 (R6) | 9.9% |
| tg128 @ d65536 c1 (R8) | 9.0% |
| tg128 @ d131072 c1 (R5) | 9.3% |
| tg32 @ d8192 c1 (R1) | 21.4% |

The driver is **how many MTP verify steps a measurement averages over, and how
good acceptance is in that regime**. A long generation at shallow depth runs many
verify steps at ~93% acceptance and is quiet. A short generation averages over 4x
fewer steps. A deep context collapses acceptance (93.6% -> 47.7% at d131072) and
widens every step's draw. Concurrency was a proxy for the first of those all
along — raising `c` multiplies the sequences averaged per step, which is the same
lever as lengthening the generation, and it is why c8 and c16 gave σ 0.51% and
**0.15%**, the quietest cells the campaign ever measured.

**This should govern how future rounds are priced**, and it inverts the old rule:

- ~~`tg128` at d16384, any `c` >= 1: **runs=3** is adequate (σ 0.15-2.6%).~~
  **⚠ REFUTED BY R11 at c1 — do not quote this again.** That exact cell has now
  been measured at three engine starts and σ/med reads **2.6% (R6) / 5.5% (R8) /
  8.01% (R11)**. At 8.01% a 3-run median carries a standard error near **5.8%**,
  five times the effect R11 was built to resolve. **σ is itself a draw**, and the
  only budget that has been safe at all three sessions is **runs=7**. The `c>1`
  half of the old rule is untouched — c8 and c16 really did give 0.15–0.51% — so
  the corrected rule is: **runs=7 at c1 anywhere; runs=3 is defensible only at
  `c>=8`, where the batch averages many sequences per step.**
- Anything `tg32`, and anything at **d65536 or deeper**: **runs=7**, non-negotiable.
  R3 skipped this and put a 13%-wrong number in the standings for five rounds.
- Price the round on **the estimator the verdict actually rests on.** R10 needed
  runs=7 not because `tg` is noisy (0.52%) but because `peak_throughput` is
  (3-9%). The sampling budget belongs to the number being read.
- The distribution is a **mode plus low outliers**, not a spread (R8: six runs in
  112.51-114.36, the seventh at 95.56). Medians are the verdict; means are not.

⚠ **AND R22 PUT A NUMBER ON "σ IS ITSELF A DRAW", WHICH THIS SECTION HAD ONLY
ASSERTED.** This file recorded σ/med **24.20%** at `tg32 @ d32768 c1` as **"the
noisiest cell the campaign has ever measured"**, from R8c arm F's 7 runs. R22
re-measured the **identical configuration** at runs=14 and read **11.39%** — a
factor of **2.1** at the same config, same box, same image. The practical rule:
**a σ/med quoted from 7 runs carries roughly ±50% of itself as uncertainty**, so
**this file's habit of naming "the noisiest cell in the campaign" from a single
arm stops here** and no such record should be quoted again unless it rests on
pooled runs across engine starts. The consequence for run budgets is unchanged
and better founded: at ~10–13% σ/med, **runs=14 buys SE ≈ 3.0–4.5% and runs=7
buys 4.5–7.5%** — which is why R22 said before running that it could not resolve
a 0.24% margin, and why it did not pretend afterwards that it had.

### The two findings with the largest practical consequence

**1. The campaign's own token budget was starving concurrency, and it had been
doing so since round 2.** `--max-num-batched-tokens 8192` against a d16384
prefill means a scheduler step admits *half* of one request's prefill. R7 found
the engine holding a median of 9 of 16 sequences resident at c16 and assumed a
high-concurrency problem; R9 then found it biting at **c4**, the cell holding the
campaign's only contested win, where the scheduler logged `(2,2)` and `(3,1)`
instead of a full `(4,0)`. Raising the budget to 32768 admits two whole prefills
per step, and the effect is large because llama-benchy's headline metric divides
by a span that includes admission stagger — a starved budget is charged twice,
once in occupancy and once in the denominator:

| cell | campaign config | mnbt 32768 | change | `peak_throughput` change |
|---|---:|---:|---:|---:|
| c2 | 84.00 | **140.77** | +67.6% | 182 -> 181 (**-0.5%**) |
| c4 | 52.85 | **147.25** | +179% | 272 -> 284 (+4.4%) |
| c5 | 48.12 | **128.93** | +168% | 265 -> 290 (+9.4%) |
| c16 | 40.47 | 53.45 | +32% | 440 -> **515** (+17.0%) |

**AND R13c CURVED IT. THE CURVE KNEES AT 65536 — this is the single most
actionable number the campaign produced.** Six budgets at c4, d16384, tg128,
`mns 5`, runs=7 each, one invocation per budget:

| mnbt | admission steps | `tg` | σ/med | `tg_req` | span ratio | `peak_thr` | scheduler |
|---:|---:|---:|---:|---:|---:|---:|---|
| 8192 | 9 | 52.07 | 1.03% | 33.00 | 2.535 | 271 | **partial occupancy** |
| 16384 | 5 | 85.90 | 2.08% | 43.99 | 2.048 | 277 | **partial occupancy** |
| 32768 | 3 | 143.83 | 3.87% | 59.48 | 1.654 | 288 | `(4,0)` 13/13 |
| **65536** | 2 | **173.34** | 4.39% | **65.24** | **1.505** | 308 | `(4,0)` 10/10 |
| 98304 | 1 | 169.69 | 4.01% | 64.02 | 1.509 | 302 | `(4,0)` 11/11 |
| 131072 | 1 | 170.89 | 3.89% | 64.14 | 1.501 | 304 | `(4,0)` 12/13 |

8192 → 65536 is **+233%**; 65536 → 131072 is **−1.4%**, i.e. nothing — the top
three budgets span 2.1% against a per-arm σ/med of ~4% and are one point.
**`max_num_batched_tokens 98304`, which R13 derived from one-step-admission
arithmetic and paid a torch.compile rebuild for, is not needed.** The ceiling is
reached at 65536, a **two**-step configuration, so removing the last admission
step is not what the gain was made of — which is the same result as R13's
`Waiting: 0` finding, seen from the other side. The curve also separates two
thresholds this campaign had conflated: **residency** saturates at 32768, the
**span ratio** does not, and it keeps falling to 65536 with nothing waiting at
either.

**What it implies for the recipe — ⚠ REVISED, IT IS NOW FOLDED.** The lever is
real, verified at runs=7 across four separate engine starts and three scheduler
widths, and it is the difference between 1.13x and 3.71x on our best contested
cell. It sat outside `recipe.yaml` for thirteen rounds for one good reason: the
c1 anchor (112.62, pooled over R6+R8) that every depth and concurrency comparison
hangs from was measured at 8192, and folding without re-measuring that anchor
would silently create a new epoch. **R11 was exactly that measurement, R13c told
it which value to test (65536, the knee — not 32768 and not 98304), and it
landed: the anchor reads 112.92 at 65536, +0.27%. `recipe.yaml` now carries
`max_num_batched_tokens: 65536`.** The epoch is therefore *declared* rather than
silent — see the warning at the top of this synthesis.
Three things went into the recipe note, and they are the trade the fold buys:
at c2 the
hardware ceiling did not move at all (181 vs 182) while the board metric rose two
thirds, so this buys a *ranking*, not throughput; **time-to-first-response gets
worse at every concurrency and at every budget increase tested** (+7.3% c2,
+15.6% c4, +19.8% c5, +32.4% c16; ttfr rose for the sixth consecutive budget step
at R13, 12102 ms at c4 and 15126 ms at c5); and a budget sweep is **cheap** —
R13c measured engine-start cost as a function of budget SIZE, not novelty,
~110–190 s across 8192–98304 with a step up to 310 s at 131072, correcting R13's
warning that each new value costs a full rebuild. It is a throughput-versus-latency
trade and must be written as one.

**2. Prefix caching has never once hit on this benchmark — and the flag is worth
2.414x of the headline metric anyway, of which 83% is batch span.** ⚠ **REWRITTEN
BY R9c. The earlier version of this section said "57%", named `mamba_block_size`
16 → 32768 as the suspect, and said nobody knew the mechanism. All three are
superseded; read this version.**

**The three readings that have to sit together, because a cold reader will
otherwise think two of them contradict the third.** They do not, and the
reconciliation is the point of this section:

- **R9b: prefix caching never engages.** vLLM's own counter reads `Prefix cache
  hit rate: 0.0%` with the flag **ON** — 22 samples in R9's A1, 92 in R10, 22 in
  each of R9c's P and G arms, **158 consecutive samples and no hit ever
  recorded**. Total prompt tokens processed differ 1.7% between on and off. **No
  prefill work is saved, ever.**
- **The `ctx_` phase-label correction: there was never a cached pass to look
  at.** llama-benchy's `ctx_` row is Phase 1, the context load, charged
  `depth + 2048` tokens against Phase 2's 2048, so the ~9x `ctx_pp` advantage
  read for twelve rounds is the denominator and not the cache. Two of the
  archived pairs are prefix-caching-**OFF** arms and they read the same ratio,
  which is independent proof the cache never hits.
- **R9c: the flag is nonetheless worth 2.414x**, on 14 runs re-measured in one
  session (146.32 ON vs 60.60 OFF at `tg128 @ d16384 c4`, `mnbt 32768`,
  `mns 4`), and the decomposition **closes exactly** on the campaign's own
  identity `tg = c x tg_req / span`:

      tg ratio 2.415  =  tg_req ratio 1.160  x  span ratio 2.082
      log-share:  batch span 83%   per-request decode 17%
      hardware:   peak_throughput 287 vs 289 — 0.7%

**THE RECONCILIATION, IN ONE SENTENCE: the flag is not buying cache hits and is
not buying hardware throughput; it is buying a shorter measurement window, and
the window is `tg_throughput`'s denominator.** All three readings are true at
once because they are about different quantities. R9b measured the *cache* and
found it idle. The phase correction removed the *column* the campaign had been
reading cache effects out of. R9c measured the *metric* and found 83% of the
flag's value sitting in the batch span — which is exactly the term R10 proved
`tg_throughput` is charged for. **A flag can be worth 2.414x of a scheduling
measurement while saving zero prefill work, and that is what this one does.**

**The span is not an inference. It was measured directly as ttfr dispersion
within the batch: 1516 ms with the flag on, 6269 ms with it off — 4.13x.** At
~59 tok/s/req a 128-token generation lasts ~2.2 s, so the OFF arm's 6.3 s spread
swamps the decode window entirely while the ON arm's 1.5 s spread sits inside
it. One request per batch of four returns its first token about 6 s early with
the flag off, and the aggregate is divided by the whole span.

**What this retires.** Every earlier reading that credited a `c>1` margin to
"prefix caching working" is retired twice over — once by R9b (it never worked)
and once by R9c (83% of what it is worth is the denominator, not the engine).
And the "57% of `tg`" figure is retired as a single-draw understatement: it came
from two 3-run medians four hours and one engine start apart. **2.414x on 14
runs measured in one session is the figure.**

**What is NOT explained, stated plainly rather than papered over.** ⚠ **REVISED
BY R13b, WHICH SUPPLIED THE MECHANISM THIS PARAGRAPH SAID WAS MISSING.** The
span difference is **first-token spread** — the flag's 1516 ms against 6269 ms is
prefill-completion stagger, and putting R9c's own arms through R13b's
zero-parameter identity reproduces both measured span ratios to ~5%. See
`THE MECHANISM CHAIN` below; note the identification is **inferred from
arithmetic**, because nobody has run the per-request probe against a
caching-OFF engine. **What remains genuinely unexplained is narrower than it was:
why the flag changes the spread by 4.13x in the first place**, and R9c narrowed
that without closing it:

- `mamba_block_size` is **not** 16 → 32768. It is **2144 → 32768, 15.3x** —
  `platforms/interface.py:911-918` overwrites the 16 with the aligned attention
  block size, and all seven archived engine logs carry the same
  `Setting attention block size to 2144` line. **The 2048x premise was wrong by
  two orders of magnitude and no round ever ran under it.**
- Moved from the only legal side (`--block-size 32768` with caching ON), it
  explains **at most 42%** of the span gap and arrives with a 2.03x per-request
  decode penalty the caching-OFF arm does not have — so it is not the whole
  story and the arm that tested it was confounded (87% of KV capacity lost).
- ⚠ **And the caching-OFF arm is not at full residency** — `(3,1)` in 7 of 13
  loaded samples at `c4`/`mns 4` with 3.34M tokens of KV free. Capacity is not
  the reason and the campaign does not know what is. Its span figure is
  therefore doing double duty as a queueing figure, and by the lead's own rule
  the stagger proxy holds only at full residency. **Mechanism UNEXPLAINED, not
  invented.**
- **The remaining half is not benchmarkable in this engine.** Prefix caching ON
  forces `mamba_cache_mode: align`; OFF forces `none`; `mamba_block_size` may be
  set only with caching ON and is then overwritten by `block_size` under
  `align`. The four things the flag moves cannot be separated by any flag, in
  either direction. See open question 1 — it is a source-reading task now.

Two consequences, and both are corrections rather than discoveries:

- **Nothing in this campaign's `c>1` gains should be described as "prefix caching
  working".** It is not working. What rides along with the flag is worth 2.414x
  at c4 and 83% of that is the batch span; R9c priced it and proved the
  remainder cannot be isolated by benchmarking.
- **The `ctx_` and cold labels have been backwards since R1.** llama-benchy's
  `ctx_` row is Phase 1, the **context load** — the uncached pass that establishes
  the cache. The rows this campaign calls "cold" are Phase 2, the cache-eligible
  one. And the two phases are charged different prompt-token counts (16384 vs
  2048), so the ~9x `ctx_pp` advantage read at every depth for twelve rounds is
  `16384/2048` and not a cache effect. Every ctx-versus-cold reading in this
  journal before R9b is mislabelled; the `tg` comparisons survive the token-count
  problem but not the labelling.
  **Since measured, not just asserted, and then extended:** `ctx_pp / pp =
  (depth+2048)/2048` — a prediction with **no free parameters** — holds in ⚠ **43
  of 44** archived phase pairs across five depths, eight token budgets and five
  concurrencies (⚠ **R8c added pairs 43 and 44** at d32768, reading **17.396**
  and **17.468** against a predicted **17.00** — the same ratio at two budgets 8x
  apart, which is what a pure denominator artefact must do), residuals −0.7% to +6.4% (R13d added the 37th pair, R11 the 38th
  at c1 above the old budget, and **R9c's four arms added pairs 39-42, reading
  9.167 / 9.139 / 9.151 / 9.148 against a predicted 9.00** — the tightest cluster
  of four in the audit, and the first taken at three different `mamba_block_size`
  values and both settings of prefix caching. **That the ratio is invariant to
  the flag is itself further proof the two phases differ by token count and not
  by caching.**). R13c's
  six budget arms added the one dimension the audit lacked: the ratio reads
  9.21 / 9.11 / 9.12 / 9.23 / 9.58 / 9.20 against a predicted 9.00 while the
  scheduler's token budget moves **16x**, which is what a pure denominator
  artefact must do and what a real prefill effect could not. The two phases
  prefill at the same rate to within 4% and **no prefill speedup exists anywhere
  in this campaign's data, at any depth, concurrency or budget, and there never
  was.** Two of the pairs are the prefix-caching-OFF arms and they do not move,
  which is an independent proof that the cache never hits — **the archives were
  carrying proof that prefix caching never hits, in the very column the campaign
  was reading as proof that it did.** Full audit later in this file.
  **AND THE MOST DANGEROUS MISREADING OF THIS CORRECTION IS DISARMED THERE:** the
  obvious move on learning that `pp2048` is charged 2048 tokens for `depth + 2048`
  of real work is to rescale our prefill figures and declare the six prefill
  losses void. That is wrong — the board's entries come through the same
  llama-benchy CSV and carry the identical understatement, so the artefact
  cancels. **The prefill cells remain losses at exactly the recorded margins.**

### THE MECHANISM CHAIN — one cause under all of it, closed by R13b (2026-08-22)

**This section is new in the sixth revision and it is the most important thing in
this synthesis.** For most of its life the campaign held three separate stories:
a token-budget lever it could not explain, a prefix-caching flag worth 2.414x
that never once hit the cache, and a span ratio whose floor it kept mis-naming.
**R13b showed they are one story.** Read the chain, then read the ledger of which
links are measured and which are still inferred — the campaign's own rule is that
a mechanism paragraph without that ledger is how three rounds got the mechanism
right and the number wrong.

    token budget  →  residency  →  prefill-completion stagger  →  batch span  →  every `c>1` number

1. **Token budget → residency.** A scheduler step admits `mnbt` tokens of
   prefill; a Phase-2 request at d16384 costs 18432. At 8192 and 16384 the
   scheduler never holds `(4,0)` at c4; from 32768 up it does. **MEASURED**,
   R13c's six-budget curve, 19/16/13/10/11/13 loaded samples per budget.
2. **Budget → prefill-completion stagger, past the residency point.** Residency
   saturates at 32768 but the span ratio keeps falling to 65536 — 1.654 → 1.505
   — **with `Waiting: 0` at both**. A larger budget cuts each request's prefill
   into fewer chunks, so the five prefills finish closer together. **PARTLY
   INFERRED.** The falling span is measured (R13c); the tightening first-token
   spread that is supposed to cause it has **never been measured across budgets**
   — R13b measured the spread at exactly one budget (98304). Anyone with an
   engine up should re-run the R13b probe at 16384 and 65536 and close this link;
   it is one invocation and it is the cheapest link left in the chain.
3. **Prefill-completion stagger → batch span.** The first request to finish
   prefill starts decoding while its four neighbours still prefill; its verify
   steps are co-scheduled with their chunked prefill and cost **88.5 ms against
   55–58 ms**, a 1.57x penalty borne by exactly one request — and it is the
   request `tg_duration = max(last token) − min(first token)` is measured from.
   **MEASURED**, R13b: `corr(start stagger, ms per verify step) = −0.980` over 35
   requests, against `corr(verify steps, decode duration) = +0.142`. The
   zero-parameter check `1 + 1.26/2.30 = 1.548` reproduces the observed **1.499**
   to 3%.
4. **Batch span → the headline metric.** `tg_throughput` at `c>1` is total decode
   tokens over that span (`results.py:352`). **MEASURED / definitional**, R10 from
   the source, corroborated by R5c against 34 archived records.
5. **Therefore every `c>1` number.** Anything that tightens the first-token
   spread is charged straight into this metric, whether or not it makes the
   hardware do more work. That is why `peak_throughput` sat still while `tg` rose
   two thirds at c2 (R12) and +233% across R13c's curve.

**AND IT REACHES R9c's 83%, WHICH IS THE LINK THAT MAKES THE CHAIN WORTH
WRITING.** R9c decomposed `--enable-prefix-caching` as `tg` ratio 2.415 =
`tg_req` ratio 1.160 x **span ratio 2.082**, i.e. **83% batch span**, and
measured the span directly as within-batch ttfr dispersion: **1516 ms with the
flag on, 6269 ms with it off**. Put R9c's own archived numbers through R13b's
identity `span ≈ 1 + spread / decode_duration`, with `decode_duration = 127 /
tg_req`:

| R9c arm | ttfr spread | `tg_req` | decode duration | predicted span | measured span | gap |
|---|---:|---:|---:|---:|---:|---:|
| **P** (caching ON) | 1516 ms | 58.78 | 2.161 s | **1.702** | **1.607** | +5.9% |
| **N** (caching OFF) | 6269 ms | 50.68 | 2.506 s | **3.502** | **3.346** | +4.7% |

**Both arms, no fitted parameter, same sign, ~5%.** R13b's identity was derived
at c5 / `mnbt 98304` / prefix caching ON, from a different client, and it
reproduces two arms of a different round at c4 / `mnbt 32768` / both settings of
the flag. **So R9c's 83% batch-span term and R13b's span floor are the same
physical quantity: how far apart the batch's prefills finish.** The flag is not
buying cache hits (it never hits), is not buying hardware (0.7%), and is not
buying decode rate (16%) — it is buying **prefill-completion alignment**, and
that is the whole of its 2.414x.

⚠ **Two honest qualifications on that link, and neither is small.**
(a) The R9c → R13b identification is **INFERRED FROM ARITHMETIC, not measured**.
Nobody has run R13b's per-request probe against a prefix-caching-OFF engine; the
table above is R13b's identity evaluated on R9c's archived aggregates. The ~5%
over-prediction on both arms is consistent with the identity being slightly wrong
in a fixed direction, and two points cannot separate that from noise.
(b) **Arm N is not at full residency** — `(3,1)` in 7 of 13 loaded samples with
3.34M tokens of KV free — so some of its 6269 ms spread is genuine queueing
rather than prefill stagger, and by the campaign's own rule (R5c) the span proxy
holds only at full residency. **Arm P is clean** (`(4,0)` in 13 of 14), and it is
the arm that matters for the identification. Do not quote arm N's agreement as
independent confirmation; quote it as not contradicting.

**What the chain retires, and it is the part a future session will otherwise
re-derive.** The `c>1` results in this campaign do **not** need three mechanisms.
They need one, and the two that were tried before it are both dead: **admission
stagger** (refuted by R13, `Waiting: 0` in 100% of samples) and **MTP acceptance
dispersion** (refuted by R13b, 1.085 against 1.499). See retired claims 16 and 22.

**What it does NOT close.** The residual per-request decode terms — R9c's 16% and
R13's +15.5% — are not explained by this chain and are not claimed to be. Nor is
R9b's finding that turning chunked prefill *off* cuts `tg_req` 44% while
*improving* stagger; that is plausibly the same effect seen from the far side
(unchunked prefill blocks decode outright but leaves the starts aligned), **but
that reading is inferred and was never tested.** And the chain says nothing about
c1, where there is no batch and the span is 1.000 by assignment.

⚠ **AND THAT LAST SENTENCE IS WHY THE d32768 c1 INVERSION HAD TO GO — R8c,
added in the seventh revision.** For most of the campaign the `−27.3%` Phase-1
deficit at `ctx_tg32 @ d32768 c1` looked like a deep-context effect awaiting a
mechanism. Two things then removed every candidate mechanism it could have had.
**First the `ctx_` phase-label correction (R9b):** the `ctx_` phase is the
context-**load** pass, not a cached one, so "the cached pass is slower at depth"
was never a coherent reading of it — and prefix caching never engaged in this
campaign at all, in 180-plus consecutive samples. **Then the chain above, via
R9c and R13b:** the campaign's one surviving mechanism is prefill-completion
stagger acting through the batch span, and at `c1` it is **silent by
construction** — R8c measured `tg == tg_req` exactly in all four phase-arms, so
the span ratio is **1.0000 by assignment**, and residency read `(1,0)` in 9 of 9
loaded samples. There is no stagger, no span and no admission term at `c1` for a
depth effect to ride on. **So a surviving −27% would have left the campaign
owning a `c1` effect that nothing in its closed mechanism story could explain.**
R8c's pre-run hypothesis said the gap needed a bigger sample rather than a
mechanism, and at runs=7 it read **+0.9%** at R1's own condition and **+6.9%**
on the folded recipe. **The chain is not merely consistent with the retirement —
it predicted it, and it is the reason the retirement needs no new physics.**

### The depth curve, as finally measured

| depth | tg128 c1 median | vs previous | per doubling | source |
|---:|---:|---:|---:|---|
| 16384 | **113.06** | — | — | R8, runs=7, one engine start |
| 65536 | **94.10** | **-16.8%** (4x) | -8.8% | R8, runs=7, same engine start |
| 131072 | ⚠ **81.22** | **-13.7%** (2x) | -13.7% | ⚠ **REVISED BY R21** — pooled 10 runs (R5's 3 + R21's 7 at R5's own invocation, `pp` controls +0.35% / +0.30%). Was 77.13 / −18.0% on R5's 3 runs alone |

**Monotone and steepening.** Physics required monotonicity — per-step decode work
cannot fall as context grows — so every "deeper is faster" reading this campaign
published was always going to be sampling, and all of them are gone. The
five-round "flat, flat, then a cliff" story is retired; there was never a knee.

**The naive model still misses by a large factor, and that is an open problem
rather than a solved one.** Against a fixed ~1.7 GB active-weight read per decode
step, FP8 KV over 10 of 40 layers is 0.62 GB at d16384 and 2.50 GB at d65536 —
total read 1.81x, which a pure-bandwidth model turns into **-44.8%**. Measured
**-16.8%**: right sign, wrong by **2.7x** in magnitude. The architecture explains
a constant discount — 30 of 40 layers are fixed-state Gated DeltaNet whose
per-step cost does not grow with context, and the KV layers are FP8 — but a
constant discount does not explain a curve that *steepens*. MTP acceptance decay
is the leading candidate for the steepening (R5 watched acceptance fall from
93.6% to 47.7% under d131072 load), and **the campaign never got the unconfounded
measurement**: R8 was in position to take acceptance at two depths under one
engine start and lost the engine log. That measurement is still outstanding and
still cheap.

✅ **THE d131072 POINT IS NO LONGER THE WEAK LEG — R21 RE-MEASURED IT.** It was
a 3-run median from a separate invocation at σ 9.3%, flagged here as the least
trustworthy part of the curve and number 2 on the priority re-measure list.
R21 ran seven runs at R5's own invocation and read **81.32, +5.43%**; the pooled
10-run median is **81.22**, which flattens the last leg from −18.0% to
**−13.7%** and makes the curve's steepening milder than this section originally
described. It is still **monotone and still steepening** (−8.8% then −13.7% per
doubling), so nothing above changes qualitatively — but the naive-bandwidth
model's miss factor at the deep end shrinks with it. ⚠ Note the direction: the
one point on this curve that stood on three runs came in **high**, like every
other unaudited row (see the three-run warning). ⚠ **Do not re-measure it
again** — the standings verdict it could once have flipped is now a 0.11 SE dead
heat that no affordable run budget can resolve, and Arm A was 96% of R21's grid
bill.

### Claims this campaign published and later withdrew

Kept together so a cold reader does not resurrect one of them from an early round:

1. "tg32 is 26.5% faster than tg128" — R1, retired by R6. It is ~2.9%.
2. "Depth is flat from d16384 to d65536" — R3, retired by R8. It falls 16.8%.
3. "`tg_throughput` is per-request" — R2, retired by R10 from the source.
4. "`aggregate = per-request x c`" — used from R2 to R9, dissolved by R10. It
   double-counts an already-aggregate metric; that is the whole of why it kept
   exceeding `peak_throughput`. Report `tg_throughput` and `peak_throughput` side
   by side and never multiply.
5. "The board's `c>1` figure is an aggregate and ours is per-request, so our c4
   win is really 4.53x" — R7, withdrawn by R10. Both are the same field.
6. "Chunked prefill interference costs the c5 deficit" — R4, refuted by R9b. It
   is queueing at `c > max_num_seqs`, and chunked prefill in fact *protects*
   decode (turning it off cuts `tg_req` 44% at c4 while improving stagger and
   ttfr).
7. "Removing prefill removes the run-to-run variance" — R1-R4, broken three times
   (R5, R6, R8) for two different reasons, retired rather than patched.
8. "The ctx-vs-cold margin grows monotonically with concurrency" — R7, dead by
   R10: the sign flips at c4 and c5 on the token budget alone.
9. "The ctx inversion deepens with depth" — R3. ⚠ **NOW FULLY RETIRED BY R8c —
   this item used to say "-27% at d32768 (3 runs, never repeated) is the only
   surviving evidence". That evidence is gone.** R8c re-measured d32768 at runs=7
   at R1's own condition and read **+0.9%** (and **+6.9%** on the folded recipe)
   against R1's **-27.3%**. All three deep inversions have now vanished under
   better sampling — d65536 -17.0% -> **-1.2%** (R8), d131072 **-0.6%** (R5),
   d32768 -27.3% -> **+0.9%** (R8c). **No deep ctx-versus-Phase-2 inversion
   exists anywhere in this campaign's data, and none ever did.** Note the shape:
   every extreme in the campaign's inversion table was a 3-run pair and every
   7-run pair was moderate, and that was visible in the archives before R8c spent
   a second of box time. ⚠ **R22 confirmed the retirement on twice the sample and
   at both budgets.** Measured *within* single engine starts, and therefore
   immune to the position bias, the four well-sampled readings at this cell span
   **−1.04% to +6.93%** (R8c E +0.90%, R8c F +6.93%, R22 G +3.91%, R22 H
   −1.04%); R1's −27.28% sits **30 points outside all of them.**
10. "The -12% reproduction gap" — R0/R1, mostly undersampling. It is **-2.9%** at
    the pooled 14-run figure, and 3 of those 14 runs clear the board entry.

**Added by the phase-label correction pass (2026-08-22). Five more, and they are
the largest single batch the campaign has retired at once:**

11. "The `ctx_` phase is prefill-free and ~9x faster at prefill" — R1 to R9b.
    The ratio is `(depth+2048)/2048`, measured to within 4% in 29 of 30 archived
    phase pairs. **No `ctx_pp`-versus-`pp` comparison anywhere is retained.**
12. "The `ctx_` phase does no prefill, so it never staggers much" — R10's
    mechanism for the sign flip. Withdrawn at the premise; Phase 1 prefills
    `depth` tokens.
13. "Why does removing prefill work make the batch stagger worse?" — R12's
    sharpened open question 4, carried by the synthesis and by R13's pre-run
    prediction. **Dissolved.** Nothing is removed.
14. "The `ctx_` cells are the cheapest place in this campaign to measure a real
    effect" — R3, quoted in RESULTS.md for six rounds. Rested on 11 and on the
    already-retired quietness rule (7).
15. Open question 4 as posed — "do the `ctx_` prefix-caching phases deserve
    their own tuning?" They are not prefix-caching phases and the cache never
    hits. The cells stay worth winning; the framing is dead.

**Added by R13 and R13c. Three more, and the first is the campaign's central
mechanism:**

16. **"The `c>1` gap is admission stagger, and it is 83-93% of what remains"** —
    R10 through R12, the campaign's explanation for every `c>1` result it had.
    **Refuted by R13 with the instrument.** At `mnbt 98304` the scheduler reads
    `Waiting: 0` in 100% of loaded samples and the span ratio barely moves (1.70
    → 1.54 at c5). R13c confirmed it independently: the span keeps tightening
    between 32768 and 65536 with nothing waiting at either, then hits a floor of
    ~1.50 that no budget touches. The ratio is real and it is charged to the
    metric; **calling it admission is what is withdrawn.** ⚠ **The tail of this
    item used to read "no replacement mechanism is asserted — MTP acceptance
    dispersion is a candidate, not a finding." That candidate is now REFUTED
    too (item 22), and there IS a replacement: prefill-completion stagger.** See
    `THE MECHANISM CHAIN` above.
17. **"`tg128 @ d16384 c4` is 3.74x and `ctx_tg @ d16384 c4` is 6.16x"** — R13,
    superseded by R13c the same night. Same configuration, second engine start,
    pooled 14-run medians: **3.67x** and **6.15x** (⚠ the latter superseded as the
    widest margin by R13d's 6.21x at mnbt 131072). The margins survive; the
    decimals were a single draw.
18. **"Each new `max_num_batched_tokens` value costs a full torch.compile
    rebuild"** — R13's cost note, corrected by R13c at no cost. Start time tracks
    the **size** of the budget, not its novelty. Sweeping the flag is affordable.

**Added by R11. One more, and it is a methodology rule the campaign priced
rounds on for eight rounds:**

19. **"`runs=3` is adequate for `tg128 @ d16384`"** — R6, refuted by R11. R6 read
    σ/med **2.6%** at that cell and generalised it into the runs budget. Measured
    three times now, at three engine starts: **2.6% (R6) / 5.5% (R8) / 8.01%
    (R11)**. **σ is itself a draw**, and at 8.01% a 3-run median has a standard
    error near 5.8% — larger than most effects the campaign chased. The `c>=8`
    half of R6's rule survives (0.15–0.51% at c8/c16, where the batch averages
    many sequences per step); the c1 half does not. **runs=7 at c1, always.**
    Note the shape: this is the same error as items 1, 2 and 17 — a dispersion or
    a level measured once, generalised, and wrong on re-measurement.

**Added by R9c. Two more, and both were load-bearing for the round that retired
them:**

20. **"`--enable-prefix-caching` is worth 57% of `tg` at c4"** — R9b, carried by
    this synthesis and by `RESULTS.md`. **It is 2.414x**, and the 57% was two
    3-run medians taken four hours and one engine start apart. R9c re-measured
    both endpoints at runs=7 inside one session: 146.32 vs 60.60. The direction
    was right; the size was a cross-invocation artefact of exactly the kind this
    campaign refuted three times elsewhere (items 1, 2, 6).
21. **"Prefix caching off moves `mamba_block_size` from 16 to 32768, a 2048x
    change in Gated DeltaNet state granularity"** — R9b's leading suspect,
    quoted in open question 1 and in the R9c queue entry. **Wrong by two orders
    of magnitude.** `platforms/interface.py:911-918` overwrites the 16 with the
    aligned attention block size, so the true contrast is **2144 → 32768,
    15.3x**, and every archived engine log had been logging the real value all
    along. **No round ever ran under the 2048x condition; it never reached the
    engine.** Note the shape: this is the same error as item 4 — a value inferred
    from one source pass and never checked against the log that prints it.

**Added by R13b. One more, and it retires a whole line of reasoning rather than a
single number — read it before proposing any acceptance-based explanation of
anything the scheduler does:**

22. **"The span ratio's floor is MTP acceptance dispersion across the batch"** —
    R13's closing candidate, carried by open question 7, by this synthesis's R13
    bullet, by `RESULTS.md`, and by the R13b queue entry that specified the
    round. **REFUTED by R13b, which measured it per request rather than inferring
    it.** Acceptance dispersion acting alone gives a span ratio of **1.085**
    against an observed **1.499** — 17% of the excess, against a pre-declared
    refute threshold of 1.20.
    **Two distinct errors are being retired here and both generalise:**
    (a) **The wrong statistic.** R13's "1.44x spread against a measured 1.54"
    is max/**min**. The quantity that enters the span is max/**harmonic-mean**,
    which is strictly smaller — even fed R13's own widest logged range
    (2.77–4.00) it reaches only **1.19**, not 1.44. A dispersion figure quoted
    against a span figure must be the statistic the span is actually made of.
    (b) **The wrong samples.** Those 2.77–4.00 readings are 10-second batch
    aggregates from different runs and phases — **between-sample** variation.
    Measured **within** one batch, per-request acceptance max/min is **1.167**
    median over 35 requests. A ~42-step average concentrates hard, and it was
    always going to.
    **What this retires beyond R13:** every sentence in this file that offers
    acceptance as the reason a `c>1` batch's span is wide, and every proposal to
    buy the answer with more acceptance telemetry. **Do not re-open open question
    7 as an acceptance question.** ⚠ **And do not confuse this with R6's variance
    result, which survives untouched** — R6 is about the run-to-run σ of a
    *median over many verify steps* and acceptance genuinely drives that. Item 22
    is about the *within-batch spread across five simultaneous requests*. Same
    word, different quantity, opposite verdict.
    Note the shape: this is the same error as items 1, 2, 17 and 19 — a
    dispersion measured across invocations, generalised, and wrong when measured
    inside one.

**Added by R22. Two more, and the first of them is why every small number in this
file now needs a second look:**

23. **"The folded token budget is worth +6.36% on Phase 1 at `d32768 c1`"** —
    R8c, which reported it as NOT ESTABLISHED under its own conjunction rule and
    instructed that the protection round measure both budgets. **R22 did, and
    REFUTED it: the quantity R8c measured was not the one it named.** R8c ran
    arm E (8192) first and arm F (65536) second; R22 ran H (65536) first and G
    (8192) second, and **in 4 comparisons of 4 the arm that ran SECOND read
    higher** (+6.36, +0.37, +12.24, +6.89%, mean **+6.5%**). The budgets are
    swapped between the rounds, so a budget effect cannot produce that pattern
    and a position effect produces exactly it. **Comparing first arm against
    first arm — the contrast where the warm-up state is matched — the budget
    reads −1.08% (Phase 1) and +0.86% (Phase 2): inert on both, satisfying the
    conjunction rule R11 and R8c both declared.** With R11's +0.27% at d16384,
    **`max_num_batched_tokens` inertness at c1 is CLOSED and Phase 1's exception
    is withdrawn.** ⚠ **The position effect that replaces it is itself NOT
    established** — 4 comparisons, 2 sessions, **p = 0.25** — and is stated as a
    suspicion everywhere this file uses it. Note the shape: this is the same
    error as items 1, 2, 6 and 20 — a cross-invocation difference given a
    physical name — but it is the first time the campaign identified the
    *confound* rather than merely the wrong size.
24. **"σ/med 24.20% at `tg32 @ d32768 c1` is the noisiest cell the campaign has
    measured"** — R8c arm F, 7 runs, carried by this synthesis and by
    `RESULTS.md`. **R22 re-measured the identical configuration at runs=14 and
    read 11.39%** — a factor of 2.1. **A σ estimate from 7 runs is a draw like
    any other and carries roughly ±50% of itself.** What is retired is not the
    idea that this cell is noisy but the *record*: no "noisiest cell" claim
    should be made from a single arm again. Note the shape: this is item 19 one
    level up — a dispersion measured once and generalised.

### Refusals and broken gates — recorded, not dropped

The campaign's rule is that a gate that breaks and an arm that cannot run are
**results**, and get written down where the next reader will trip over them.
Three exist:

1. **R9's arm B refused to start.** `--no-enable-chunked-prefill` parses, warns,
   and then the engine dies: *"Chunked prefill is required for mamba cache mode
   'align'"*, and `align` is what prefix caching ON selects. One engine start
   spent for zero numbers, none invented. R9b later ran the arm from the legal
   side.
2. **R9b's `ctx_pp2048 < 1200` gate broke and the gate was wrong, not the arm.**
   It measured ~6100. Under the corrected phase labels the gate was
   **arithmetically impossible** — Phase 1 is charged 16384 tokens whether a
   cache exists or not, so its `pp` figure carries an 8x floor in the
   denominator. Overriding it on the engine's own counters was the correct call,
   **and recording it as a broken gate rather than dropping it is what made it
   diagnosable a round later.**
3. ⚠ **NEW — R9c's queued arm was REFUSED BY A VALIDATOR and could never have
   run.** The queue specified "prefix caching OFF with an explicit
   `-o mamba_block_size=16`". `vllm/config/vllm.py:2607-2618` in the pinned
   image raises at config validation: *"--mamba-block-size can only be set with
   --enable-prefix-caching"*, and `config/cache.py:145-148` says the same in its
   docstring. `mamba_block_size 16` + `max_model_len 32768` + caching off is
   **exactly** the refused combination. **The arm the queue specified would have
   died before the engine loaded.**
    **What it cost and what it bought:** nothing and a round. The refusal was
    found by grepping the validators out of the pinned image with a throwaway
    `docker run --rm --entrypoint bash` **before any box time was spent** — R9's
    open-question-11 rule, and the third consecutive round it has paid. R9c was
    then redesigned around the only legal lever (`--block-size` from the ON
    side) and ran. **The general lesson, which is the reusable half: an arm that
    a validator will refuse should be caught at the queue, not at the engine
    start. Any future round proposing to vary prefix caching and
    `mamba_cache_mode` independently must be refused at the queue** — the source
    read in open question 1 proves it is impossible in both directions.

Note what is NOT on this list: **any board margin.** Both sides of every `ctx_`
comparison are Phase 1 against Phase 1, so the standings are untouched at 8 won
/ 12 lost — and R13c's protection sweep then held all six `c4` rows in place from
separate engine starts. Item 7's premise also failed retrospectively — "removing prefill
removes the variance" was retired for breaking three times, and it turns out
nothing was being removed.

### COST LEDGER

Box time is grid time as reported by llama-benchy, plus engine starts at roughly
3 minutes each (6 for the large-budget arm in R9). Harness tokens are the
round agent's own accounting; R1, R2 and R5b did not record theirs.

| round | grid time | starts | tokens | what it bought | worth it? |
|---|---:|---:|---:|---|---|
| R1 | 349 s | 1 | — | 6 cells; 2 wins claimed; the parse-round.py fix | **mixed** — its headline figure was retired by R6 and its ctx figures are still 3-run |
| R2 | not recorded | 2 | — | the c4 win, verified; the units "correction" | **mixed** — the cell was real; the units proof was a tautology that misdirected nine rounds |
| R3 | 150.8 s | 1 | ~35k | the two widest deep-cell wins | **yes** for the cells; its "depth is flat" reading was wrong and stood five rounds |
| R4 | 315.7 s | 2 | ~55k | the concurrency curve; `mns >= c`; first telemetry | **yes** — the `mns` lesson unlocked R7/R9/R10 even though its mechanism story was wrong |
| R5 | 397.6 s | 2 (1 wasted) | ~60k | the deep end of the depth curve; acceptance seen live; one loss | **WORST RATIO OF THE CAMPAIGN** — ~50 min of box time, ~8x R3's, for four cells of which one was scoreable and it lost, at runs=3 so its curve point is the least trustworthy one we have. A wasted engine start on a silently-defaulted `-b depth`. Do not return to d131072 |
| R6 | **124 s** | 1 | ~45k | two open questions closed, one claimed figure revised down, the variance mechanism | **BEST RATIO OF THE CAMPAIGN** — two minutes of grid time changed how every subsequent round was priced |
| R7 | 638.6 s | 2 | ~55k | the tail shape; caught the aggregate-estimator break; acceptance vs concurrency | **yes** — recording two estimators cost nothing and stopped a 47% overstatement shipping |
| R8 | 322.5 s | 1 | ~50k | the depth curve corrected; a 13% overstatement retired | **yes, high** — five minutes of box time to find one of the two widest wins was overstated |
| R9 | 442.5 s | 3 (1 refused to start) | ~70k | the deficit confirmed within one invocation; the mechanism proved untestable by the obvious route; **the token budget discovery** | **yes, accidentally** — nothing it set out to do worked, and its by-product is the campaign's biggest lever |
| R9b | 440.4 s | 2 | ~85k | R4's mechanism refuted; prefix caching never hits; the phase labels are backwards | **yes** — most expensive in tokens, zero claimable cells, and two corrections that reach every `ctx_` row |
| R10 | 923.4 s | 1 | ~75k | units settled from source; c4 1.13x -> 3.15x; c16 gate halved | **best standings round** — and its largest result cost no box time at all |
| R12 | 359 s | 1 | ~65k | c2 and c5 transformed; the gap priced as 83-93% stagger | **yes** — the decomposition is worth more than either cell, even though R13 then refuted the "stagger" label on it |
| **R5c** | **0 s** | **0** | ~25k | the board-metric question closed against 34 archived records; the stagger proxy's validity limit found | **yes, free** — no box, no re-scrape, and it corroborated R10's source read from a second direction |
| **R13** | 490.1 s | 1 | ~85k | c4 to a claimed 3.74x and a record 6.16x; c5 to 0.73x and still lost; **the stagger model refuted with the occupancy log** | **yes, and not for the reason it ran** — it failed to take its target cell and its most valuable output is the refutation of the campaign's own mechanism |
| **ctx-CORRECTION** | **0 s** | **0** | not recorded | every `ctx_` row audited; the token-count error measured at 29 of 30 pairs; six claims withdrawn | **yes, free, and the largest single retraction batch of the campaign** — it reaches every `ctx_` row ever written |
| **R11** | **73.9 s** | 1 | ~70k | **the fold** — the c1 anchor at the knee value, `recipe.yaml` changed for the first time in the campaign; open question 13 answered free; R6's runs-budget rule refuted free | **the campaign's best ratio after R6** — 74 seconds of grid time to move the largest lever it found from a footnote into the shipped config, plus two by-products that cost nothing |
| **R9c** | 883.8 s | 4 | ~95k | `--enable-prefix-caching` priced at **2.414x on 14 runs** and decomposed **83% span / 17% decode / 0.7% hardware**; both endpoints re-measured in one session; the 2048x premise corrected to 15.3x; the queued arm shown to be validator-refused; **a proof that the flag's four effects cannot be separated in this engine**; the engine-log capture's third failure mode found and fixed | **yes, and not for the reason it ran** — its declared primary instrument landed inside its own dead zone and its deciding arm was confounded, yet **three of its five results cost no box time at all** and it retired two claims this synthesis was carrying |
| **R13b** | ~420 s (2 probe passes, 1 discarded) | 1 | ~120k | **open question 7 CLOSED** — acceptance dispersion refuted at **1.085 vs 1.499 observed**, and the floor identified as **prefill-completion stagger** (first starter 88.5 ms/verify-step vs 55–58 for its batch, corr −0.980); R13's "1.44x" retired as the wrong statistic on the wrong samples; **the campaign's first cross-client reproduction** (+1.75% / −1.46% / −2.63%); a fifth engine-log failure mode found from source at zero cost | **BEST MECHANISM RATIO OF THE CAMPAIGN** — ~7 min of grid to settle the question four rounds had been circling, and it refuted its own candidate rather than confirming it |
| **R13c** | 1353.5 s | 6 | ~90k | all six `c4` headline rows protected and standing; two tightened to pooled 14-run medians; **the budget curve and its knee at 65536**; the ~2% single-measurement error bar | **the campaign's best round on evidence per second** — it is the only systematic protection sweep, it told R11 which value to fold, and it corrected two of R13's own notes |

| **R21** | **815.5 s (784.5 + 31)** | 2 | ~95k | the **three-run audit**: four unaudited standings rows re-measured at runs=7, **all four moved UP**; `tg128 @ d131072 c1`'s recorded loss corrected **0.95x → 0.995x, a margin wrong by 10x**; R1's worst-sampled row (`tg32 @ d8192 c1`, σ/med 21.4%) **retired** and replaced; the campaign's thinnest claim (1.07x) **protected** and firmed to 1.08x; the last unaudited extreme in the phase-pair table collapsed (+19.1% → +4.00%); the audit-selection reading **confirmed five for five**; d131072 priced out for good | **yes — and see the verdict below, because the two arms are not the same purchase.** Arm B is arguably the best ratio in the campaign; Arm A is 96% of the bill and bought a correction rather than a cell |
| **R8c** | 228.5 s (117.6 + 110.9) | 2 | ~85k | the campaign's **last deep inversion retired** (-27.3% -> +0.9%, retired claim 9 fully dead); a **protection sweep on two 3-run rows** — one stands, one **failed upward by 31.6%** and corrected a standings margin from 0.72x to 0.92x; **`ctx_tg @ d32768 c1` found to be a dead heat** at the folded budget; **budget inertness at c1 confirmed at a second depth** (+0.37% vs R11's +0.27%); the **d32768 acceptance point** measured at two engine starts; audit pairs 43-44; the campaign's **noisiest cell** (σ/med 24.20% — ⚠ **since retired by R22 as a draw**) | **yes, high — and its most valuable output was the half nobody queued.** It was sold on a mechanism question that was already retired; re-framing it as a protection round before running is what made it worth the box. Four minutes of grid to retire a claim, correct a margin by 28% and surface the campaign's closest unclaimed cell |
| **R22** | 416.6 s (205.2 + 211.4) | 2 | ~105k | the campaign's **closest unclaimed cell settled as a LOSS** on a 45-run sample, with a **pre-declared claim rule honoured when it cost the cell** (one arm read 1.046x and was not promoted); **a POSITION BIAS found in cross-invocation arm comparisons** — 4 of 4, mean +6.5%, budgets swapped — which **refutes R8c's Phase-1 budget effect** and **closes budget inertness at c1 on both phases**; the deep-inversion retirement confirmed at double the sample and at both budgets; the **residency instrument recovered at c1** (19/19 loaded samples `(1,0)`); the **noisiest-cell record shown to be a sampling draw** (24.20% → 11.39%); audit pairs 45–46; four independent acceptance starts at d32768; 42 more zero-hit cache samples | **yes — and the verdict has to be argued, because it claimed no cell.** See below |

**Totals:** ⚠ **UPDATED FOR R22.** ~8,085 s of measurement grid time (≈135
minutes) across 34 engine starts (R22's two on top of the 32 counted before,
which had added R8c's two and R21's two to the 28 before them), of which two
produced nothing (R5's aborted invocation, R9's arm B that refused to start).
Roughly 7¾ hours of box wall clock. ~1,210k harness tokens across the eighteen
entries that recorded them (R1, R2, R5b and the `ctx_` correction pass did not).
Twenty board cells scored, eighteen win rows and twelve loss rows carried.
**Zero arena submissions — there is no login and none was ever attempted.**

**⚠ WAS R22 WORTH ITS BOX TIME? IT CLAIMED NO CELL AND INVALIDATED A CLASS OF
COMPARISONS, AND THE ANSWER IS YES — BUT THE REASON MATTERS MORE THAN THE
VERDICT.** This is the first round in the campaign whose output is entirely
negative: it took no cell, moved no standing, changed no config, and its main
result *subtracts* confidence from figures already published. Stated plainly:

- **What it bought for 12.5 minutes of box wall clock.** The campaign's last
  live prospect settled on its largest sample (45 runs, four engine starts), so
  no future round will spend on it again — and R22's own advice is **do not go
  back**, at 0.34 SE. A budget question R8c left explicitly open, **closed on
  both phases**. And a **methodology finding that reaches every small
  cross-invocation delta this file contains**, bought by a control that cost
  *nothing* — reversing the order of two arms that had to run separately
  anyway.
- **The negative result is worth more than the cell would have been.** Had the
  cell been claimed, the campaign would own a ninth win at 1.002x built on one
  arm — precisely the figure R13c's and R21's rules exist to prevent. Instead it
  owns a **pre-declared rule that bound when it hurt**, which is the only
  evidence anyone has that the campaign's other refusals were principled rather
  than lucky.
- **Against that, the honest cost.** R22's finding puts **every arm-to-arm
  reading at or below ~7% in this file in doubt**, R13c's six-point budget curve
  included, and it does so on a sample too small to establish (p = 0.25). A
  round that leaves the file *less* certain than it found it has to be judged on
  whether it named the next measurement, and it did: **the A-B-B-A round, ~25
  min, four invocations in one session**, which either establishes the bias or
  kills it.
- **The reusable lesson is the cheapest one in the ledger: the free control is
  the one to add.** R22's headline came from reversing an order, which cost zero
  seconds of grid and zero engine starts. R8c named this weakness and could not
  address it; R22 addressed it by changing the sequence of two invocations it
  was going to run regardless. **Every multi-arm round from here should reverse
  or randomise arm order, because the price is nothing and the term it controls
  is larger than most effects this campaign has chased.**

**⚠ DOES THE THREE-RUN AUDIT TAKE THE BEST-VALUE TITLE FROM R6? ARM B DOES;
THE ROUND AS A WHOLE DOES NOT — AND THE SPLIT IS THE POINT.** The question is
worth answering plainly because the audit was cheap and moved five rows across
two rounds, which is more standings figures than any other line of work in the
campaign touched.

- **On grid time per row corrected, R21's Arm B is the best purchase the
  campaign ever made: 31 seconds** of grid cleared two standings rows, one of
  them the worst-sampled figure in the file (σ/med 21.4%). Nothing else comes
  close per second. Add R8c's cheap half and the audit line looks
  extraordinary: **five standings figures corrected for well under five minutes
  of grid.**
- **But R21 as a whole cost 815.5 s, and 96% of it was Arm A** — seven runs at
  d131072 to convert a 5.5% published deficit into a 0.47% one. That is a real
  result (the file was overstating a loss by 10x, and the old figure was the
  kind of near-miss that invites an expensive tuning round) but **it bought a
  correction, not a cell, and it changed no decision the campaign will now
  take** other than "do not go back", which R5's ledger row already said.
- **R6 keeps the title, and the reason is that value is leverage, not
  arithmetic.** R6's 124 seconds **changed how every subsequent round was
  priced** — it found that σ tracks verify steps rather than concurrency, which
  set the run budget for everything after it. R21's corrections are worth having
  and they are confined to the rows they touched; they made the file honest, they
  did not make the next round cheaper. **The honest ranking is: R6 for leverage,
  R21 Arm B for raw ratio, and the audit line — R8c plus R21 — as the campaign's
  best value per second spent on *correcting what it had already published*,
  which is a category no other round competes in.**
- **The reusable lesson is the cost asymmetry inside the audit itself.** The
  four rows split into two arms whose bills differ by **25x** for the same
  number of rows cleared, purely because of depth. **Audit shallow rows freely
  and deep rows only when the margin is live** — R21's own Arm A is the worked
  example of paying 13 minutes to learn that a margin was not live after all.

**R11 belongs in the "cheapest rounds were the most valuable" pattern and it is
the cleanest instance of it:** 73.9 seconds of grid time — the shortest grid of
the campaign — decided the fold, answered an open question the campaign had been
unable to touch because every prior measurement was at `c>1`, and refuted a
sampling rule that had been pricing rounds since R6.

**The pattern in that table is the campaign's most reusable cost lesson: the
cheapest rounds were the most valuable ones.** R6 (124 s) and R8 (322 s) each
corrected a headline figure. **Three of the campaign's four largest results cost
ZERO box time** — what `tg_throughput` measures (R10, from the source), that
prefix caching never hits and the phases are labelled backwards (R9b + the
correction pass), and the board-metric closure (R5c) — and all three came from
reading the instrument or re-reading the archives rather than running the box.
Meanwhile the most expensive round by box time (R5) and the most expensive by
tokens (R9b) produced no claimable cell between them. **Read the instrument
before spending the box.** This queue under-scheduled control rounds and
source-reading for nine rounds running.

**The one place box time was unambiguously well spent is R13c**, and it is the
counter-example worth keeping: 22 minutes of grid time plus 18 of engine starts
bought a protection sweep on six published figures, a six-point curve that
retired R13's own fold value, and the campaign's only *measured* error bar. A
campaign that publishes figures should budget one round like this per dozen.

### OBSERVATIONS — campaign-wide sweep (per the `observe` skill)

Wider scopes (`stack:`, `box:`, `family:`, `model:`) were recalled before this
pass; most per-round facts were already stored by the round agents and are not
re-stored here. What follows is what was new at campaign level.

**Hardware.** Telemetry sessions across every round that sampled it agree — eleven at the round-12 checkpoint, and R13 and R13c added more without breaking the run: SM clock **2392-2398 MHz** median against a reported 3003 MHz ceiling, ≤79 °C, ⚠ **≤100.5 W — R22 raised this bound again (100.47 W, the first reading over 100 W), after R8c had raised it from the ≤97.3 W this line carried all campaign**, under every load the campaign produced — from a 7-minute shallow grid to 16-way concurrency to a 400-second d131072 run. The clock never moved with temperature or load. R1's outlying 2554 MHz is a bad reading, outnumbered ten to one. *Surprise: none left — this is the campaign's most reproduced fact.* *Headroom: the box runs at 80% of its clock ceiling by policy; if that policy is a fleet-wide arena condition then it is not headroom at all, and if it is local then ~20% of decode is sitting on the table. Nobody has established which, and changing it is Mat's call, not the loop's.* *Blindness: no memory-bandwidth counter was ever sampled — every bandwidth argument in twelve rounds is arithmetic, never measurement, which is precisely why the naive depth model went unchecked for so long.*

**System.** `sparkrun` cannot clear the page cache (no passwordless sudo), so every round in the campaign carries the same uncontrolled cold-read state. Uniform across rounds, so it biases nothing between them, but it is a floor on how quiet any single measurement can be and it is not measured. Image epoch was pinned and identical (`dgx-vllm-eugr-nightly:2026082102`) in all thirteen rounds, R13c's six invocations included — checked per round in `state.yaml`, which is what makes any cross-round comparison legitimate at all. Note the console line saying it is distributing `:latest` is not evidence of an epoch change; `container_image_longterm_ref` is the field to read.

**Serving stack.** The flag space is far more coupled than the campaign assumed: `--enable-prefix-caching` moves **four** things at once (`mamba_cache_mode`, the chunked-prefill requirement, `mamba_block_size`, and caching itself), and R9 spent an engine start discovering one of those the expensive way. R9b's practice — grep the validators out of the pinned image with a throwaway `docker run --rm --entrypoint bash` before writing the hypothesis — cost two minutes and cleared both arms in advance. Make it the default. *Headroom, UPDATED by R13c: `max_num_batched_tokens` was the campaign's largest unexplored axis and it has now been curved at c4 over six values, 8192 to 131072 — **the knee is 65536** and nothing above it buys anything. What remains unexplored is the same curve at OTHER concurrencies: at c16 even 32768 leaves the gate half-closed (`Running` 11 of 16) and sixteen d16384 prefills would need 262144, so the knee must move with `c` and nobody has measured where. A sweep is also cheaper than R13 warned — start cost tracks budget SIZE, not novelty, ~110–190 s across 8192–98304.* *Blindness: the scheduler log is the primary occupancy instrument and it was LOST in two of the four rounds that planned to use it; the working command is now proven (`docker exec <container> tail -f /tmp/sparkrun_serve.log`, verified live with `grep -c 'Running:'`).* ⚠ **R22 added the sampling half of that: R8c's arm F caught 11 of 11 samples reading `Running: 0` and could not carry its residency claim, which looked like a broken instrument and was cadence luck. At c1 the loaded window is narrow against the log's ~10 s cadence, so doubling to runs=14 recovered it — 19 loaded samples across two arms, 19 of them `(1,0)`, zero `Waiting` ever. Residency claims at c1 need runs=14, not runs=7.**

**Model.** MTP acceptance is now measured against depth (R5), concurrency (R7), the token budget (R10), prefix caching and chunked prefill (R9b). It moves with **depth** and it moves with **concurrency**; it does **not** move with any scheduler knob — flat at 2.85-3.09 acceptance length and 61.7-69.8% across every scheduling change tested, in four consecutive rounds. That is a genuinely useful negative: **MTP acceptance is ruled out as an explanation for anything the scheduler does on this model**, and ⚠ **R13b extended it from the batch mean to the per-request spread** — within one batch, acceptance dispersion accounts for 1.085 of a 1.499 span. The tail of this paragraph used to read "which is why every c>1 result in this campaign resolves to admission behaviour"; **that is withdrawn — admission was refuted by R13. Every `c>1` result resolves to prefill-completion stagger**, per `THE MECHANISM CHAIN` above. *Headroom, and it is the largest un-taken lever in the campaign: acceptance collapses from 93.6% to 47.7% between d16384 and d131072, and with `num_speculative_tokens=3` halving acceptance roughly halves tokens per verify step. The MTP module ships BF16 in every Qwen3.6-35B quant arm, so it is a full-precision draft head being asked to draft over long contexts. Calibrating or fine-tuning it on long-context text is a quality-neutral throughput lever — needs a training-infra decision, and is out of scope for this loop.*

**Workload and measurement.** The benchmark did not measure what the campaign thought, in three separate ways, and each was found by reading rather than by benchmarking: `tg_throughput` is a batch aggregate charged for admission stagger (R10); the `ctx_`/cold phase labels are inverted and the two phases are charged different token counts (R9b); prefix caching never hits (R9b). **A fourth was added after this pass: what the campaign called "admission stagger" is not admission (R13's `Waiting: 0`, confirmed by R13c's curve), so the mechanism behind three rounds of `c>1` interpretation was wrong as well as the units. ⚠ A fifth closed it: R13b supplied the replacement — prefill-completion stagger — and did it by writing a client of its own, because the field it needed goes to the HTTP response body and llama-benchy discards it. That is the fifth distinct way this campaign's chosen instrument turned out not to carry the quantity the round was about.** ⚠ **AND R22 ADDED A SIXTH THAT IS ABOUT THE PROCEDURE RATHER THAN THE INSTRUMENT: comparing two arms across two engine starts carries a position term the campaign never priced — in 4 comparisons of 4 the second arm read higher, mean +6.5%, with budgets swapped so no budget effect explains it.** Not established (p = 0.25) and not a clock effect (2395.7 vs 2395.4 MHz), but if real it means the campaign's `±2.5% reproduction floor` was measured without controlling the one variable that moves it. *Headroom: the fix is free — reverse or randomise arm order in every multi-arm round, which is exactly how R22 found this.* *Blindness: no round before R22 recorded which arm ran first, so the position term cannot be retro-fitted to the archives — it can only be measured forward, by the A-B-B-A round.* *Surprise: the headline metric is a **scheduling** measurement wearing a throughput's units — R12 moved it +67.6% at c2 while the sustained hardware ceiling moved -0.5%, and R13c reproduced that shape across a whole curve (`tg` +233%, `peak_thr` +14%).* *Blindness, and this is the sharpest one left: the prefill cells. Our `pp2048 @ d32768 c1` reads 295.71 against 4644.54 for another vLLM NVFP4 entry in the same board cell — a 15x gap — while our decode rate sits within 3% of what a like-for-like incumbent's headline requires. A 15x like-for-like gap in one metric family and a 3% gap in another is the signature of a definition mismatch, not of a slow box, and nobody has read `pp_throughput`'s definition or the board's prefill test-type mapping.*

**Process and cost.** Covered in the ledger above. One addition: the campaign's own predictions got sharply better once they were built by **decomposing the metric** rather than by scaling the previous round's percentages — R12 was the first round where both headline bands held, and it built them from `tg = c x tg_req / stagger`. R10 and R12 both wrote the same post-mortem: *the mechanism section was right and the numeric band was wrong, in the same document*, because the band was set by scaling while the generating model sat one paragraph above. That is a repeatable failure and it has a repeatable fix.

Memories written by this pass (widest true scope, deduped against existing):
one `stack:vllm` lesson on cross-invocation inference and the one-sided
survival of flattering draws; one `stack:vllm` lesson on reading the
instrument's source before spending the box; one `stack:vllm` idea on the
unexplained prefill gap; one `box:spark-6f0e` lesson that twelve rounds found
no hardware-limited effect; one `family:` retraction covering the ctx-vs-cold
regularities; and one campaign `[COST]` total.

### Open questions that are genuinely still open

1. **Why is `--enable-prefix-caching` worth 2.414x of the headline metric when it
   never hits?** (Posed as "57%" until R9c re-measured it.) ⚠ **NARROWED BY R9c,
   AND ITS PREMISE CORRECTED — read this version, the one above it was wrong in
   two ways.** (a) The flag is worth
   **2.414x**, not 57%, on R9c's 14 re-measured runs (146.32 vs 60.60), and the
   decomposition closes exactly: **83% batch span, 17% per-request decode, 0.7%
   hardware** (`peak_throughput` 287 vs 289). The span is made of **ttfr
   dispersion measured directly at 1516 ms vs 6269 ms**. (b) The suspect was
   stated as `mamba_block_size` 16 -> 32768, a 2048x change. **It is 2144 ->
   32768, a 15.3x change** — `platforms/interface.py:911-918` overwrites the 16
   with the aligned attention block size, and all seven archived engine logs
   carry the same `Setting attention block size to 2144` line. **R9c ran the
   granularity arm from the only legal side** (`--block-size 32768` with caching
   ON) and it **explains at most 42% of the span gap** while bringing a 2.03x
   per-request decode penalty the caching-OFF arm does not have — so
   granularity is **not** the whole answer.
   **AND THE REMAINING HALF IS NOT SEPARABLE BY ANY FLAG IN THIS ENGINE.**
   Prefix caching ON forces `mamba_cache_mode: align`; OFF forces `none`;
   `mamba_block_size` may be set only with caching ON
   (`config/vllm.py:2607-2618`) and is then overwritten by `block_size` under
   `align`. **Do not queue another benchmark here.** Reword the question as
   *what does `align` mode do to prefill chunk scheduling* and answer it by
   reading the mamba2 kernel's chunking path. R9c also left one direct
   observation behind for whoever does: **arm N does not hold full residency —
   `(3,1)` in 7 of 13 loaded samples at `c4`/`mns 4` with 3.34M tokens of KV
   free** — so R7's plain-queueing account is live again and unexplained.
   ⚠ **SHARPENED BY R13b, and the reword above turns out to be exactly right.**
   The 83% batch-span term is **first-token spread**, i.e. prefill-completion
   stagger (`THE MECHANISM CHAIN`), so the question is no longer "what is the
   span made of" — it is answered — but specifically **why does `align` mode make
   five prefills finish 4.13x further apart**. That is a question about the
   mamba2 chunking path and it is still a reading task, not a benchmark. **One
   cheap measurement would help and it is not a benchmark either:** run R13b's
   per-request probe against a caching-OFF engine and read the first-token
   spread directly instead of inferring it from aggregates.
2. ~~**Why does removing prefill work make the batch stagger WORSE?**~~
   **CLOSED — the question is dissolved, not answered.** It presupposed that the
   `ctx_` phase removes prefill work. It does not: `ctx_` is Phase 1, the
   context load, which prefills `depth` tokens against Phase 2's `depth + 2048`.
   The regularity underneath it (1.17 vs 1.13, 1.80 vs 1.57, 2.12 vs 1.70) was
   separately **refuted by R13** at `mnbt 98304`, where Phase 1 staggers LESS at
   both arms. Both halves gone. **Do not spend a cell here and do not pose a
   third form of it.** The `ctx_` cells remain real board cells worth winning —
   one of them, `ctx_tg @ d16384 c4`, is the campaign's widest margin — ⚠ now
   **6.21x at mnbt 131072** (R13d), was 6.15x at mnbt 98304.
   R13c added the last nail: the ctx-vs-Phase-2 sign is a smooth **function of
   the token budget** that crosses zero twice (+4.8% / −19.9% / −12.6% / −4.8% /
   −0.8% / +2.6% across the six budgets). Every round that read its local sign as
   a rule was reading one point on a curve.
3. **What accounts for the two thirds of the depth term the bandwidth model does
   not predict, and what makes the curve steepen?** -16.8% measured against -44.8%
   naive. MTP acceptance decay is the candidate and has never been measured
   unconfounded across depths.
   ⚠ **PARTLY FED BY R8c, WHICH SUPPLIED THE MISSING MIDDLE POINT — but did NOT
   close this.** Acceptance at `d32768 c1` reads **87.0% / length 3.61** and
   **88.9% / 3.67** at two independent engine starts, reproducing each other to
   under 2%. Against R5's 93.6% at d16384 and 47.7% at d131072 the decay is
   **gentle over the range where the depth term is -8.8% per doubling and
   collapses beyond it** — the right shape to be the steepening term. **But the
   endpoints are still R5's, from other invocations at other conditions, so only
   the middle point is controlled.** The measurement that closes this is
   unchanged: **R8b's two-depths-under-one-engine-start design** (item 6). Do not
   treat the three-point table as the answer. ⚠ **R22 doubled the middle point's
   support without closing anything**: four independent engine starts at
   `d32768 c1` now span **3.56–3.71 acceptance length and 85.4–90.2%**, the
   campaign's best-reproduced quantity at this depth, and **the budget does not
   move it** (the spread within a budget is as large as between budgets). The
   endpoints are still R5's, still taken at other conditions. **Four points at
   one depth do not fix two endpoints at others; open question 3 stays open.**
4. **Is our `pp_throughput` the same quantity the board ranks?** A 15x
   like-for-like gap says probably not. Zero box time to check.
5. **Does the c16 aggregate keep climbing past 16?** Still climbing at +24% (c8
   -> c16) and the gate is only half-open even at mnbt 32768. c32 is a
   one-invocation question. R13c settled the budget question **at c4 only** — the
   knee is 65536 there, and sixteen concurrent d16384 prefills would need 262144
   — so a c32 or c16 round should now sweep the budget rather than fix it, and
   should expect the knee to move with `c`.
6. **Is the box's 80%-of-ceiling clock a fleet-wide arena condition or a local
   one?** Closed as a *measurement* question — the clock is flat policy — but the
   headroom question behind it was never asked of anyone who would know.
7. ✅ **ANSWERED BY R13b — CLOSE THIS. What is the span ratio's ~1.50 floor made
   of?** It is **prefill-completion stagger**, and it is the third candidate, not
   either of the first two. For four rounds the answer was "admission stagger";
   R13 refuted that with `Waiting: 0` in every sample. The replacement candidate
   was **MTP acceptance dispersion**, and **R13b refutes that too**: measured per
   request through `--per-request-spec-decode-metrics detailed`, acceptance
   dispersion acting alone gives a span ratio of **1.085** against an observed
   **1.499** — 17% of the excess. Within one batch, per-request acceptance
   max/min is **1.167** (35 requests); R13's "1.44x" was max/**min** of pooled
   between-sample readings, and the statistic that enters the span is
   max/**harmonic-mean**, which even on R13's own widest range reaches only 1.19.

   What it actually is, measured directly: `corr(start stagger, ms per verify
   step) = −0.980` and `corr(verify steps, decode duration) = +0.142` over 35
   requests. **The five prefills do not complete together.** The first request to
   finish prefill decodes at **88.5 ms/step** while the other four run at
   **55–58 ms/step**, because its verify steps are co-scheduled with the batch's
   remaining chunked prefill — and the batch decode span is measured from that
   request's first token. First-token spread **1.26 s** on a clean decode of
   ~2.3 s gives `1 + 1.26/2.30 = 1.548` against the observed 1.499, no fitted
   parameter.

   **`Waiting: 0` was never evidence against this**, because `Running` counts a
   prefilling request and a decoding one identically and the engine log has no
   column that separates them. It also explains R13c's curve: more budget means
   fewer prefill chunks and a tighter spread, so the ratio falls to 65536 with
   nothing waiting — then floors, because the prefill work itself cannot be made
   simultaneous across five requests by any budget.

   ⚠ **The terms are substitutes, not addends.** Removing the first-starter
   penalty alone *raises* the ratio to 1.634, the span passing to the last
   starter. Do not quote a three-way partition. **Nobody should re-open this as
   an acceptance question.**
8. **NEW. Are single measurements in this campaign systematically ~2% high, and
   if so why?** Six of six protected rows reproduced low, mean −1.94%, p ≈ 3% on
   a coin. Decode-side session effect and first-measurement bias are both live
   and R13c could not separate them. The `pp2048` control cannot decide it —
   `pp` is prefill. A cheap test exists: re-run one arm at a different time of
   day and see whether the sign follows the clock or the ordinal.
   ⚠ **WEAKENED BY R9c.** Its arm P reproduced R9's 143.08 at **+2.27%, HIGH** —
   the first same-cell repeat in the campaign to break the run — while arm N
   reproduced **−2.46% low** minutes later on the same box, and G2 reproduced G1
   at −1.81%. **Two arms measured minutes apart moving in opposite directions by
   the same magnitude is what a ±2.5% reproduction noise floor looks like, not
   what a systematic looks like.** The run is now 8 low / 1 high / 1 low and the
   coin argument is materially weaker. Do not treat the −1.9% as a correction to
   apply.
   ⚠ **RE-POSED BY R22, AND THIS IS NOW THE MOST CONSEQUENTIAL OPEN QUESTION IN
   THE FILE.** The question was always "is there a systematic, and what sets its
   sign". R22 supplies a candidate the earlier readings could not see because
   nobody recorded it: **arm position**. In 4 comparisons of 4, the arm running
   **second** read higher, mean **+6.5%** — larger than the ±2.5% floor this
   question has been working with, and it would mean R9c's own arms (P first, N
   later) were confounded in exactly the direction they read. ⚠ **Not
   established: p = 0.25 on a sign test, and it is not a clock effect (2395.7 vs
   2395.4 MHz) nor thermal drift in the obvious direction (the second arm ran
   warmer and faster).** The cheap test this item asked for — "re-run one arm at
   a different time of day and see whether the sign follows the clock or the
   ordinal" — has been superseded by a better one that also answers it:
   **the A-B-B-A round**, four invocations in one session at budgets
   8192 / 65536 / 65536 / 8192, ~25 min. If position is real, arms 3 and 4 read
   above arms 1 and 2 regardless of budget; if the budget matters, arms 2 and 3
   separate from 1 and 4. **Until it runs, treat every cross-invocation delta at
   or below ~7% in this file as unresolved.**

### What to run next, in priority order

1. ~~**R11 — the fold decision.**~~ ✅ **DONE, and it folded.** `tg128 @ d16384
   c1` at `mnbt 65536` reads **112.92** against the 112.62 anchor — **+0.27%**,
   0.07 standard errors — and the Phase-1 partner is inside its own noise
   (−4.15% at 0.89 SE on a cell with σ/med 10.21%). Both routes by which the
   budget has ever moved this metric were measured absent at c1: residency
   `(1,0)` in 4 of 4 loaded samples, and `tg == tg_req` exactly, so the span
   ratio is 1.000 by assignment. **`recipe.yaml` now carries
   `max_num_batched_tokens: 65536`** and eight of the eighteen win rows are the
   shipped config. See the `Round 11 outcome` section, and read the epoch warning
   at the top of this synthesis before comparing anything to a pre-fold row.

   **⚠️ The one thing R11 did NOT buy, and it is the cheapest round left:
   `mnbt 65536 + mns 4` at c4.** The 3.71x row was measured at `mns 5`; the
   recipe ships `mns 4`. Three measurements at mnbt 32768 across mns 4/5/16 span
   2.9%, and mns 4 holds full `(4,0)` residency at c4 from 32768 up, so the
   recipe should land within a few percent — **but nobody has measured it, and
   until somebody does, no row in `RESULTS.md` states what the recipe actually
   produces at the cell the campaign cares most about.** One invocation, c4 only,
   runs=7, ~220 s grid + ~180 s start.
2. **The prefill metric check — zero box time.** Read llama-benchy's
   `pp_throughput` definition and the board's prefill test-type mapping. The last
   two times someone read the instrument instead of inferring from it, the
   campaign got its two largest results. Do this while a benchmark runs.
   **Sharpened by the correction pass, and one blind alley is already closed:**
   `pp2048` is charged 2048 tokens for `depth + 2048` of real work, but
   rescaling our figures by that factor does NOT void the prefill losses — the
   board's entries come through the same CSV and carry the same understatement,
   so it cancels. What the check must explain instead is a *shape* disagreement:
   our Phase-1 rate falls with depth (6148.56 → 2803.17) while the board's
   `ctx_pp` incumbents rise (775123 → 945271). Start there.
3. ~~**R9c — separate prefix caching from `mamba_block_size`.**~~ ✅ **DONE, and
   it did NOT settle the question — see the revised open question 1.** The arm
   as queued (caching off + `mamba_block_size=16`) is **refused by a validator**
   and could never have run; the premise behind it (2048x) was **wrong by two
   orders of magnitude**; and the legal substitute (`--block-size 32768` with
   caching ON) came in at `R_span` **1.359, inside its own pre-declared dead
   zone**, while collapsing KV capacity by 87%. What the round did buy: both
   endpoints re-measured at runs=7 in one session (**146.32 vs 60.60 = 2.414x**),
   the 83%/17% span-versus-decode split, and a **proof that the four things the
   flag moves cannot be separated in this engine**. See the `Round 9c outcome`
   section. **Do not re-queue this as a benchmark.**
4. ~~**R13d — repeat `ctx_tg @ d16384 c4` at `mnbt 131072`.**~~ ✅ **DONE.**
   The repeat read **170.16** (−2.99% on R13c's 175.40). **The pooled 14-run
   median is 171.77 = 6.21x, which takes the widest-margin title from the mnbt
   98304 row's 6.15x — by 0.83%, a bookkeeping change and not a discovery.**
   R13c's 6.34x is retired as the high draw it looked like. The cell is closed
   and must not be measured a third time. See the `Round 13d outcome` section.
5. ~~**R8c — re-measure `ctx_tg @ d32768 c1` and its Phase-2 arm at runs=7.**~~
   ✅ **DONE, two arms, 2026-08-22, and it did more than retire the inversion.**
   The -27.3% read **+0.9%** at runs=7 at R1's own condition, so **retired claim
   9 is now fully dead** and no deep inversion survives anywhere. Its larger
   result was the protection half: `tg32 @ d32768 c1` **STANDS** (115.56 ->
   109.62, -5.14%; pooled 10-run **112.59 = 4.83x**), while
   `ctx_tg32 @ d32768 c1` **FAILED its band upward by 31.6%** — R1's 84.03 was a
   3-run LOW draw, so that cell was **0.92x, not the 0.72x carried all
   campaign**, and read **1.002x on the folded recipe: a dead heat, deliberately
   not claimed.** ⚠ **BOTH TAILS SUPERSEDED BY R22 (item 9): the 1.002x is
   RETIRED and the cell is a LOSS at 0.987x, and the σ/med 24.20% "noisiest
   cell" record re-measures at 11.39%.** By-products that stand: budget
   inertness at c1 confirmed at a **second depth** on Phase 2 (+0.37%, against
   R11's +0.27%), the d32768 acceptance point measured twice, and audit pairs
   43-44. See the `Round 8c outcome` section.
6. **R8b's acceptance-vs-depth measurement**, riding along with any deep round —
   d16384 and d65536 under one engine start with the engine log captured. It is
   the missing half of open question 3 and it costs nothing extra now that the
   capture command is proven (`docker exec <container> tail -f
   /tmp/sparkrun_serve.log`; `docker logs -f` does NOT work on this image and
   cost R12 its occupancy instrument).
7. ✅ **DONE — R13b. Do not re-queue.** Per-request MTP acceptance at `c>1`, and
   it **refuted the candidate and closed open question 7 anyway**. This item's
   own instruction — check the engine log first — was answered "no, and it does
   not matter": the field goes to the **response body**, not the log, so the
   measurement was available all along through a client of our own.
   `sparkrun benchmark perf` could never have delivered it, because llama-benchy
   receives the field and discards it. The floor is prefill-completion stagger;
   see item 7 of the numbered section above.

8. **NEW — R13c-probe: re-run R13b's probe at two more budgets, and once with
   prefix caching OFF.** This is the one soft link in `THE MECHANISM CHAIN`
   (link 2) and the one inferred step in the R9c identification, and the same
   probe closes both. The probe already exists
   (`experiments/r13b-perreq-probe/`), it needs no llama-benchy grid, and each
   batch is ~8 s of decode on an engine that is up anyway. Measure the
   **first-token spread** at `mnbt 16384` and `65536` at c4 or c5 — the chain
   predicts it falls with budget and floors where the span floors — and once with
   `--no-enable-prefix-caching`, where it predicts ~6 s. **Ride it along with
   whatever round is next; do not buy an engine start for it.** ⚠ Instrument
   only — `recipe-r13b-perreq.yaml` must never be folded, and no row it produces
   is scoreable.

9. ~~**Protect `ctx_tg @ d32768 c1` at BOTH budgets.**~~ ✅ **DONE — R22, and it
   closed the cell as a LOSS.** Two arms at runs=14, both budgets, one engine
   start each, with the arm order **reversed** from R8c's as a free control.
   R8c's 117.65 read **109.41 (−7.00%, inside its band)**, so the **1.002x dead
   heat is RETIRED**; the pooled 21-run median at the folded budget is
   **113.37 = 0.966x** and the pooled 24-run median at the pre-fold budget is
   **115.86 = 0.987x**. The pre-declared claim rule (clear **120.53**) was
   **missed by 6.1%**, and ⚠ **the arm that read 1.046x was NOT promoted.**
   **Counts stay 8 won / 12 lost and there is no cell left that box time can
   flip.** ⚠ **Do not re-run it** — 0.987x is 0.34 SE on the campaign's largest
   sample. The round's larger output became **item 10**. See the `Round 22
   outcome` section.

10. ~~**the A-B-B-A position-bias round**~~ ✅ **DONE — R23, 2026-08-22, and the
    answer is NO: the position bias is REFUTED.** Four arms at
    `tg128 @ d16384 c1` (R11's fold anchor, not the cell this entry suggested —
    the fold question lives at d16384), runs=7, budgets 8192 / 65536 / 65536 /
    8192, one sitting, five engine starts, zero crashes. Position read four ways:
    **−4.40, −0.91, +0.71, +2.84%, mean −0.44%, p = 1.0**; the six adjacent
    different-config pairs split 3 up / 3 down. Clocks identical across the five
    starts (2392–2398 MHz loaded), box warmed 16 °C without throttling.
    **R11's fold STANDS** on a drift-free **−1.76%** (Phase 2) / **+4.91%**
    (Phase 1, band edge), and `recipe.yaml` is untouched. Free rider: the shipped
    recipe measured at c4 for the first time (**179.34 = 3.84x**). ⚠ **Do not
    re-queue this**, and do not re-attach the "check which arm ran first"
    instruction to any delta — what replaces it is a **symmetric ±5%** arm-to-arm
    spread on identical configurations. See the `Round 23 outcome` section.
    The original entry, kept for the record:
    R22's free order-reversal control found
    that **in 4 comparisons of 4, across two rounds and four engine starts, the
    arm running SECOND read higher** (mean **+6.5%**), with the budgets swapped
    between rounds so no budget effect explains it. ⚠ **It is NOT established**
    — 4 comparisons from 2 sessions, **p = 0.25** on a sign test — and that is
    exactly why it must be settled rather than assumed: **it decides how much of
    this campaign's small-delta arithmetic is real.**
    **Design: four invocations in ONE session, same probe, budgets
    8192 / 65536 / 65536 / 8192.** If position is real, arms 3 and 4 read above
    arms 1 and 2 **regardless of budget**; if the budget matters, arms 2 and 3
    separate from 1 and 4. The two readings are orthogonal, which is the point of
    the design. Run it at the cell R22 measured (`ctx_tg32` / `tg32 @ d32768
    c1`) so the four new arms pool with the 45 runs already there, and take the
    per-arm run budget at **runs=7** — the contrast is a ~6.5% effect, not a
    0.24% one, and four arms at runs=14 does not fit the estimate. **~25 min,
    four engine starts.** ⚠ **Declare the reading thresholds before the run**, as
    R22 did, and record which arm ran first in every row — no round before R22
    did, which is why the bias cannot be retro-fitted to the archives.
    **What rides on it:** if position is real, **R9c's ±2.5% reproduction floor
    is an underestimate** and every arm-to-arm reading at or below ~7% in this
    file — R13c's six-point budget curve included — needs a caveat attached
    permanently. If it is not, the campaign's small deltas are restored and the
    finding costs 25 minutes. **Either answer is worth the box time; that is
    rare enough to put it first.** ⚠ **What does NOT ride on it: the knee at
    65536.** A 6.5% bias cannot manufacture a +233% effect, and no large result
    in this campaign is at risk.

**R13 as originally queued — "c5 at `max_num_batched_tokens 81920`" — is DONE
and it did not take the cell.** It ran at 98304, reached 0.73x, and its premise
(c5's gap is 93% admission stagger) has since been withdrawn. Do not re-pose it.

Not worth running: anything at d131072 (~8x R3's box time, the cell is lost and
was never tunable within the campaign's rules); any further budget increase at c4
(the curve knees at 65536 and 131072 buys −1.4%); any round premised on the
`ctx_` rows being the cached pass; any round premised on admission stagger
being the `c>1` mechanism; and ⚠ **any round premised on MTP acceptance
dispersion explaining the span — refuted by R13b at 1.085 against 1.499, retired
claim 22, and more acceptance telemetry will not change it.** ⚠ **And, added by
R22: any further repeat of `ctx_tg @ d32768 c1` — the cell is closed at 45 runs
across four engine starts, the margin is 0.34 SE, and no affordable run budget
resolves it. It joins `tg128 @ d131072 c1` in the priced-out category.**
**And nothing is ever submitted to the arena — there is no login.**

### HANDOFF

**Start here and stop here — this revised synthesis is the whole handoff, and as
of 2026-08-22 (post-R22, its ninth revision) it post-dates every round block in
this file: the `ctx_` correction, R13c, R13d, **R11** (the fold), **R9c**,
**R13b** (which closed the mechanism), **R8c**, **R21** (the three-run audit),
and **R22**, which ran last, closed the campaign's final scoreable cell and
found the position bias. You do not need to read them.**

**The state.** ⚠ `recipe.yaml` is **NO LONGER the one the campaign opened with**
— R11 folded `max_num_batched_tokens: 65536` into it on 2026-08-22, the single
change in the campaign's history, with the reasoning written into the file
itself. Seventeen rounds plus three no-box-time passes are archived under
`experiments/`. `RESULTS.md` carries **8 won cells over 18 rows, 12 lost,
and the unscoreable remainder**, every row naming its configuration and every
retired figure marked as retired. **Eight of the eighteen win rows are now the config the
recipe ships**, after R11's fold; the rest name a scheduler width (`mns 5`,
`mns 16`) or a budget other than 65536 and remain genuine mutations. One image epoch throughout
(`dgx-vllm-eugr-nightly:2026082102`), so every number in the file is comparable
to every other. Nothing has ever been submitted to the arena and nothing should
be — there is no login.

**R11 is DONE and the token-budget lever is now the config, not a footnote.**
The fold was the single most consequential thing outstanding and it landed: the
budget is inert at c1 (+0.27% on the anchor), so `recipe.yaml` carries
`max_num_batched_tokens: 65536` and no baseline, depth-curve point or margin
moved. **Read the epoch warning at the top of this synthesis before comparing any
new measurement to a row labelled "mnbt 8192 — PRE-FOLD recipe".**

**R9c is DONE and it closed a queue entry rather than a cell.** It moved no
standing, changed no config and produced twelve NOT SCOREABLE rows. What it
bought: `--enable-prefix-caching` priced at **2.414x** and decomposed **83% batch
span / 17% per-request decode / 0.7% hardware**; the "57%" and the "2048x
`mamba_block_size`" claims retired (items 20 and 21); and a **proof from source
that the flag's effects cannot be separated in this engine, so open question 1's
remainder is a reading task and must never be re-queued as a benchmark**. Its
queued arm was **refused by a validator** and is recorded above under refusals.

**R13b is DONE and it closed the campaign's mechanism story.** It
moved no standing and produced no scoreable row. What it bought: the span
ratio's ~1.50 floor identified as **prefill-completion stagger** — the first
request to finish prefill decodes at **88.5 ms per verify step against 55–58 ms
for the rest of its batch**, `corr = −0.980` over 35 requests — and the
replacement candidate (**MTP acceptance dispersion**) refuted at **1.085 against
1.499 observed** on the way. **Two mechanisms are now dead and one is live**, and
the live one is the same physical term as R9c's 83% batch span: see
`THE MECHANISM CHAIN` above, which is the section to read if you read only one.
**Nobody should re-open this as an acceptance question** (retired claim 22), and
nobody should re-derive it — the chain's one soft link is named there, it is
cheap, and it is link 2. R13b also found the fifth distinct engine-log failure
mode at zero cost: `--per-request-spec-decode-metrics` writes to the **HTTP
response body**, and llama-benchy receives the field and discards it, so
`sparkrun benchmark perf` could never have answered the question. Its probe was
the campaign's **first cross-client reproduction** (+1.75% / −1.46% / −2.63% on
`tg` / `tg_req` / span against R13's c5 cell). `recipe-r13b-perreq.yaml` is an
instrument and must never be folded.

**R8c IS DONE AND IT IS THE ROUND THAT FIRST CHANGED A NUMBER IN THE
STANDINGS — UPWARD.** Two arms at `ctx_tg32` / `tg32 @ d32768 c1`, runs=7. It
retired the campaign's **last deep inversion** (−27.3% → **+0.9%**; retired
claim 9 is dead outright, and `THE MECHANISM CHAIN` explains why it had to be:
at `c1` the chain is silent by construction, so a surviving −27% would have been
an effect nothing in this campaign could explain). Its **protection half is the
part that matters**: `tg32 @ d32768 c1` **stands** and now carries a pooled
10-run **4.83x**, while `ctx_tg32 @ d32768 c1` **failed its band upward by
31.64%** — R1's 84.03 was a 3-run **low** draw, the cell is **0.92x, not the
0.72x this file published for eleven rounds**, and on the folded recipe it read
**117.65 against a 117.37 incumbent**. That last figure was **a dead heat and
was NOT claimed** (one measurement, +0.24%, 0.06 SE), which made a 125-entry
crowded cell the closest unclaimed cell in the campaign. ⚠ **R22 then ran the
protection round it earned and the dead heat did not survive: 117.65 → 109.41,
the 1.002x is RETIRED, and the cell is a LOSS at 0.987x on 45 runs. R8c's
refusal to claim it on one measurement was correct.** **The reusable lesson
is in the rewritten three-run warning above: this section's own "every 3-run
median came in high" rule was a small-sample artefact of which figures anyone
bothered to re-measure, and the campaign made exactly the error it was
warning about. Audit the unflattering figures first.**

**R21 IS DONE, IT RAN LAST, AND IT IS THE ROUND THAT TURNED R8c's CORRECTION
INTO A PATTERN — AND INVERTED WHAT THIS FILE HAD BEEN WARNING ABOUT.** It worked
the priority re-measure list: two arms, `runs=7`, each reproducing its row's
original pre-fold configuration with an explicit `-o max_num_batched_tokens=8192`
and the two near-zero-σ `pp` figures as the reproduction control (+0.35% /
+0.30%, so Arm A really is R5's invocation). **Four rows moved and all four moved
UP.** Three stood inside ±10% and pooled (`ctx_tg @ d8192 c1` → **127.64**,
`tg128 @ d131072 c1` → **81.22**, `ctx_tg128 @ d131072 c1` → **77.52**); one
failed upward at **+16.54%**, retiring R1's `tg32 @ d8192 c1` outright.
**No cell changed hands and no loss flipped — the counts stay 8 won / 12 lost.**
The product is a margin: `tg128 @ d131072 c1` was published as a **5.5% loss and
is short by 0.47% — 0.11 SE**, a dead heat we are on the wrong side of, **not
claimed** and ⚠ **not to be re-run** (0.11 SE is unresolvable at any affordable
budget, and that arm was 96% of the round's grid bill). Free by-products: the
campaign's thinnest claim (`ctx_tg @ d8192 c1`, 1.07x over best vLLM+NVFP4)
**survived and firms to 1.08x**, and the last unaudited extreme in the
phase-pair table collapsed (+19.1% → +4.00%), so every extreme in that table is
now known to have been a 3-run artefact.

**⚠⚠ R22 IS DONE, IT RAN LAST, AND IT DID TWO THINGS — THE SECOND OF WHICH IS
WHY A COLD READER SHOULD NOT QUOTE A SMALL NUMBER OUT OF THIS FILE WITHOUT
READING THIS PARAGRAPH.**

**(1) The last scoreable cell is closed, as a LOSS, and the rule held when it
cost us the cell.** `ctx_tg @ d32768 c1` — the 125-entry cell R8c left at a
**1.002x dead heat** — was re-measured at **runs=14 at both budgets**, one
engine start each. R8c's 117.65 read **109.41 (−7.00%, inside its band)**, so
**the 1.002x is RETIRED**; the pooled 21-run median at the folded budget is
**113.37 = 0.966x**, the pooled 24-run median at the pre-fold budget is
**115.86 = 0.987x**, and R22's **pre-declared claim rule** — pooled must beat
117.37 by more than 1 SE, i.e. clear **120.53** — was **missed by 6.1%.**
⚠ **One arm read 122.80 = 1.046x, comfortably over the incumbent and on the
largest sample ever taken at that cell, and it was NOT promoted**, because it is
one arm at one position in one session. **That refusal is the point of the
round. The rule was written before the run precisely so it could not be moved
afterwards, and a rule that only binds when it is convenient is not a rule.**
**Counts stay 8 won / 12 lost**, the cell is closed at 45 runs across four
engine starts, and ⚠ **there is no cell left that box time can flip.**

**(2) The wider result, and it is the one that matters: THE CAMPAIGN'S
ARM-TO-ARM COMPARISONS CARRY A POSITION BIAS.** R22 reversed R8c's arm order as
a free control — the two budgets cannot share an engine start, so the comparison
is unavoidably cross-invocation, and reversing the sequence cost nothing.
**In 4 comparisons of 4, across two rounds and four engine starts, the arm that
ran SECOND read higher** — +6.36, +0.37 (R8c, E→F) and +12.24, +6.89% (R22,
H→G), **mean +6.5%**. The budgets were **swapped** between the two rounds, so no
budget effect can produce that pattern; a position effect produces exactly it.
⚠ **THIS IS NOT ESTABLISHED, AND THE QUALIFICATION TRAVELS WITH THE FINDING
EVERYWHERE IT IS USED: four comparisons from two sessions, the two phases within
a session are not independent, and treated as two independent sessions it is
p = 0.25 on a sign test — which establishes nothing.** What it is not: **not a
clock effect** (mean SM clock 2395.7 MHz vs 2395.4 MHz, identical to 0.01%) and
**not thermal drift in the obvious direction** (the second arm ran ~1 minute
later on a *warmer* box and was *faster*, the opposite of throttling).

**What it settles.** R8c's **"+6.36% from the folded budget on Phase 1" is
refuted** — the quantity R8c measured was not the one it named. Comparing first
arm against first arm, where the warm-up state is matched, the budget reads
**−1.08% (Phase 1)** and **+0.86% (Phase 2)**: **inert on both**, satisfying the
conjunction rule R11 and R8c both declared. With R11's +0.27% at d16384,
**`max_num_batched_tokens` inertness at c1 is CLOSED and Phase 1's exception is
withdrawn.**

**What survives and what does not — read both halves, not just the second.**
✅ **The knee at 65536 is SAFE.** It rests on a **+233%** effect and a 6.5% bias
cannot manufacture that; no large result in this campaign is at risk, and
neither is any margin the standings rest on (the widest is 6.21x). ✅ So are the
intra-invocation readings — anything measured with both quantities under one
engine start, which is most of the mechanism story. ⚠ **What is in doubt is
every arm-to-arm reading in this campaign at or below ~7%**, and that includes
**R13c's six-point budget curve**, whose six invocations ran in sequence with
nobody recording the order. ⚠ **R9c's ±2.5% "reproduction floor" is an
underestimate for first-versus-later position.** **Never quote a small
cross-invocation delta from this file without checking which arm ran first — and
before R22, no round recorded it.**

**The round that settles it is cheap and it is now the top of the queue: an
A-B-B-A within one session**, four invocations, budgets
8192 / 65536 / 65536 / 8192, **~25 min**. If position is real, arms 3 and 4 read
above arms 1 and 2 regardless of budget; if the budget matters, arms 2 and 3
separate from 1 and 4. See *what to run next* item 10.

**One more thing R22 changed, and it is a housekeeping rule with teeth: σ
figures from 7 runs are themselves draws.** This file recorded σ/med **24.20%**
at `tg32 @ d32768 c1` as **"the noisiest cell in the campaign"**, from a single
7-run arm. R22 re-measured the identical configuration at **11.39%** — a factor
of 2.1. **A σ/med quoted from 7 runs carries roughly ±50% of itself, and this
file's habit of naming noise records from a single arm stops here.**

**⚠ AND HERE IS THE THING A COLD READER MOST NEEDS TO KNOW, BECAUSE IT REVERSES
THE FILE'S OWN LONG-STANDING WARNING. THIS CAMPAIGN HAS BEEN UNDERSTATING ITS
OWN RESULTS.** Five re-measurements of rows nobody was defending have now moved
**+31.64%, +16.54%, +5.43%, +2.24%, +1.77% — five for five UP** — against five
for five DOWN on the rows somebody was defending. **Recorded losses and thin
margins are the rows most likely to be wrong, and most likely to be wrong in our
favour.** That is the opposite of the risk this campaign spent most of its life
guarding against, and it is why the remaining 3-run rows are labelled provisional
with an expected direction attached. **Do not over-read it either:** five is a
modest sample from two rounds, the established thing is the *mechanism* (audit
selection, not a sampling asymmetry), and any individual 3-run row can still go
either way. See the three-run warning above for the full ledger.

**Pick up at the A-B-B-A position-bias round, and it is not a close call any
more.** ⚠ **(a) THE A-B-B-A ROUND** (*what to run next* item 10) — four
invocations in one session at budgets 8192 / 65536 / 65536 / 8192, **~25 min**.
It is first because **it decides how much of this campaign's small-delta
arithmetic is real**, and because either answer is worth having: it establishes
the bias, or it restores the file's sub-7% readings for 25 minutes of box time.
(b) **`mnbt 65536 + mns 4` at c4** — the config the recipe now actually ships,
which has been measured at c1 only. One invocation, and it closes the last gap
between what this file claims and what the recipe does. ⚠ **Note that (b) is
itself a cross-invocation comparison against rows measured at `mns 5`, so run it
after (a) or reverse its arm order and record which ran first.** Then the
zero-box-time prefill metric check. ✅ **The protection round on
`ctx_tg @ d32768 c1` is DONE — R22 closed it as a LOSS and it must not be
re-run.** ✅ **The
priority re-measure list is worked and closed** — R21 cleared three of its four
rows; the fourth (`tg128 @ d16384` c2 and c5) is declined on the record and
labelled provisional, because both lose by more than 2x and no correction this
campaign has seen closes a 2x gap.

**THE TOKEN BUDGET IS A `c>1` LEVER AND ONLY A `c>1` LEVER — this is the
campaign's clearest tuning result, and its three legs belong together.** Three
rounds measured the same flag in three places and the shape they make is the
thing to carry out of this campaign:

| leg | round | measurement | reading |
|---|---|---|---|
| **Inert at c1** | **R11** | `tg128 @ d16384 c1`, 8192 → 65536 (an **8x** budget rise): 112.62 → **112.92**, **+0.27%**, 0.07 SE | the flag does **nothing** at c1 |
| **Knees at 65536 at c4** | **R13c** | `tg128 @ d16384 c4`, six budgets one invocation each: 52.07 → **173.34**, **+233%** to the knee | the flag is the **largest lever in the campaign** at c4 |
| **Flat above the knee at c4** | **R13d** | 65536 → 131072 at c4: **−1.4%** on Phase 2; on the `ctx_` arm 5.96x → 6.15x → 6.21x | the ordering is **bookkeeping**, not the lever still paying |
| ⚠ **Inert at c1 on BOTH phases, at a second depth** | **R22** | `ctx_tg32` / `tg32 @ d32768 c1`, 8192 vs 65536 with **arm position controlled** (first arm vs first arm): **−1.08%** and **+0.86%** | the c1 leg is **CLOSED**, and R8c's Phase-1 exception is **withdrawn** — it was a position artefact, not a budget effect |

**Why the asymmetry, and it is mechanical rather than empirical.** The budget
has only ever moved this metric by two routes, and R11 measured **both absent at
c1**: residency read `(1,0)` in 4 of 4 loaded scheduler samples — one request
cannot fail to be resident — and `tg == tg_req` exactly, so the span ratio is
**1.000 by assignment** and there is no admission stagger for a bigger budget to
remove. ⚠ **R22 measured both absent again at a second depth and at runs=14** —
residency `(1,0)` in **19 of 19** loaded samples across both budgets, `tg ==
tg_req` exactly in all four phase-arms — which is why its position-controlled
reading of **−1.08% / +0.86%** is the expected one and R8c's +6.36% was not.
**The structural argument predicted the result before the run, and that is the
strongest form this campaign has for any of its conclusions.** At `c>1` both
routes are live, which is why the same flag is worth +233% at c4. **The corollary is the one that generalises: the +15.5% per-request rise
R13 read at `c>1` is a sharing artefact** (open question 13, closed by R11) —
at c1, where `tg` *is* `tg_req`, the same change moves it +0.27%.

**What this licenses and what it does not.** It licenses the fold: a flag that
is inert at c1 cannot move the anchor every depth and concurrency comparison
hangs from. It does **not** license reading the knee at any other concurrency —
the curve was taken at c4 only, and the admission arithmetic says the knee must
move with `c`.

**On the token budget above the knee — read this before you queue another
budget point.** R13d put the campaign's widest margin at `mnbt 131072`, and on
the `ctx_` arm the three above-knee budgets do rank monotonically: 5.96x at
65536, 6.15x at 98304, 6.21x at 131072. **That ordering is bookkeeping, not the
lever still paying.** The whole spread is 4.2% across a 2x budget range, inside
the ~2–4% cross-invocation error R13c measured, and the Phase-2 arm at the same
three budgets runs the other way (3.71x at the knee, 3.66x at 131072, −1.4%).
The knee holds. **Do not spend box time chasing budget values above 65536 at
c4 — that question is closed.** The live thread the budget lever still has is a
different one: **the curve was only ever taken at c4.** At c16 even 32768 leaves
the gate half-closed (`Running` 11 of 16), sixteen d16384 prefills would need
262144, and nobody has measured where the knee sits at any other concurrency. A
sweep is cheap — start cost tracks budget SIZE, not novelty, ~110–190 s across
8192–98304. That is the obvious next budget round, not another point at c4.

Then spend the zero-box-time item — the prefill metric check, open question 4 —
while the next benchmark runs, because this campaign's record on that is
unambiguous: **three of its four largest results cost no box time and came from
reading the instrument.** The fourth is still sitting unread in
`pp_throughput`'s definition.

**Carry these five rules, in this order.** (1) Put the compared quantities under
one engine start; declare the resolution budget and reading thresholds before the
run. (2) Read the instrument's source before spending the box. (3) ⚠ **REVISED
BY R8c AND CONFIRMED BY R21 — treat any figure that was never repeated as wrong
by ~1 standard error in an UNKNOWN direction, and audit the unflattering ones
first, because nobody else will.** This rule used to read "assume any flattering
figure is too high", on the strength of four retired figures that were all high;
R8c then retired a fifth that was **28.5% low**, and the all-high pattern turned
out to describe which figures got re-measured, not how sampling behaves. **R21
then ran the audit that reading called for and moved four more unaudited rows
UPWARD, making it five for five, against five for five DOWN on the rows somebody
was defending.** The operational form: **the unflattering rows are where your
surviving errors are, and they are wrong in your favour** — so expect a recorded
loss or a thin margin to improve under audit, and re-measure those before you
re-measure anything you are proud of. ⚠ **But that direction is a prior on a
modest sample, not a law:** at any individual row a 3-run figure is still an
unrepeated draw that can go either way, and the campaign has already twice
over-generalised from ten-ish re-measurements. R13c's residual ~2% downward bias
on figures that stand is a separate and much smaller effect. (4)
Schedule a protection round: re-measure your
published figures from a separate engine start against a pre-declared band, and
pool same-config repeats instead of picking the better draw. (5) ⚠ **NEW, EARNED
BY R22 — when two arms cannot share an engine start, REVERSE OR RANDOMISE THEIR
ORDER, and record which ran first in every row.** R22's headline came from
changing the sequence of two invocations it was going to run regardless: it cost
**zero seconds of grid and zero engine starts**, and it found that the arm
running second read higher in 4 comparisons of 4, mean **+6.5%** — larger than
most effects this campaign chased. **It is not established** (p = 0.25) and it
may yet be nothing, but the control that would have caught it earlier was free,
and no round before R22 even recorded the order, which is why the bias cannot be
retro-fitted to the archives. **A free control that can return more than the
round's headline is the cheapest thing in experimental design; add it by
default.**

**And carry the campaign's honesty, because it is the point.** This campaign
retired two of its own widest wins (R1's 4.60x, R3's 6.56x), withdrew its central
`c>1` mechanism after four rounds of building on it, discovered its two
measurement phases had been labelled backwards since round one, found that the
prefix caching it credited for its concurrency gains never once engaged, and
declined to promote a wider margin it had already measured — then spent a round
repeating that cell rather than claiming it, and the repeat came in 2.99% low,
exactly as the refusal predicted. Its final round refuted its own sharpest
prediction (`ttfr` was called to fall at c1 and rose) and refuted a sampling rule
it had been pricing rounds on since R6, in the same document that licensed the
only change it ever made to its config. **And its actual last round, R13b, wrote
down before it ran that it expected to refute its own candidate, gave the
arithmetic for why, and then did exactly that** — the mechanism paragraph and the
numeric band written together, which is the one process fix this campaign kept
having to relearn. **And its actual last round, R8c, caught the campaign making
the very error this section had spent six revisions warning about** — it had
generalised "3-run medians always come in high" from four re-measurements it had
chosen by how flattering they were, and the first unflattering row anyone
audited came back **28.5% low**, correcting a published loss from 0.72x to
0.92x. The warning was right about the mechanism and wrong about the direction,
and it is rewritten above rather than quietly deleted. **And R21, the actual
last round, did the only honest thing left to do with that: it took the
rewritten warning's prediction, spent box time trying to break it, and reported
that four more unaudited rows all came in high — which means the file a reader
is holding had been publishing losses it did not have.** A campaign that
discovers it has been understating itself has to say so as plainly as it said
the opposite, and it is said above. None of that is tidied away and none of it
should be.

**And R22, which actually ran last, did the two hardest things on the list.**
First it **honoured a rule that cost it the cell**: the claim threshold was
written before the run, one arm came in at **1.046x over the incumbent on the
largest sample ever taken at that cell**, and it was not promoted, because a
rule that only binds when it is convenient is not a rule. The campaign ends with
**8 won / 12 lost** rather than 9 / 11 for that reason alone, and that is the
entry in this file that makes the other refusals credible. Second, and harder,
it **published a finding that subtracts confidence from work already in this
document**: its free order-reversal control suggests the campaign has been
reading a **~6.5% position term as physics** in every arm-to-arm comparison it
ever made, R13c's budget curve included. ⚠ **It said in the same breath that the
finding is not established — 4 comparisons, p = 0.25 — rather than either
burying it or overselling it**, named the one round that would settle it, and
recorded the single place where it departed from a pre-declared procedure
instead of quietly applying the convention. **A round whose main output is
"several of our small numbers may not mean what we said" is the least
comfortable thing a results file can contain, and it is at the top of the
handoff rather than in a footnote.**

**The standings survived all of it at 8 won and 12 lost, which is the
reason to trust them — and the small deltas did not all survive, which is the
reason to read the caveats attached to them.**

---

## R5c — the board-metric question, closed without new box time (2026-08-22)

**NO BOX TIME. No box was touched, no benchmark was run, no board page was
re-scraped.** This round is a desk round, run alongside R13's grid exactly as the
queue specified.

### R5c was already answered before it started, and that is the honest headline

R5c was queued by R7 to settle whether the board's `c>1` tg figure is
**per-request** or a **batch AGGREGATE**, because the campaign's only marginal
win — `tg128 @ d16384 c4` — read 1.13x under one reading and 4.53x under the
other. R7's proposed instruments were the board's own methodology page, or one
model with entries spanning c1 through c8+.

**R10 reached the answer first and by a better instrument: llama-benchy 0.4.0's
own source.** `results.py:352` defines `batch_tg_throughput = observed_decode_tokens
/ (max_last_token - min_first_token)`, and line 194 selects it whenever
`concurrency > 1`; `llama_benchy.py`'s CSV row builder maps `t_s <- tg_throughput`
and sparkrun uploads that CSV to the arena. So the board's headline decode number
**is the same field we already record**, it is a batch aggregate at `c>1`, and
every `c>1` comparison the campaign made was like-for-like all along. R7's 4.53x
alternative was withdrawn by R10 and open question 7 was closed there.

Finding a queued round already answered is a legitimate outcome and is recorded
as one rather than padded into work. But R10's answer rested on **one** instrument
(a source read), and it overturned nine rounds of interpretation, so R5c spent its
zero-cost budget on the thing still missing: an **independent test of R10's
conclusion against data R10 did not use.**

### The independent test — three structural predictions, 34 archived records

The aggregate definition makes predictions that the per-request reading does not.
All were checked against **every `c>1` benchmark record in `experiments/`** —
34 records spanning c2, c4, c5 and c16, five configurations, nine benchmark IDs,
including every arm of R2, R4, R7, R9, R9b, R10 and R12.

| prediction of the AGGREGATE reading | per-request reading predicts | result |
|---|---|---|
| `tg_throughput > tg_req_throughput` at every `c>1` point | `tg ≈ tg_req` (same quantity) | **34 / 34 aggregate**, ratios **1.13x to 4.02x**; per-request reading refuted in every row |
| `tg_throughput <= peak_throughput` always | no constraint | **34 / 34**, zero violations |
| `tg_throughput / tg_req_throughput <= c` always (the ratio is `c / stagger`, stagger >= 1) | no constraint | **34 / 34**, zero violations |

The first row is decisive on its own. `tg_throughput` and `tg_req_throughput` are
**never** the same number at `c>1` in any archived run — they differ by up to 4x —
so `tg_throughput` cannot be the per-request figure. The per-request figure is the
separate `tg_req_throughput` field, exactly as R10 read it. The second and third
rows are the consistency checks: an aggregate must sit under the sustained
ceiling, and its ratio to the per-request rate cannot exceed the concurrency. Both
hold without a single exception across five configurations, which is what a
correct metric identity looks like and what a misreading would not survive.

**The double-count is visible in the data too.** `c x tg_throughput` — the
campaign's retired `aggregate = per-request x c` convention — exceeds
`peak_throughput` in **14 of 34** rows, which is impossible for a sustained
figure. All fourteen are low-stagger arms (the raised-budget runs and c16). That
is why the error stayed hidden for nine rounds: at the campaign's original
`max_num_batched_tokens 8192` the stagger was 2-2.5x, which happened to keep the
double-counted product *under* the peak and made a wrong convention look sound.
**The convention was never right; it was merely not yet caught.**

### One genuinely new methodology note, and it is a caveat on a shortcut

R10 measured admission stagger from per-request timestamps. The archived
aggregates offer a cheaper proxy: `stagger ≈ c / (tg / tg_req)`. It agrees with
R10's measured values to a few percent at c2 and c4 — and at c5 **only when
`max_num_seqs >= c`**. On the c5 arms run at `max_num_seqs 4`
(`bench_0ef7af8997ce`, `bench_d9fdc68576f2-a1`) the proxy reads **3.85-4.08**
against R10's measured **~2.39**, because a request excluded from residency
stretches the batch span without contributing decode to the numerator in the way
the derivation assumes.

**Use the proxy only at full residency, and confirm residency from the
scheduler's own `Running: N / Waiting: M` lines first.** This is the same
standing rule R7 and R10 arrived at from the other direction — `max_num_seqs >= c`
does not imply full occupancy — now with a second failure mode attached to it.

### What R5c did NOT do

- No board re-scrape. The queue forbade the box and R5c had no need of the board:
  the question was about the metric's definition, and the definition was settled
  from the producing source.
- **No verdict, margin, standing or row value changed.** `tg128 @ d16384 c4`
  keeps 1.13x on the campaign config and 3.15x on the raised budget. The single
  RESULTS edit is the removal of a now-false clause on the `bench_5399a85d7aec-a0`
  c4 row that still said the units dispute was open.
- No 3-run figure was promoted, and nothing here rests on one. The test is over
  archived medians whose only role is a ratio between two fields of the *same*
  record, so per-run sampling error cancels and the campaign's provisional-median
  rule does not bite.
- Nothing was attributed to prefix caching. The `ctx_` rows appear in the 34 only
  as records to test the identity on; no `ctx_` behaviour is explained here.

### Cost

Zero box time, zero benchmark time, one branch, ~25k harness tokens. The queue's
claim that R5c was "worth more than any remaining cell" was right about the
question and wrong about who would answer it — the answer came free, from a ride-
along in a round that was queued for something else entirely. **That is the second
time this campaign got its biggest result from reading the instrument instead of
running it.**

---

## Round 13 hypothesis — the one-step admission round: tg128 @ d16384, c4 and c5 at `max_num_batched_tokens 98304`, runs=7, one engine start

**This round runs after the campaign synthesis.** Rounds 1-12 are closed and
synthesised; this appends to that narrative rather than revising it, and where
it changes a standing it says so and RESULTS.md is updated. The synthesis is a
checkpoint, not a seal.

R12 named this cell the only one left with a live route to a win, and it named
the reason: **c5's remaining gap is 93% admission stagger.** Our per-request
decode rate is already within 3% of what the incumbent's headline figure
requires. What the board's own `Qwen3.6-35B-A3B-NVFP4` on vLLM is doing that we
are not is admitting its whole batch without stretching the span the metric
divides by. `tg_throughput = sum(decode tokens) / (max_last_token −
min_first_token)`, so the stagger is charged directly.

### THE PRE-FLIGHT, and it changed the round before any box time was spent

The queue specified `max_num_batched_tokens 81920` (= 5 x 16384) and warned that
`81920 > max_model_len 32768` would "almost certainly" force a second mutation,
`-o max_model_len=81920`. It also flagged open question 11 — check the
validators from the pinned image first, R9b's practice. Both halves of that
warning turn out to be wrong, and **both were settled by reading, at zero box
cost.** This is the third consecutive round where reading the instrument beat
inferring from it.

**1. `max_model_len` does NOT have to move.** From
`vllm/config/scheduler.py:248-284` in the pinned image
(`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`), `verify_max_model_len`
contains exactly three constraints on `max_num_batched_tokens`:

- `mnbt < max_model_len` raises **only if chunked prefill is OFF**. Ours is ON
  (and, per R9's finding, prefix caching forces it ON), so this never fires.
- `mnbt >= max_num_seqs` — 98304 >= 5, satisfied.
- `mnbt > max_num_seqs * max_model_len` is a **warning, not an error**, and at
  5 x 32768 = 163840 it does not even warn.

**There is no `mnbt <= max_model_len` validator.** So the round keeps
`max_model_len` at the recipe default 32768 and carries **one mutation
dimension** relative to R12, not two. That matters for more than tidiness:
raising `max_model_len` would have moved the KV reservation and, per R9b,
`mamba_block_size` rides on the same family of decisions. R13 vs R12's c5 arm
now differs in exactly one parameter.

**2. 81920 IS NOT ENOUGH, because the campaign has been using the wrong prefill
size for twelve rounds.** The admission arithmetic everyone has used is
`floor(mnbt / 16384)` — one prefill per `depth` tokens. `llama_benchy/runner.py`
(pinned 0.4.0, the Phase 2 branch at lines 155-172) sends
`context_text=context` **and** `prompt_text=prompt` in the same request. The
headline `tg` rows are Phase 2. So a Phase-2 request's prefill is
**`depth + pp` = 16384 + 2048 = 18432 tokens**, not 16384 — and since R9b
established that prefix caching never hits (`Prefix cache hit rate: 0.0%` in
114 engine samples), none of the 16384 is free.

R12's own export corroborates this without a new run. Phase-2 `ttfr` over
Phase-1 `ttfr`, both pure-prefill quantities on the same batch:

| cell | ctx (Phase 1) ttfr | cold (Phase 2) ttfr | ratio | 18432/16384 |
|---|---:|---:|---:|---:|
| c2 | 5269.25 | 6069.14 | **1.152** | 1.125 |
| c5 | 12731.35 | 14484.92 | **1.138** | 1.125 |

Phase 2 costs ~13-15% more time to first token than Phase 1 on the identical
batch, against a 12.5% larger prompt and a cache that never hits. The two agree.
**The `ctx_pp`-vs-`pp` token-count correction R9b made has an admission-side
consequence nobody had drawn: every prefill in this campaign is 18432 tokens
wide, not 16384.**

Consequence for the budget. One-step admission of five requests needs
`5 x 18432 = 92160` tokens.

| budget | token-packing model `ceil(cP/B)` | whole-prefill model `ceil(c/floor(B/P))` | steps at c5 |
|---:|---:|---:|---|
| 32768 (R12) | 3 | 5 | **not one step** |
| **81920** (queue's figure) | **2** | **2** | **not one step** |
| **98304** | **1** | **1** | **ONE STEP** |

Both readings of how vLLM packs a step agree that 81920 leaves a trailing step
and that 98304 does not. **81920 would have measured the same class of thing
R12 already measured and could not have tested the hypothesis.** The round runs
at **98304** (6 x 16384, i.e. 5 x 19660 per request — 6.6% headroom over the
92160 requirement, enough to absorb chat-template overhead). This is a
deliberate, evidenced deviation from the queue's numeral in service of the
queue's actual hypothesis, and it is recorded as one.

### The arms, and why c4 rides along

ONE invocation, `-b concurrency=4,5`, so both points share an engine start and a
thermal state. The campaign's central methodological result is that
cross-invocation inference kept being overturned by single-invocation controls
(R6 over R1, R8 over R3, R9b over R4, R10 over R2); this round does not repeat
that mistake.

**c5 is the round.** **c4 rides along for ~220 s** and buys two things c5 alone
cannot: a second, independent point on the same admission model at the same
budget under the same engine start (c4 needs `4 x 18432 = 73728 < 98304`, so it
is also one step), and a possible standings improvement on the one contested
cell the campaign holds. `max_num_seqs 5` is used for both arms; R10 established
that `max_num_seqs` comfortably above `c` is neutral (its c4 arm at mns 16 read
147.25 against R9's A1 at mns 4 reading 143.08, a 2.9% reproduction), so the c4
arm remains comparable to R10's figure.

### THE DISCRIMINATOR, declared before the run

The queue asked for exactly this and it is the round's whole point. The
zero-stagger bound `c x tg_req` is only a win if `tg_req` itself does not sag.
R12's c5 `tg_req` was 43.72. Against the campaign's own per-request series
(`c1 112.62`, roughly `c^-0.48`):

| c | series prediction | measured (raised budget) | on the series? |
|---:|---:|---:|---|
| 2 | 80.8 | 79.73 (R12) | **yes** |
| 4 | 57.9 | 57.8 (R10) | **yes** |
| 5 | 52.0 | **43.72** (R12) | **NO — 16% below** |

c2 and c4 sit on the series; c5 alone sits below it. R12 reached its c5 point in
three admission steps, so its prefill was split and interleaved with ongoing
decode. If that interleaving is what costs the 16%, one-step admission should
return c5's `tg_req` to the series.

- **H_span_only** — the budget buys only a shorter denominator, and per-request
  decode is untouched. Prediction: `tg_req(c5) <= 46.0`.
- **H_span_plus_decode** — un-splitting the prefill also lifts per-request
  decode back onto the series. Prediction: `tg_req(c5) >= 48.0`.
- Between 46.0 and 48.0 the round reports **mixed** and does not force it.

**The two hypotheses differ on the standing, which is what makes this worth box
time.** At stagger 1.08:

- H_span_only: `5 x 43.7 / 1.08` = **202**, i.e. **0.90x — still a LOSS.**
- H_span_plus_decode: `5 x 52.0 / 1.08` = **241**, i.e. **1.07x — a WIN.**

### Numeric predictions, built by decomposing the metric

`tg = c x tg_req / stagger`, per R12's post-mortem — bands from the generating
model, not from scaling the last round's percentages.

| quantity | baseline | predicted | reasoning |
|---|---|---|---|
| c5 `tg_throughput` | 128.93 (mnbt 32768) | **195-250**, centre 220 | straddles the 225.46 target; the discriminator decides the side |
| c5 stagger | 1.70 | **1.00-1.15** | one admission step; c2's one-step-ish figure was 1.13, the c1 floor is 1.00 |
| c5 `tg_req` | 43.72 | **43.7-53** | the discriminator |
| c5 `peak_throughput` | 290 | **285-320** | the ceiling barely moves on this knob (c2 -0.5%, c5 +9.4%) |
| c5 pp2048 (Phase 2) | 677.44 | **670-720** | SESSION CONTROL — must land, or the tg figures are not readable |
| c5 ttfr | 14484.92 | **14500-19000** | betting AGAINST a fall for the sixth time; a 92160-token step is long, so the FIRST response comes later too |
| c4 `tg_throughput` | 147.25 (R10) | **190-250**, centre 215 | `4 x ~58 / ~1.08` |
| c4 stagger | 1.57 | **1.00-1.15** | 73728 < 98304, one step |
| c4 `tg_req` | 57.8 | **56-65** | already on the series; little room to lift |
| c4 `peak_throughput` | 284 | **280-310** | |
| c4 pp2048 | 672.59 | **660-710** | session control |
| ctx vs cold | — | **ctx BELOW cold at both**, and **ctx stagger ABOVE cold stagger at both** | fourth and fifth test of R12's contradiction of R10's mechanism |
| σ/med on tg | 1.81% (c5), 3.25% (c4) | **0.5-5%** both | |
| scheduler `Running`/`Waiting` | UNMEASURED for two rounds | **5/0 and 4/0 in >=95% of loaded samples** | see below |
| MTP acceptance | 2.85-3.09 / 61.7-69.8% | **2.85-3.15 / 61-72%** | flat under every scheduler knob in four rounds |
| SM clock median | 2392-2398 | **2392-2398** | tenth consecutive session |
| grid time | — | **400-560 s** | R12's c5 arm 236 s, R10's c4 arm ~220 s |

### The standings call, made in advance

**c5 is called at 40% to clear 225.46**, and the round declines to predict its
sign more confidently than that. The band straddles the target and the
discriminator is genuinely open — the campaign has never measured whether
per-request decode moves when a prefill stops being split. If c5 clears, it is
**the first cell this campaign wins against its own model on the board**, and it
is won on a scheduler knob rather than a probe.

**c4 is called at >90% to improve its margin** from 3.15x, and that is a
standings change to a cell already in the WON table. It is a smaller result than
it looks: c4 is already won, so this widens a margin rather than taking a cell.

### MUTATIONS, stated plainly

`-o max_num_seqs=5` and `-o max_num_batched_tokens=98304`. **Both are
MUTATIONS.** `recipe.yaml` is NOT touched and `max_model_len` stays at its
default 32768. Every RESULTS.md row this round produces names this
configuration. The fold decision remains R11's.

### The instrument that has now been lost three times

R8, R12 and (partly) R9 all planned to read `Running: N reqs, Waiting: M reqs`
and MTP acceptance from the engine log and shipped without them. R12 diagnosed
why: `docker logs -f` returns only the container's CUDA entrypoint banner
because vLLM's serve output does not reach container stdout on this image. **The
capture for this round is `ssh <box> docker exec <container> tail -f
/tmp/sparkrun_serve.log`, and it is VERIFIED LIVE** — `grep -c 'Running:'` on
the capture within a minute of the grid starting — before the round is allowed
to rely on it. If the verification fails, the round says so and quotes no
occupancy figure, exactly as R12 did.

### Discipline

- **runs=7.** These are headline numbers with a scoreable target. Both 3-run
  medians this campaign ever promoted had to be retired and **both were too
  high** (R1's tg32, R3's d65536).
- **BOTH estimators at every c>1 point** — `tg_throughput` and
  `peak_throughput` side by side, `tg_req_throughput` for the stagger. Never
  `tg x c`; R10 settled that it double-counts an already-aggregate metric.
- **σ is set by MTP verify-step count and acceptance quality, not by
  concurrency** (R6). These are long generations at shallow depth in a wide
  batch — the quiet regime — which is why runs=7 is affordable here.
- Read the `Benchmark args:` echo before letting the run proceed (R5 lost an
  engine start to a silently-defaulted depth).
- ONE invocation. Serial — nothing else touches the box. No arena submission,
  ever. No box system settings, no `apt`.

## Round 13 outcome — bench_433eeaf9827e (2026-08-22)

One invocation, `session_count: 1`, `crash_count: 0`, so c4 and c5 shared one
engine start and one thermal state. Seven runs at each. Same pinned image epoch
(`dgx-vllm-eugr-nightly:2026082102`) as every round since R1. Config:
`-o max_num_seqs=5 -o max_num_batched_tokens=98304`, both **MUTATIONS**;
`max_model_len` left at the recipe default 32768, which the pre-flight
established was permitted.

| cell | tg (board metric) | (mean) | σ | σ/med | peak_thr | tg_req | stagger | residency | runs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| tg128 @ d16384 c4 | **174.68** | (173.59) | 7.70 | 4.41% | **310** | 66.76 | **1.53** | 3.88 of 4 | 177.10 / 181.08 / 169.05 / 181.16 / 172.87 / 174.68 / 159.19 |
| tg128 @ d16384 c5 | **164.27** | (165.23) | 5.40 | 3.29% | **303** | 50.50 | **1.54** | 4.81 of 5 | 160.79 / 174.46 / 158.52 / 164.27 / 166.43 / 162.80 / 169.34 |
| ctx_tg128 @ c4 | 170.59 | (171.97) | 6.34 | 3.72% | 294 | 61.93 | 1.45 | 3.95 of 4 | 181.48 / 170.12 / 164.63 / 170.59 / 165.01 / 178.33 / 173.64 |
| ctx_tg128 @ c5 | 160.67 | (161.15) | 3.48 | 2.16% | 314 | 48.73 | 1.52 | 5.06 of 5 | 156.51 / 160.67 / 159.16 / 165.46 / 165.26 / 162.77 / 158.20 |
| pp2048 @ c4 | 676.40 | — | — | — | — | — | — | — | — |
| pp2048 @ c5 | 676.14 | — | — | — | — | — | — | — | — |

Both estimators are reported side by side at every point. `tg` sits under
`peak_thr` at both concurrencies (174.68 < 310, 164.27 < 303), so the two
estimators are consistent and nothing here repeats R7's or R9's break.

### STANDINGS — one win widened, one record margin, and c5 is STILL A LOSS

| cell | was | now | incumbent | was | now |
|---|---:|---:|---:|---:|---:|
| tg128 @ d16384 c4 | 147.25 | **174.68** | 46.68 | 3.15x | **3.74x** |
| ctx_tg @ d16384 c4 | 126.35 | **170.59** | 27.68 | 4.56x | **6.16x** |
| tg128 @ d16384 c5 | 128.93 | **164.27** | 225.46 (like-for-like) | 0.57x | **0.73x** |

**`ctx_tg @ d16384 c4` at 6.16x is now the campaign's widest margin**, past
`tg128 @ d65536 c1`'s 5.71x. RESULTS.md is updated accordingly.

**c5 REMAINS A LOSS and is recorded as one.** 164.27 against the like-for-like
225.46 is 0.73x — improved from 0.57x, short by 27%. And the honest fuller
statement, which RESULTS.md now carries: the c5 *cell* is topped by
LFM2.5-350M BF16 at **428.95**, so even clearing 225.46 would have beaten the
board's own Qwen3.6-35B-A3B-NVFP4 entry without taking the cell. Against the
cell top we are at 0.38x.

### THE DISCRIMINATOR: H_span_plus_decode HOLDS — and the round's mechanism is REFUTED anyway

Declared before the run: `tg_req(c5) >= 48.0` reads H_span_plus_decode,
`<= 46.0` reads H_span_only, between is mixed.

**`tg_req(c5) = 50.50`.** H_span_plus_decode holds, cleanly and above the
threshold. Per-request decode DID lift when the prefill stopped being split —
43.72 to 50.50, essentially back onto the `c^-0.48` series that predicted 52.0
and that c2 and c4 already sat on.

**But the round predicted that lift would arrive alongside a stagger collapse,
and the stagger did not collapse.** Predicted 1.00-1.15 at both arms; measured
**1.53 at c4 and 1.54 at c5**, against R10's 1.57 and R12's 1.70. c4's stagger
barely moved at all.

So the round got its numbers from the term it treated as secondary and got
nothing from the term it was designed around. **Both `tg_req` figures rose by
exactly the same factor:**

| cell | tg_req before | tg_req now | change | stagger before | stagger now |
|---|---:|---:|---:|---:|---:|
| c4 | 57.80 | 66.76 | **+15.5%** | 1.57 | 1.53 |
| c5 | 43.72 | 50.50 | **+15.5%** | 1.70 | 1.54 |

A uniform +15.5% in per-request decode at two different concurrencies, with the
span ratio nearly untouched. That is not what an admission-stagger lever looks
like.

### WHY THE MECHANISM IS REFUTED RATHER THAN MERELY MISSED — the instrument says so directly

**R8b is measured, at the fourth attempt.** The capture
(`docker exec <container> tail -f /tmp/sparkrun_serve.log`) produced **453 lines,
48 `Running:` samples and 34 SpecDecoding samples**, verified live before the
round leaned on it, and archived as `engine-capture.log`. R8, R9 and R12 all
planned this reading and shipped without it.

**Occupancy, in every loaded sample:**

| arm | reading | loaded samples |
|---|---|---:|
| c4 | `Running: 4 reqs, Waiting: 0 reqs` | 10 of 10 |
| c5 | `Running: 5 reqs, Waiting: 0 reqs` | 13 of 13 |

**`Waiting: 0` in 100% of loaded samples at both concurrencies.** The scheduler
is admitting the entire batch, exactly as the round's arithmetic said it would
at 98304. **And the stagger is still 1.54.** So whatever stretches the span
between the first request's first token and the last request's last token, it
is **not requests waiting for admission** — there is nothing waiting.

**This reframes R12's headline decomposition.** R12 priced c5's gap as "93%
admission stagger" and the campaign has been calling the ratio "admission
stagger" since R10. With the budget raised until nothing queues at all, the
ratio falls only 1.70 to 1.54. **Most of what the campaign has been attributing
to admission is not admission.** The name was inherited from the configuration
that first produced it and it stopped being accurate somewhere before this round.

### THE LEADING CANDIDATE FOR THE RESIDUAL SPAN, stated as a candidate

The requests start together and finish apart. The obvious way that happens on
this model is **MTP acceptance dispersion across the batch**: a request drawing
acceptance length 4.00 completes 128 tokens in ~32 verify steps, one drawing
2.77 needs ~46 — a **1.44x** spread against a measured 1.54.

The engine log's acceptance samples span **2.77 to 4.00** (median 3.085) across
the grid, so dispersion of the right size is present. Two honest caveats:
vLLM's SpecDecoding logger reports a **batch aggregate every 10 s**, not a
per-request figure, so this round **cannot** demonstrate that the dispersion is
*within* a batch rather than *between* runs; and the span-average occupancy
computed from our own export (`tg / tg_req` = 3.25 of 5 at c5, against a peak
residency of 4.81 of 5) is consistent with requests retiring at spread-out times
but does not identify why. **No figure here is quoted as settled.** What would
settle it is per-request acceptance, which needs
`per_request_spec_decode_metrics` — visible as `'none'` in this image's
observability config, and therefore available without a code change.

### R9b CONFIRMED A THIRD TIME, at a third budget

**`Prefix cache hit rate: 0.0%` in all 48 samples**, flag ON, at
`max_num_batched_tokens 98304`. R9's A1 (22 samples) and R10 (92 samples) read
the same at 32768. Prefix caching has now never hit in 162 engine samples across
three token budgets. Nothing in this round's gains is a caching effect and
nothing here should be described as one.

### ctx vs cold: the observation holds, and R12's stagger asymmetry BREAKS

ctx is **below cold at both** arms — 170.59 vs 174.68 (−2.3%) at c4, 160.67 vs
164.27 (−2.2%) at c5 — so the sign is where R10 and R12 found it. But the
magnitude has almost vanished: R12 read −9.7% and −18.7% at the same cells one
budget down.

**And R12's asymmetry reverses.** R12 established that the `ctx_` phase staggers
MORE than cold at every raised-budget point (1.17 vs 1.13, 1.80 vs 1.57, 2.12 vs
1.70) and made that the sharpened form of open question 4. At 98304 it staggers
**LESS** at both:

| cell | cold stagger | ctx stagger | R12/R10 at mnbt 32768 |
|---|---:|---:|---|
| c4 | 1.529 | **1.452** | 1.57 vs **1.80** |
| c5 | 1.537 | **1.517** | 1.70 vs **2.12** |

The prediction made before this run was that ctx would stagger more, on R12's
evidence. **It is refuted at both arms.** Open question 4's sharpened form —
"why does removing prefill work make the batch stagger worse?" — was built on a
regularity that holds at one token budget and not at the next, which is the same
failure mode the ctx-vs-cold question has now suffered four times. It should be
re-posed as a budget-dependent observation or dropped.

> ⚠ **DROPPED, and the correction pass says why it could never have been
> re-posed.** R13 was right to refuse a fifth sharpening. The question's premise
> — that the `ctx_` phase removes prefill work — is false: `ctx_` is Phase 1,
> the context load, prefilling `depth` tokens. R13's own pre-flight established
> the other half of the arithmetic (a Phase-2 prefill is `depth + pp` = 18432)
> without either round noticing that together they kill the question. The
> stagger figures in the table above stand; the question does not.

### Predictions: 14 held, 6 missed

- **c5 `tg` 195-250, centre 220: MISSED LOW** at 164.27. **c4 `tg` 190-250:
  MISSED LOW** at 174.68. Both misses trace to the same wrong term — the bands
  assumed stagger near 1.05 and it came in near 1.53.
- **c5 stagger 1.00-1.15: MISSED HIGH** at 1.537. **c4 1.00-1.15: MISSED HIGH**
  at 1.529. The round's central mechanical claim, and the instrument refuted it.
- **c5 `tg_req` 43.7-53: HELD** at 50.50 — the discriminator, and the round's
  one correct forecast about a mechanism.
- **c4 `tg_req` 56-65: MISSED HIGH** at 66.76, marginally.
- **peak_throughput both HELD**: 303 at c5 (285-320), 310 at c4 (280-310, at the
  top edge). Unlike c2 in R12, the ceiling did move here — c5 290 -> 303 (+4.5%),
  c4 284 -> 310 (+9.2%) — which is consistent with real decode work being
  recovered rather than only a denominator shrinking.
- **pp2048 both HELD: SESSION CONTROL PASSES.** 676.40 at c4 (660-710) and
  676.14 at c5 (670-720), reproducing R12's 677.44 to within 0.2% from a separate
  engine start. This is what licenses reading the tg figures at all.
- **ttfr HELD** at 15126.01 (14500-19000), +4.4% on R12's 14484.92. **Raising
  the budget makes time-to-first-response worse for the sixth consecutive time.**
  c4's 12101.77 is +2.6% on R12-era figures. Any row from this config says so.
- **σ/med 0.5-5%: HELD both** at 4.41% (c4) and 3.29% (c5). runs=7 was the right
  call; c4's runs span 159.19-181.16.
- **ctx BELOW cold at both: HELD.** **ctx stagger ABOVE cold: REFUTED at both.**
- **`Running`/`Waiting` 5/0 and 4/0 in >=95% of loaded samples: HELD**, at 100%.
- **MTP acceptance 2.85-3.15 / 61-72%: HELD** at median 3.085 / 69.6% (34
  samples). **Fifth consecutive round finding acceptance flat under a scheduler
  knob** — and this is the strongest version yet, because the knob tripled.
- **Telemetry: HELD.** 1500 samples, SM clock **2398 MHz** median (2216-2411),
  75 °C peak, 100.27 W peak — the **tenth consecutive session** agreeing with
  R4's 2392. First reading above 100 W, by 0.3%. No clock, power-policy, driver
  or kernel setting was touched, and no `apt` was run.
- **Grid time 400-560 s: HELD** at **490.1 s** (c4 225.5 s, c5 264.6 s).

### COST, and one cost the round created

One engine start, ~12 min wall, ~85k harness tokens. **The engine start itself
cost ~225 s against a ~180 s norm**, because 98304 is a new
`compile_ranges_endpoints` value and torch.compile missed its cache and rebuilt.
That is a one-off per budget value, not per round, and it is worth knowing before
anyone sweeps `max_num_batched_tokens` across several values: each new value buys
a full recompile.

### Mutations NOT folded into recipe.yaml

`recipe.yaml` is untouched. Every R13 row in RESULTS.md names its configuration.
The fold decision remains **R11's**, and this round makes it harder rather than
easier: there are now three measured budgets (8192, 32768, 98304) and the c1
anchor has been measured at only one of them.

### The round's value, in one line

**It widened the campaign's only contested win to 3.74x and set a new widest
margin of 6.16x, moved c5 from 0.57x to 0.73x without taking it, recovered the
occupancy instrument after three lost attempts — and used it to refute its own
mechanism, showing that with `Waiting: 0` in every sample the span ratio still
sits at 1.54, so most of what this campaign has been calling "admission stagger"
since R10 is something else.**

---

## THE `ctx_` PHASE-LABEL CORRECTION — full audit, 2026-08-22, no box time

A dedicated correction pass over material already on disk. No benchmark was run,
no board figure re-scraped, no recipe touched. It exists because R9b, chasing a
validity gate that had just failed, found two instrument errors that reach every
`ctx_` row this campaign wrote across thirteen rounds — and R9b recorded them
without having time to audit what they invalidated. This is that audit.

### The two errors, and when they were found

**Found 2026-08-22, in R9b, by reading `llama_benchy/runner.py:127-176` and
`223-225` (pinned 0.4.0) after `ctx_pp2048 < 1200` failed as a void condition.**

**(a) llama-benchy labels its two phases backwards relative to how they read.**
When the probe has `prefix_caching` on and `depth > 0`, Phase 1 is the CONTEXT
LOAD and is recorded with `is_context_phase=True` — that is the `ctx_` row, and
it is the **uncached** pass, the one that *establishes* the cache. Phase 2 is
the inference pass, `is_context_phase=False`, and it is the **cache-eligible**
one. That is the row this campaign has called "cold" since Round 1. The two are
exactly inverted, in every round entry above.

The archived exports carry the same fact independently of the source read: every
record in `experiments/` has `"is_context_prefill_phase": true` on its `ctx_`
rows, and `"context_size": 16384, "prompt_size": 2048` on **both** phases.

**(b) The two phases are charged different token counts.** Phase 1 is charged
`expected_ctx` = `depth` prompt tokens. Phase 2 is charged `expected_pp` = 2048,
while actually processing `depth + 2048` (R13's pre-flight, and prefix caching
never hits so none of the `depth` is free). So the ~9x `ctx_pp` advantage the
campaign read at every depth for twelve rounds is a denominator.

### What the correction pass added: the token-count error is now measured

R9b asserted the ratio was `16384/2048`. Tested against every archived pair in
`experiments/` where both phases appear in one record, the prediction with no
free parameters is `ctx_pp / pp = (depth + 2048) / 2048`:

Run over **every** `(depth, concurrency, response_size)` cell in the 18 archived
`consolidated.json` files where both phases were measured — 30 pairs, not a
sample:

| depth | pairs | observed | predicted | residual |
|---:|---:|---:|---:|---:|
| 8192 | 1 | 5.18 | 5.00 | +3.6% |
| 16384 | 24 | 8.93 – 9.32 | 9.00 | −0.7% to +3.5% |
| 32768 | 1 | 17.20 | 17.00 | +1.2% |
| 65536 | 2 | 33.58, 33.77 | 33.00 | +1.7%, +2.3% |
| 131072 | 1 | 65.82 | 65.00 | +1.3% |

**29 of 30 pairs, five depths, every configuration the campaign ever ran, every
residual between −0.7% and +3.6%.** The two phases prefill at the same rate to
within 4%. The small, almost always positive residual is Phase 1 being
marginally faster per token, which is the direction a pass with no decode setup
should go. **There is no prefill speedup anywhere in this campaign's data and
there never was.** The single exception is R13's c5 `ctx_pp` at 7.65 (−15%), a
broken measurement rather than a counter-example: its σ is 817 on a median of
5175, sixteen times the dispersion of the c4 arm beside it in the same
invocation. Recorded, not used.

**This is also a second instrument for R9b's other finding.** Two of the 30
pairs are R9b's **prefix-caching-OFF** arms and they read 9.20 and 9.16, indistinguishable
from the caching-ON arms. Had the cache ever hit, Phase 2 would have skipped
16384 of its 18432 tokens and the ratio would have collapsed toward 1. It does
not move. **The archives were carrying proof that prefix caching never hits, in
the very column the campaign read as proof that it did.**

### And the premise underneath four rounds of mechanism is false

The campaign's stock phrase for the `ctx_` phase — from R1's "with the prefill
work removed, the measurement is much quieter" through R10's "the `ctx_` phase
does no prefill, so it never staggers much" — has the work backwards. Phase 1
prefills `depth` tokens. Phase 2 prefills `depth + 2048`. **Phase 1 does 89% as
much prefill as the phase it was being compared against, not none of it.**
Nothing is removed, so nothing that was attributed to a removal can stand.

### WITHDRAWN — six claims

Withdrawn, not adjusted. A comparison the denominator invalidates cannot be
rescaled into looking right, and a mechanism with a false premise is not patched
into a smaller version of itself.

1. **"The `ctx_` phase is prefill-free and ~9x faster at prefill"** — R1 to R9b.
   Withdrawn entirely; no `ctx_pp`-versus-`pp` comparison in this journal or in
   RESULTS.md is retained.
2. **"Removing the prefill removes the run-to-run variance"** — R1-R4. The
   regularity was already retired after breaking three times (R5, R6, R8); the
   premise is now gone too. The quietness of some `ctx_` cells survives as an
   unexplained observation.
3. **"The `ctx_` phase does no prefill, so it never staggers much"** — R10's
   mechanism for the ctx-vs-cold sign flip. Withdrawn at the premise. R12 had
   already contradicted it with the instrument; it was false before that.
4. **"Why does removing prefill work make the batch stagger WORSE?"** — R12's
   sharpened open question 4, carried into the synthesis and into R13's
   pre-run prediction. **Dissolved, not answered.** It presupposes a removal
   that never happens.
5. **"The `ctx_` cells are the cheapest place in this campaign to measure a real
   effect"** — R3, quoted in RESULTS.md for six rounds. Built on 1 and 2.
6. **Open question 4 as posed.** They are not prefix-caching phases, and there
   is no cached phase to tune because the cache never hits. The `ctx_` cells are
   still real, separately-ranked board cells worth winning; the framing is dead.

That makes **fifteen** claims this campaign has published and later withdrawn.
The list in the synthesis has been extended accordingly.

### NOT WITHDRAWN — and this is the part that matters for the standings

**No board margin moves. No win is lost, no loss becomes a win, and the
standings stay at 8 cells won / 12 lost.** The reason is not charity, it is the
comparison structure: the board publishes `ctx_tg @ dN` and `ctx_pp @ dN` as
their own test types (`docs/arena-recipe.md`), and its entries arrive through
the same llama-benchy CSV ours do — the upload path R10 established. Every
`ctx_` comparison is Phase 1 against Phase 1. A shared convention that is
strange is still shared. What was wrong was never the margin; it was the
sentence describing what the margin measured.

The `tg` comparisons between the phases also survive intact — both phases decode
128 tokens per request, so the token-count error is confined to `pp_throughput`.
Their values and signs are unchanged. What changes is which one gets called
cached, and the answer is neither.

**R9b's broken validity gate is now explained rather than merely confessed.** It
demanded `ctx_pp2048 < 1200` with caching off and measured ~6100. Under the
corrected reading the gate could not have passed at any setting: Phase 1 is
charged 16384 tokens whether a cache exists or not, so its `pp` figure has an 8x
floor built into the denominator. **The arm was right, the gate was
arithmetically impossible, and overriding it on the engine's own counters was
the correct call.** Recording it as a broken gate rather than dropping it is
what made this diagnosable a round later.

### The trap this correction sets, and it is disarmed here

The obvious move on learning that `pp2048` is charged 2048 for `depth + 2048`
tokens of work is to rescale our prefill figures and void the losses: at d32768
that turns 295.71 into ~5027 against the best like-for-like vLLM entry's
4644.54, i.e. a win. **That is wrong.** The board's prefill figures come through
the same CSV and carry the identical understatement, so the artefact cancels and
the ratio is untouched. **The six prefill c1 cells remain losses at exactly the
recorded margins.** Any future session that reaches for this rescaling should
stop here.

What the correction does sharpen is the open mismatch question. Our Phase-1
series **falls** with depth (6148.56 → 2803.17 over 16x) while the board's
`ctx_pp` incumbents **rise** (775123 → 945271 over 4x). Ours is a real rate over
a real token count and attention makes it fall; theirs cannot be the same
quantity behaving the same way. That is a shape disagreement on top of the ~150x
magnitude one — evidence *for* a definition mismatch, not against it. The
zero-box-time prefill metric check stays the second-priority item.

### What this pass closes and what it leaves

Closed: the audit itself, R9b's two corrections propagated into every affected
row and claim, and open question 4 dissolved rather than left sharpened. Left
open and unchanged: **R11** (still the highest-value round), R9c, the prefill
metric check, R8c, R13b, R13c. Nothing here changes the handoff.

**The one line worth carrying:** this campaign's three largest results — the
units resolution, the phase labels, and the never-hitting cache — all came from
reading the instrument rather than measuring around it, and all three cost
nothing. The fourth is still sitting unread in `pp_throughput`'s definition.

---

## Round 13c hypothesis — the `max_num_batched_tokens` curve at ONE concurrency: tg128 @ d16384 c4, six budgets, runs=7

**This round is a PROTECTION round first and a curve second.** Three rows in
RESULTS.md's WON table are `tg128 @ d16384 c4`, one per configuration — 52.85
(1.13x, campaign config), 147.25 (3.15x, mnbt 32768) and 174.68 (3.74x, mnbt
98304) — and each rests on a single engine start at a single budget value. Their
Phase-1 partners include the campaign's widest margin (`ctx_tg @ d16384 c4`
170.59 = **6.16x**). Mat reads those rows in the morning. A round that protects a
standing must be at least as rigorous as the round that won it, so every point
here is runs=7, and the round's pre-declared rule for what happens if a
reproduction fails is written below **before** the run.

The campaign has retired three of its own headline numbers already (R6 over R1,
R8 over R3, R13 over R12's reading) and the `ctx_` correction withdrew five more.
If a row does not reproduce, it comes down. That is the point of running this.

### The curve, and why the budget earned one

R13 moved `tg_req` by **+15.5% at two different concurrencies with the span ratio
flat** (c4 1.57 -> 1.53, c5 1.70 -> 1.54) and with `Waiting: 0` in 100% of loaded
scheduler samples. No admission story predicts that. The campaign therefore has a
knob that demonstrably moves **decode** and has never been curved: three budgets
(8192 / 32768 / 98304) measured at scattered concurrencies, with c4 the only
concurrency that appears at more than one of them, and even there at three
different `max_num_seqs` values.

Six budgets at ONE concurrency, everything else held: **8192, 16384, 32768,
65536, 98304, 131072**, all at `max_num_seqs 5`, c4, d16384, tg128, runs=7.

### THE ADMISSION ARITHMETIC, computed before the run

A Phase-2 request prefills `depth + pp` = **18432** tokens (R13's pre-flight;
prefix caching never hits, so none of the 16384 is free). Four requests are
**73728** tokens. With chunked prefill ON a scheduler step packs up to `B` tokens
across requests, so admission takes `ceil(73728 / B)` steps:

| mnbt B | admission steps at c4 | new value? |
|---:|---:|---|
| 8192 | 9 | no — R2/R9 A0 |
| 16384 | 5 | **NEW** — torch.compile rebuild |
| 32768 | 3 | no — R9 A1 / R10 |
| 65536 | 2 | **NEW** — torch.compile rebuild |
| 98304 | 1 | no — R13 |
| 131072 | 1 | **NEW** — torch.compile rebuild |

**98304 and 131072 are the same admission configuration** — both admit the whole
batch in one step, both leave `Waiting: 0`. That pair is the round's discriminator.

### THE DISCRIMINATOR, declared before the run

R13 left an unexplained fact: the budget lifts per-request decode. Two accounts,
and they differ on the one place the curve can separate them — past the point
where admission is already a single step.

- **H_admission_decode** — decode is depressed only while prefill is being
  chunked across steps and interleaved with ongoing decode. Once `B >= 73728` the
  effect is exhausted. Prediction: **`tg_req(131072) <= 1.03 x tg_req(98304)`**,
  and `tg_req(65536)` already within 5% of `tg_req(98304)`.
- **H_budget_decode** — the budget itself buys decode (larger compile ranges,
  a wider token allocation per step), independent of how many steps admission
  takes. Prediction: **`tg_req(131072) >= 1.05 x tg_req(98304)`**.
- Between 1.03 and 1.05 the round reports **mixed** and does not force it.

Secondary, and cheap: the knee. If admission steps drive the curve, the knee sits
between 32768 (3 steps) and 65536 (2 steps) and the curve is flat above it.

### HEADLINE PROTECTION — the reproduction rule, written before the numbers exist

Three of the six points re-measure an archived headline figure. The band is
**±10%** around the archived median, and it is not arbitrary: σ/med at this cell
is 3.3-4.4%, a 7-run median's standard error is ~2%, and the campaign's own
measured cross-invocation systematics are 2.9% (R10 vs R9 A1), 1.8% (R8 vs R6)
and 0.2% (R13's pp2048 vs R12's). ±10% is about 2.5x the expected combined
spread — wide enough that a true reproduction clears it comfortably, tight enough
that a real regression fails it.

| # | protected row | archived | band | margin at stake |
|---|---|---:|---|---|
| P1 | tg128 @ d16384 c4, campaign config | 52.85 | **47.6 – 58.1** | 1.13x vs 46.68 |
| P2 | tg128 @ d16384 c4, mnbt 32768 | 147.25 | **132.5 – 162.0** | 3.15x |
| P3 | tg128 @ d16384 c4, mnbt 98304 | 174.68 | **157.2 – 192.1** | **3.74x** |
| P4 | ctx_tg @ d16384 c4, mnbt 98304 | 170.59 | **153.5 – 187.6** | **6.16x — widest in campaign** |
| P5 | ctx_tg @ d16384 c4, mnbt 32768 | 126.35 | **113.7 – 139.0** | 4.56x |
| P6 | ctx_tg @ d16384 c4, campaign config | 56.36 | **50.7 – 62.0** | 2.04x |

**The rule, and it binds this round:**

- **Inside the band** — the row STANDS, and the journal and RESULTS.md record the
  reproduction gap as a number, not as a reassurance.
- **Outside the band** — the claimed figure for that row becomes the **pooled
  14-run median** of the archived runs and this round's runs, exactly as R6 did to
  R1 and R8 did to R3, the margin is revised in RESULTS.md, and the journal says
  plainly that the row came down. If the pooled median falls below the incumbent
  the cell moves from WON to LOST.
- **No row is defended by discarding this round's runs.** Seven runs against seven
  runs, same instrument, same image epoch — there is no basis for preferring the
  older draw.

One systematic is knowingly introduced and must be named: **the curve holds
`max_num_seqs 5` at every point**, while the archived rows were measured at mns 4
(P1, P6), mns 16 (P2, P5) and mns 5 (P3, P4). Varying `mns` to chase each
historical row would have wrecked the curve. At c4 every one of those values
satisfies `mns >= c`, so no request waits for a *slot* in any of them — R4's
+5.5% mns effect was measured at c5 where `mns 4 < c`, and R10 priced an mns
change at c4 (mns 4 -> 16, same budget) at **2.9%**. The ±10% band already covers
twice that. If P1 or P2 misses low by less than that margin, the journal will say
so rather than blaming `mns` for it.

### ONE INVOCATION IS IMPOSSIBLE HERE, and the round says so instead of pretending

The campaign's strongest methodological result is that single-invocation controls
beat cross-invocation inference every time it tested one (R6 over R1, R8 over R3,
R9b over R4, R10 over R2). **This round cannot have one.**
`max_num_batched_tokens` is a vLLM *serve* argument substituted into the recipe's
command template; `sparkrun -o key=value` takes a single value per key and starts
one engine per invocation. There is no way to vary it inside an engine start. Six
budgets = **six invocations, six engine starts**. The queue entry's "ONE
invocation" is not achievable and the round is not going to fake it by running
one budget and inferring the rest.

So this comparison is **weaker than a single-invocation one**, and three things
are done about it rather than said about it:

1. **`pp2048` is a session control in every arm**, against a series flat across
   nine invocations (623-643 at campaign config, 655-680 at raised budgets). Any
   arm whose control misses has its `tg` figures declared unreadable.
2. **Telemetry in every arm** — the SM clock has read 2392-2398 MHz in ten
   consecutive sessions; a drifting box would show here first.
3. **Three of the six points ARE reproductions**, so this round *measures* its own
   cross-invocation systematic instead of assuming one. That is a by-product worth
   as much as the curve: nobody has ever measured this campaign's engine-start
   error at three widely separated operating points in one night.

**Arm order is priority order, not curve order** — 98304, 32768, 8192, then the
three new values 16384, 65536, 131072. If the night is cut short, the three
protection points are already banked. Thermal drift across the sequence is
exactly what the telemetry and `pp2048` controls are for.

### Numeric predictions

`tg = c x tg_req / stagger`. Bands built from the generating model and from the
three archived points, not by scaling percentages.

| mnbt | `tg` band | centre | `tg_req` band | stagger band | peak_thr band |
|---:|---|---:|---|---|---|
| 8192 | 45 – 60 | 52 | 30 – 37 | 2.3 – 2.8 | 275 – 300 |
| 16384 | 75 – 115 | 95 | 40 – 55 | 1.8 – 2.4 | 275 – 305 |
| 32768 | 132 – 162 | 147 | 54 – 62 | 1.45 – 1.75 | 275 – 305 |
| 65536 | 150 – 182 | 166 | 60 – 69 | 1.42 – 1.62 | 285 – 315 |
| 98304 | 157 – 192 | 175 | 62 – 71 | 1.42 – 1.62 | 290 – 320 |
| 131072 | 155 – 195 | 175 | 62 – 71 | 1.40 – 1.65 | 290 – 325 |

Side predictions, each of them a standing campaign regularity being tested again:

| quantity | predicted | why |
|---|---|---|
| `pp2048` @ mnbt 8192 | **623 – 643** | campaign-config series, nine invocations |
| `pp2048` @ every raised budget | **655 – 690** | raised-budget plateau (658.93 / 663.93 / 667.00 / 669.28 / 672.59 / 676.40 / 677.44) |
| `ttfr` monotone rising with B | **yes**, and `ttfr(131072) >= 12102` | rose on all six previous budget increases |
| MTP acceptance | **2.85 – 3.15 / 61 – 72%** at every budget | flat under every scheduler knob for five rounds |
| Prefix cache hit rate | **0.0% at all six budgets** | 0.0% in 162 samples across three budgets |
| `Running`/`Waiting` at c4 | **NOT (4,0) at 8192 and 16384; clean (4,0) at 32768 and above** | R9 read `(2,2)`/`(3,1)` at 8192; R10 and R13 read `(4,0)` at 32768 and 98304 |
| stagger proxy `c/(tg/tg_req)` | **INVALID at 8192 and 16384** if residency is partial | R5c: the proxy holds only at full residency |
| ctx (Phase 1) vs Phase 2 | **ctx below Phase 2 at the raised budgets**, sign unpredicted at 8192/16384 | −2.3% at 98304, −14.2% at 32768, but **+4.4% at 8192** — this regularity has broken four times and is not leaned on |
| SM clock median | **2392 – 2398 MHz** | eleventh consecutive session |
| grid time | **1250 – 1500 s** total | R13's c4 arm was 225.5 s at runs=7 |
| engine starts | **3 cached (~180 s) + 3 rebuilt (~225 s)** ≈ 1750 s | R13: a NEW budget value misses the torch.compile cache and costs ~45 s extra |
| wall clock | **55 – 75 min** | the round is six invocations, and it is priced as six |

### MUTATIONS, stated plainly

`-o max_num_seqs=5` and `-o max_num_batched_tokens=<B>` at six values.
**Both are MUTATIONS**; `recipe.yaml` is NOT touched and `max_model_len` stays at
the recipe default 32768 (R13 established from `vllm/config/scheduler.py:248-284`
in the pinned image that there is no `mnbt <= max_model_len` validator while
chunked prefill is on; the only other constraints are `mnbt >= max_num_seqs`,
satisfied at every value, and a *warning* above `max_num_seqs x max_model_len` =
163840, which no value here reaches). Every RESULTS.md row this round produces
names its configuration. The fold decision remains **R11's**, and this round is
what R11 needs: R11 asks for the c1 anchor at the folded budget, and it cannot
even be posed properly until somebody knows the shape of the budget response.

### Discipline

- **runs=7 at every point.** Both 3-run medians this campaign ever promoted had
  to be retired and both were too high.
- **BOTH estimators at every point** — `tg_throughput` and `peak_throughput` side
  by side, `tg_req_throughput` for the span ratio. **Never `tg x c`.**
- Read the `Benchmark args:` echo before letting a run proceed (R5's lost engine
  start). The first arm's echo is read by hand; the driver asserts the same
  fields on every later arm and aborts if they differ.
- Engine log captured the proven way — `docker exec <container> tail -f
  /tmp/sparkrun_serve.log` — and **verified live** with `grep -c 'Running:'`
  before any arm's occupancy figure is quoted. R8, R9 and R12 all shipped without
  this instrument; R13 recovered it.
- Serial. Nothing else touches the box. No arena submission, ever. No box system
  settings, no `apt`.

## Round 13c outcome — six invocations, 2026-08-22

Six budgets at c4 / d16384 / tg128 / `max_num_seqs 5` / runs=7. Every arm
`session_count: 1`, `crash_count: 0`, same pinned image epoch
(`dgx-vllm-eugr-nightly:2026082102`) as every round since R1. Archived as
`bench_<id>-mnbt<B>`:

| mnbt | benchId | grid | engine start |
|---:|---|---:|---:|
| 8192 | `bench_0f4c34c12223-mnbt8192` | 226.2 s | 112.8 s |
| 16384 | `bench_fa5630a4ac79-mnbt16384` | 222.4 s | 137.7 s |
| 32768 | `bench_10bd1b5f24ea-mnbt32768` | 220.5 s | 160.6 s |
| 65536 | `bench_0bd1f20dca74-mnbt65536` | 218.3 s | 185.2 s |
| 98304 | `bench_d6cec044441c-mnbt98304` | 229.5 s | 177.9 s |
| 131072 | `bench_0509b2a740f6-mnbt131072` | 236.6 s | **310.0 s** |

### THE ANSWER TO THE ROUND'S FIRST QUESTION: ALL SIX PROTECTED ROWS STAND

Every one of the six protected figures reproduced inside its pre-declared ±10%
band, from a separate engine start, at runs=7 against runs=7.

| # | protected row | archived | R13c | gap | band | verdict |
|---|---|---:|---:|---:|---|---|
| P1 | tg128 @ d16384 c4, mnbt 8192 | 52.85 | **52.07** | **−1.48%** | 47.6–58.1 | **STANDS** |
| P2 | tg128 @ d16384 c4, mnbt 32768 | 147.25 | **143.83** | **−2.32%** | 132.5–162.0 | **STANDS** |
| P3 | tg128 @ d16384 c4, mnbt 98304 | 174.68 | **169.69** | **−2.86%** | 157.2–192.1 | **STANDS** |
| P4 | ctx_tg @ d16384 c4, mnbt 98304 | 170.59 | **168.37** | **−1.30%** | 153.5–187.6 | **STANDS** |
| P5 | ctx_tg @ d16384 c4, mnbt 32768 | 126.35 | **125.74** | **−0.48%** | 113.7–139.0 | **STANDS** |
| P6 | ctx_tg @ d16384 c4, mnbt 8192 | 56.36 | **54.57** | **−3.18%** | 50.7–62.0 | **STANDS** |

P2 is worth a second line: 143.83 at `mns 5` reproduces **R9's arm A1** (143.08,
`mns 4`, runs=3) to **+0.5%** as well as R10's 147.25 (`mns 16`, runs=7) to
−2.3%. That cell now has three independent measurements at three different
`max_num_seqs` values spanning 4 to 16, inside a 2.9% band. R10's pricing of the
`mns` systematic at c4 is confirmed rather than assumed.

**AND ALL SIX GAPS ARE NEGATIVE.** −1.48 / −2.32 / −2.86 / −1.30 / −0.48 /
−3.18%, mean **−1.94%**, six of six the same sign. On a coin that is p ≈ 3%.
Two candidates and **this round cannot separate them**: a small decode-side
session effect tonight, or a first-measurement bias in a campaign that promotes
the figure from the run that motivated the round. Evidence bearing on it: the
`pp2048` session control landed in band at **five of six** arms, so no night-wide
slowdown is visible — but `pp` is a prefill measurement and `tg` is a decode
measurement, so a decode-only session effect would not show there. **Recorded as
an open, unresolved 2% systematic**, not explained away. It is small enough that
no verdict, margin or standing changes sign, and large enough that it should be
subtracted mentally from any figure this campaign has measured exactly once.

### THE STANDINGS CHANGE THAT FOLLOWS, and it is a tightening

For P3/P4 the two measurements are the **same configuration** (mnbt 98304 + mns
5), seven runs each. There is no basis for preferring either draw, so the claimed
figure becomes the **pooled 14-run median**, which is what R2 did with its verify
run and what R6 and R8 did when they retired 3-run figures:

| cell | R13 (7) | R13c (7) | **pooled (14)** | margin was | **margin now** |
|---|---:|---:|---:|---:|---:|
| tg128 @ d16384 c4, mnbt 98304 | 174.68 | 169.69 | **171.31** | 3.74x | **3.67x** |
| ctx_tg @ d16384 c4, mnbt 98304 | 170.59 | 168.37 | **170.36** | 6.16x | **6.15x** |

**This is a stricter standard than the round declared** — the pre-declared rule
only required pooling on a band miss — and it is applied because the reproduction
was same-config. `ctx_tg @ d16384 c4` remains the campaign's widest margin at
**6.15x**, comfortably past `tg128 @ d65536 c1`'s 5.71x. ⚠ **CORRECTED by R13d:**
the title is now the mnbt 131072 pooled 171.77 = **6.21x**.

P1/P2/P5/P6 are **NOT pooled**: those rows were measured at `mns 4` and `mns 16`
and this round ran `mns 5`. Pooling across a configuration difference is the one
thing this file has said repeatedly must never happen. The archived figures stand
as claimed, and R13c's points get their own rows naming `mns 5`.

### THE CURVE — Phase 2 (the headline rows)

| mnbt | admission steps | `tg` | σ/med | `tg_req` | span ratio | `peak_thr` | `pp2048` | ttfr | scheduler |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 8192 | 9 | **52.07** | 1.03% | 33.00 | 2.535 | 271 | 638.04 | 10217 | **partial** |
| 16384 | 5 | **85.90** | 2.08% | 43.99 | 2.048 | 277 | 659.21 | 11175 | **partial** |
| 32768 | 3 | **143.83** | 3.87% | 59.48 | 1.654 | 288 | 670.76 | 11859 | (4,0) 13/13 |
| 65536 | 2 | **173.34** | 4.39% | **65.24** | **1.505** | 308 | 671.68 | 12167 | (4,0) 10/10 |
| 98304 | 1 | **169.69** | 4.01% | 64.02 | 1.509 | 302 | 645.90 | 12375 | (4,0) 11/11 |
| 131072 | 1 | **170.89** | 3.89% | 64.14 | 1.501 | 304 | 670.32 | 12208 | (4,0) 12/13 |

### THE CURVE — Phase 1 (`ctx_`, the context load)

| mnbt | `ctx_tg` | σ/med | `tg_req` | span ratio | `peak_thr` | `ctx_pp` | vs Phase 2 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 8192 | 54.57 | 0.87% | 31.01 | 2.273 | 263 | 5875.22 | **+4.8%** |
| 16384 | 68.79 | 0.84% | 42.38 | 2.464 | 259 | 6007.70 | **−19.9%** |
| 32768 | 125.74 | 2.57% | 58.10 | 1.848 | 283 | 6117.63 | −12.6% |
| 65536 | 164.95 | 1.95% | 62.05 | 1.505 | 289 | 6200.01 | −4.8% |
| 98304 | 168.37 | 3.46% | 61.20 | 1.454 | 284 | 6189.65 | −0.8% |
| 131072 | **175.40** | 3.95% | 64.26 | 1.465 | 296 | 6163.69 | **+2.6%** |

### THE DISCRIMINATOR: H_admission_decode HOLDS — and it kills the reason R13 ran at 98304

Declared before the run: `tg_req(131072) <= 1.03 x tg_req(98304)` reads
H_admission_decode, `>= 1.05x` reads H_budget_decode, between is mixed.

**`tg_req(131072) / tg_req(98304) = 64.14 / 64.02 = 1.0019.`** Decisively
H_admission_decode. The second leg held too: `tg_req(65536)` = 65.24 is within
**1.9%** of `tg_req(98304)`, against a 5% threshold. **The budget does not buy
decode past the point where admission stops being split. There is nothing above
the knee.**

**But the mechanism is only half right, and the half that is wrong is R13's.**
H_admission_decode said decode is depressed *while prefill is chunked across
steps*, which implies the ceiling arrives at one-step admission. It does not.
**The ceiling arrives at 65536, which is a TWO-step configuration** — and 65536
is the highest `tg_req` of the six. The three budgets at or above 65536 read
173.34 / 169.69 / 170.89 on `tg`, a **2.1% spread against a per-arm σ/med of
~4%**: statistically one point.

**So `max_num_batched_tokens 98304` — the value R13 derived from careful
one-step-admission arithmetic and paid a torch.compile rebuild for — buys
NOTHING over 65536.** R13's pre-flight was right that 81920 would leave a
trailing step and right that 98304 removes it; it was wrong that removing the
last step is what the gain was made of. Two steps is already enough. This is the
same shape as R13's own outcome, which got its numbers from the term it treated
as secondary.

### THE KNEE, and what it means for R11

The knee is at **65536**, exactly where the round predicted it, and the curve is
flat above it. Going 8192 -> 65536 is **+233%**; going 65536 -> 131072 is
**−1.4%**, i.e. nothing.

**R11's fold decision now has a value, and it is 65536, not 98304.** Same
throughput to within noise, a smaller activation budget, and a cheaper engine
start (185.2 s against 310.0 s at 131072). R11 still needs what it always
needed — the c1 anchor re-measured — but it no longer needs it at three budgets:
it needs it at one, and this round says which one.

### FULL RESIDENCY IS NOT THE SAME THING AS A FULL SPAN, and the curve separates them

Two thresholds sit at different budgets and the campaign has been conflating them:

- **Residency** saturates at 32768. The scheduler reads a clean
  `Running: 4, Waiting: 0` in 13/13 loaded samples there, and at every budget
  above. Below it the batch queues: at 16384 the log carries `(2,2)` x4 and
  `(3,1)` x5 against `(4,0)` x7, and at 8192 it carries `(1,3)`, `(2,2)` x4 and
  `(3,1)` x5 against `(4,0)` x9. **The prediction that 8192 and 16384 would not
  hold full occupancy and 32768 and above would, held exactly**, and it
  reproduces R9's direct observation at c4/mnbt 8192 from a fourth engine start.
- **The span ratio** does NOT saturate at 32768. It keeps falling to 65536
  (1.654 -> 1.505) and then stops dead (1.509, 1.501).

So between 32768 and 65536 nothing is waiting for admission and the span still
tightens by 9%. **That is R13's `Waiting: 0` finding seen from the other side,
and it is the second independent confirmation that the ratio this campaign spent
four rounds calling "admission stagger" is not admission.** The floor it settles
on is **~1.50**, reached at 65536 and unmoved by doubling the budget twice more.

Per the pre-declaration, the span figures at 8192 and 16384 are **proxies only
and are not treated as physical stagger** — residency is partial at both, which
is exactly the condition R5c showed invalidates `c / (tg/tg_req)`. They are
reported because they are what the metric's arithmetic contains, not because they
measure a batch span.

### A NEW WIDEST MARGIN WAS MEASURED AND IS DELIBERATELY NOT PROMOTED

⚠ **RESOLVED BY R13d.** The repeat read 170.16; the pooled 14-run median is
**171.77 = 6.21x**, which does take the title — but by 0.83%, not by the 3.1%
the 175.40 draw suggested. **175.40 / 6.34x is retired.** Original text below.

`ctx_tg @ d16384 c4` at mnbt 131072 reads **175.40**, which against the incumbent
27.68 is **6.34x** — higher than the pooled 6.15x that currently holds the
campaign's widest-margin title.

**It is recorded as a row and it is NOT claimed as the widest margin.** It is a
single 7-run median at a configuration measured once, its σ/med is 3.95%, and its
two neighbours above the knee read 168.37 and 164.95 — the three are one point
within noise, and 175.40 is simply the highest draw of the three. Promoting the
best first measurement of a cell is precisely the error that retired R1's 129.32
and R3's 108.15, **both of which were too high**, and this is a round whose whole
purpose is to not do that. If somebody wants 6.34x, it costs one repeat: queued
as R13d.

### CONTROLS, and one gate that was set too tight

**`pp2048` session control: five of six arms in band, one miss.**

| mnbt | `pp2048` | band | verdict |
|---:|---:|---|---|
| 8192 | 638.04 (σ 1.31) | 623–643 | **PASS** |
| 16384 | 659.21 (σ 3.82) | 655–690 | **PASS** |
| 32768 | 670.76 (σ 2.49) | 655–690 | **PASS** |
| 65536 | 671.68 (σ 2.13) | 655–690 | **PASS** |
| 98304 | **645.90** (σ 38.43) | 655–690 | **MISS, −1.4%** |
| 131072 | 670.32 (σ 25.06) | 655–690 | **PASS** |

The declared consequence of a control miss was that the arm's `tg` figures are
unreadable. **That consequence is NOT applied to the 98304 arm, and here is the
argument, made in the open rather than by waiving the rule.** (a) The miss is
one low draw: the seven runs are 556.89 / 627.74 / 636.74 / 645.90 / 661.85 /
676.11 / 678.13, and six of seven sit inside or beside the band — the same
mode-plus-one-low-draw shape R8 and R12 documented. (b) The **same arm carries a
second, better-resolved prefill control**: `ctx_pp` (Phase 1) is charged 16384
tokens rather than 2048 and reads **6189.65 against R13's 6222.20 — 0.5%**. (c)
The arm run immediately before it and the arm run immediately after it both
passed. (d) Telemetry passed. **The gate was too tight for a 7-run `pp2048`
median whose σ can reach 6%; it was built from seven historical point estimates
without pricing their dispersion.** That is the second broken validity gate this
campaign has recorded (R9b's `ctx_pp2048 < 1200` was the first) and it is
recorded as broken rather than quietly dropped. A future round should gate on
`ctx_pp`, which is the same physics measured nine times more precisely.

**Telemetry: SM clock median 2398 MHz in all six arms** (2290 samples), 79 °C
peak, 99.91 W peak. Sessions **eleven through sixteen** agreeing with R4's 2392.
No clock, power-policy, driver or kernel setting was touched and no `apt` was run.

**Prefix cache hit rate 0.0% in all 135 engine samples, at all six budgets**, flag
ON. The campaign total is now **297 samples across six token budgets spanning
16x**. Nothing on this curve is a caching effect.

**MTP acceptance flat across a 16x budget sweep**: medians 3.03 / 3.09 / 3.19 /
3.09 / 3.08 / 3.14 at the six budgets (123 samples). Sixth consecutive round
finding acceptance unmoved by a scheduler knob, and the strongest version yet
because the knob moved 16-fold. The 32768 arm's 3.19 is 1.3% above the declared
band and is scored as a miss.

### THE ctx-VS-PHASE-2 SIGN IS A FUNCTION OF THE TOKEN BUDGET, and it flips TWICE

+4.8% (8192) -> **−19.9%** (16384) -> −12.6% (32768) -> −4.8% (65536) -> −0.8%
(98304) -> **+2.6%** (131072). The prediction "ctx below Phase 2 at the raised
budgets" held at four of five and is **refuted at 131072**.

This is the sixth time this regularity has broken, and the curve finally shows
why nobody could pin it: **it is not a regularity at all, it is a smooth response
to the token budget with a minimum near 16384**, and every previous round sampled
it at one or two budgets and read the local sign as a rule. R12's asymmetry gets
the same treatment and the same explanation — the `ctx_` phase staggers MORE than
Phase 2 at 16384 (2.464 vs 2.048) and at 32768 (1.848 vs 1.654), exactly as R12
found, and LESS at 65536, 98304 and 131072 (1.505/1.454/1.465 against
1.505/1.509/1.501), exactly as R13 found. **R12 and R13 were both right about
their own budget and both wrong to call it a rule.** With the phase-label
correction having already dissolved the question this asymmetry was posed to
answer, the right disposition is: the numbers are a budget response, and there is
no puzzle left attached to them.

### PREDICTIONS: 43 held, 7 missed, of 50 pre-declared bands and thresholds

Held: **all 24 main-table bands except one** — every `tg`, `tg_req` and span-ratio
band at all six budgets, and five of six `peak_thr` bands. The `tg` band at 8192
predicted centre 52 and measured 52.07. Also held: `pp2048` at 8192 and at four
of five raised budgets; `ttfr(131072) >= 12102` (12208); MTP acceptance at five
of six; prefix cache at all six; `Running`/`Waiting` at all six, exactly as
specified; the stagger-proxy validity call; ctx-vs-Phase-2 sign at four of five;
SM clock; and grid time (1353.5 s against 1250–1500 s).

Missed, all seven:
1. `peak_thr` at 8192: **271** against 275–300, low by 1.5%.
2. `pp2048` at 98304: **645.90** against 655–690 — the broken gate above.
3. **ttfr monotonicity**: rose on five consecutive increases (10217 -> 11175 ->
   11859 -> 12167 -> 12375) and then **fell 1.4% at 131072** (12208). The
   seven-increase run of "raising the budget makes time-to-first-response worse"
   ends here, though the fall is inside noise and the threshold prediction held.
4. MTP acceptance at 32768: 3.19 against 2.85–3.15.
5. ctx below Phase 2 at 131072: **+2.6%**, refuted.
6. **Engine-start cost: 1084.2 s total against ~1750 s predicted.** See below.
7. **Wall clock 45m23s against 55–75 min.** The round was cheaper than priced.

### A CORRECTION TO R13's COST NOTE, bought for nothing

R13 reported that a new `max_num_batched_tokens` value costs a full torch.compile
rebuild (~+45 s) and warned anyone sweeping the flag to budget for it per value.
Three of this round's six values were new. Measured:

| mnbt | engine start | new value? |
|---:|---:|---|
| 8192 | 112.8 s | cached |
| 16384 | **137.7 s** | **NEW** |
| 32768 | 160.6 s | cached |
| 98304 | 177.9 s | cached |
| 65536 | **185.2 s** | **NEW** |
| 131072 | **310.0 s** | **NEW** |

**Start cost tracks the SIZE of the budget, not its novelty.** 16384 and 65536
were both new and both sit on the trend line drawn by the cached values; only
131072 sits above it, by roughly two minutes. So a sweep is much cheaper than
R13's note implies — the correct planning figure is ~110–190 s across
8192–98304 with a step up beyond that, not a flat rebuild penalty per value.
Sweeping this flag is affordable, which is worth knowing before the next one.

### MUTATIONS NOT FOLDED

`recipe.yaml` is untouched. `max_num_seqs 5` and `max_num_batched_tokens <B>` are
MUTATIONS at every point and every RESULTS.md row this round produces names its
configuration. `max_model_len` stayed at the recipe default 32768 throughout and
no validator fired at any budget up to 131072, confirming R13's source read.

### ONE INVOCATION WAS IMPOSSIBLE, AS DECLARED — and the round measured the price

Six budgets meant six engine starts; `max_num_batched_tokens` is a serve argument
and cannot vary inside a session. The round said so in advance and treated the
comparison as the weaker kind. **What it bought instead is the first direct
measurement of this campaign's cross-invocation error at several operating points
in one night: 0.48% to 3.18%, mean 1.94%, always in the same direction.** Every
cross-round comparison in this file inherits an error bar of about that size, and
until tonight it was assumed rather than measured.

### COST

Six invocations, six engine starts, **1353.5 s of grid time**, 1084.2 s of engine
start, **45m23s wall**, ~90k harness tokens. Zero crashes, zero retries, no arena
submission, no box system change.

### The round's value, in one line

**All six protected rows reproduced from separate engine starts at runs=7, the
two same-config figures were tightened to pooled 14-run medians (3.67x, and 6.15x
⚠ since superseded as the widest margin by R13d's 6.21x —
which is still the campaign's widest), the budget response was curved for the
first time and knees at 65536 — so R13's 98304 buys nothing and R11's fold value
is 65536 — and six-for-six low reproductions put a measured ~2% error bar on
every figure this campaign has taken exactly once.**

---

## Round 13d hypothesis — the promotion test: repeat `ctx_tg @ d16384 c4` at `mnbt 131072 + mns 5`, runs=7, one invocation

Written BEFORE the run, 2026-08-22.

### What this round is for

R13c measured **`ctx_tg @ d16384 c4` = 175.40** at `max_num_batched_tokens
131072`, `max_num_seqs 5`. Against the board incumbent **27.68** that is
**6.34x** — wider than the campaign's current title, the **pooled 14-run 170.36
(6.15x)** at `mnbt 98304`. R13c deliberately did NOT promote it, for the reason
that has bitten this campaign twice: **it is a single 7-run median at a config
measured exactly once**, and its two neighbours above the budget knee (168.37 at
98304, 164.95 at 65536) make the top three statistically one point (σ/med ~4%).
R1's 129.32 and R3's 108.15 were both retired for being high draws, and both
were 3-run. This one is 7-run, but it is still one draw of the config.

**One repeat settles it.** This round runs the identical configuration a second
time and pools.

### The exact configuration — identical to R13c's 131072 arm

`pp 2048`, `depth 16384`, `tg 128`, `concurrency 4`, `runs 7`,
`-o max_num_batched_tokens=131072 -o max_num_seqs=5`, everything else the
campaign recipe. Two mutations off the campaign config, both journaled, neither
folded. **One invocation, one engine start** — the Phase-2 partner
(`tg128 @ d16384 c4`) rides along free in the same grid, which is the second
thing this round buys.

### Decision rule, declared before the run

Let `M14` be the median of the **14 pooled runs** at `mnbt 131072` (R13c's seven
plus this round's seven). Pooling is legitimate here and only here: same recipe,
same probe, same two mutations, same values. This is exactly what R13c did to
R13's 98304 arm.

- **`M14 > 170.36` → the title MOVES.** `ctx_tg @ d16384 c4` at `mnbt 131072`
  becomes the campaign's widest margin, quoted as `M14 / 27.68`.
- **`M14 <= 170.36` → the title STAYS at 170.36** and R13c's 175.40 is recorded
  as the high draw it looks like. The question is then **closed for good** — no
  third measurement, whatever the gap.

No other outcome is available. In particular, a repeat median above 175.40 does
not by itself move anything; only the pooled figure decides.

### Numeric predictions

**Primary — the repeat's own 7-run median, `ctx_tg`.** Three arguments point the
same way and I will state the strongest first.

1. **Regression toward the top-three mean.** The three above-knee budgets read
   175.40 / 168.37 / 164.95 for `ctx_`, plus R13's 170.59 at 98304 — mean
   **169.8**. If they are one point, 175.40 is the top draw of four and the
   repeat should land near 169.8, not near 175.40.
2. **R13c's measured systematic.** All six of its reproductions came in low,
   mean **−1.94%**, six of six the same sign (p≈3%). Applied to 175.40 that is
   **172.0**.
3. **Dispersion.** σ/med was 3.95% on the prior seven (runs 158.89 to 178.96, a
   1.13x spread). A 7-run median of that distribution has a sampling spread of
   its own of order 2-3%.

**Prediction: repeat median `ctx_tg` = 160 – 176, centre 169.**

**Prediction: `M14` = 168 – 174, centre 171.0.** This is honestly knife-edge
against the 170.36 threshold and I am saying so before the run rather than
after: a repeat at my central 169 pools with R13c's seven to roughly **171**,
about **0.4%** above the title. **The most likely single outcome is a title move
by a margin too small to mean anything physically** — 6.15x to ~6.18x. The
round's value is not the third decimal place; it is that the 6.34x claim gets
tested instead of sitting in RESULTS.md as an unpromoted asterisk.

**Secondary — the Phase-2 partner, `tg128 @ d16384 c4`.** R13c read **170.89**
here, against 173.34 at 65536 and 169.69 at 98304. Prediction: **162 – 178**.
The above-knee-is-one-point claim survives if the new value lands inside the
existing 169.69–173.34 spread widened by its own σ; it is damaged if the repeat
falls outside 160–180.

**Controls and side-predictions.**

| Quantity | Prior (R13c 131072 arm) | Predicted | Why |
| --- | --- | --- | --- |
| `ctx_pp2048` (session gate) | 6163.69 | **5900 – 6400** | R13c's lesson: gate on `ctx_pp`, not `pp2048`. `ctx_pp` reproduced to 0.5% where `pp2048` broke its gate on one low draw |
| `pp2048` | 670.32 (σ 25.06) | 610 – 690 | recorded, NOT gated — this is the gate R13c broke and it was built without pricing dispersion |
| `ctx_pp / pp` ratio | 9.20 | **8.7 – 9.4** | zero-free-parameter phase-label prediction `(depth+2048)/2048 = 9.0`, holding at 35 of 36 archived pairs |
| `tg_req` (Phase 2) | 64.14 | 60 – 68 | decode rate is the budget-insensitive term above the knee |
| span ratio `tg/tg_req` | 1.501 (Phase 2), 1.465 (ctx) | 1.40 – 1.60 both | floors at ~1.50 above the knee (R13c); **NOT admission** — `Waiting: 0` |
| scheduler `Running/Waiting` | (4,0) 12/13 | **(4,0) in ≥90% of loaded samples** | full residency from mnbt 32768 up |
| MTP acceptance length | 3.03 – 3.19 across six budgets | **3.0 – 3.2** | flat across every scheduler knob for five rounds |
| prefix cache hit rate | 0.0% | **0.0%** | 297 samples, six budgets, zero hits |
| SM clock median | 2398 MHz | **2392 – 2398** | sixteen sessions agreeing |
| σ/med, both phases | 3.95% / 3.89% | 2 – 6% | |
| `ttfr` (Phase 2) | 12208 | 11500 – 13000 | |
| grid time | 236.6 s | 210 – 270 s | |
| engine start | 310.0 s | **270 – 350 s** | start cost tracks budget SIZE, not novelty (R13c's correction); 131072 is the one budget above the trend line |

**The systematic is the round's second product.** If this repeat also lands
below its predecessor, that is a **third independent look** at R13c's −1.94%
downward bias — six reproductions became seven, and a bias measured on six
same-sign reproductions is worth more to every once-measured figure in
RESULTS.md than the margin this round is nominally chasing. If it lands ABOVE
175.40, the bias story weakens and the "high draw" reading is wrong.

### What would make this round void

- Any `crash_count > 0` or `session_count > 1` — the comparison is to a
  single-engine-start figure and must itself be one.
- `Benchmark args:` echo not showing `depth: [16384]`, `concurrency: [4]`,
  `runs: 7` (the R5 process failure: sparkrun silently defaults an omitted
  `-b depth` to 0 and does not error). **Read the echo before letting it run.**
- `ctx_pp2048` outside 5000 – 7000, which would mean the prefill is not doing
  what every other run at this depth does.

### Cost

One invocation, ~237 s grid + ~310 s engine start, ~10 min wall.

## Round 13d outcome — bench_0509b2a740f6-r13d (2026-08-22)

`ctx_tg @ d16384 c4` at `max_num_batched_tokens 131072` + `max_num_seqs 5`,
runs=7, ONE invocation, ONE engine start (`session_count: 1`, `crash_count: 0`),
Phase-2 partner riding along. Archived at
`experiments/bench_0509b2a740f6-r13d/`. sparkrun reused R13c's benchId — same
recipe, same params — so the round carries the `-r13d` suffix; R13c's directory
was not touched.

### THE TITLE MOVES, BY 0.8%, AND THE ROUND SAID SO BEFORE IT RAN

**Pooled 14-run median `ctx_tg @ d16384 c4` at mnbt 131072 = 171.77**, against
the board incumbent 27.68: **6.21x**. The threshold declared before the run was
the standing 170.36 (6.15x) at mnbt 98304. **171.77 > 170.36, so the title
moves** — and it moves by **0.83%**, which is the outcome the hypothesis called
"a title move by a margin too small to mean anything physically". The right way
to read this round is therefore NOT that a better configuration was found. It is
that the campaign's widest-margin claim now rests on 14 runs at a re-measured
configuration instead of one 7-run draw, and it landed almost exactly where the
pre-run arithmetic put it.

| | R13c | **R13d** | pooled 14 | vs 170.36 |
|---|---:|---:|---:|---|
| `ctx_tg` (Phase 1) | 175.40 | **170.16** | **171.77** | **+0.83% — TITLE MOVES, 6.21x** |
| `tg128` (Phase 2) | 170.89 | 168.97 | 170.84 | — |

**R13c's 175.40 = 6.34x is retired as the high draw it looked like.** The repeat
came in 2.99% below it and the pooled figure sits 2.07% below it. The 6.34x
number should not appear in any standings claim again.

### PREDICTIONS: THE PRIMARY ONES ALL HELD, AND THEY WERE THE TIGHT ONES

| prediction | band | measured | verdict |
|---|---|---:|---|
| repeat median `ctx_tg` | 160 – 176, centre **169** | **170.16** | **HELD**, 0.7% from centre |
| **`M14` pooled** | 168 – 174, centre **171.0** | **171.77** | **HELD**, 0.45% from centre |
| Phase-2 repeat | 162 – 178 | 168.97 | HELD |
| `ctx_pp/pp` ratio | 8.7 – 9.4 (theory 9.00) | **9.08** | **HELD** |
| `tg_req` Phase 2 | 60 – 68 | 64.11 | HELD |
| span ratio, both phases | 1.40 – 1.60 | **1.440** ctx / **1.517** P2 | HELD |
| scheduler `(4,0)` | ≥90% of loaded samples | **13 of 13 = 100%** | HELD |
| MTP acceptance length | 3.0 – 3.2 | **3.08** (median of 19 samples) | HELD |
| prefix cache hit rate | 0.0% | **0.0% in all 24 samples** | HELD |
| SM clock median | 2392 – 2398 MHz | **2398** | HELD |
| σ/med both phases | 2 – 6% | 2.11% ctx / 5.86% P2 | HELD, both at an edge |
| `ttfr` Phase 2 | 11500 – 13000 | 12847.72 | HELD |
| grid time | 210 – 270 s | **250.1 s** | HELD |
| `ctx_pp2048` (the gate) | 5900 – 6400 | **5781.15** | **MISSED LOW** by 2.0% |
| engine start | 270 – 350 s | **267 s** | **MISSED LOW** by 1.1% |

**14 held, 2 missed**, and both misses are small and in the same direction as
everything else this round. The `ctx_pp` miss is worth naming because R13c
declared `ctx_pp` the *replacement* session gate after `pp2048` broke its own
gate on one low draw — and on its first outing the new gate missed too, by 2.0%.
It is a narrow band built from one prior arm, not a broken instrument: `ctx_pp`
5781.15 against 6163.69 is a −6.2% move whose σ collapsed from 416.60 to 136.29,
so the two arms disagree about dispersion as much as about level. **Widen the
`ctx_pp` gate to ±10%, the same band the protection points use, or stop calling
it a gate.**

### THE −1.94% SYSTEMATIC GETS ITS THIRD LOOK AND IT SURVIVES

R13c reported six reproductions, all low, mean −1.94%. This round adds two more
from an independent engine start:

| reproduction | prior | R13d | gap |
|---|---:|---:|---|
| `ctx_tg` c4, mnbt 131072 | 175.40 | 170.16 | **−2.99%** |
| `tg128` c4, mnbt 131072 | 170.89 | 168.97 | **−1.12%** |

**Eight reproductions, eight the same sign, mean now −1.88%.** On a fair coin
eight-of-eight is p ≈ 0.8%. Two candidate causes and this round still cannot
separate them — a decode-side session effect, or first-measurement bias — but it
does narrow one thing R13c could not: **R13c's six reproductions were all of
figures that had motivated their own promotion, which is exactly the shape
first-measurement bias takes. This round's Phase-2 partner was NOT a promoted
figure — nothing hung on it, it rode along free — and it came in low anyway
(−1.12%).** That is mild evidence for the session-effect half, because a
first-measurement bias has no reason to touch a row nobody was invested in. Not
conclusive: one unpromoted point against seven promoted ones.

**The ~2% downward correction on every once-measured figure in RESULTS.md
stands, and is now better supported than when R13c wrote it.**

### THE TOP THREE BUDGETS ARE STILL ONE POINT — CONFIRMED, NOT ASSUMED

The round's second product. Phase 2 at mnbt 131072 now reads 168.97 against
R13c's 170.89, and the above-knee series reads:

| mnbt | `tg` (Phase 2) | `ctx_tg` (Phase 1) |
|---:|---:|---:|
| 65536 | 173.34 | 164.95 |
| 98304 | 169.69 / 170.59 (R13) | 168.37 / 170.59 (R13) |
| **131072** | **170.89 / 168.97** | **175.40 / 170.16** |

Every above-knee measurement of both phases now sits between 164.95 and 175.40 —
a **6.3% spread across three budgets, two phases and five engine starts**,
against per-arm σ/med of 2 – 6%. **R13c's "the top three budgets are one point"
survives a second draw at its most extreme value, and the knee at 65536 is
untouched. R11's fold value is still 65536.** Nothing here reopens that.

### σ FLIPPED PHASES AND THE CAMPAIGN HAS NO RULE LEFT HERE

`ctx_` σ/med **2.11%** against Phase 2's **5.86%** — the ctx phase is the quiet
one by 2.8x. At the identical config R13c read 3.95% / 3.89%, i.e. equal. The
campaign has now seen ctx quieter, ctx noisier, and the two equal, **at the same
depth, concurrency, budget and scheduler width**. There is no ctx-vs-Phase-2
dispersion regularity; R9b's phase-label correction already dissolved the
mechanism that used to be offered for one. Recorded so nobody re-derives it.

The Phase-2 σ is where the whole round's dispersion lives: runs span
151.04 – 183.90, a 1.22x spread, the familiar mode-plus-one-low-draw shape
(151.04 is 11% below the next value). Medians remain the verdict.

### ctx-vs-Phase-2 SIGN: +0.7%, AND R13c's BUDGET-RESPONSE CURVE HOLDS

Phase 1 sits **+0.70%** above Phase 2 (170.16 vs 168.97). R13c read **+2.6%** at
this budget, the same sign, at the top of a curve that crossed zero twice across
six budgets (+4.8 / −19.9 / −12.6 / −4.8 / −0.8 / +2.6%). **Same sign, smaller
magnitude — the budget-response reading holds and the "rule" readings from R12
and R13 stay dead.** Neither figure is far from zero and the round claims nothing
more than the sign.

### INSTRUMENTS — R8b WORKED ON THE FIFTH ATTEMPT, AFTER ONE FAILURE THIS ROUND

**The capture failed first and was caught before the grid, not after.** The
container on this image is named `sparkrun_<hash>_<hash>_solo`, **not** `vllm-*`:
the first capture command matched on `vllm` and collected **zero lines**. Caught
by checking the capture during the engine start, fixed to
`grep "^sparkrun_"`, restarted, and **verified live** before the grid — 67 lines
of vLLM startup with the container up. That check is the reason this round has an
instrument and R8 and R12 do not.

**Add to the R8b recipe: match the container on `^sparkrun_`, and verify the
capture is non-empty DURING the engine start, when there is still time to fix
it.** Verifying at grid start, as R12 and R13 did, is already too late if the
match is wrong — the engine start is the only slack in the round.

Yield: 308 lines, **24 `Running:` samples (13 loaded, all `(4,0)`)**, 19
SpecDecoding samples, 24 prefix-cache samples.

- **Scheduler `(4,0)` in 13 of 13 loaded samples.** Full residency, nothing
  waiting — and the span ratio still reads 1.44 / 1.52. **Third independent
  confirmation that the ratio this campaign called "admission stagger" is not
  admission.** R13 saw it, R13c saw it across the budget curve, this round sees
  it again at the extreme budget.
- **MTP acceptance length median 3.08, draft acceptance 69.5%** (19 samples,
  spanning 2.35 – 4.00). Flat for the sixth consecutive round and across a 16x
  budget sweep. Acceptance remains ruled out as an explanation for anything the
  scheduler does on this model.
- **Prefix cache hit rate 0.0% in all 24 samples.** Campaign total **321 samples
  across seven budgets, zero hits, ever.**
- **Telemetry 700 samples: 2398 MHz median, 76 °C peak, 99.79 W peak** — the
  **seventeenth** session agreeing on the clock. ⚠ The power peak is a campaign
  high (prior 97.29 W, R12) and the first reading to touch 100 W. The clock did
  not move with it, so it changes nothing about the policy reading; noted because
  it is the only telemetry number that has ever drifted.

### VALIDITY

All three pre-declared void conditions passed: `session_count: 1`,
`crash_count: 0`; the `Benchmark args:` echo read `depth: [16384]`,
`concurrency: [4]`, `runs: 7` and was checked before the run was allowed to
proceed (the R5 discipline); `ctx_pp2048` 5781.15 is inside the 5000 – 7000 void
band, though below its own narrower prediction as noted above.

### WHAT THIS ROUND CLOSES

**The question is closed for good, exactly as the pre-run rule said it would
be.** `ctx_tg @ d16384 c4` at mnbt 131072 is the campaign's widest margin at
**6.21x on 14 pooled runs**, and no third measurement of this cell should be
taken whatever the gap. R13d is the last scoreable round the queue had.

Cost: 250.1 s grid + 267 s engine start, one invocation, ~10 min wall,
~60k tokens, zero crashes. **Mutations NOT folded into `recipe.yaml`** — the
fold decision remains R11's, at 65536.

## Round 11 hypothesis — the fold decision: `tg128 @ d16384 c1`, runs=7, at `max_num_batched_tokens 65536`

Written BEFORE the run, 2026-08-22.

### What this round is for, and why it is the last one that matters

`max_num_batched_tokens` is the largest effect this campaign found — it is the
difference between **1.13x and 3.71x** on `tg128 @ d16384 c4`, the only contested
cell we hold — and it is **not in `recipe.yaml`**. **Ten of the eighteen win rows
in `RESULTS.md` depend on mutations the recipe does not carry.** R11 is the round
that decides whether that ends.

It was never a free decision. At `d16384` a Phase-2 prefill is `depth + pp` =
**18432** tokens, so at `mnbt 8192` it is **three** scheduler steps and at 65536
it is **one**. The flag is therefore not obviously inert at `c1` either — and the
`c1` anchor that every depth and concurrency comparison in this campaign hangs
from (**112.62**, pooled over R6's seven runs and R8's seven, both at `mnbt 8192`)
was measured at the old budget. **Folding without re-measuring that anchor would
silently create a new epoch and quietly invalidate the depth curve.** This round
is that measurement.

### What has changed since this round was queued — checked, not assumed

Three later rounds moved this round's target, and all three simplify it:

- **R13c curved the budget at c4 and the curve KNEES AT 65536.** `tg` reads
  52.07 / 85.90 / 143.83 / **173.34** / 169.69 / 170.89 across
  8192 / 16384 / 32768 / 65536 / 98304 / 131072 — **+233%** up to the knee and
  **−1.4%** over the two doublings above it, the top three spanning 2.1% against a
  per-arm σ/med of ~4%. **So the value to fold is 65536, not R11's original 32768
  and not R13's 98304**: same ceiling, smaller activation budget, cheaper engine
  start. R13's original worry that this round would need the `c1` anchor at three
  budgets is gone — it needs it at **one**.
- **R13d re-drew the extreme point and the knee held.** Every above-knee
  measurement of both phases now sits in 164.95–175.40, a 6.3% spread across three
  budgets, two phases and five engine starts. Nothing above 65536 is worth folding.
- **R13c + R13d measured a cross-invocation systematic: eight reproductions,
  eight the same sign, mean −1.88%.** That is not a footnote here — it is the
  single most important input to this round's band, because a reading ~2% below
  the anchor is what "no effect" looks like from a separate engine start.

**No config pre-flight is outstanding.** R13 established there is no
`mnbt <= max_model_len` validator (that error fires only when chunked prefill is
off), and R13c then ran 65536 / 98304 / 131072 with `max_model_len` left at the
recipe's 32768. So this round needs **exactly one mutation** and no second one.

### The exact configuration

`pp 2048`, `depth 16384`, `tg 128`, `concurrency 1`, `runs 7`,
`-o max_num_batched_tokens=65536`, everything else the campaign recipe —
`max_num_seqs` stays at the recipe's **4** (`c1` needs no scheduler width, and
adding `mns 5` would make this a two-mutation round for nothing). **ONE mutation,
one invocation, one engine start.** The Phase-1 partner (`ctx_tg @ d16384 c1`)
rides along free in the same grid and gives a **second, independent inertness
test** at no cost.

`runs=7` because this is a headline figure and the campaign's own rule is that
every 3-run median it promoted was later retired and all of them were too high.

### The anchors this is measured against — all at `mnbt 8192`, campaign config

| quantity | R6 (`bench_dd3afc9e1c94`) | R8 (`bench_3d8149654d1b`) | pooled 14-run median |
|---|---:|---:|---:|
| `tg128` (Phase 2) | 111.11 (σ 2.91, 2.6%) | 113.06 (σ 6.20, 5.5%) | **112.62** |
| `ctx_tg128` (Phase 1) | 104.85 | 102.68 | **102.99** |
| `pp2048` (Phase 2) | 634.99 | 628.66 | — |
| `ctx_pp2048` (Phase 1) | 5849.11 | 5856.93 | — |
| `ttfr` (Phase 2) | 3237.23 ms | 3269.39 ms | — |
| `peak_throughput` (Phase 2) | 117.43 | 117.43 | — |

Note `tg_throughput == tg_req_throughput` **exactly** in both, at both phases —
that is `results.py:195`'s assignment, not a measurement, and it is why the span
ratio is 1.000 by construction at `c1`.

### THE MECHANISM, AND WHY I PREDICT THE FLAG IS INERT HERE

The budget has moved this metric by exactly two routes in thirteen rounds, and
**both are structurally absent at `c1`**:

1. **Occupancy.** A starved budget gates admission, so the engine holds fewer
   than `c` sequences resident — `(2,2)` and `(3,1)` at c4 (R9, R13c), 9 of 16 at
   c16 (R7). At `c1` there is one request. There is nothing to admit alongside it
   and residency is 1 of 1 at every budget.
2. **The span denominator.** At `c>1`, `tg_throughput` is a batch aggregate
   divided by `max_last_token − min_first_token` (R10, `results.py:352`), so a
   shorter admission span inflates it — which is how R12 moved `tg` +67.6% at c2
   while `peak_throughput` moved **−0.5%**. At `c1` there is no batch and
   `tg_throughput` is **assigned** the per-request value. There is no span for the
   budget to shorten.

What the budget *does* change at `c1` is prefill **chunking**: three steps become
one (Phase 2), two become one (Phase 1). Decode is untouched — 128 tokens emitted
~3.1 at a time through MTP verify steps, orders of magnitude below any budget, so
the budget never binds during the phase `tg128` measures.

**H_inert: the fold is safe.** `tg128 @ d16384 c1` at 65536 equals the 112.62
anchor to within noise plus the −1.88% systematic.

**The rival is real and this round is the only place it can be tested.** R13
found `tg_req` rose **exactly +15.5% at BOTH c4 and c5** on 32768 → 98304, and
R13c's c4 `tg_req` curve runs 33.00 → 65.24 across 8192 → 65536, **+98%**. That is
a *per-request* quantity moving with the budget. The campaign's reading is that it
is a sharing artefact — a request stalled behind chunked prefills of its
neighbours decodes slower — but nobody has separated that from an intrinsic
per-request effect, because **every measurement of it was taken at `c>1`**.
**H_decode: if any material share of that +98% is intrinsic, `c1` lifts too.**

At `c1` the two hypotheses are cleanly separated for the first and only time.
That is this round's second product and it costs nothing extra.

### DECISION RULE AND DISCRIMINATOR — declared before the run

Let `M` be the 7-run median of `tg128 @ d16384 c1` at `mnbt 65536`.
Anchor 112.62; band **±5%** = **107.0 – 118.3**, which prices the −1.88%
systematic plus a 7-run median's own sampling spread at σ/med 2.6–5.5%
(≈1.2–2.6%) with room to spare.

- **`M` ∈ [107.0, 118.3] → H_inert holds → FOLD.** Set
  `max_num_batched_tokens: 65536` in `recipe.yaml`'s defaults. The 112.62 anchor
  survives, the depth curve and every `c1` comparison stay valid, no new epoch,
  and the `c4` win is restated as the campaign's headline on the config the recipe
  actually ships.
- **`M` > 118.3 → H_decode → DO NOT FOLD in this round.** The flag is *not* inert
  at `c1`; it is a genuine per-request decode lever and folding it re-anchors
  everything. That is a bigger, better result than the fold — and it makes the
  fold a re-measurement project (the depth curve at d65536 and d131072, and every
  `c1` figure in `RESULTS.md`), not a one-line edit. Record the new `c1` figure,
  price the re-anchor, and leave the recipe alone.
- **`M` < 107.0 → the budget COSTS something at `c1` → DO NOT FOLD.** The flag
  stays a per-round mutation and every `c>1` row keeps naming its configuration,
  exactly as the queue specified.

I am stating in advance that **I expect H_inert and therefore expect to fold**,
and that the honest risk in this round is the opposite of the usual one: the
result I predict is the one that licenses a change to the only tuned artifact in
the campaign, so a marginal reading must be resolved *against* folding, not for
it. A median at 118.0 is inside the band and would still be a bad fold; if `M`
lands in the top 1% of the band (117.2 – 118.3) I will treat it as **not
established** and not fold, and say so.

### Numeric predictions

**Primary. `tg128 @ d16384 c1` at mnbt 65536 = 105 – 118, centre 110.5**
(= 112.62 × 0.981, the anchor carrying the measured systematic). Note the
prediction band is deliberately *wider on the low side* than the fold band — a
reading of 105–107 would be a prediction hit and a fold refusal at the same time,
and those are different questions.

**Secondary — the free Phase-1 partner. `ctx_tg @ d16384 c1` = 96 – 110, centre
101.1** (102.99 × 0.981). Same argument, independent measurement. If Phase 2 is
inert and Phase 1 is not, or vice versa, the inertness reading is not established
whatever the fold band says.

| Quantity | Anchor (mnbt 8192) | Predicted | Why |
| --- | ---: | --- | --- |
| `ttfr` (Phase 2) | 3237 / 3269 ms | **2900 – 3300, and I predict it FALLS** | **The round's sharpest non-obvious call.** `ttfr` got WORSE at every budget increase this campaign tested — six consecutive times (+7.3% c2, +15.6% c4, +19.8% c5, +32.4% c16) — but **every one of those was at `c>1`**, where a bigger budget admits more neighbours per step and lengthens the step before anyone's first token. At `c1` there are no neighbours, and an 18432-token prefill goes from three steps to one. **If the regularity is a `c>1` effect it must break here.** First chance to test that |
| `pp2048` (Phase 2) | 634.99 / 628.66 | 620 – 690 | fewer scheduler steps for the same work; flat-to-slightly-up. Recorded, **NOT gated** — this is the gate R13c broke on one low draw |
| `ctx_pp2048` (Phase 1) | 5849.11 / 5856.93 | **5270 – 6440 (±10%)** | the session gate, **widened to ±10% per R13d's lesson** — R13c declared `ctx_pp` the replacement gate and it missed by 2.0% on its first outing because the band was built from one arm without pricing dispersion |
| `ctx_pp / pp` ratio | 9.21 / 9.32 | **8.7 – 9.6** (theory **9.00**) | the zero-free-parameter phase-label prediction `(depth+2048)/2048`, holding at 35 of 36 archived pairs *(⚠ CORRECTED after the run: R13d had already added the 37th pair, so the audit stood at 36 of 37 and R11's is the **38th**, taking it to 37 of 38. The count is a citation error in this pre-run table, not a prediction — the band and the theory value are unaffected.)*. This adds a pair at **`c1` above the old budget** — a budget×c1 corner the audit lacks |
| `peak_throughput` (Phase 2) | 117.43 both rounds | 112 – 122 | the hardware ceiling; the budget has never moved it more than a few percent and at c2 moved it −0.5% |
| span ratio `tg / tg_req` | 1.000 | **exactly 1.000** | assignment, not measurement. If it is anything else, the instrument is not what R10's source read says and the round is void |
| scheduler `Running/Waiting` | — | **`(1,0)` in 100% of loaded samples** | one request, and 65536 admits its whole 18432-token prefill in one step |
| MTP acceptance length | 3.08 at `c>1` (six rounds flat) | **3.1 – 3.9, and I expect it ABOVE the `c>1` figure** | R5 read 3.81 / 93.6% at `c1` and 2.94 / 64.5% at c16, and R7 named the confound: a `c16` sample reports the **population mean** of a bimodal distribution while a `c1` sample reports **one draw**. The campaign has never taken a clean `c1` acceptance sample at d16384 with the working capture command. Free here. **The confound is not resolved by one c1 sample and I am not claiming it will be** |
| prefix cache hit rate | 0.0% | **0.0%** | 321 samples, seven budgets, zero hits ever |
| SM clock median | 2392 – 2398 MHz | **2392 – 2398** | seventeen sessions agreeing; this would be the eighteenth |
| σ/med, Phase 2 | 2.6% / 5.5% | 2 – 7% | R6's rule: `tg128` at d16384 is the quiet regime |
| grid time | R6: 124 s for 14 runs at this depth | **110 – 150 s** | 7 runs × 2 phases at d16384 c1 |
| engine start | R13c at 65536: 177.9 s | **160 – 200 s** | start cost tracks budget SIZE, not novelty (R13c's correction to R13) |

### What would make this round void

- `crash_count > 0` or `session_count > 1` — the anchor is a single-engine-start
  figure and this must be one too.
- The `Benchmark args:` echo not reading `pp: [2048]`, `depth: [16384]`,
  `tg: [128]`, `concurrency: [1]`, `runs: 7`. **`sparkrun` silently defaults an
  omitted `-b depth` to 0 and does not error** — R5 lost an engine start to this.
  **Read the echo before letting the grid proceed.**
- `ctx_pp2048` outside 5000 – 7000, which would mean prefill is not doing what
  every other run at this depth does.
- `tg_throughput != tg_req_throughput` at `c1`.

### Instrument plan

Engine log per R13d's hard-won recipe: `docker exec <container> tail -f
/tmp/sparkrun_serve.log`, container matched on **`^sparkrun_`** (it is named
`sparkrun_<hash>_<hash>_solo`, **not** `vllm-*` — R13d's first capture matched
`vllm` and got zero lines), and **verified non-empty DURING the engine start**,
not at grid start, which is already too late to fix a bad match. Telemetry
alongside. `docker logs -f` does **not** work on this image and cost R12 its
occupancy instrument.

### Cost

One invocation, one engine start. ~130 s grid + ~180 s engine start, ~8 min wall.
This is the cheapest consequential round left in the queue.

## Round 11 outcome — bench_c9518e3e96a3-r11 (2026-08-22)

`tg128 @ d16384 c1` at `max_num_batched_tokens 65536`, runs=7, ONE invocation,
ONE engine start (`session_count: 1`, `crash_count: 0`), Phase-1 partner riding
along. Image `dgx-vllm-eugr-nightly:2026082102` — the same epoch as all thirteen
prior rounds. Archived at `experiments/bench_c9518e3e96a3-r11/`.

### THE FLAG IS INERT AT c1. THE FOLD RULE IS SATISFIED. `recipe.yaml` HAS BEEN CHANGED.

**`tg128 @ d16384 c1` at mnbt 65536 = 112.92**, against the pooled 14-run anchor
**112.62** at mnbt 8192: **+0.27%**. The pre-declared fold band was
**107.0 – 118.3** and the pre-declared caution zone at the top of it
(117.2 – 118.3) was not entered. **H_inert holds and the flag is folded.**

| phase | anchor (mnbt 8192, 14 runs) | **R11 (mnbt 65536, 7 runs)** | change | SE of median | in units of SE |
|---|---:|---:|---:|---:|---:|
| `tg128` (Phase 2) | 112.62 | **112.92** | **+0.27%** | 3.80% | **0.07** |
| `ctx_tg` (Phase 1) | 102.99 | **98.72** | −4.15% | 4.84% | 0.89 |

Runs, Phase 2: 115.02 / 91.92 / 103.97 / 99.86 / 114.71 / **112.92** / 118.65
(σ 9.05). Phase 1: 98.72 / 92.25 / 124.87 / 96.89 / 106.40 / 96.00 / 101.08
(σ 10.08).

**Both phases are inert and that is the conjunction the round required.** The
hypothesis said in advance that a split verdict — one phase moving and the other
not — would leave inertness unestablished whatever the fold band said. Phase 1's
−4.15% is **0.89 standard errors** on a cell whose σ/med is 10.21%, the noisiest
reading of this cell in the campaign; it is not a move, and it is inside its own
pre-declared 96 – 110 band. **Nothing about the fold rests on Phase 1 being
exactly flat — only on it not moving where Phase 2 does not.**

**The two figures are NOT pooled.** They are different configurations, and
pooling across a config difference is the thing `RESULTS.md` says must never
happen. 112.62 remains the mnbt-8192 anchor; 112.92 is a separate row.

### WHY IT IS INERT, AND THIS IS THE RESULT THAT GENERALISES

The budget has moved this metric by exactly two routes in thirteen rounds, and
the round predicted before running that **both are structurally absent at c1**:

1. **Occupancy.** A starved budget gates admission — `(2,2)`/`(3,1)` at c4 (R9,
   R13c), 9 of 16 at c16 (R7). **Measured here: `Running: 1, Waiting: 0` in 4 of
   4 loaded scheduler samples.** One request; residency is 1 of 1 at any budget.
2. **The span denominator.** At `c>1`, `tg_throughput` is a batch aggregate over
   `max_last_token − min_first_token` (R10, `results.py:352`), so a shorter
   admission span inflates it — R12 moved `tg` +67.6% at c2 while
   `peak_throughput` moved −0.5%. **Measured here: `tg_throughput ==
   tg_req_throughput` to the last decimal at BOTH phases** (112.92/112.92,
   98.72/98.72). That is `results.py:195`'s assignment, so the span ratio is
   **exactly 1.000** and there is no denominator for the budget to shorten.

So the campaign's largest lever is a **scheduling** lever end to end, and at a
concurrency of one there is nothing to schedule. Third independent line of
evidence for the same reading, and the cleanest: R12 saw the metric move without
the hardware ceiling moving; R13 and R13c saw the span tighten with nothing
waiting; **R11 sees the lever do nothing at all once the batch is removed.**

`peak_throughput` corroborates and does it better than expected: **117.43 at
Phase 2, identical to the last decimal to both R6's and R8's 117.43** — three
engine starts, two token budgets, one number. The hardware ceiling at c1 does not
know the flag exists.

### H_decode IS REFUTED, AND IT WAS THE ROUND'S REAL QUESTION

R13 found `tg_req` rising **exactly +15.5% at BOTH c4 and c5** on 32768 → 98304,
and R13c's c4 `tg_req` curve runs 33.00 → 65.24 across 8192 → 65536, **+98%**.
That is a *per-request* quantity moving with a scheduler knob, and **every
measurement of it was taken at `c>1`**, so nobody could say whether it was a
sharing artefact or an intrinsic per-request effect. It was queued as open
question 13.

At c1, `tg` **is** `tg_req` by assignment, so this round measures that quantity
directly with sharing removed. **It moved +0.27%.** If even a tenth of R13c's
+98% were intrinsic to the request, c1 would have lifted ~10%; it lifted nothing.
**The per-request rise at `c>1` is a sharing artefact — a request stalled behind
its neighbours' chunked prefills — and not a property of the request.** Open
question 13 is answered, at no extra cost, by a round that was run for a
different reason.

### THE ttfr REGULARITY SURVIVED WHERE THE ROUND PREDICTED IT WOULD BREAK

The round's sharpest non-obvious call, and it **missed**. `ttfr` has got worse at
every budget increase this campaign tested — six consecutive times (+7.3% c2,
+15.6% c4, +19.8% c5, +32.4% c16) — and R11 argued that all six were `c>1`, where
a bigger budget admits more neighbours per step and lengthens the step before
anyone's first token. With no neighbours at c1, the regularity was predicted to
break and `ttfr` to **fall** into 2900 – 3300 ms.

**Measured 3303.92 ms** against anchors 3237.23 (R6) and 3269.39 (R8): it
**ROSE**, by +2.06% and +1.06%, and it cleared the band's ceiling by 0.1%. That
is a real if tiny move — SE of the median is ~12.9 ms, so the rise is 2.7–3.9 SE.
**Seventh consecutive budget increase, seventh worse `ttfr`, and the first at a
concurrency where the campaign's explanation for it cannot apply.**

The honest reading is that the round got the **magnitude** right and the **sign**
wrong, and that these are different claims. The neighbour mechanism does explain
the collapse — +1.6% here against +7.3% to +32.4% at `c>1`, an order of magnitude
— so most of the effect *is* a `c>1` effect. What survives at c1 needs a
different, smaller cause, and there is a plausible one in the data: at 65536 the
whole 18432-token prefill runs in **one** scheduler step instead of three, and a
single 18432-token forward pass appears to be marginally less efficient per token
than three chunked ones. `pp2048` agrees — 629.78 against R6's 634.99, −0.8%, the
same direction and roughly the same size. **Stated as a candidate, not a
finding**, on two small same-signed moves.

### PREDICTIONS: 11 HELD, 4 MISSED

| prediction | band | measured | verdict |
|---|---|---:|---|
| **`tg128 @ d16384 c1`** | 105 – 118, centre 110.5 | **112.92** | **HELD** |
| **`ctx_tg @ d16384 c1`** | 96 – 110, centre 101.1 | **98.72** | **HELD** |
| `pp2048` | 620 – 690 | 629.78 | HELD — and inside the flat 623–643 d16384 series held across nine invocations; **session control PASSES** |
| `ctx_pp2048` (the ±10% gate) | 5270 – 6440 | **5853.81** | **HELD** — and it reproduces R6's 5849.11 to **0.09%** and R8's 5856.93 to **0.05%**. The widened gate is the right instrument; R13d's advice was correct |
| `ctx_pp / pp` ratio | 8.7 – 9.6 (theory **9.00**) | **9.295** | **HELD** — the **38th** archived phase pair, audit now **37 of 38** |
| `peak_throughput` (Phase 2) | 112 – 122 | **117.43** | **HELD** — identical to R6 and R8 to the last decimal |
| span ratio `tg / tg_req` | exactly 1.000 | **1.000, both phases** | HELD — `results.py:195` assignment confirmed a third time |
| scheduler `Running/Waiting` | `(1,0)` in 100% of loaded samples | **4 of 4** | HELD |
| prefix cache hit rate | 0.0% | **0.0% in 7 of 7** | HELD |
| SM clock median | 2392 – 2398 MHz | **2398** | HELD — **eighteenth** session agreeing |
| MTP acceptance length | 3.1 – 3.9 | **3.13** | **HELD on the band; the sub-expectation FAILED** — see below |
| `ttfr` (Phase 2) | 2900 – 3300, predicted to FALL | **3303.92** | **MISSED**, high by 0.1% and the wrong direction |
| σ/med, Phase 2 | 2 – 7% | **8.01%** | **MISSED HIGH** |
| grid time | 110 – 150 s | **73.9 s** | **MISSED LOW by 33%** |
| engine start | 160 – 200 s | **~210 s** | **MISSED HIGH by ~5%** |

**The grid-time miss is a bookkeeping error in the hypothesis, not a surprise on
the box, and it is worth naming so the anchor stops being misquoted.** R11 took
R6's "124 s at this depth" as the cost of 14 runs. R6 ran **four** cells at
runs=7 — tg32 and tg128, each with both phases — so 124 s bought **28** runs, and
the correct anchor for R11's 14 was ~62 s. Measured 73.9 s. **The rate anchor for
`d16384 c1` is ~4.4 s per run**, and any future round should price from that
rather than from R6's total.

Engine start ~210 s against R13c's 177.9 s at the same budget (+18%), bounded
below by the 203 s between the API-server banner and `Application startup
complete` in the capture. R13c's "start cost tracks budget SIZE, not novelty"
survives in shape but its point estimates carry more spread than one arm showed.

### THE σ MISS IS THE ROUND'S MOST USEFUL SIDE RESULT — R6's RUNS-BUDGET RULE IS NOT SAFE

R6 concluded that `tg128` at d16384 is the quiet regime and that **runs=3 is
adequate** there, on a reading of σ/med **2.6%**. That rule has priced rounds
ever since. Lining up every measurement of that exact cell:

| round | engine start | σ/med, `tg128 @ d16384 c1` |
|---|---|---:|
| R6 | 1 | 2.6% |
| R8 | 2 | 5.5% |
| **R11** | 3 | **8.01%** |

**The same cell, the same probe, three engine starts, and the dispersion trebles
across them.** At 8.01% a 3-run median carries a standard error near 5.8% — five
times the effect this round was built to resolve, and R11 would have been unable
to answer its own question at runs=3. R11's own runs show the familiar shape:
five of seven span 103.97 – 118.65 with 91.92 and 99.86 hanging below.

**Do not quote "runs=3 is adequate at d16384" again.** The defensible version is
that σ at this cell is itself a draw, that it has read 2.6 / 5.5 / 8.0% on three
sessions, and that **runs=7 is the only budget that has been safe at every one of
them.** n=3, so this is a warning and not a law — but it points the same way as
the campaign's other sampling lesson, and the campaign has already been burned
four times by trusting a small sample of a quantity it had only measured once.

### MTP ACCEPTANCE AT c1 — THE BAND HELD AND THE REASONING BEHIND IT DID NOT

**Median 3.13 acceptance length, 71.1% draft acceptance** (7 samples, spanning
2.79 – 3.24 and 59.8 – 74.8%). The band held at its very bottom.

The *expectation* attached to it failed, and that is the informative half. R11
predicted c1 would read clearly **above** the `c>1` figure, on R7's confound: a
`c16` sample reports the **population mean** of a bimodal distribution while a
`c1` sample reports **one draw**, so "acceptance falls with concurrency" and "our
c1 figures sit above the population mean" predict the same observation. Against
R13d's `c>1` reading at the same depth — **3.08 / 69.5%** — this c1 reading of
**3.13 / 71.1%** is **+1.6% and +2.3%**, i.e. the same number.

**At d16384 there is no acceptance difference between c1 and `c>1`.** That
removes R7's confound at this depth rather than resolving it in R7's favour, and
it makes acceptance flat for the **seventh** consecutive round — now across
depth-matched concurrency as well as every scheduler knob. R5's collapse to
47.7% at d131072 is untouched; it was always a **depth** effect and this is
further evidence it is only that.

`per_request_spec_decode_metrics: 'none'` is confirmed in this image's
observability config again — the settable field **R13b** depends on.

### TELEMETRY — AND A SECOND CONSECUTIVE POWER HIGH

363 samples: SM clock **2398 MHz** median (eighteenth session agreeing), **71 °C**
peak — the coolest peak of any round that sampled — and ⚠ **100.45 W peak, a
campaign high and the first reading strictly above 100 W** (prior high 99.79 W,
R13d, itself a high over R12's 97.29). **Two consecutive rounds have now set a
power record**, on a counter that was flat within 3 W for eleven sessions before
them. The clock did not move with it and the temperature is the lowest recorded,
so nothing about the policy reading changes. Flagged because it is the only
telemetry number in the campaign that has ever drifted, and it has now drifted
twice in the same direction. Not investigated; not a finding.

### VALIDITY

All four pre-declared void conditions passed. `session_count: 1`,
`crash_count: 0`. The `Benchmark args:` echo was read before the grid was allowed
to proceed and showed `pp: [2048]`, `depth: [16384]`, `tg: [128]`,
`concurrency: [1]`, `runs: 7` — the R5 discipline. `ctx_pp2048` 5853.81 is inside
the 5000 – 7000 void band and inside its own narrower gate.
`tg_throughput == tg_req_throughput` at c1, both phases.

**Instrument capture worked first time**, using R13d's recipe without
rediscovering it: container matched on **`^sparkrun_`**, capture verified
non-empty **during the engine start** (12 lines with the container up, ~3 minutes
of slack still available). Yield 220 lines, 7 `Running:` samples (4 loaded), 7
SpecDecoding, 7 prefix-cache. **The yield is thin — a quarter of R13d's — because
the grid is a quarter as long**, and 4 loaded scheduler samples is a weak
instrument in absolute terms even though `(1,0)` at c1 is the least surprising
reading in the campaign. Recorded as thin rather than quoted as if it were R13d's
13 of 13.

### THE FOLD, AND WHAT IT COSTS

`recipe.yaml`'s `max_num_batched_tokens` default is now **65536**, was 8192,
with the reasoning written into the file. **This is the first change to
`recipe.yaml` in the campaign's history** — thirteen rounds ran on the recipe
exactly as inherited.

**Only one flag was folded.** `max_num_seqs` stays at **4**. The c4 rows at
mnbt 65536 were measured at `mns 5`, so the recipe as folded is **not bit-for-bit
the config behind the 3.71x row**. What licenses shipping it anyway: at c4 the
scheduler width is worth ≤2.9% once the budget is adequate — mnbt 32768 has been
measured at mns 4 / 5 / 16 and reads 143.08 / 143.83 / 147.25 — and mns 4 reaches
full `(4,0)` residency at c4 from 32768 up (R13c). What is **not** licensed:
claiming the 3.71x row is what the recipe now produces. **`mnbt 65536 + mns 4` at
c4 has never been measured**, and the honest statement is that the recipe should
land within a few percent of it. That row is flagged in `RESULTS.md` and it is
the obvious cheap follow-up.

**THE FOLD IS A CONFIG EPOCH BOUNDARY AND IT IS THE MOST DANGEROUS THING THIS
ROUND DID.** Every row measured before today at the recipe's defaults was
measured at mnbt 8192. Those rows are no longer reproducible from `recipe.yaml`.
They have been relabelled throughout `RESULTS.md` from "campaign config" to
**"mnbt 8192 — PRE-FOLD recipe"**, and the file now carries an epoch warning at
the top. The next round that runs `./recipe.yaml` unmutated will get a
**different engine** from every round before R11, and at `c>1` it will get
dramatically different numbers. Nothing in the archives is invalidated; what
changes is what the word "unmutated" means after 2026-08-22.

**What the fold buys:** eight of the eighteen win rows — the mutation rows at
mnbt 65536 and the c1/c4 figures that depend on the budget — are now the config
the recipe ships rather than a per-round `-o` flag. That was the entire point of
the round, and it is why the synthesis called it the highest-value item left.

### COST

One invocation, one engine start. **73.9 s grid + ~210 s engine start**, ~7 min
wall, ~70k tokens, zero crashes. The cheapest consequential round of the
campaign after R6, and it changed the only tuned artifact in it.

## Round 9c hypothesis — why is `--enable-prefix-caching` worth 57% of `tg` at c4 when it never hits? THREE arms, c4 only, runs=7

Earned by R9b and named by the synthesis as **open question 1**, the campaign's
sharpest open mechanism. The fact under test, from R9's arm A1 and R9b's arm A,
both at `mnbt 32768` / `mns 4` / `tg128 @ d16384 c4`: prefix caching ON reads
`tg` **143.08**, prefix caching OFF reads **62.13** — a 2.30x swing — while
`peak_throughput` is **297 in both, identical to the token**, `pp2048` moves
0.8%, total prompt tokens processed moves 1.7%, and the cache hit rate is
**0.0% in both**. No prefill work is saved and no hardware ceiling moves.

**Two things were settled by reading before an engine start was spent, and both
change the round.** This is R9's open question 11 rule applied — grep the
validators out of the pinned image
(`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`) with a throwaway
`docker run --rm --entrypoint bash` — and it is the third consecutive time the
practice has paid.

### FINDING 1 (no box time) — R9c AS QUEUED IS NOT RUNNABLE. A validator refuses it.

The queue's instruction was "run prefix caching OFF with an explicit
`-o mamba_block_size=16`". `vllm/config/vllm.py:2607-2618` in the pinned image:

    @model_validator(mode="after")
    def validate_mamba_block_size(self) -> "VllmConfig":
        mamba_block_size_is_set = (
            self.cache_config.mamba_block_size is not None
            and self.cache_config.mamba_block_size != self.model_config.max_model_len
        )
        if mamba_block_size_is_set and not self.cache_config.enable_prefix_caching:
            raise ValueError(
                "--mamba-block-size can only be set with --enable-prefix-caching"
            )

`mamba_block_size 16` with `max_model_len 32768` and prefix caching off is
**exactly** the refused combination, and `config/cache.py:145-148` says the same
thing in the docstring: *"Can be set only when prefix caching is enabled."* The
arm the queue specified would have died at config validation. That is R9's
lesson repeating in a new place, and this time it cost nothing.

**So `mamba_block_size` cannot be moved from the prefix-caching-OFF side at all.
The only legal lever is from the ON side** — see the round design below.

### FINDING 2 (no box time) — THE 2048x PREMISE IS WRONG BY TWO ORDERS OF MAGNITUDE. `mamba_block_size` was never 16.

R9b read `model_executor/models/config.py:600-638` and concluded that prefix
caching ON gives `mamba_block_size = block_size = 16`, so the flag moves Gated
DeltaNet state granularity by 2048x. **It does not, because a later pass
overwrites it.** `platforms/interface.py:867-918` runs after that and, for
`mamba_cache_mode == "align"` (which is what prefix caching ON forces), ends with

    if cache_config.block_size < attn_block_size:
        cache_config.block_size = attn_block_size          # interface.py:911 logs this
    ...
    if cache_config.mamba_cache_mode == "align":
        cache_config.mamba_block_size = cache_config.block_size

and `attn_block_size` is the smallest aligned size making the attention page at
least as large as the mamba page. **All three archived arms log the same value:**

    interface.py:911] Setting attention block size to 2144 tokens to ensure
    that attention page size is >= mamba page size.

— `bench_d9fdc68576f2-a1` (caching ON), `bench_9379c15468ec-a-chunk` and
`bench_10496035f7fd-b-nochunk` (both OFF). So the true contrast is
**`mamba_block_size` 2144 (ON) vs 32768 (OFF) — 15.3x, not 2048x.** The 16 in
the queue and in the synthesis's open question 1 is a value that never reaches
the engine. Both documents are corrected in the outcome.

### FINDING 3 (no box time) — THE EFFECT IS 86% BATCH SPAN, AND THE ARITHMETIC CLOSES EXACTLY.

Re-read of the two archived JSONs through the campaign's own identity
`tg = c x tg_req / span`, at `c4 d16384` Phase 2:

| | caching ON (a1) | caching OFF (a-chunk) | ratio |
|---|---|---|---|
| `tg_throughput` | 143.08 | 62.13 | **2.303** |
| `tg_req_throughput` | 57.89 | 51.49 | 1.124 |
| span ratio | 1.618 | 3.315 | **2.049** |
| `peak_throughput` | 297 | 297 | 1.000 |
| ttfr within-batch spread | **1614 ms** | **6146 ms** | **3.81** |

`1.124 x 2.049 = 2.303` to three decimals — the decomposition is exact, not
approximate. **86% of the effect in log-share is the span denominator and 14% is
real per-request decode.** And the span is made of ttfr dispersion: at ~58
tok/s/req a 128-token generation lasts ~2.2 s, so a **6.1 s** spread in
first-response times swamps the decode window entirely, while the ON arm's
**1.6 s** spread is smaller than it. In the OFF arm one request in every four
returns its first token at ~6.2 s while the other three return at ~12.3 s; in
the ON arm the same batch spans 10.6–12.2 s.

**So the question is no longer "why is the throughput different".** The
sustained hardware rate is identical to the token. The question is **why the
four prefills finish at far more dispersed times when prefix caching is off** —
and the leading suspect is now precise: under `align`, chunked prefill must
break at `mamba_block_size` (2144) boundaries so states land on block edges,
which forces the four prefills to interleave in fixed-size pieces and finish
together. Under `none` the granularity is 32768 — **larger than the whole
18432-token prefill** — so the constraint is vacuous and prefills can run
greedily to completion one at a time.

### The round, redesigned to be runnable

`mamba_block_size` is settable only with prefix caching ON, and under `align` it
is assigned `cache_config.block_size`. **So `--block-size` is the one legal
lever that moves mamba granularity**, and it reaches 32768 from the ON side.
Three arms, all `tg128 @ d16384 c4`, `mnbt 32768`, `mns 4`, `runs=7`, Phase-1
partner riding along free:

| arm | recipe | prefix caching | `mamba_cache_mode` | `mamba_block_size` |
|---|---|---|---|---|
| **P** (control) | `recipe-r9c-p-pc-on.yaml` | ON | `align` | 2144 |
| **G** (the test) | `recipe-r9c-g-block32768.yaml` | ON | `align` | **32768** |
| **N** (control) | `recipe-r9c-n-pc-off.yaml` | OFF | `none` | 32768 |

**THE CONFOUND, STATED UP FRONT.** `--block-size` moves the *attention* page
size along with mamba granularity — under `align` the two are the same number by
construction and no flag separates them. Arm G therefore tests "granularity"
as a bundle, not mamba specifically. It cannot be done better in this engine and
the outcome must not claim otherwise.

**THE CONFIG EPOCH, HANDLED.** R11 folded `mnbt 65536` into `recipe.yaml`, so
the recipe no longer reproduces R9/R9b's condition. Every arm here pins
`-o max_num_batched_tokens=32768` explicitly, and **both endpoints (P and N) are
re-measured in this session** rather than quoted from the archive. Prefix
caching is an engine flag, so three arms is three engine starts — that weakness
is irreducible and is stated, but it is bounded by measuring all three
back-to-back in one hour on one idle box instead of comparing across the four
hours that separate R9 from R9b.

### Predictions, and the primary instrument declared before the run

Primary instrument is the **span ratio**, because that is where 86% of the
effect lives. `R_span = span(G) / span(P)`.

- **H_gran confirmed** if `R_span > 1.7` — granularity is the mechanism, prefix
  caching is a red herring, and arm G lands with arm N.
- **H_gran refuted** if `R_span < 1.25` — granularity is inert, the effect
  belongs to `mamba_cache_mode: align` itself, and the flag is genuinely
  inseparable from the mode.
- Between 1.25 and 1.7 both contribute; report the split by the decomposition
  above and claim neither.

**H_gran is the declared primary hypothesis**, on the reasoning in finding 3.

| quantity | measured before | prediction | reasoning |
|---|---|---|---|
| P `tg` c4 | 143.08 (runs=3) | **132–148**, centre 140.4 | re-measure; downward-reproduction systematic is 8 of 8, mean −1.88% |
| N `tg` c4 | 62.13 (runs=3) | **58–66**, centre 61.0 | same systematic on a σ/med 1.1% cell |
| **G `tg` c4** | never | **60–80** under H_gran; 130–150 under H_align | the whole round |
| P span ratio | 1.618 | 1.55–1.70 | |
| N span ratio | 3.315 | 3.10–3.50 | |
| **G span ratio** | never | **2.9–3.5** under H_gran | `R_span` 1.8–2.2 |
| G ttfr spread | never | **>4500 ms** under H_gran | vs P's ~1600 ms |
| `peak_throughput`, all arms | 297 / 297 | **285–305 in all three** | the ceiling has never moved on this flag; if G's moves, the block-size change cost real compute and the arm is a different experiment |
| P, G scheduler residency | — | `(4,0)` majority | mns 4 holds full residency at c4 from mnbt 32768 up |
| σ/med, all arms | 1.1–2.8% at runs=3 | **1.5–5%** at runs=7 | R11 refuted "runs=3 is adequate"; σ is set by MTP verify count, not by concurrency |

### Validity gates, declared now so a failure is recorded and not dropped

1. **THE ARM-G GATE, and it is the one that matters.** Arm G's engine log must
   show the block size at **32768**, i.e. it must NOT carry
   `interface.py:911 Setting attention block size to 2144`. If it still reads
   2144 the flag did not take and **every arm-G number is void** — recorded as a
   broken gate with the log line, per the R9b precedent.
2. Arm P's median must land in 132–148. If it does not, the three arms remain
   comparable to each other (one session) but the tie to R9's archive is broken
   and no claim may be made across it.
3. `Prefix cache hit rate: 0.0%` in P and G. It has been 0.0% in all 114 samples
   ever taken with the flag on; if it is ever non-zero, the whole framing changes.
4. `crash_count: 0` and `session_count: 1` in all three arms.
5. `peak_throughput` in 285–305 for all three. Outside that, the arm changed the
   hardware regime and is not a clean span measurement.

### What this cannot answer

Nothing here transfers to the campaign config as a *standings* row. All three
arms sit at `mnbt 32768` against a recipe that now ships 65536, and two of them
turn off a flag the recipe ships. **All rows are NOT SCOREABLE.** The round buys
a mechanism, not a cell. And it does not close open question 7 (the ~1.50 span
floor) — it explains a span *difference*, not the floor.

### Cost estimate

Three engine starts (~180–240 s each) plus ~250 s of grid per arm at c4 runs=7
with the Phase-1 partner. ~25 min wall predicted.

## Round 9c outcome — bench_30d6586cc70a-p-pc-on + bench_76bccce3d8b3-g-block32768 (+ -repeat) + bench_107f95223a60-n-pc-off (2026-08-22)

**FOUR invocations, four engine starts, all `session_count: 1` and
`crash_count: 0`, all archived, all under one hour on one idle box.** Arm G was
run twice because its first engine-log capture produced three lines — the repeat
bought both the gate evidence and a 14-run pooled figure.

**HEADLINE, and it is a declared non-result rather than a finding.** The primary
instrument was pre-declared as `R_span = span(G)/span(P)`, confirm above 1.70,
refute below 1.25. **It measured 1.359 — inside the dead zone the hypothesis
itself named**, so `H_gran` is **NEITHER CONFIRMED NOR REFUTED**, and by the
round's own rule neither is claimed. Worse for the round and better for the
record: **the deciding arm turned out to be confounded in a way the hypothesis
did not predict**, and the confound is large enough that arm G could not have
settled the question even had it landed cleanly.

### The four arms, `tg128 @ d16384 c4`, `mnbt 32768`, `mns 4`, runs=7 each

| arm | prefix caching | `mamba_block_size` | phase | `tg` med | σ/med | `tg_req` | span ratio | `peak_thr` | ttfr spread |
|---|---|---|---|---:|---:|---:|---:|---:|---:|
| **P** | ON | 2144 | Phase 2 | **146.32** | 2.85% | 58.78 | **1.607** | 287 | **1516 ms** |
| **G1** | ON | **32768** | Phase 2 | 54.05 | 1.42% | 29.49 | 2.183 | 291 | 7460 ms |
| **G2** | ON | **32768** | Phase 2 | **53.07** | 0.93% | 28.97 | **2.184** | 286 | **7510 ms** |
| **N** | OFF | 32768 | Phase 2 | **60.60** | 1.61% | 50.68 | **3.346** | 289 | **6269 ms** |
| P | ON | 2144 | ctx_ (Phase 1) | 123.92 | 0.73% | 56.59 | 1.827 | 280 | 2005 ms |
| G1 | ON | 32768 | ctx_ | 58.65 | 0.95% | 30.43 | 2.075 | 280 | 6551 ms |
| G2 | ON | 32768 | ctx_ | 58.50 | 1.01% | 30.28 | 2.070 | 273 | 6597 ms |
| N | OFF | 32768 | ctx_ | 70.91 | 2.57% | 48.36 | 2.728 | 286 | 5066 ms |

Individual runs, Phase 2: **P** 146.32 / 151.73 / 140.97 / 151.83 / 152.50 /
145.19 / 144.24. **N** 59.73 / 60.01 / 60.60 / 61.08 / 62.49 / 61.16 / 59.42.
**G1** 54.63 / 53.14 / 54.05 / 52.57 / 53.18 / 54.70 / 54.29. **G2** 53.93 /
53.74 / 52.54 / 53.04 / 52.99 / 53.87 / 53.07. **G pooled 14-run median 53.46.**

### BOTH ENDPOINTS REPRODUCED, and that is the round's most reusable result

The whole point of re-measuring P and N in this session was to stop quoting R9
and R9b across four hours and a config epoch. They reproduce, and closely:

| quantity | archive (runs=3) | R9c (runs=7) | move |
|---|---:|---:|---:|
| P `tg` | 143.08 (R9 A1) | 146.32 | **+2.27%** |
| P span ratio | 1.618 | 1.607 | −0.68% |
| P ttfr spread | 1614 ms | 1516 ms | −6.1% |
| N `tg` | 62.13 (R9b arm A) | 60.60 | **−2.46%** |
| N span ratio | 3.315 | 3.346 | +0.94% |
| N ttfr spread | 6146 ms | 6269 ms | +2.0% |

**So the prefix-caching effect is real, it is bigger than R9b thought, and it
now rests on 14 runs instead of 6: `tg` 146.32 vs 60.60 = 2.414x** (was 2.303x).

⚠ **AND THE DOWNWARD-REPRODUCTION SYSTEMATIC BREAKS.** The synthesis records 8
of 8 protected rows reproducing low, mean −1.88%, and open question 8 asks
whether single measurements here are systematically ~2% high. **Arm P reproduced
+2.27% HIGH** — the first same-cell repeat in the campaign to do so — while arm
N reproduced −2.46% low in the same hour on the same box. **Two arms measured
minutes apart moved in opposite directions by about the same amount, which is
what a ±2.5% reproduction noise floor looks like and is not what a systematic
looks like.** Open question 8's "p ≈ 3% on a coin" was computed on a run of
eight; it is now 8 low, 1 high, 1 low (G2 vs G1, −1.81%) and the coin argument
is weaker than it was. Recorded, not resolved.

### THE MECHANISM DECOMPOSITION, now on runs=7, and it closes exactly

Using the campaign's `tg = c x tg_req / span` identity on medians:

**P → N (the prefix-caching effect, the thing open question 1 asks about):**

    tg ratio 2.415  =  tg_req ratio 1.160  x  span ratio 2.082  =  2.415  ✓
    log-share:  span 83%   per-request decode 17%

**P → G (the block-size effect, the thing this round bought):**

    tg ratio 2.757  =  tg_req ratio 2.029  x  span ratio 1.359  =  2.757  ✓
    log-share:  span 30%   per-request decode 70%

**These are not the same effect wearing different hats. They are opposites.**
Turning prefix caching off costs 83% span and 17% decode. Raising the block size
with prefix caching on costs 70% **decode** and 30% span. Arm G went *below* arm
N on the headline number by taking a completely different road there.

### WHY ARM G IS CONFOUNDED — the engine log says it plainly

**Gate 1 PASSES, with positive evidence, and it is the same line that voids the
arm as a clean probe.** Arm G2's engine log carries `'block_size': 32768` in the
`Initializing a V1 LLM engine` config dump and does **not** carry
`interface.py:911 Setting attention block size to 2144`, which both P and N do.
The flag took. And then:

| | KV cache | GPU KV cache size | max concurrency @ 32768 |
|---|---:|---:|---:|
| P | 65.38 GiB | **3,071,735 tokens** | 93.74x |
| N | 64.20 GiB | **3,339,995 tokens** | 101.93x |
| **G** | 66.45 GiB | **395,264 tokens** | **12.06x** |

**Arm G lost 87% of its KV token capacity from the same flag**, because under
`align` the mamba page is padded to exactly the attention page size and the
attention page went from 2144 to 32768 tokens — 15.3x of padding waste on the 30
Gated DeltaNet layers. That is not a granularity experiment, it is a
memory-layout experiment, and it shows in the scheduler:

- **P**: `(4,0)` in **13 of 14** loaded samples, `(3,0)` once. Full residency.
- **N**: `(3,1)` in **7 of 13**, `(4,0)` in 6. **Not at full residency.**
- **G**: `(4,0)` in **6 of 16**, `(3,1)` in 5, `(2,2)` in 4, `(2,0)` in 1.
  Residency is falling apart.

**The honest reading: arm G could not have answered the question.** It moves
`mamba_block_size` to the target value, but it drags attention paging, KV
capacity and residency along with it, and the hypothesis section named only the
first of those four. The confound was declared in advance ("arm G tests
granularity as a bundle") — **its size was not.** `peak_throughput` 286 passed
gate 5 and did not warn, because the sustained ceiling genuinely did not move.

### WHAT THE ROUND DOES ESTABLISH ABOUT OPEN QUESTION 1

1. **The effect is 83% batch span, on runs=7, arithmetically closed.** The
   sustained hardware rate is the same in both arms (287 vs 289, 0.7% apart).
   `--enable-prefix-caching` is not buying throughput; it is buying a shorter
   measurement window.
2. **The span is made of ttfr dispersion, measured directly: 1516 ms vs 6269 ms,
   a 4.13x spread.** At ~59 tok/s/req a 128-token generation lasts ~2.2 s, so
   N's 6.3 s spread swamps the decode window while P's 1.5 s spread sits inside
   it. One request per batch of four returns its first token ~6 s early in N.
3. **`mamba_block_size` moves the span in the right direction but explains at
   most 42% of it** (log scale: `ln(2.184/1.607) / ln(3.346/1.607)`), **and it
   cannot be the whole story**, because it arrives with a 2.03x per-request
   decode penalty that prefix-caching-OFF does not have (1.16x).
4. **⚠ NEW AND UNCLAIMED: arm N is not at full residency.** `(3,1)` in 7 of 13
   loaded samples with `mns 4`, `c4`, and 3.34M tokens of KV — capacity is not
   the reason and the campaign does not know what is. R7's plain-queueing
   account, which survived R9b, now has a direct observation attached to it at
   c4. **The lead's rule applies: the stagger proxy holds only at full
   residency, and N is not there**, so N's span figure is doing double duty as a
   queueing figure. Mechanism UNEXPLAINED, not invented.

**So open question 1 is NARROWED, NOT CLOSED.** What remains: is the residual
span difference `mamba_cache_mode: align` itself, or the admission behaviour in
(4) above? Those two are not separable by any flag in this engine — see below.

### AND THE SEPARATION IS PROVABLY IMPOSSIBLE IN THIS ENGINE

Collected from the three source reads, this is the most durable thing the round
produces and it costs nothing to reuse:

- `enable_prefix_caching` **ON** forces `mamba_cache_mode = "align"`
  (`models/config.py:601-604`) and `align` forces chunked prefill on
  (`:620-622`).
- `enable_prefix_caching` **OFF** forces `mamba_cache_mode = "none"`
  (`:630-635`).
- `mamba_block_size` may be set **only** with prefix caching on
  (`config/vllm.py:2607-2618`), and under `align` it is then **overwritten** by
  `cache_config.block_size` (`platforms/interface.py:918`).

**Therefore prefix caching and `mamba_cache_mode` cannot be varied
independently at all, in either direction, and `mamba_block_size` can only be
reached through `--block-size`, which drags attention paging with it.** Any
future round that proposes to separate them should be refused at the queue
rather than at the validator. **Open question 1 should be reworded to ask what
`align` mode does to prefill scheduling, and answered by reading the mamba2
kernel's chunking path, not by a benchmark.**

### The gates

1. **Arm-G gate — PASSES**, with positive evidence (`'block_size': 32768`, and
   the 2144 line absent). ⚠ For **G1 the live capture failed** (three lines: the
   container was matched but `/tmp/sparkrun_serve.log` did not yet exist when
   `docker exec tail -f` fired, so tail exited immediately). G1's gate rests
   only on its numerical agreement with G2 (`tg` 54.05 vs 53.07, span 2.183 vs
   2.184 — identical to three decimals). **Recorded as a capture failure, and
   the fix is in the next section.**
2. **Arm-P band 132–148 — PASSES** at 146.32, near the top.
3. **`Prefix cache hit rate: 0.0%` in P and G — PASSES**, 22 of 22 samples in
   each. That is now **158 consecutive samples** with the flag on and no hit
   ever recorded.
4. **`crash_count: 0`, `session_count: 1` — PASSES in all four.**
5. **`peak_throughput` 285–305 — PASSES in all four** (287 / 291 / 286 / 289).
   ⚠ **And it passed while arm G lost 87% of its KV cache**, so this gate does
   not detect a memory-layout change. Do not rely on it for that.

### THE ENGINE-LOG CAPTURE HAS A THIRD FAILURE MODE, and it is now fixed

R12 lost the instrument to `docker logs -f`. R13d lost it to matching `vllm`
instead of `^sparkrun_`. **R9c lost it to firing `docker exec tail -f` as soon
as the container appeared — the container exists for tens of seconds before
`/tmp/sparkrun_serve.log` is created, `tail` exits non-zero, and the capture
returns three lines.** The working recipe now needs BOTH waits:

    for i in $(seq 1 300); do cid=$(docker ps --format '{{.Names}}' | grep '^sparkrun_' | head -1); [ -n "$cid" ] && break; sleep 1; done
    for i in $(seq 1 300); do docker exec "$cid" test -f /tmp/sparkrun_serve.log && exec docker exec "$cid" tail -f -n +1 /tmp/sparkrun_serve.log; sleep 1; done

With both waits the capture produced **306–309 lines and 22 scheduler samples on
three consecutive arms**, which is the first time this campaign has captured the
occupancy instrument on every arm of a round.

### Predictions: 7 held, 5 missed, 0 gates broken

**Held:** P `tg` 132–148 (146.32) · N `tg` 58–66 (60.60) · P span 1.55–1.70
(1.607) · N span 3.10–3.50 (3.346) · G ttfr spread >4500 ms (7510) ·
`peak_throughput` 285–305 in all four · P residency `(4,0)` majority (13 of 14).

**Missed:** ⚠ **G `tg` missed BOTH declared bands** — 53.07 against 60–80 under
`H_gran` and 130–150 under `H_align`, i.e. the round's central quantity fell
outside every value the hypothesis allowed for. · G span 2.9–3.5 under `H_gran`
(2.184). · G residency `(4,0)` majority (6 of 16). · σ/med 1.5–5% in all arms —
**G2 read 0.93% and G1 1.42%, both below band**, and low σ is the signature of
the KV-capacity collapse pinning the arm. · The implicit prediction that arm G
would be a clean probe.

**The pattern is R10's and R12's post-mortem for the third time: the mechanism
section was right and the numeric band was wrong, in the same document.** The
band for G was set by interpolating between P and N, while the paragraph above
it said arm G changes attention paging as well — which is exactly the term that
put it outside both bands. **Decompose the metric; do not interpolate between
the arms you already have.**

### Telemetry — sessions twelve through fifteen, all agreeing

2,379 samples across the four arms. **2398 MHz median SM clock in every one**,
73–77 C, 96.53–97.15 W peak. Fifteen sessions and the box has never once shown a
thermal or power excursion. The 80%-of-ceiling clock remains flat policy.

### Phase pairs — the audit reaches 41 of 42

`ctx_pp / pp` against the zero-free-parameter prediction `(16384+2048)/2048` =
9.00: **P 9.167 · N 9.139 · G1 9.151 · G2 9.148** — residuals +1.5% to +1.9%,
the tightest cluster of four the audit has, and the first at three different
`mamba_block_size` values. The phase-label correction now stands at **41 of 42
pairs**.

### What is NOT claimed

No standings row moves. All twelve rows are **NOT SCOREABLE** — every arm sits
at `mnbt 32768` against a recipe that ships 65536, and two arms turn off a flag
the recipe ships. **Nothing here transfers to the campaign config**, and the
round did not close open question 1, open question 7, or the `mns 4` gap the
synthesis names as the cheapest round left.

### COST

Four invocations, four engine starts, zero crashes. **883.8 s of grid**
(220.6 + 217.9 + 223.1 + 222.2) plus four starts of ~180–200 s, **~36 min wall**
against ~25 min predicted — the overrun is entirely the arm-G repeat. ~95k
tokens. **Three of the round's five results cost no box time at all**, which is
the third consecutive round where reading the image beat benchmarking it.

## WHERE THE HANDOFF IS

**This is the end of the round log, not the end of the campaign's conclusions.**
The authoritative handoff is the **`CAMPAIGN SYNTHESIS`** section above, revised
2026-08-22 (**post-R22**, its ninth revision) to cover everything below it:
R5c, R13, the `ctx_` phase-label correction, R13c, R13d, **R11 — including its
fold and the config-epoch rule that follows from it** — **R9c**, whose
prefix-caching decomposition rewrote the synthesis's numbered item 2 and whose
refused arm is recorded there, **R13b**, whose span-floor result produced the
synthesis's `THE MECHANISM CHAIN` section, **R8c**, which retired the last deep
inversion and **corrected a published loss upward from 0.72x to 0.92x**,
rewriting the synthesis's three-run sampling warning in the process, and
**R21**, the **three-run audit**: four more unaudited rows re-measured at
runs=7, **all four moved UP**, and a recorded loss corrected from 0.95x to
**0.995x** — and **R22**, which ran last, closed `ctx_tg @ d32768 c1` as a
**LOSS** on 45 runs and found the **position bias** in the campaign's
arm-to-arm comparisons. It is the only synthesis in this file and it must stay
the only one — revise it, never append a second.

Short version for anyone who reads nothing else: **8 board cells won, 12 lost,
nothing submitted to the arena and nothing ever will be. Widest margin **6.21x**
(`ctx_tg @ d16384 c4` at `mnbt 131072 + mns 5`, 14 pooled runs, R13c + R13d). The
campaign's mechanism story is CLOSED — the `c>1` numbers are prefill-completion
stagger, not admission stagger (refuted R13) and not acceptance dispersion
(refuted R13b), and R9c's 83% batch-span term is the same thing. The
token budget is the campaign's big lever, its curve knees at 65536, and **R11
folded that value into `recipe.yaml` after measuring the c1 anchor at it and
finding it inert (+0.27%)** — so the recipe is no longer the one the campaign
opened with, and any row labelled "mnbt 8192 — PRE-FOLD recipe" now needs an
explicit `-o` to reproduce. ⚠ **R8c corrected `ctx_tg @ d32768 c1` from 0.72x to
0.92x — a 3-run median that was 28.5% too LOW — which retired the campaign's
"3-run medians always come in high" rule as a small-sample artefact of which
figures got audited. R21 THEN RAN LAST AND TESTED THAT: four more unaudited rows
at runs=7, ALL FOUR UP, and `tg128 @ d131072 c1`'s recorded loss corrected from
0.95x to 0.995x — a published deficit that was wrong by a factor of ten. Five
upward corrections in a row on rows nobody was defending, against five downward
on rows somebody was: THE CAMPAIGN HAS BEEN UNDERSTATING ITSELF, and its
recorded losses and thin margins are the figures most likely to be wrong in our
favour** (a modest sample, and a prior rather than a law — see the three-run
warning). **No cell changed hands; the counts stay 8 won / 12 lost.**

⚠️ **R22 THEN RAN LAST (R8c-PROTECT) AND DID TWO THINGS.** (1) It **closed the
last scoreable prospect**: `ctx_tg @ d32768 c1` was re-measured at runs=14 at
**both** budgets, R8c's **1.002x dead heat is RETIRED** (117.65 → 109.41, and
the pooled 21-run median is **113.37 = 0.966x**), the pre-declared claim rule was
**not met**, and the cell is a **LOSS** at 0.987x on its best-sampled figure
(24 pooled runs at mnbt 8192). **There is no cell left that box time can flip.**
(2) Far more important: its free arm-order control **found a POSITION BIAS in
cross-invocation comparisons** — in **4 of 4** comparisons across two rounds the
arm that ran **second** read higher (mean **+6.5%**), with the budgets swapped
between rounds so no budget effect can explain it. **R8c's "+6.36% budget effect
on Phase 1" is refuted**; position-controlled, `max_num_batched_tokens` is
**inert at c1 on BOTH phases** (−1.08% / +0.86%), closing the question R8c left
open. ⚠ The bias itself is **NOT established** (2 sessions, p = 0.25) but it is
**not a clock effect** and **not thermal in the obvious direction**. **The knee
at 65536 is safe; every arm-to-arm reading at or below ~7% is now suspect.**

**Pick up at the A-B-B-A position-bias round** (four invocations in one session,
budgets 8192 / 65536 / 65536 / 8192, ~25 min) — it is now the highest-value item
in the queue, because it decides how much of this campaign's small-delta
arithmetic is real. After that, **`mnbt 65536 + mns 4` at c4**, the config the
recipe actually ships and the one cell nobody has measured it at.

## Round 13b hypothesis — per-request MTP acceptance, and whether it is what the span ratio is made of (2026-08-22)

Branch `feature/thin-cell-r19`. Written BEFORE any box time. R13b was earned by
R13 and is open question 7's only live candidate: **what is the span ratio's
~1.50 floor made of?**

### THE QUEUE'S INSTRUMENT IS WRONG, and this is the round's first result

QUEUE.md specifies: enable `per_request_spec_decode_metrics`, re-run c5 at
`mnbt 98304` with runs=3, and **"capture the engine log the proven way — R13
shows it works."** The synthesis's own gate (what-to-run item 7) is stricter and
right: *"Establish first whether per-request acceptance is available at all from
the engine log; if it is only the batch mean, say so and close the question as
unmeasurable rather than running a round that cannot answer it."*

**Answered from the image, at zero box cost. The field is real and settable, and
the engine log is the wrong place to look for its output.** From
`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:latest`:

- `vllm/config/observability.py:48` —
  `per_request_spec_decode_metrics: Literal["none","summary","detailed"] = "none"`,
  so the CLI flag is `--per-request-spec-decode-metrics`. Confirms the campaign's
  two prior readings of `'none'` in the config dump.
- Its docstring: *"Include per-request speculative-decoding acceptance metrics
  **in the response** under `metrics.speculative_decoding`"* — `summary` gives
  mean acceptance length, draft acceptance rate and the step histogram;
  `detailed` **additionally records the ordered per-step accepted/proposed
  arrays**. Only for `n == 1`. **"Independent of `--disable-log-stats`."**
- `vllm/config/vllm.py:1352` — raises unless `--speculative-config` is set. We
  ship MTP, so the gate passes.
- `vllm/entrypoints/openai/chat_completion/serving.py:837` and
  `completion/serving.py:479` — the streaming path attaches it to the **final
  usage chunk**, emitted only when `stream_options.include_usage=true`.
  Non-streaming: `serving.py:1140` / `:637`, unconditional on the server flag.
- `vllm/entrypoints/openai/engine/protocol.py:145` — the payload is
  `num_spec_steps`, `num_accepted_draft_tokens`, `num_draft_tokens`,
  `num_spec_tokens`, plus `per_step_accepted` / `per_step_drafted` at `detailed`.

**So `num_spec_steps` — the per-request verify-step count — is readable
directly.** That is better than acceptance: it is the exact quantity R13's
candidate is about ("a request drawing 4.00 completes 128 tokens in ~32 verify
steps, one drawing 2.77 needs ~46"). No modelling step is needed.

**But nothing reaches the engine log, and nothing reaches llama-benchy's
export** — benchy streams `/v1/chat/completions` with
`stream_options.include_usage` (`client.py:_build_generation_payload`), so the
server *would* send the field and benchy *would* discard it. **Running
`sparkrun benchmark perf` with the flag on would therefore produce exactly the
numbers we already have and none of the ones the round needs.** The round is
run instead as: `sparkrun run` to hold the engine up, then a probe of our own
that replicates benchy's request shape and reads the response bodies.

**MUTATION, journalled**: `recipe-r13b-perreq.yaml` = `recipe.yaml` +
`--per-request-spec-decode-metrics detailed`, run at
`-o max_num_batched_tokens=98304 -o max_num_seqs=5` to sit on R13's config.
Instrument only; **not for folding**, and no row it produces is scoreable.

### The probe, and why it is faithful

llama-benchy runs on the laptop over HTTP, so its client is readable and its
workload reproducible exactly. The probe imports **llama-benchy's own**
`TokenizedCorpus` + `PromptGenerator` (Sherlock Holmes,
`gutenberg.org/files/1661/1661-0.txt`, model tokenizer) and copies
`_build_generation_payload` verbatim: streaming chat completions,
`stream_options.include_usage`, `return_token_ids`, and `exact_tg` →
`max_tokens = min_tokens = 128, ignore_eos = true`. It reproduces both phases
in benchy's order — Phase 1 the uncached context load (`prompt_text="."`), then
Phase 2 the inference batch — with 5 concurrent requests fired by one
`asyncio.gather`, each on its **own random corpus slice**, which is exactly
benchy's `generate_batch`. Content variation across the batch is the thing under
test, so it must not be removed.

⚠ **The probe's span ratio is our instrument, not benchy's.** Its internal
validity gate is declared below.

### The arithmetic, and it is the reason I expect a refutation

With 5 requests admitted in one scheduler step (`Waiting: 0`, R13) and each
generating exactly 128 tokens, request *i* retires after its own `S_i` verify
steps. Holding step time `t` constant:

    tg      = 5*128 / (max(S) * t)
    tg_req  = mean_i( 128 / (S_i * t) )
    span ratio = 5 * tg_req / tg = **max_i(S_i) x mean_i(1/S_i)**

i.e. **max / harmonic mean**, zero free parameters.

**R13 compared the wrong statistic.** Its "1.44x spread against a measured 1.54"
is max/**min** of the acceptance samples. The quantity that enters the span is
max/**harmonic mean**, which is strictly smaller. Feeding R13's own full
2.77–4.00 range into a single batch as `S = 128/a` = [32.0, 36, 40, 43, 46.2]
gives `46.2 x mean(1/S)` = **1.19**, not 1.44 and not 1.54. **Even granting the
candidate the widest dispersion the campaign has ever logged, and granting that
all of it happens within one batch, the arithmetic reaches about a third of the
excess span.**

And that grant is itself too generous. Those 2.77–4.00 samples are 10-second
batch aggregates taken across different runs and phases — between-run variation,
which is the confound R13 admitted it could not remove. Within one batch, `a_i`
is an average over ~42 steps, so sampling noise alone concentrates it hard: with
acceptance 3.08 (R13d) and `k=3`, per-step accepted `j` has `E[j]=2.08`,
`p≈0.78`, `Var[j]≈0.65`; by Wald `S ~ 41.6 ± 1.7 steps` (4.1%), and five draws
give `max(S) x mean(1/S) ≈ **1.05**`. Real content variation sits somewhere
between that 1.05 and the 1.19 ceiling.

**So the prediction is that R13b refutes its own candidate.** Stated plainly
because the campaign's rule is that the mechanism paragraph and the numeric band
must be written together, and three rounds got the mechanism right and the band
wrong by writing them apart.

### Numeric predictions, declared before the run

| Quantity | Band | Reasoning |
|---|---|---|
| per-request acceptance `a_i`, max/min within one c5 batch | **1.05 – 1.25** | ~42-step average concentrates it; I do NOT expect the log's 1.44 to appear within a batch |
| **predicted span ratio** `max(S) x mean(1/S)` | **1.02 – 1.20** | the arithmetic above, 1.05 floor to 1.19 ceiling |
| observed span ratio of the probe itself | **1.40 – 1.70** | brackets R13's 1.537 with room for probe-vs-benchy differences |
| share of the excess span (0.537) explained by acceptance | **≤ 40%** | follows from the two bands above |
| per-request `num_spec_steps` `S_i` | **36 – 48** | 128 tokens at acceptance 2.8–3.5 |
| mean acceptance across the batch | **2.9 – 3.3** | flat for seven rounds (3.03–3.19, R13c; 3.08, R13d; 3.13 c1, R9c) |
| `Running: 5, Waiting: 0` at `mnbt 98304` | full residency | R13 measured it; 5 x 16384 = 81920 < 98304 |

### Verdict rule, declared before the run

- predicted span ratio **≥ 1.45** → candidate **CONFIRMED**, open question 7 closes.
- **1.20 – 1.45** → **PARTIAL**: acceptance is a major but incomplete term.
- **< 1.20** → candidate **REFUTED as the dominant mechanism**; open question 7
  stays open and loses its only live candidate.

### Validity gates, declared before the run

1. **The instrument gate.** `metrics.speculative_decoding` must be present and
   populated on every one of the 5 Phase-2 responses. If the field is absent or
   null, the round is a **refusal**, recorded with its evidence — not a result.
2. **The fidelity gate.** The probe's own observed span ratio must land in
   **1.40 – 1.70**. Outside that, the probe is not reproducing the cell R13
   measured, and the decomposition is reported as the probe's own, explicitly
   not transferable to R13's 1.537.
3. **Exact-length gate.** Every request must report exactly 128 completion
   tokens. Any shortfall means `ignore_eos`/`min_tokens` did not take, and
   length dispersion — not acceptance — would be driving the span.
4. `session_count`/engine start clean, no crash loop.

Only the c5 Phase-2 cell is under test. `runs=3` in the queue text refers to
benchy runs; the probe runs the 5-request batch **7 times** instead, because
the campaign's rule is that 3-run medians are always too high and this costs
nothing — the engine is already up and each batch is ~8 s of decode.

Nothing here is scoreable and no standing can move.

## Round 13b outcome — `experiments/r13b-perreq-probe/`, 2026-08-22

Branch `feature/thin-cell-r19`. One engine start, `session_count: 1`,
`crash_count: 0`, box released. **No sparkrun benchId exists for this round and
that is not an omission** — R13b ran no llama-benchy grid, for the reason its
hypothesis gives, so the archive directory is named for the round rather than a
benchId.

### THE CANDIDATE IS REFUTED, AND THE ROUND SAID SO BEFORE IT RAN

**MTP acceptance dispersion is not what the span ratio is made of.** The
pre-declared statistic — `max(S) x mean(1/S)` over the five requests' verify-step
counts — reads a **median 1.085** across seven c5 batches, against an observed
span ratio of **1.499**. The declared verdict rule put `< 1.20` at REFUTED and
the measurement landed at 1.085, below even the 1.19 ceiling the hypothesis
computed from R13's own widest logged spread.

**Acceptance dispersion acting alone would produce a span ratio of 1.085. It
accounts for 17% of the excess span and the other 83% is something else.**

### AND THE ROUND FOUND WHAT IT ACTUALLY IS — a third mechanism, not either of the two on the table

The campaign has now had three candidates for the span floor. R13 refuted
admission stagger. R13b refutes acceptance dispersion. **The answer is neither,
and the probe measured it directly rather than inferring it:**

    corr(start stagger f_i, time per verify step d_i/S_i) = -0.980   (Phase 2)
                                                          = -0.986   (Phase 1)
    corr(verify steps S_i, decode duration d_i)           = +0.142   (Phase 2)

Decode duration is **not** set by how many verify steps a request needs. It is
set by **when the request started decoding**, at a correlation of −0.98 on 35
requests. By start rank, Phase 2:

| start rank | decode duration | verify steps | **ms per verify step** |
|---|---|---|---|
| 0 (first to emit) | 3.414 s | 39 | **88.5** |
| 1 | 2.411 s | 42 | 55.4 |
| 2 | 2.351 s | 41 | 56.4 |
| 3 | 2.163 s | 39 | 57.8 |
| 4 | 2.298 s | 40 | 56.8 |

**The first request to finish prefill decodes at 88.5 ms per verify step; every
other request in the same batch decodes at 55–58 ms.** A **1.57x penalty**, borne
by exactly one request, and it is the one the batch decode span is measured
from — `tg_duration = max(last token) − min(first token)`.

The mechanism is plain once seen: **the batch's five prefills do not complete
together.** The first request to finish begins decoding while the other four are
still prefilling, so its verify steps are co-scheduled with chunked-prefill work
and cost ~1.57x. The others start decoding after prefill has drained and run
clean. First-token spread is **1.26 s median** against a clean decode of ~2.3 s,
and `1 + 1.26/2.30 = 1.548` reproduces the observed **1.499** to 3% with no
fitted parameter.

**Call it prefill-completion stagger, or the first-starter penalty. Do not call
it admission stagger** — that name is refuted and this is not it.

**This is fully consistent with `Waiting: 0`, which is why R13 could not see it.**
Nothing queues. All five requests are `Running`. But **`Running` counts a request
that is still prefilling the same as one that is decoding**, and the engine log
has no column that separates them. R13's instrument was not wrong; it was blind
to the distinction the question turned on.

It also explains the curve R13c measured and could not account for: a larger
token budget means fewer prefill chunks and a tighter first-token spread, so the
span ratio keeps falling to 65536 **with nothing waiting at any budget** — and
then floors, because the prefill *work* still has to be done and cannot be made
simultaneous across five requests by any budget.

⚠ **The three terms are substitutes, not addends, and the counterfactuals say so.**
Removing the first-starter penalty alone *raises* the span ratio to 1.634,
because the span is then set by the last starter instead. The stagger is the
irreducible term; the interference redistributes it. Do not quote the three
percentages as a partition. The one clean statement is the counterfactual with
both stagger terms removed: **span would be 1.085, all of it acceptance.**

### AND IT IS THE SAME EFFECT R11 FOUND FROM THE OTHER SIDE — two instruments, one cause

Recorded because the campaign has spent rounds treating these as separate
puzzles. **Open question 13** — why does the token budget move per-request
*decode* by +15.5% at `c>1` but only +0.27% at c1? — was answered by R11 as
**"a request being stalled behind its neighbours' chunked prefills"**, inferred
from the c1-vs-`c>1` asymmetry. **Open question 7** — what is the span ratio's
floor? — is answered by R13b as **the first request to finish prefill paying
1.57x per verify step because its steps are co-scheduled with its neighbours'
remaining chunked prefill**, measured directly at `corr = −0.980`.

**These are the same sentence.** R11 saw it in `tg_req` and had to infer it;
R13b saw it in the span and measured it per request. Two open questions, two
instruments, one physical cause: **at `c>1` on this engine, decode steps are
priced by how much prefill is still in flight beside them.** That also makes
R9b's "chunked prefill protects decode" the third view of it.

### WHY THE QUEUE'S INSTRUMENT WOULD NOT HAVE WORKED — the round's zero-cost result

Recorded because the campaign has now lost the engine-log instrument four times
and this is a fifth distinct failure mode, found before it cost anything.
`per_request_spec_decode_metrics` writes to the **HTTP response body**
(`metrics.speculative_decoding`), never to `/tmp/sparkrun_serve.log`. QUEUE.md's
"capture the engine log the proven way — R13 shows it works" would have produced
a clean capture containing nothing the round needed. The full source trail is in
the hypothesis above. **llama-benchy receives the field and discards it**, so
`sparkrun benchmark perf` with the flag on would have returned exactly the
numbers already in RESULTS.md.

**Read the instrument's own source before pricing a round on it.** Three of this
round's five results cost no box time, for the fourth consecutive round.

### R13's "1.44x spread against a measured 1.54" COMPARED THE WRONG STATISTIC

Retired. Max/**min** of pooled acceptance samples is not the quantity that enters
the span; **max/harmonic-mean** is. Feeding R13's own 2.77–4.00 range into one
batch gives 1.19, not 1.44. And the range itself was between-sample, not
within-batch: measured **within** a batch, per-request acceptance max/min is
**1.167 median** (35 requests, 2.224–3.657), and the engine log this round read a
batch-aggregate spread of 3.18–3.83 alongside it. The dispersion was never large
enough, and the statistic was never the right one.

### THE PROBE REPRODUCED R13's CELL — the fidelity gate, and it is a real reproduction

An independent client, written from llama-benchy's source rather than using it,
on a separate engine start, against R13's `tg128 @ d16384 c5` at
`mnbt 98304 + mns 5`:

| | R13 (7 runs, benchy) | R13b probe (7 runs) | gap |
|---|---|---|---|
| `tg_throughput` | 164.27 | **167.14** | **+1.75%** |
| `tg_req_throughput` | 50.50 | **49.76** | **−1.46%** |
| span ratio | 1.537 | **1.499** | **−2.63%** |
| Phase 1 `tg` | 160.67 | **161.68** | **+0.63%** |

Gate 2 declared 1.40–1.70 for the span ratio; it read 1.499. **This is the
campaign's first cross-client reproduction** and it is tighter than several of
its cross-invocation ones. ⚠ Phase 1 `tg_req` came in **−4.13%**, the round's
one figure outside 3%.

**Note the direction: two of the four came in HIGH.** The −1.88% eight-of-eight
downward systematic (open question 8) does not extend to this round, which is
mild further evidence for the session-effect half over first-measurement bias —
mild, and from a different client, so it is weak evidence at best.

### VALIDITY — all four gates passed

1. **Instrument gate PASSED.** `metrics.speculative_decoding` present and
   populated on **70 of 70** requests. The engine config echoed
   `per_request_spec_decode_metrics='detailed'` and `max_num_batched_tokens=98304`,
   read from the capture **during the engine start**, per R13d's rule.
2. **Fidelity gate PASSED**, 1.499 inside 1.40–1.70. See the table.
3. **Exact-length gate PASSED.** All 70 requests returned exactly 128 completion
   tokens, so no part of the span is length dispersion.
4. **Engine clean.** One start, no crash loop, box released.

**A DEFECT IN THE FIRST PROBE RUN, CAUGHT AND FIXED, RECORDED HERE.** The first
pass computed the batch span from `min(start)` rather than `min(first token)`,
which put the ~15 s prefill inside the decode denominator and read `tg` = 34
instead of 167 — **5x low** — with a span ratio of 1.01. It was caught by the
fidelity gate doing exactly its job, and the second pass was rewritten against
`llama_benchy/results.py` line by line (decode tokens are those *strictly after*
the first timestamp; the batch span is `max(last token) − min(first token)`; the
per-request rate excludes the first token from both numerator and denominator).
**The first pass cost one grid re-run on an engine that was already up, and no
number from it is used.** The lesson generalises: `tg` at depth is dominated by
prefill unless the denominator explicitly excludes it, and a probe that does not
reproduce a known cell is a broken probe, not a discovery.

### Predictions: 6 held, 2 missed

**Held:** predicted span ratio 1.02–1.20 (**1.085**) · acceptance max/min within
a batch 1.05–1.25 (**1.167**) · share of excess explained ≤40% (**17%**) ·
`num_spec_steps` 36–48 (median 40, 35–58 range) · mean acceptance 2.9–3.3
(**3.225** Phase 2, **2.932** Phase 1 — eighth consecutive flat round) ·
`Running: 5, Waiting: 0` (**28 of 30 loaded samples**).

**Missed:** the observed span ratio band 1.40–1.70 held at 1.499, but **Phase 1
read 1.439 with two runs at 1.52–1.54**, straddling more than expected · and the
implicit prediction that the three terms would decompose additively, which the
counterfactuals refuted — they are substitutes. **The mechanism paragraph was
right and one band was loose, for the fourth round running.**

### Prefix caching and telemetry

**`Prefix cache hit rate: 0.0%` in all 53 samples** at `mnbt 98304`, flag ON.
Campaign total now **374 samples across seven budgets, zero hits ever**, and this
is the first such count taken from a non-benchy client.

Telemetry 884 samples: SM clock **2398 MHz** median (**nineteenth** session
agreeing), 76 °C peak, ⚠ **99.83 W peak** — the third consecutive round at or
above the old ceiling (99.79 R13d, 100.45 R9c). The clock is unmoved. Still not
investigated; still not a finding.

### What is NOT claimed

**No standing moves and nothing here is scoreable.** Every number was taken at
`mnbt 98304 + mns 5` against a recipe that ships `mnbt 65536 + mns 4`, and from a
client that is not the one the board's figures come from. The probe's agreement
with R13 licenses reading its *decomposition*; it does not make its `tg` a
quotable row. **`recipe-r13b-perreq.yaml` is an instrument, not a candidate, and
must not be folded** — `--per-request-spec-decode-metrics detailed` costs a list
append per verify step and was never measured for overhead.

The round did not measure `mnbt 65536 + mns 4` (R11b, still the cheapest
consequential round left) and did not touch open question 8.

### COST

One engine start (~230 s), two probe passes (~7 min of grid total, the first
discarded), **~22 min wall**, ~120k tokens, zero crashes. Cheapest mechanism
result the campaign has bought.

## Round 8c hypothesis — the last surviving deep inversion, and a protection point on a 3-run win: `ctx_tg32` / `tg32 @ d32768 c1`, runs=7, TWO budget arms

Written BEFORE the run, 2026-08-22, on `feature/thin-cell-r20`.

### THE QUEUED FRAMING IS HALF OBSOLETE. WHAT SURVIVES, AND WHAT REPLACES IT

R8c was written after R8 and it was sold on **open question 4** — "the ctx
inversion deepens with depth", and whether the `ctx_` cells "deserve their own
tuning". Both halves of that sale are dead, and a round that ran on them would be
spending box time on a settled point:

- **The `ctx_` phase-label correction** established that `ctx_` is **Phase 1, the
  uncached context load**, and the rows this campaign called "cold" are Phase 2,
  the cache-eligible pass. The framing "cached versus cold" is gone. Retired
  claims 11-15 cover it; **open question 4 as posed is retired claim 15** and
  **its sharpened form is retired claim 13, dissolved rather than answered.**
- **R9b** established prefix caching never engages at all — 158 consecutive
  samples, zero hits — so no `ctx_` result can be a caching result.
- **R9c** priced what the flag is actually worth (2.414x) and decomposed it
  **83% batch span**; **R13b** identified the span's floor as
  **prefill-completion stagger**. `THE MECHANISM CHAIN` in the synthesis is the
  campaign's single explanation for every `c>1` number it has.

So this round does **not** pose another form of "why does Phase 1 stagger", and
it does not treat the cells as prefix-caching phases. **Do not read it as
re-opening open question 4.**

**What survives is sharper than what was queued, and it is two things.**

**(1) The mechanism chain is DEFINITIONALLY SILENT AT c1, so it cannot have
already explained this.** The synthesis says so in terms: *"the chain says
nothing about c1, where there is no batch and the span is 1.000 by
assignment."* Every explanation this campaign owns for a Phase-1-versus-Phase-2
gap is a batch-span explanation. At `c1` there is no batch. R11 confirmed the
arithmetic directly — `tg == tg_req` exactly at both phases at c1, which is
`results.py:195`'s assignment. **The archives therefore do NOT already answer
R8c**, and I checked before assuming they did. A −27% Phase-1 deficit at `c1` is
outside everything the chain covers.

**(2) The number itself is the least protected figure left in the standings, and
it is TWO rows, not one.** `bench_25a0e7f36ab0` is a **runs=3** invocation from
R1 and it is the sole source of both:

| row | R1 figure (runs=3) | σ/med | standing |
|---|---:|---:|---|
| `tg32 @ d32768 c1` (Phase 2) | **115.56** | 9.0% | **WIN, 4.96x** vs 23.31 — ⚠ 3-run, flagged provisional |
| `ctx_tg32 @ d32768 c1` (Phase 1) | **84.03** | 12.7% | **LOSS, 0.72x** vs 117.37 (Atlas) / 116.65 (best vLLM) |

**So this is a protection round on a standing win before it is anything else.**
The campaign's own rule: *"EVERY 3-run median this campaign promoted and later
re-measured was TOO HIGH, and every one of them was eventually retired"* — R1's
tg32 by 11%, R3's d65536 by 13%, R13's two by 2.9% and 1.3%. Four for four, same
sign. 115.56 is a flattering 3-run draw that was promoted to a 4.96x margin and
never repeated. It is exactly the profile the synthesis says to assume high.

**REFRAMED IN ONE LINE: R8c is the protection sweep R13c ran for the six `c4`
rows, applied to the two `d32768 c1` rows — and the inversion falls out of it for
free, because both arms come from one invocation.**

### The prior, assembled from the archives at zero box time

Every archived `c1` phase pair in the campaign, Phase 1 against Phase 2 on `tg`
(the `tg` comparison survives the token-count problem; the `pp` comparison does
not):

| depth | tg | runs | Phase 1 | Phase 2 | Phase1 vs Phase2 | round |
|---:|---:|---:|---:|---:|---:|---|
| 8192 | 32 | **3** | 126.52 | 106.24 | **+19.1%** | R1 |
| 16384 | 32 | **3** | 130.16 | 129.32 | +0.6% | R1 |
| 16384 | 32 | 7 | 122.97 | 116.43 | +5.6% | R6 |
| 16384 | 128 | 7 | 104.85 | 111.11 | −5.6% | R6 |
| 16384 | 128 | 7 | 102.68 | 113.06 | −9.2% | R8 |
| 16384 | 128 | 7 | 98.72 | 112.92 | −12.6% | R11 (mnbt 65536) |
| **32768** | **32** | **3** | **84.03** | **115.56** | **−27.3%** | **R1 — THIS ROUND'S TARGET** |
| 65536 | 128 | **3** | 89.76 | 108.15 | **−17.0%** | R3 |
| 65536 | 128 | 7 | 92.98 | 94.10 | **−1.2%** | R8 |
| 131072 | 128 | **3** | 76.66 | 77.13 | −0.6% | R5 |

**Read the `runs` column, not the `depth` column.** The five 3-run pairs span
**+19.1% to −27.3%**, a 46-point range. The five 7-run pairs span **+5.6% to
−12.6%**, an 18-point range. Every extreme in the table is a 3-run pair. There is
no depth trend at all once sampling is held fixed: at d16384 the 7-run pairs read
+5.6 / −5.6 / −9.2 / −12.6 and at d65536 −1.2.

**And the precedent is exact, not analogical.** R3 measured this same inversion
at d65536 on 3 runs and read **−17.0%**. R8 re-measured it at runs=7 with both
arms in one invocation and read **−1.2%**. The stored lesson from that round says
it plainly: *"twice the deep inversion has vanished under better sampling."*
d32768 is the third and last one, and it is the only one never re-measured.

### THE HYPOTHESIS

**H_sampling (predicted): the −27.3% is a 3-run draw and does not survive seven
runs.** At runs=7 the Phase-1/Phase-2 gap at `d32768 c1 tg32` contracts toward
the family value, and `tg32 @ d32768 c1` reproduces BELOW 115.56.

**H_real (the alternative that would matter): the −27.3% is a real effect at
d32768.** If it survives, the campaign has a `c1` Phase-1 deficit that its one
surviving mechanism cannot touch by construction, at a depth flanked by
non-effects on both sides (−12.6% at d16384, −1.2% at d65536). That would be a
genuine finding and it would deserve a successor round — with per-request
instrumentation, per open question 4's own closing instruction, not with more
ratios.

**Mechanism for H_sampling.** Nothing physical distinguishes d32768 from its
neighbours. Both phases prefill at the same rate to within 4% at every depth,
concurrency and budget in the 42-pair audit. Phase 1 loads `depth` tokens and
Phase 2 loads `depth + 2048`; at c1 both then decode 32 tokens from a
single-request batch with residency 1 of 1 and span 1.000 by assignment. The only
term that differs between the phases at c1 is the prompt the decode starts from,
and R6 showed generation length — a far larger structural difference — moves this
metric ~2.9% net of arm-to-arm systematic. A 27% gap has no room to come from.
What it does have is σ/med 12.7% and 9.0% on three runs each: SE of a 3-run
median ≈ 0.61σ, so **SE on the R1 ratio is ~9.5%** and −27.3% sits ~1.8 SE from a
−10% family value. It does not need a mechanism; it needs a bigger sample.

### The exact configuration, and why there are TWO arms

`pp 2048`, `depth 32768`, `tg 32`, `concurrency 1`, `runs 7`. Probe args
identical to R1's d32768 leg, which is what makes this a protection point rather
than a new cell.

`-o max_model_len=40960` in **both** arms — d32768 + pp 2048 + tg 32 = 34848 does
not fit the recipe's 32768 window. This is the probe-driven override R1 used at
this exact depth and it is not a tuning mutation; R3, R5 and R8 treated their
depth overrides the same way.

- **Arm E (`-o max_num_batched_tokens=8192`) — the pre-fold replica.** Bit-for-bit
  R1's condition. This is the arm the protection verdict is read from.
- **Arm F (recipe as shipped, `mnbt 65536`) — the current epoch.** This is the arm
  that produces a quotable, current-epoch `RESULTS.md` row.

**Why I am spending the second engine start, stated plainly.** R11 folded
`mnbt 65536` and the synthesis's standing warning is that comparing a post-fold
number to a pre-fold row is *"the single move this campaign refuted more often
than any other"* — R6 over R1, R8 over R3, R9b over R4, three real effects read
out of uncontrolled condition differences. The whole protection half of this
round is precisely such a comparison. One arm would force me to caveat the only
verdict the round exists to deliver. Two arms cost ~110 s of extra start plus
~120 s of extra grid and buy the verdict clean.

**The weakness that remains, named rather than hidden:** the two arms are
necessarily separate engine starts — two budgets cannot share one — so the
Arm F versus Arm E comparison is itself cross-invocation and must be read against
R9c's measured **±2.5% reproduction floor**, not as an exact quantity. That is
unavoidable and it is the same design R13c used for its six-budget curve. **The
primary reading and the protection reading are both intra-invocation and are not
exposed to it:** each arm produces its own Phase 1 and Phase 2 under one engine
start.

`max_num_seqs` stays at the recipe's 4 in both arms. At c1 scheduler width does
nothing and changing it would make this a two-mutation round for no reason.

`runs=7` in both arms, non-negotiable: the synthesis's corrected rule is
**runs=7 at c1 anywhere**, `runs=3` is defensible only at `c>=8`, and this is a
tg32 cell — *"anything `tg32` ... runs=7, non-negotiable"*.

### Numeric predictions, declared before the run

**PRIMARY — the inversion, Arm E, intra-invocation.** Phase 1 versus Phase 2 at
`d32768 c1 tg32`, runs=7:

**Predicted −4%, band −18% to +8%.** Centre from the d65536 precedent: −17.0% at
3 runs became −1.2% at 7, a contraction of ~14x; applying the same contraction to
−27.3% gives −2%, and the tg32 arms of the family run positive (+19.1 / +0.6 /
+5.6), so I place the centre slightly negative rather than at zero.

- **Gap ≤ −20% → H_real. The −27% survives in substance.** Retired claim 9 keeps
  its last piece of evidence, the campaign owns a `c1` effect its mechanism chain
  cannot explain, and R8c earns a successor. **I predict this does not happen.**
- **Gap > −20% → H_sampling. The −27% is retired as a 3-run draw**, retired claim
  9 loses its only surviving evidence and the "inversion deepens with depth"
  story is dead outright rather than merely unreproduced.
- **Gap in −20% to −18% → NOT ESTABLISHED either way.** Say so; do not round it
  into a verdict.

**Honest power statement, made in advance.** At runs=7 with σ/med ~10%, SE of a
median ≈ 0.40σ, so SE on the new ratio is ~6%, and SE on the *change* from R1's
ratio is ~11%. A shift from −27% to −4% is **~2 SE**. This round can retire a
27-point effect; it could not resolve a 10-point one, and I am not claiming it
can. If the reading lands mid-band the honest output is "the effect is smaller
than R1 measured and this round cannot say by how much".

**SECONDARY — the protection verdict, Arm E, against R1's rows.** Band declared
in advance at **±10%**, R13c's protection band:

| row | R1 (runs=3) | STANDS if | predicted | why |
|---|---:|---|---:|---|
| `tg32 @ d32768 c1` (Phase 2) | 115.56 | **104.0 – 127.1** | **107, band 100 – 116** | depth curve 113.06 @ d16384 → 94.10 @ d65536 is −8.8%/doubling, so tg128 @ d32768 ≈ 103; R6's tg32-over-tg128 offset is +4.79% → ≈ 108. Then the 4-for-4 rule and R9c's −2.5% floor pull it down, not up |
| `ctx_tg32 @ d32768 c1` (Phase 1) | 84.03 | **75.6 – 92.4** | **102, band 88 – 115** | = predicted Phase 2 × the predicted ratio. **I am predicting this row moves OUTSIDE its own protection band, upward** — that is what H_sampling means here, and it is the round's sharpest call |

**I am predicting a split protection verdict and saying so before the run:**
Phase 2 stands (low in band), Phase 1 does **not** stand and comes in high. That
is the only shape consistent with H_sampling, and it is falsifiable in both
directions. Note the asymmetry of consequence: Phase 2 failing low costs the
campaign a decimal on a 4.96x win that is not in danger either way (the incumbent
is 23.31 — even a 30% fall leaves it above 3.4x); Phase 1 rising costs it a
retired claim. **Neither cell changes side.** `ctx_tg @ d32768 c1` needs +39% to
reach 116.65 and I predict +21%, so it stays a loss; I name the upside only so
that nobody later reads a surprise as having been unanticipated.

**TERTIARY — budget inertness at c1 at a second depth (Arm F vs Arm E, free).**

**Predicted |Δ| < 2.5% on both phases; declared inert if < 5%.** R11 measured the
budget inert at c1 at d16384 (+0.27%) and the mechanism is structural, not
empirical: the two routes by which the budget has ever moved this metric are
occupancy and span, and both are absent at c1 — residency is 1 of 1 at every
budget, and `tg == tg_req` makes the span 1.000 by assignment. **This arm extends
that result to a second depth, which it currently does not have**, and d32768 is
a stiffer test than d16384: a Phase-2 prefill of 34816 tokens is **5** scheduler
steps at 8192 against **1** at 65536, where R11's was 3 against 1. If it moves
>5%, the fold's licence is depth-limited — which does **not** invalidate the fold
(measured at the anchor depth) but does mean deep rows cannot be compared across
the epoch, and that is worth escalating into the synthesis.

**Free riders — zero box cost, recorded either way:**

| quantity | predicted | why it is worth recording |
|---|---|---|
| MTP acceptance @ d32768 c1 | **length 3.2 – 3.7, acceptance 78 – 92%** | **the missing middle point of open question 3.** R5 read 93.6% at d16384 and 47.7% at d131072 and the campaign has never taken the point between them. Free from the engine log |
| `ctx_pp / pp` | **16.4 – 17.9** (theory **17.00** = (32768+2048)/2048) | pairs **43 and 44** of the phase-label audit, currently 41 of 42. R1's d32768 pair read 17.20; these add the first at this depth **above** the old budget |
| prefix cache hit rate | **0.0%** | 158+ consecutive samples, never a hit |
| scheduler `Running/Waiting` | **`(1,0)` in 100% of loaded samples** | one request; this is the occupancy half of the inertness argument |
| span ratio `tg / tg_req` | **exactly 1.000, both phases, both arms** | assignment, not measurement. Anything else voids the round |
| `peak_throughput` (Phase 2) | 100 – 125 | the hardware ceiling; the budget has never moved it more than a few percent |
| SM clock median | **2392 – 2398 MHz** | eighteen sessions agreeing; the box's most reproduced fact |
| σ/med, both phases | 6 – 14% | R1 read 9.0% / 12.7% at 3 runs; σ is itself a draw (retired claim 19) |
| grid time | **110 – 150 s per arm** | R1's d32768 leg at 3 runs, scaled |
| engine start | **100 – 140 s (Arm E), 160 – 200 s (Arm F)** | start cost tracks budget SIZE, not novelty (R13c) |

### What would make this round void

- `crash_count > 0` or `session_count > 1` in either arm — each arm must be one
  engine start.
- The `Benchmark args:` echo not reading `pp: [2048]`, `depth: [32768]`,
  `tg: [32]`, `concurrency: [1]`, `runs: 7`. **`sparkrun` silently defaults an
  omitted `-b depth` to 0 and does not error** — R5 lost an engine start to it.
  **Read the echo before letting the grid proceed, in both arms.**
- `tg_throughput != tg_req_throughput` at c1.
- `ctx_pp / pp` outside 15 – 19, which would mean the two phases are not doing
  what they do at every other depth.
- A container image other than `dgx-vllm-eugr-nightly:2026082102` in either
  `state.yaml` — read `container_image_longterm_ref`, not the console line about
  `:latest`.

### Instrument plan

Engine log per R13d's recipe: `docker exec <container> tail -f
/tmp/sparkrun_serve.log`, container matched on **`^sparkrun_`** (it is named
`sparkrun_<hash>_<hash>_solo`, **not** `vllm-*`), verified non-empty **during**
the engine start rather than at grid start. `docker logs -f` does not work on
this image and cost R12 its occupancy instrument. Telemetry alongside per arm.

### Cost

Two invocations, two engine starts. ~240 s grid + ~300 s starts, **~15 min wall**
estimated. Against that: a protection point on a standing win, the retirement or
survival of the campaign's last deep inversion, a second depth for R11's
inertness result, and the missing acceptance point of open question 3.

### ABSOLUTELY NO ARENA SUBMISSION

No `--arena` flag, in either arm. There is no login and none will be attempted.

## Round 8c outcome — bench_2b0f7bc8fb7b-mnbt8192 (arm E) + bench_964a188f3d16-mnbt65536 (arm F), 2026-08-22

`ctx_tg32` / `tg32 @ d32768 c1`, runs=7, TWO arms, ONE engine start each
(`session_count: 1`, `crash_count: 0` in both). Image
`dgx-vllm-eugr-nightly:2026082102` — the same epoch as all fifteen prior rounds.
`-o max_model_len=40960` in both, `-o max_num_batched_tokens=8192` in arm E only.

### THE −27% INVERSION IS RETIRED. IT WAS A THREE-RUN DRAW.

| measurement | Phase 1 `ctx_tg32` | Phase 2 `tg32` | **P1 vs P2** |
|---|---:|---:|---:|
| **R1, runs=3, mnbt 8192** | 84.03 | 115.56 | **−27.3%** |
| **R8c arm E, runs=7, mnbt 8192** — same condition | **110.61** | **109.62** | **+0.9%** |
| **R8c arm F, runs=7, mnbt 65536** — folded recipe | **117.65** | **110.03** | **+6.9%** |
| pooled mnbt 8192, 10 runs (R1 + arm E) | 107.73 | 112.59 | −4.3% |
| all R8c, 14 runs, both budgets | 117.06 | 109.82 | +6.6% |

The pre-declared reading thresholds were **≤ −20% → H_real**, **> −20% →
H_sampling**, and −20% to −18% → not established. **Both arms land far on the
H_sampling side and they agree in sign with each other.** The predicted band was
**−18% to +8%, centre −4%**; arm E read **+0.9%** and arm F **+6.9%**, both
inside it, and the pooled 10-run figure at the original condition read
**−4.3%**, which is the predicted centre to a tenth of a point.

**Retired claim 9 has lost its last evidence.** "The ctx inversion deepens with
depth" (R3) was already unreproduced at d65536 (−17.0% at 3 runs → **−1.2%** at
7, R8) and at d131072 (−0.6%, R5). d32768 was the only surviving piece and it
behaved the same way: **the third deep inversion to vanish under better
sampling, and the last one there was.** The claim is now dead outright rather
than merely unreproduced, and **no deep `ctx_`-versus-Phase-2 inversion exists
anywhere in this campaign's data.**

**Note what did NOT have to be invoked.** No mechanism was needed and none is
offered. The pre-run hypothesis said the gap did not need a mechanism, it needed
a bigger sample, and that is exactly how it resolved. This matters because at
`c1` the campaign's one surviving mechanism — `THE MECHANISM CHAIN`'s
prefill-completion stagger — is **silent by construction**: `tg == tg_req`
exactly in all four phase-arms measured here, so the span ratio is **1.0000**,
by assignment. Had the −27% survived, the campaign would have owned a `c1`
effect nothing in it could explain. It did not survive.

### THE PROTECTION VERDICT IS SPLIT, EXACTLY AS PRE-DECLARED

Read from **arm E**, which replicates R1's condition bit for bit
(`mnbt 8192`, `mns 4`, `max_model_len 40960`, same probe args, same image):

| row | R1 (runs=3) | **R8c arm E (runs=7)** | change | ±10% band | verdict | predicted |
|---|---:|---:|---:|---|---|---:|
| `tg32 @ d32768 c1` (Phase 2) | 115.56 | **109.62** | **−5.14%** | 104.0 – 127.1 | **STANDS** | 107 (100 – 116) ✅ |
| `ctx_tg32 @ d32768 c1` (Phase 1) | 84.03 | **110.61** | **+31.64%** | 75.6 – 92.4 | **DOES NOT STAND — high** | 102 (88 – 115) ✅ |

The hypothesis predicted this split shape, both directions and both magnitudes,
in advance: *"I am predicting a split protection verdict and saying so before the
run: Phase 2 stands (low in band), Phase 1 does not stand and comes in high."*
Both predictions landed inside their declared bands.

**Phase 2 is the ninth same-sign low reproduction the campaign has recorded**
(−5.14%), which is larger than R13c's −1.94% mean but the same direction. It does
**not** strengthen open question 8 much: R9c already weakened the systematic to a
±2.5% noise floor, and a −5.14% move on a cell whose σ/med is 15.82% is 0.8
standard errors. Read it as noise with a sign, not as a correction to apply.

**Phase 1 is the campaign's largest single-figure retraction by percentage** —
84.03 was **28.5% below** what seven runs at its own condition say. Note the
shape, because it is the mirror image of the campaign's four-for-four rule: the
rule says *promoted* 3-run medians came in too high, and this is a 3-run median
that came in too **low**. It was never promoted, because it was a loss. **The
one-sided survival the synthesis describes is a property of what gets defended,
not of the sampling** — a flattering draw becomes a claim and gets defended, an
unflattering one becomes a recorded loss and nobody re-measures it for eleven
rounds. **Both directions were live all along and only one of them was being
audited.** That is the reusable half of this round.

### THE CONSEQUENCE NOBODY QUEUED: `ctx_tg @ d32768 c1` IS NOW A DEAD HEAT, NOT A 0.72x LOSS

This cell has been carried as a **0.72x loss** since R1 — one of the twelve
losses in the standings, and read as hopeless. It is not.

| configuration | figure | vs 117.37 (Qwen3.6-35B-A3B-NVFP4 on **Atlas**, the cell top) | vs 116.65 (best vLLM entry) |
|---|---:|---:|---:|
| R1, 3 runs, mnbt 8192 | 84.03 | 0.716x | 0.720x |
| **pooled mnbt 8192, 10 runs** | **107.73** | **0.918x** | 0.924x |
| **arm F, 7 runs, mnbt 65536 — the folded recipe** | **117.65** | **1.002x** | **1.009x** |
| all R8c, 14 runs | 117.06 | 0.997x | 1.004x |

**THIS IS NOT CLAIMED AS A WIN AND MUST NOT BE.** The campaign's own rule,
earned by R13c and paid for by R1 and R3: *"a single 7-run median at a
configuration measured once is not a claim"*, and *"promoting the best first
measurement of a cell is exactly what retired R1's and R3's figures."* The margin
is **+0.24%** on a cell whose σ/med is 9.44% — **0.06 standard errors**, which is
a tie in every sense that matters, and arm F's figure is the first and only
measurement of this cell at this budget. Recording it as a win would repeat the
precise error this round was built to correct, in the same document that
corrects it.

**What IS established: the cell was mis-scored, and by a lot.** The standings say
0.72x; the evidence says **0.92x at the pre-fold budget and a coin flip at the
folded one**. The loss stands, the margin does not. `RESULTS.md` is corrected
accordingly and the cell is queued for a protection round — it is a **125-entry
crowded cell** and it is now the closest unclaimed cell in the campaign.

### BUDGET INERTNESS AT c1 EXTENDS TO d32768 ON PHASE 2, AND IS NOT ESTABLISHED ON PHASE 1

Arm F against arm E — the same probe at two budgets, which necessarily means two
engine starts:

| phase | mnbt 8192 | mnbt 65536 | change | SE of the change | pre-declared inert if |
|---|---:|---:|---:|---:|---|
| Phase 2 `tg32` | 109.62 | 110.03 | **+0.37%** | ~10.6% | < 5% → **INERT** |
| Phase 1 `ctx_tg32` | 110.61 | 117.65 | **+6.36%** | ~6.4% | < 5% → **NOT ESTABLISHED** |

**Phase 2's +0.37% is a striking reproduction of R11's +0.27%** at d16384 — the
same flag, the same concurrency, a second depth, an 8x budget change, and the
two independent measurements agree to a tenth of a percent. The mechanism is
structural and this round measured both of its legs directly: residency read
**`Running: 1, Waiting: 0` in 9 of 9 loaded scheduler samples** in arm E, and
`tg == tg_req` exactly in all four phase-arms, so the span ratio is **1.0000 by
assignment** and there is no admission stagger for a larger budget to remove.
This is the stiffer version of R11's test — at d32768 a Phase-2 prefill of 34816
tokens is **five** scheduler steps at 8192 against **one** at 65536, where
R11's was three against one.

**Phase 1's +6.36% clears the pre-declared 5% bar and must be reported as not
established, not as inert.** It is **1.0 standard error** on the arm-to-arm
comparison, so it is equally consistent with zero — but the hypothesis committed
in advance to the conjunction rule R11 used (*"if Phase 2 is inert and Phase 1 is
not, or vice versa, the inertness reading is not established whatever the band
says"*), and honouring that rule when it is inconvenient is the point of
declaring it. **The honest statement is: the budget is inert at c1 on Phase 2 at
a second depth, and this round cannot say whether it is inert on Phase 1.**

That matters more than it looks, because **arm F's Phase 1 is the dead-heat
figure above.** If the +6.36% is real, the folded recipe genuinely helps this
cell; if it is noise, arm F simply drew high and the cell sits near 0.92x. **The
protection round this cell needs must therefore measure both budgets**, not just
repeat arm F.

### THE FREE RIDERS — every one recorded, four of five predicted correctly

**1. MTP acceptance at d32768 c1 — the missing middle point of open question 3,
and it was taken TWICE.**

| depth | acceptance rate | acceptance length | source |
|---:|---:|---:|---|
| 16384 | 93.6% | 3.81 | R5 |
| **32768** | **87.0%** | **3.61** | **R8c arm E** (12 samples) |
| **32768** | **88.9%** | **3.67** | **R8c arm F** (11 samples) |
| 131072 | 47.7% | — | R5 |

Predicted **3.2 – 3.7 and 78 – 92%**; both arms landed inside both bands and
**reproduced each other across two engine starts to 2.2% and 1.7%**. This is the
campaign's first acceptance figure taken at two independent engine starts at one
depth, and the first at this depth at all.

**What it says about open question 3, carefully.** The curve is **not linear in
log-depth**: d16384 → d32768 costs 5–7 points of acceptance, d32768 → d131072
costs ~40. Acceptance decays *gently* over the range where the depth term is
−8.8% per doubling and *collapses* beyond it. That is the right shape to be the
steepening term the bandwidth model misses — but ⚠ **it is not the unconfounded
measurement open question 3 asks for.** The d16384 and d131072 endpoints are R5's,
taken at other invocations and other conditions; only the middle point is
controlled. **R8b's design — two depths under ONE engine start — is still the
measurement that closes this, and it is still outstanding.** Do not read this
table as having closed it.

**2. The phase-label identity, audit pairs 43 and 44.** `ctx_pp / pp` reads
**17.396** (arm E) and **17.468** (arm F) against the zero-free-parameter
prediction `(32768+2048)/2048 = 17.00` — residuals **+2.3%** and **+2.8%**,
inside the audit's −0.7% to +6.4% range. The audit stands at **43 of 44**. Both
pairs are at d32768, and arm F is the first at this depth above the old budget.
The ratio is unmoved by an 8x budget change, which is what a denominator
artefact must do.

**3. Prefix caching still never hits.** `Prefix cache hit rate: 0.0%` in **12 of
12** samples (arm E) and **11 of 11** (arm F) — **23 more consecutive samples,
taking the campaign's run past 180 with no hit ever recorded**, now at a depth
and a budget it had not been checked at.

**4. Residency and the span.** Arm E: `(1,0)` in **9 of 9** loaded samples, as
predicted. Span ratio **exactly 1.0000** in all four phase-arms. ⚠ **Arm F's
occupancy sample is empty** — all 11 of its scheduler lines read `Running: 0`,
i.e. the sampler caught only the gaps between runs. The capture itself worked
(it was verified live during the engine start, and it carried acceptance and
cache lines from the same run); what failed is that at `c1` with a ~30 s cadence
the loaded window is narrow. **Recorded as a partial instrument failure, not
papered over** — arm E's 9 samples carry the residency claim and arm F's do not.

**5. Telemetry — the nineteenth agreeing session, with one new extreme.** SM
clock median **2398 MHz** (min 2275, max 2411) against the reported 3003 MHz
ceiling, over 686 samples. Temperature max **75 °C**. ⚠ Power max **99.49 W**,
which is a **new campaign maximum** — the observation section has said "≤97.3 W"
for the whole campaign and that bound is now wrong. The clock did not move with
it, so it changes nothing about the clock-policy reading; it is a bookkeeping
correction to a stated bound.

### σ — THIS CELL IS THE NOISIEST THE CAMPAIGN HAS EVER MEASURED AT c1

| measurement | σ/med, Phase 2 | σ/med, Phase 1 |
|---|---:|---:|
| R1, 3 runs | 11.03% | 15.58% |
| arm E, 7 runs | 15.82% | 11.78% |
| **arm F, 7 runs** | **24.20%** | 9.44% |

Arm F's **24.20%** beats `tg32 @ d8192 c1`'s 21.4% and is the largest σ/med in
the campaign's records. Its runs span **75.36 to 144.99** — a factor of 1.92
between the best and worst draw of one cell at one engine start.

**This is retired claim 19 (σ is itself a draw) at its most extreme, and it is
also R6's variance mechanism working exactly as R6 said it does.** `tg32` is a
32-token generation at ~3.6 accepted tokens per verify step — roughly **nine
verify steps per run**. R6's result is that σ is set by how many verify steps a
measurement averages over; nine is the fewest of any cell in the campaign, and
this is the noisiest. The two facts are the same fact. **The practical
consequence: `runs=7` was not merely justified here, it was barely adequate** —
at σ/med 24.2% a 7-run median still carries a standard error near 9.7%. Anything
that needs to resolve better than ~10% at a `tg32` cell needs more than seven
runs, and the campaign has never budgeted that.

### WHAT THE QUEUED FRAMING GOT WRONG, RECORDED SO IT IS NOT REPEATED

R8c was queued as *"open question 4 has a real deep effect to explain"* if the
inversion survived. **That sale was already void before this round ran**, and the
hypothesis said so: open question 4 as posed is retired claim 15, its sharpened
form is retired claim 13, the `ctx_` phase is not a caching phase (R9b, the
phase-label correction), and the synthesis instructs that no cell be spent on
another form of that question. **The round was re-sold, before running, as a
protection round on two 3-run rows, with the inversion falling out for free.**
That reframing is what made it worth the box time: the inversion answer alone
would have retired a claim nobody still believed, while the protection half
corrected a standings row by 28% and found the campaign's closest unclaimed cell.

**The general lesson, and it is the same one the cost ledger keeps teaching:**
this round's most valuable output came from re-reading the archives, not from the
box. The ten-row `c1` phase-pair table in the hypothesis — assembled at zero cost
— showed that **every extreme in the campaign's inversion data was a 3-run pair
and every 7-run pair was moderate**, which predicted the result before the engine
started. The box time confirmed a conclusion the archives had already implied.

### WHAT IS NOT CLAIMED

- **No standings side changes.** `tg32 @ d32768 c1` is still a **WIN** and
  `ctx_tg32 @ d32768 c1` is still a **LOSS**. The counts stay **8 won / 12
  lost**. Two margins are corrected; no cell moves.
- **`ctx_tg @ d32768 c1` at 1.002x is NOT a win** and no row claims it. See above.
- **The acceptance-vs-depth curve is not closed.** Only its middle point is
  controlled; open question 3 still needs R8b's two-depths-one-start design.
- **Phase 1 budget inertness at c1 is not established** at this depth, by the
  round's own pre-declared conjunction rule.
- **Nothing was submitted to the arena.** No `--arena` flag was passed in either
  arm; there is no login and none was attempted.
- **`recipe.yaml` is untouched.** This round proposed no mutation. The
  `max_model_len 40960` override is probe-driven, exactly as it was for R1, R3,
  R5 and R8, and is not a tuning change.

### COST

Two invocations, two engine starts, **zero crashes**, zero wasted starts.
Grid time **117.6 s** (arm E) + **110.9 s** (arm F) = **228.5 s**; engine starts
~150 s and ~180 s. **~11 minutes of box wall clock**, ~85k harness tokens.

Bought: the campaign's last deep inversion retired, a standings row corrected by
28%, a second-depth confirmation of R11's inertness result on Phase 2, the
missing acceptance point of open question 3 measured twice, audit pairs 43-44,
23 more zero-hit prefix-cache samples, the campaign's noisiest cell characterised
— and the discovery that a 125-entry cell recorded as a 0.72x loss is a coin
flip. **Good ratio: it sits between R6 and R8 in the ledger.**

## Round 21 hypothesis — the three-run audit: re-measure the surviving `runs=3` standings rows at runs=7, TWO arms

Written BEFORE the run, 2026-08-22, on `feature/thin-cell-r21`.

### WHY THIS ROUND EXISTS, AND IT IS THE CAMPAIGN'S OWN ARGUMENT TURNED ON ITSELF

For eleven rounds this file published a rule: **every 3-run median the campaign
re-measured came in too high.** Four for four — R1's `tg32 @ d16384` by 11%,
R3's `d65536` by 13%, R13's two pooled figures by 2.9% and 1.3%. The rule was
used to justify treating unrepeated wins as inflated.

**R8c broke it, and broke it in the expensive direction.** `ctx_tg32 @ d32768 c1`
had been carried as a **0.72x loss** since R1 on a 3-run median of 84.03. Seven
runs at R1's own condition read **110.61 — +31.64%**. The cell is **0.92x**, and
on the folded recipe it is a **dead heat at 1.002x**. The campaign spent eleven
rounds not looking at a cell it had written off on a bad draw.

The synthesis's revised reading is the one this round acts on: the four-for-four
pattern was **an artefact of which rows got audited, not of sampling.** A
flattering draw becomes a claimed win, a claimed win gets defended, and defended
figures get re-measured. **An unflattering draw becomes a recorded loss and
nobody looks at it again.** Sampling error is symmetric; the error that survives
in a results file is whichever direction nobody was auditing.

**R21 is the audit of the rows nobody had a motive to check.** It is a
standings-protection round, not a new-cell hunt. **No cells are added.**

### THE FOUR ROWS, AND WHICH TWO INVOCATIONS COVER THEM

`RESULTS.md` lists four standings rows still standing on 3-run medians. Ordered
by what a re-measure could change — losses that could flip first, thin claims
second:

| # | row | recorded | σ/med | SE of a 3-run median (≈0.61σ) | what could move |
|---:|---|---:|---:|---:|---|
| 1 | `tg128 @ d131072 c1` | 77.13 | 9.3% | **5.7%** | ⚠ **LOST by 5.5% to 81.60.** The deficit is **one SE**. The only recorded loss on the board that a re-measure could plausibly **flip to a win** |
| 2 | `ctx_tg @ d8192 c1` | 126.52 | 6.3% | **3.8%** | Carries a published **1.07x over best vLLM+NVFP4** (118.07). A thin claim; 1.07x is 1.8 SE and a downward correction would withdraw it |
| 3 | `tg32 @ d8192 c1` | 106.24 | **21.4%** | **13.0%** | Uncontested — the board publishes no figure, so **no margin can move whichever way it lands.** The noisiest 3-run row in the standings; rides along free with #2 |
| 4 | `tg128 @ d16384` c2 (84.00) and c5 (48.12) | losses by **>2x** | — | — | **NOT MEASURED THIS ROUND, deliberately.** No sampling error of this size closes a 2x gap, and both already have 7-run tuned successors. Box time spent here buys nothing |

**Rows 2 and 3 are the same invocation** — Phase 1 and Phase 2 of one
`tg32 @ d8192 c1` grid, exactly as they were in R1. So **three of the four rows
cost two engine starts**, and the fourth is declined on the record rather than
forgotten.

### ARM A — `tg128 @ d131072 c1`, runs=7. The flip candidate

Reproduces **R5's `bench_076db52d341c`** condition exactly:

```
-b pp=2048 -b tg=128 -b depth=131072 -b concurrency=1 -b runs=7
-o max_model_len=139264 -o max_num_batched_tokens=8192
```

⚠ **`-o max_num_batched_tokens=8192` is mandatory and is what makes this a
re-measure rather than a new cell.** R5 ran before R11's fold; `recipe.yaml` now
ships **65536**. Running it bare would measure a different engine and the
protection verdict would be uninterpretable. `max_model_len=139264` is R5's own
probe-driven window override (depth 131072 + pp 2048 + tg 128 with headroom),
not a tuning change. `max_num_seqs` stays at the recipe's 4 — at c1 scheduler
width does nothing.

**The cost objection, stated and overruled.** The journal's standing advice is
not to return to d131072: it is the campaign's most expensive depth, ~8x a
shallow round, and R5 itself said "the expense is itself an argument against ever
returning to this depth to tune it." **That advice was about tuning the cell, and
this is not tuning — it is auditing a loss that sits one standard error from a
win.** R5's 3-run grid ran 398 s (05:52:22 → 05:59:00), so seven runs is ~930 s
of grid plus ~150 s of engine start — **about 18 minutes.** That is the price of
finding out whether the campaign is publishing a loss it does not have, and R8c
just demonstrated the failure mode costs more.

**Prediction, declared before the run: median 72-88, centre ~78, and I do NOT
predict a flip.** R5's three runs were 72.37 / 89.39 / 77.13 — the mean (79.63)
sits above the median, so if anything the median is the low-ish summary of that
draw, but only by ~3%. To take the cell the 7-run median must clear **81.60**,
i.e. come in **+5.8%** on 77.13. That is inside one SE, which is exactly why the
round is worth running and exactly why it is not a prediction of a win. **Call
it ~30% that the cell flips.** Anything from 72 to 88 is an ordinary draw of the
same population and would be recorded as such.

**Free riders in the same invocation, none of them scoreable:**
`ctx_tg128 @ d131072 c1` (76.66 — never scraped, so held not claimed),
`pp2048 @ d131072` (42.59) and `ctx_pp2048 @ d131072` (2803.17). They are
recorded because they are measured, and the two `pp` figures had σ near zero
(0.02 and 2.43), so they are also this round's cheapest instrument check: if
either moves more than a percent, something about the invocation differs from
R5's and the whole arm's verdict is suspect.

### ARM B — `tg32 @ d8192 c1`, runs=7. The thin claim and the noisy row

Reproduces **R1's d8192 leg of `bench_25a0e7f36ab0`**:

```
-b pp=2048 -b tg=32 -b depth=8192 -b concurrency=1 -b runs=7
-o max_model_len=40960 -o max_num_batched_tokens=8192
```

`-o max_model_len=40960` is R1's window override, kept even though d8192 alone
would fit the recipe's 32768 — **the row was measured with a 40960 window and the
KV allocation follows the window, so reproducing the row means reproducing it.**
R1 swept three depths in one invocation and this runs one; that is a probe
difference, not a config difference, and it is the same design R8c used when it
re-measured R1's d32768 leg alone.

**This is the exact sibling of the row R8c corrected.** Same invocation, same
phase, same `c1`, one depth shallower. **That invocation's rows have now moved
+11%, +5.4% and −28.5% on re-measurement** — both signs, all large. Nothing about
`bench_25a0e7f36ab0` should be trusted at 3 runs.

**Predictions:**

- **`ctx_tg @ d8192 c1` (row 2): 118-135, centre ~126.** σ/med was 6.3%, the
  quietest of the three R1 Phase-1 cells. **The claim at risk is the 1.07x over
  118.07 (Nemotron-3.5-Lightning-30B-A3B-NVFP4, vLLM), not the 0.61x against the
  cell top** — 207.60 is 64% away and no sampling can reach it. If the median
  lands below 118.07 the 1.07x is withdrawn. I put that at ~35%.
- **`tg32 @ d8192 c1` (row 3): 85-125, centre ~105, and the band is that wide
  because σ/med here is 21.4% — the widest in the standings** (runs 128.35 /
  106.24 / 73.07, a 1.76x spread inside one cell). **Whatever it reads, no margin
  moves**, because the board publishes no figure for the cell. The value of
  measuring it is that it is free and that it retires the campaign's single
  worst-sampled number.
- **Phase 1 vs Phase 2 at this depth reads +19.1% on R1's 3 runs. Predict the gap
  contracts to +0-10%.** Every extreme in the campaign's phase-pair table is a
  3-run pair (five 3-run pairs span +19.1% to −27.3%; five 7-run pairs span +5.6%
  to −12.6%). d8192 is the last unaudited extreme. This is not a mechanism claim
  — the mechanism chain is definitionally silent at c1 — it is the sampling
  prediction that has now been right at d65536 (R8) and d32768 (R8c).

### THE PROTECTION BAND, DECLARED BEFORE THE RUN

Same rule R8c and R13c ran under: **±10%.** A re-measure inside the band means
the row **STANDS** and, because both arms reproduce the original configuration
exactly, the two 3-run and 7-run sets are **POOLED to a 10-run median** — which
is what R8c did for `tg32 @ d32768 c1` and what R13c did for the c4 pairs.
Outside the band, the original figure is **RETIRED** and the 7-run median
replaces it outright.

**Pooling is legitimate here and I have checked why**: both arms run the row's
own configuration, and pooling across a configuration difference is the one thing
this file says must never happen. It does not happen in this round.

**A corrected row must not read as a new one.** Any row that moves is edited in
place in `RESULTS.md` with its old figure named and marked retired, so the
standings stay honest about what changed. Any row left on 3 runs — row 4 — is
labelled provisional in `RESULTS.md` and named in the outcome below.

### WHAT WOULD MAKE THIS ROUND A FAILURE

Not a row that fails to move. **A row that moves and gets quietly overwritten**,
or the fourth row silently left at 3 runs with no note. The round's product is
the honesty of the standings, not a new margin.

## Round 21 outcome — bench_deb3090b9a29-r21-armA + bench_6921c874daee-r21-armB (2026-08-22)

**Verdict: FOUR ROWS RE-MEASURED, FOUR ROWS MOVED, AND ALL FOUR MOVED UPWARD.
No cell changed hands; the counts stay 8 won / 12 lost. The round's product is
that three standings figures are no longer 3-run medians and one recorded margin
was overstated by a factor of ten.**

### The numbers

**Arm A — `bench_deb3090b9a29-r21-armA`**, reproducing R5's condition
(`pp 2048`, `depth 131072`, `tg 128`, `c1`, `runs=7`, `-o max_model_len=139264`,
`-o max_num_batched_tokens=8192`). One session, **crash_count 0**, grid 784.5 s
(15:27:19 → 15:40:24 UTC).

| Cell | R5 (runs=3) | R21 (runs=7) | σ (σ/med) | change | pooled (10) |
|---|---:|---:|---:|---:|---:|
| `tg128 @ d131072 c1` | 77.13 | **81.32** | 8.59 (10.56%) | **+5.43%** | **81.22** |
| `ctx_tg128 @ d131072 c1` | 76.66 | **78.38** | 8.99 (11.47%) | **+2.24%** | **77.52** |
| `pp2048 @ d131072` | 42.59 | 42.74 | 0.01 | +0.35% | — |
| `ctx_pp2048 @ d131072` | 2803.17 | 2811.63 | 1.76 | +0.30% | — |

Arm A runs, `tg128 @ d131072 c1`: 81.32 / 83.59 / 79.20 / 88.93 / 81.12 / 92.89 /
63.56. ttfr 47.9 s.

**Arm B — `bench_6921c874daee-r21-armB`**, reproducing R1's d8192 leg
(`pp 2048`, `depth 8192`, `tg 32`, `c1`, `runs=7`, `-o max_model_len=40960`,
`-o max_num_batched_tokens=8192`). One session, **crash_count 0**, grid 31 s.

| Cell | R1 (runs=3) | R21 (runs=7) | σ (σ/med) | change | outcome |
|---|---:|---:|---:|---:|---|
| `ctx_tg @ d8192 c1` | 126.52 | **128.76** | 10.66 (8.28%) | **+1.77%** | pooled → **127.64** |
| `tg32 @ d8192 c1` | 106.24 | **123.81** | 16.31 (13.18%) | **+16.54%** | ⚠ **outside band — R1 RETIRED, not pooled** |
| `pp2048 @ d8192` | 1187.51 | 1158.52 | 19.25 | −2.44% | — |
| `ctx_pp2048 @ d8192` | 6148.56 | 6101.75 | 77.66 | −0.76% | — |

Arm B runs, `tg32 @ d8192 c1`: 118.58 / 112.49 / 125.59 / 152.31 / 140.64 /
123.81 / 99.04.

### THE HEADLINE — a recorded loss was overstated by a factor of ten

`tg128 @ d131072 c1` has been carried as **0.95x, "short by 5.5%"** since R5. The
pooled 10-run median is **81.22 against 81.60 — 0.995x, short by 0.47%.** At
σ/med 10.56% the standard error on the pooled median is ~4.2%, so **the deficit
is 0.11 SE.** The cell is a dead heat and we are on the wrong side of it.

**It did not flip and it is NOT claimed as a win.** This is the same discipline
R8c applied to `ctx_tg @ d32768 c1`'s 1.002x: a figure that cannot be
distinguished from the incumbent is not a win, in either direction. The row stays
in the LOST table. What changed is that the campaign was publishing a 5.5%
deficit it did not have.

⚠ **And it should not be re-run.** 0.11 SE is not resolvable at any run budget
this campaign can afford — halving the SE needs 4x the runs, and this is the
most expensive depth on the box (784 s of grid for seven runs, ttfr 47.9 s per
request). R5's standing advice not to return to d131072 was right; this round was
the exception that audits it, not the start of a campaign there.

### The band verdicts, against the rule declared before the run

±10%, declared in the hypothesis. Three of four inside → **STAND and POOL**. One
outside → **RETIRE and REPLACE**.

- `ctx_tg @ d8192 c1` **+1.77% — STANDS**, pooled to 127.64. **The thin claim
  survived:** 1.07x over best vLLM+NVFP4 (118.07) firms to **1.08x**. The 0.61x
  loss to the cell top (207.60) was never in play and reads 0.615x.
- `tg128 @ d131072 c1` **+5.43% — STANDS**, pooled to 81.22.
- `ctx_tg128 @ d131072 c1` **+2.24% — STANDS**, pooled to 77.52. Never scraped,
  so held not claimed.
- `tg32 @ d8192 c1` **+16.54% — OUTSIDE. R1's 106.24 is RETIRED** and 123.81
  replaces it outright; the sets are **not** pooled, per the rule. This was the
  campaign's worst-sampled standings row (R1 σ/med **21.4%**, runs 73.07–128.35,
  a 1.76x spread inside one cell). **No margin moves** — the board publishes no
  figure for the cell — which is why it was third in priority and not first.

### The instrument check passed, and it is what makes Arm A trustworthy

The hypothesis named the two near-zero-σ `pp` figures as the round's cheapest
control: if either moved more than a percent, the invocation differed from R5's
and the whole arm was suspect. **`pp2048` moved +0.35% and `ctx_pp2048` +0.30%**,
both on σ of 0.01 and 1.76. Arm A reproduces R5's invocation. Arm B's `pp2048` at
−2.44% is larger but sits exactly on the campaign's known ~2% reproduction floor
(R13c's six-of-six −1.94%), and its Phase-1 partner moved −0.76%.

⚠ **A methodological correction to something I asserted mid-round.** I noted that
Arm A's `intent_id` (`55e0583fe6b308a0`) matched R5's and read it as proof the
engine configuration was reproduced exactly. **It is not proof: R1's `intent_id`
is the same value**, and R1 ran a different depth sweep. The id is a
recipe-level hash and is constant across this whole campaign. What actually
establishes the reproduction is the explicit `-o max_num_batched_tokens=8192`
restoring the pre-fold budget, the identical `base_args` apart from `runs`, the
identical pinned image (`dgx-vllm-eugr-nightly:2026082102`) and framework
(0.4.0), and the `pp` controls above.

### THE FINDING: five up, five down, and the sign is predicted by motive

This is the round's real contribution and it closes the question R8c opened.

| direction | rows | corrections |
|---|---|---|
| **Re-measured because it was a CLAIM somebody defended** | R1 `tg32@d16384`, R3 `d65536`, R13 ×2 pooled, R8c arm E `tg32@d32768` | **−10.0%, −13.0%, −2.86%, −1.30%, −5.14%** — all DOWN |
| **Re-measured because nobody had audited it** | R8c `ctx_tg32@d32768`, R21 ×4 | **+31.64%, +16.54%, +5.43%, +2.24%, +1.77%** — all UP |

**Ten re-measurements, five each way, and the sign is perfectly predicted by
whether anyone had a motive to check the row.** Sampling error is symmetric;
what is not symmetric is which errors survive in a results file. A flattering
draw becomes a claim, a claim gets defended, and defended figures get audited
back down. An unflattering draw becomes a recorded loss and sits there.

**This is ordinary regression to the mean observed from both ends at once**, and
it needs no mechanism — every extreme 3-run draw moves toward the family value
regardless of sign. The campaign's pre-R8c rule ("3-run medians always come in
high") was never a property of sampling; it was a description of its own audit
queue. R21 was designed to test that reading and it holds five for five.

**The operational rule stands and is now evidenced: treat any unrepeated figure
as wrong by ~1 SE in an unknown direction, and re-measure the unflattering rows
first — they are the ones nobody else will.**

### Predictions, scored

All three declared predictions were correct, which is unusual for this campaign.

- `tg128 @ d131072 c1` predicted **72–88, centre ~78, ~30% chance of a flip** →
  **81.32.** Inside the band, above centre, and it did not flip. Correct
  including the refusal to predict a win.
- `ctx_tg @ d8192 c1` predicted **118–135, centre ~126**, with the 1.07x claim
  put at ~35% risk of withdrawal → **128.76**, claim survived. Correct.
- `tg32 @ d8192 c1` predicted **85–125, centre ~105** → **123.81**, inside the
  band at the top. Correct, and the wide band was justified by the σ.
- The Phase-1/Phase-2 gap at d8192 predicted to **contract from +19.1% to
  +0–10%** → **+4.00%.** Correct. **d8192 was the last unaudited extreme in the
  phase-pair table**, and like d65536 (R8) and d32768 (R8c) it collapsed toward
  the family value under better sampling. At d131072 the gap read −0.61% on 3
  runs and **−3.62%** on 7. Every extreme in that table was a 3-run artefact;
  none survived.

### What was NOT done, and why — stated so it is not mistaken for an oversight

**`tg128 @ d16384` c2 (84.00) and c5 (48.12) remain on three runs and are
labelled provisional in RESULTS.md.** They were the fourth priority and were
declined deliberately: both are losses by **more than 2x**, and the largest
correction this round produced was 16.5%. Nothing in the observed range of
sampling error closes a 2x gap. Both also already have 7-run tuned successors at
raised budgets (c2 → 140.77, c5 → 128.93 and 164.27), which are what the
standings actually rest on; the 3-run figures survive only as the pre-fold
baselines those successors are measured against. **They should not be quoted as
measurements.**

### Cost ledger — R21

Two engine starts, two invocations, **crash_count 0** on both. Grid time
**784.5 s + 31 s = ~816 s**; wall including both engine starts ~28 min. Arm A is
**96% of the grid bill** — seven runs at d131072 cost 25x seven runs at d8192.
Harness tokens for the round: **~95k**.

**Value: three standings rows retired from 3-run status and one recorded margin
corrected by 10x, for ~14 minutes of grid.** Arm B in particular is the best
ratio in the campaign — **31 seconds of grid** cleared two rows, one of them the
worst-sampled figure in the standings. Arm A is defensible but expensive, and it
bought a correction rather than a cell; the honest accounting is that the
campaign paid ~13 minutes to find out it was not nearly winning d131072 after
all, which is worth knowing precisely because the old 5.5% figure was the kind
of near-miss that invites a tuning round. **It has now been priced out properly:
do not go back.**

## Round 22 hypothesis — R8c-PROTECT: the 125-entry dead heat, `ctx_tg32` / `tg32 @ d32768 c1`, runs=14, BOTH budgets

Written BEFORE the run, 2026-08-22, on `feature/thin-cell-r22`.

### WHAT THIS ROUND IS, AND THE ONE THING IT CANNOT DO

R8c re-measured `ctx_tg32 @ d32768 c1` (Phase 1) and found R1's 84.03 was a
3-run low draw: seven runs at R1's own condition read **110.61 (+31.64%)**, and
seven runs on the folded recipe read **117.65** against a **117.37** incumbent —
**1.002x**, the closest the campaign has ever come to an unclaimed win, on a
**125-entry crowded cell**. R8c deliberately did not claim it, for the right
reason: +0.24% is **0.06 SE** on a cell with σ/med 9.44%, and it was the first
and only measurement of that cell at that budget. Promoting the best first
measurement of a cell is precisely what retired R1's and R3's figures.

**So this round is the protection round R8c earned, and it is honest about its
ceiling up front. IT CANNOT RESOLVE +0.24%.** SE of a median is
≈ `1.2533σ/√n`; at σ/med 9.44% that is **3.2% at n=14** and **2.6% at n=21**
pooled. A 0.24% margin is ~0.09 SE at either. **No affordable number of runs on
this box resolves it, and I am not pretending otherwise.** R21 said the same
thing about `tg128 @ d131072 c1` at 0.11 SE and told the campaign not to go back.

**What the round CAN do, and it is worth the box time:**

1. **Distinguish 117 from 108.** The two candidate readings of this cell differ
   by ~8%, which is ~2.5 SE at n=14. That is resolvable. Either arm F's 117.65
   reproduces and the cell genuinely sits at the incumbent, or it was a high
   draw and the cell sits near the pooled 8192 figure of 107.73 — a 0.92x loss.
   **Those are different facts about the standings and the campaign currently
   does not know which one is true.**
2. **Halve the error bar on the budget effect.** R8c's Phase-1 arm F-vs-E
   **+6.36%** is **1.0 SE** — equally consistent with zero. R8c's own closing
   instruction: *"The protection round this cell needs must therefore measure
   both budgets, not just repeat arm F."* At n=14 per arm the SE on the
   difference falls from ~6.4% to ~**4.5%**, so +6.36% becomes ~1.4 SE. **Still
   not decisive, and I say so before running rather than after.**
3. **Settle whether the budget-inertness-at-c1 result holds on Phase 1**, which
   R8c reported as NOT ESTABLISHED under its own pre-declared conjunction rule.

**Why it is still the right spend:** it is the last item in the queue where box
time can change the standings, it protects a figure this file has published, and
items 2 and 3 come free from the same two invocations.

### THE PRIOR — every measurement this cell has

| condition | runs | Phase 1 `ctx_tg32` | Phase 2 `tg32` | P1 vs P2 | σ/med P1 | source |
|---|---:|---:|---:|---:|---:|---|
| mnbt 8192 | 3 | 84.03 | 115.56 | −27.3% | 15.58% | R1 |
| mnbt 8192 | 7 | 110.61 | 109.62 | +0.9% | 11.78% | R8c arm E |
| **mnbt 8192 pooled** | **10** | **107.73** | **112.59** | −4.3% | — | R1+R8c |
| **mnbt 65536** | **7** | **117.65** | **110.03** | **+6.9%** | **9.44%** | **R8c arm F** |
| all R8c | 14 | 117.06 | 109.82 | +6.6% | — | R8c |

Incumbents for `ctx_tg @ d32768 c1` (cached scrape, `docs/arena-recipe.md`, 125
entries): **117.37** — Qwen3.6-35B-A3B-NVFP4 on **Atlas**, the cell top and *the
same model we are running*; **116.65** — Nemotron-3.5-Lightning-30B-A3B-NVFP4,
the best vLLM entry.

### THE HYPOTHESIS

**H_draw (predicted): 117.65 was a high draw and the cell does not reach the
incumbent.** Arm H reproduces BELOW 117.65, the pooled 21-run mnbt-65536 median
lands below the claim threshold, and the cell stays a LOSS with a corrected
margin somewhere between 0.92x and 1.00x.

**H_real (the alternative that would change the standings): the folded budget
genuinely helps Phase 1 at this depth.** Arm H reproduces at or above 117.65,
the budget effect firms up, and the pooled figure clears the claim threshold.

**Why I predict H_draw, and it is R21's own finding turned against this round.**
R21 established that the sign of a re-measurement tracks **who is defending the
row**, not sampling: five defended claims corrected DOWN (−10.0, −13.0, −5.14,
−2.86, −1.30%), five unaudited rows corrected UP (+31.64, +16.54, +5.43, +2.24,
+1.77%). **117.65 has crossed over.** When R8c measured it, it was an unaudited
row and it came in high. It is now the number this file's header calls "the
single most likely place for the standings to change" — a defended figure, and
the class that corrects downward. R13c's independent measurement of the same
thing (six first-measurements, mean −1.94%, six of six the same sign) points the
same way.

**Mechanism, or rather the absence of one.** There is no mechanism on offer for
a budget effect at c1 and that is the point. The two routes by which
`max_num_batched_tokens` has ever moved a number in this campaign are
**occupancy** and **batch span**, and both are absent at c1: residency is 1 of 1
at every budget (R8c arm E, 9 of 9 samples) and `tg == tg_req` exactly, so the
span is **1.0000 by assignment**. R11 measured the budget inert at c1 at d16384
(+0.27%) and R8c reproduced that on Phase 2 at d32768 (+0.37%) — two independent
measurements agreeing to a tenth of a percent. **A +6.36% Phase-1 effect at the
same concurrency, on the same flag, with both of its known mechanisms switched
off, is far more likely to be the 1.0-SE draw it is priced at than a real effect
nothing can explain.** I predict it shrinks.

### THE CONFIGURATION, AND THE ONE THING I CHANGED FROM R8c's DESIGN

`pp 2048`, `depth 32768`, `tg 32`, `concurrency 1`, **`runs 14`**.
`-o max_model_len=40960` in **both** arms — 32768 + 2048 + 32 = 34848 does not
fit the recipe's 32768 window. Probe-driven override, exactly as R1/R3/R5/R8/R8c
treated theirs; **not a tuning mutation**. `max_num_seqs` stays at the recipe's
4 in both arms: at c1 scheduler width does nothing.

- **Arm G (`-o max_num_batched_tokens=8192`)** — the pre-fold budget.
- **Arm H (recipe as shipped, `mnbt 65536`)** — the current epoch, and the arm
  the claim question is read from.

**`runs=14`, not 7, and only at this cell.** QUEUE.md suggested runs=14 at the
65536 arm; I am taking it at **both**, because the budget comparison is the
round's second deliverable and its SE is set by the *noisier* arm, so buying
runs on one side only wastes most of the purchase. The price is ~230 s of extra
grid, against ~330 s of engine starts I have to pay regardless. **Contingency:
if the `Benchmark args:` echo does not read `runs: 14`, I abort before the grid
and fall back to two runs=7 invocations per arm, pooled** — which is what R13c
and R21 did and is a worse but acceptable design.

**⚠ THE ONE DESIGN CHANGE FROM R8c, AND IT IS DELIBERATE: I RUN THE ARMS IN THE
REVERSE ORDER.** R8c ran E (8192) then F (65536) and read +6.36%. R22 runs **H
(65536) first, then G (8192)**. The two arms cannot share an engine start — two
budgets never can — so the arm-to-arm comparison is unavoidably cross-invocation
and exposed to R9c's measured **±2.5% reproduction floor**. Reversing the order
costs nothing and buys one real thing: **if R22 reproduces the same sign with
the order flipped, thermal drift and start-order cannot be the explanation.** If
instead the sign flips with the order, that is itself the finding, and a cheap
one. R8c named this weakness and could not address it; this addresses it.

The primary protection readings are **intra-invocation** — each arm produces its
own Phase 1 and Phase 2 under one engine start — and are not exposed to the
floor.

### NUMERIC PREDICTIONS, DECLARED BEFORE THE RUN

**PRIMARY — protection on arm F's figure. Band ±10% (R13c's protection band).**

| row | R8c figure | STANDS if | predicted | why |
|---|---:|---|---:|---|
| `ctx_tg32 @ d32768 c1` **mnbt 65536** (arm H) | 117.65 | **105.9 – 129.4** | **112, band 103 – 122** | R21's defended-row rule + R13c's −1.94% first-measurement bias, applied to a figure that is now defended |
| `tg32 @ d32768 c1` **mnbt 65536** (arm H) | 110.03 | **99.0 – 121.0** | **110, band 96 – 124** | no reason to move; the wide band is σ/med 24.20%, the campaign's noisiest cell |
| `ctx_tg32 @ d32768 c1` **mnbt 8192** (arm G) | 110.61 (arm E) / 107.73 (pooled 10) | **99.6 – 121.7** | **109, band 100 – 118** | two prior measurements bracket it; predict near the pooled figure |
| `tg32 @ d32768 c1` **mnbt 8192** (arm G) | 109.62 (arm E) / 112.59 (pooled 10) | **98.7 – 120.6** | **111, band 97 – 125** | same |

**THE CLAIM RULE, DECLARED IN ADVANCE SO IT CANNOT BE MOVED AFTERWARDS.**
`ctx_tg @ d32768 c1` is claimed as a **WIN** only if the **pooled mnbt-65536
median over all 21 runs** (R8c arm F's 7 + R22 arm H's 14) exceeds **117.37** by
**more than 1 SE of that pooled median**. At σ/med ~9.4% that threshold is
**≈ 120.4**. Anything below it is recorded as a corrected margin on a **LOSS**,
however close. **Predicted: the threshold is not met.** I would rather pre-commit
to a bar this round probably fails than write the bar after seeing the number.

**SECONDARY — the budget effect on Phase 1 (arm H vs arm G).**
Currently +6.36% at 1.0 SE. **Predicted +2%, band −5% to +10%.**
- |Δ| < 5% → **INERT**, and R11's inertness result extends to Phase 1.
- |Δ| ≥ 5% with the same sign as R8c's → **the effect firms**; report as
  established-with-caveat and note it is the third arm-to-arm reading.
- Sign flips → the +6.36% was order or draw; report as refuted.
- **I keep R8c's and R11's conjunction rule: if Phase 2 is inert and Phase 1 is
  not, or vice versa, the inertness reading is NOT ESTABLISHED whatever the band
  says.** Phase 2 predicted **|Δ| < 2.5%** (it read +0.37% at R8c and +0.27% at
  R11 at d16384).

**FREE RIDERS — zero box cost, recorded either way:**

| quantity | predicted | why it is worth recording |
|---|---|---|
| MTP acceptance @ d32768 c1 | **length 3.55 – 3.75, acceptance 85 – 91%** | third and fourth independent samples at this depth; R8c read 87.0%/3.61 and 88.9%/3.67 at two starts |
| `ctx_pp / pp` | **16.6 – 18.1** (theory **17.00**) | audit pairs **45 and 46**; stands at 43 of 44 |
| prefix cache hit rate | **0.0%** | past 180 consecutive samples with no hit ever |
| scheduler `Running/Waiting` | **`(1,0)` in loaded samples** | ⚠ **R8c's arm F sample was EMPTY** — 11 of 11 lines read `Running: 0`, the sampler catching only gaps between runs. runs=14 doubles the loaded window; if it is empty again, record it as a repeat instrument failure and stop claiming residency at c1 from this instrument |
| span ratio `tg / tg_req` | **exactly 1.0000, all four phase-arms** | assignment, not measurement. Anything else voids the round |
| σ/med | **6 – 25%** | this cell holds the campaign record (24.20%, arm F Phase 2); σ is itself a draw |
| SM clock median | **2392 – 2398 MHz** | twentieth agreeing session |
| power max | **≤ 99.5 W** | R8c set a new campaign bound at 99.49 W |
| grid time | **210 – 260 s per arm** | R8c's 7-run arms cost 117.6 s and 110.9 s |

### WHAT WOULD MAKE THIS ROUND VOID

- `crash_count > 0` or `session_count > 1` in either arm — each arm is one start.
- The `Benchmark args:` echo not reading `pp: [2048]`, `depth: [32768]`,
  `tg: [32]`, `concurrency: [1]`, `runs: 14`. **`sparkrun` silently defaults an
  omitted `-b depth` to 0 and does not error** — R5 lost a start to it. **Read
  the echo in both arms before letting the grid proceed.**
- `tg_throughput != tg_req_throughput` at c1.
- `ctx_pp / pp` outside 15 – 19.
- A container image other than `dgx-vllm-eugr-nightly:2026082102` in either
  `state.yaml` — read `container_image_longterm_ref`, not the `:latest` console
  line.

### INSTRUMENT PLAN

Engine log per R13d's recipe: `docker exec <container> tail -f
/tmp/sparkrun_serve.log`, container matched on **`^sparkrun_`** (it is named
`sparkrun_<hash>_<hash>_solo`, **not** `vllm-*`), verified non-empty **during**
the engine start. `docker logs -f` does not work on this image. Telemetry
alongside each arm.

### COST

Two invocations, two engine starts, ~460 s grid + ~330 s starts, **~14 min wall**
estimated. Against that: protection on the campaign's closest unclaimed cell, a
halved error bar on the budget effect, the Phase-1 inertness question R8c left
open, an order-reversal control R8c could not run, and two more acceptance
points.

### ABSOLUTELY NO ARENA SUBMISSION

No `--arena` flag, in either arm. There is no login and none will be attempted.

## Round 22 outcome — bench_bb4b8ef8a193-r22-armH + bench_8707c27ce1a4-r22-armG (2026-08-22)

`ctx_tg32` / `tg32 @ d32768 c1`, **runs=14**, TWO budget arms, ONE engine start
each (`session_count: 1`, `crash_count: 0` in both). Image
`dgx-vllm-eugr-nightly:2026082102` — the same epoch as all sixteen prior rounds.
`-o max_model_len=40960` in both, `-o max_num_batched_tokens=8192` in arm G only.
**Arm H (mnbt 65536) ran FIRST and arm G (mnbt 8192) SECOND — the reverse of
R8c's order, as the hypothesis declared.** Every void condition passed: the args
echo read `runs: 14` in both arms, `tg == tg_req` exactly in all four phase-arms
(span **1.0000**), and `ctx_pp / pp` read 17.50 and 17.45.

### THE CELL IS NOT CLAIMED. THE 1.002x DEAD HEAT WAS A HIGH DRAW.

The claim rule was declared before the run: **the pooled mnbt-65536 median over
all 21 runs must exceed 117.37 by more than 1 SE.**

| measurement | Phase 1 `ctx_tg32` | vs 117.37 (Atlas) | vs 116.65 (best vLLM) |
|---|---:|---:|---:|
| R8c arm F, 7 runs, mnbt 65536 | 117.65 | 1.002x | 1.009x |
| **R22 arm H, 14 runs, mnbt 65536** | **109.41** | **0.932x** | 0.938x |
| **POOLED mnbt 65536, 21 runs** | **113.37** | **0.966x** | 0.972x |
| R22 arm G, 14 runs, mnbt 8192 | 122.80 | 1.046x | 1.053x |
| **POOLED mnbt 8192, 24 runs** (R1 3 + R8c E 7 + R22 G 14) | **115.86** | **0.987x** | 0.993x |

Pooled 65536 = **113.37**; 1 SE = **2.69%**; threshold **120.53**. **NOT MET, and
not close — the pooled figure is 6.1% below the bar.** `ctx_tg @ d32768 c1`
**remains a LOSS** and the counts stay **8 won / 12 lost**.

**H_draw is confirmed and the prediction was right on the number.** The
hypothesis predicted arm H at **112, band 103–122**, on the reasoning that 117.65
had crossed from an unaudited row into a *defended* one and R21's rule says
defended rows correct downward. It read **109.41, −7.00%** — inside the predicted
band, and the direction was called in advance. **R8c's 117.65 was the best single
measurement of a cell measured once, and it behaved exactly as R13c's rule says
such figures behave.** R8c was right not to claim it.

⚠ **Note what would have happened without the pre-declared rule.** Arm G's
single 14-run median at mnbt 8192 is **122.80 = 1.046x**, comfortably above the
incumbent, and it is the largest sample ever taken at this cell. **It is not
claimed either**, for the same reason and by the same rule: it is one arm at one
position in one session, the pooled 24-run figure at that budget is **115.86 =
0.987x**, and promoting the best arm of a round is the error this round exists to
avoid repeating. **A rule that only binds when it is convenient is not a rule.**

**The honest summary of the cell after 45 runs across four engine starts: it is a
loss of between 1.3% and 3.4% depending on budget, i.e. another dead heat we are
on the wrong side of.** That is a real correction to the carried 0.72x and a real
correction to the 1.002x, in opposite directions, and the cell now has the
campaign's largest sample. **Do not go back**: 0.987x is **0.34 SE** on the
24-run pooled figure, which is the same unresolvable position R21 priced out at
`tg128 @ d131072 c1`.

### THE ROUND'S REAL FINDING, AND IT IS NOT THE ONE IT WAS QUEUED FOR: THE ARM-TO-ARM COMPARISON HAS A POSITION BIAS, AND R8c's BUDGET EFFECT WAS IT

The order-reversal control was put in to rule out one nuisance variable. **It
did not rule it out — it found it.**

| round | arm order | Phase 1 | Phase 2 |
|---|---|---:|---:|
| R8c | E (8192) **first** → F (65536) **second** | +6.36% | +0.37% |
| R22 | H (65536) **first** → G (8192) **second** | **+12.24%** | **+6.89%** |

**Read the header row, not the budgets. In four comparisons out of four, across
two rounds and four engine starts, the arm that ran SECOND read higher** —
+6.36, +0.37, +12.24, +6.89, mean **+6.5%**. The budgets are swapped between the
two rounds, so a budget effect cannot produce this pattern; a position effect
produces exactly it.

**Consequently R8c's "+6.36% on Phase 1" is refuted as a budget effect.** R8c
reported it as NOT ESTABLISHED under its own conjunction rule and instructed
that the protection round measure both budgets. It did, and the answer is that
the quantity R8c measured was not the one it named.

**THE BUDGET, MEASURED WITH POSITION CONTROLLED, IS INERT — ON BOTH PHASES.**
Comparing like position against like position:

| contrast | Phase 1 | Phase 2 | reading |
|---|---:|---:|---|
| **first arm vs first arm** (R8c E 8192 vs R22 H 65536) | **−1.08%** | **+0.86%** | **INERT**, both under 1.1% |
| second arm vs second arm (R22 G 8192 vs R8c F 65536) | −4.19% | −6.89% | less clean; the preceding arm differs |

**The first-vs-first contrast is the one to read** — both arms are the leading
invocation of a fresh session, so the warm-up state is matched — and it is
**inert on both phases at under 1.1%**, satisfying the conjunction rule R11 and
R8c both declared. **No contrast anywhere shows the folded budget helping.**

So the structural argument the hypothesis made in advance holds after all: the
two routes by which `max_num_batched_tokens` has ever moved a number are
**occupancy** and **batch span**, and both are switched off at c1 — residency is
`(1,0)` (19 of 19 loaded samples this round, both budgets) and the span is
**1.0000 by assignment**. **`max_num_batched_tokens` is inert at c1 at d16384
(R11, +0.27%) and at d32768 on both phases (this round). That question is now
closed and Phase 1's exception is withdrawn.**

**⚠ WHAT IS NOT ESTABLISHED, said plainly.** The position effect itself rests on
**four comparisons from two sessions**, and the two phases within a session are
not independent. Treated as two independent sessions it is 2 of 2 in the same
direction — **p = 0.25 on a sign test, which establishes nothing.** It is a
strong suggestion with a clean mechanism-shaped signature, not a result. **It is
also NOT a clock effect:** mean SM clock was **2395.7 MHz** in arm H and
**2395.4 MHz** in arm G — identical to 0.01% — so whatever the second arm gets,
it is not more clock. Nor is thermal drift a candidate in the obvious direction:
the second arm ran on a *warmer* box (~1 minute after the first stopped) and was
*faster*, which is the opposite of what throttling predicts.

**The discriminating experiment, and it is cheap: an A-B-B-A within one session.**
Four invocations, same probe, budgets 8192 / 65536 / 65536 / 8192. If position
is real, arms 3 and 4 read above arms 1 and 2 regardless of budget; if the
budget matters, arms 2 and 3 separate from 1 and 4. ~25 min. **Queued.**

**Why this matters beyond this cell.** Every budget curve this campaign has
measured across separate engine starts — R13c's six-point curve above all — is
built from invocations run in sequence, and none of them controlled position.
**The knee at 65536 is not in danger**: it rests on a +233% effect and a 6.5%
position bias cannot manufacture that. But **any arm-to-arm reading in this
campaign at or below ~7% is now suspect**, and that includes several the
campaign has published as small effects. R9c's ±2.5% "reproduction floor" looks
like an underestimate for first-versus-later position.

### PROTECTION: THREE OF FOUR ROWS STAND, AND THE ONE THAT FAILS FAILS UPWARD

Band declared in advance at ±10%:

| row | prior | **R22** | change | band | verdict | predicted |
|---|---:|---:|---:|---|---|---:|
| `ctx_tg32 @ d32768 c1`, mnbt 65536 | 117.65 (F) | **109.41** | **−7.00%** | 105.9–129.4 | **STANDS** | 112 (103–122) ✅ |
| `tg32 @ d32768 c1`, mnbt 65536 | 110.03 (F) | **110.56** | **+0.48%** | 99.0–121.0 | **STANDS** | 110 (96–124) ✅ |
| `tg32 @ d32768 c1`, mnbt 8192 | 109.62 (E) | **118.17** | **+7.80%** | 98.7–120.6 | **STANDS** | 111 (97–125) ✅ |
| `ctx_tg32 @ d32768 c1`, mnbt 8192 | 110.61 (E) | **122.80** | **+11.02%** | 99.5–121.7 | ⚠ **FAILS — high, by 1.1 points** | 109 (100–118) ❌ |

**The one failure is recorded, not rounded away.** +11.02% clears the ±10% band
by 1.02 percentage points. Per the campaign's convention a band failure means the
figures are **not pooled and the old one is replaced** — but that convention was
written for cases where the new measurement is the better-controlled one, and
here it is not: **arm G is a second-position arm and the failure is the same
sign and roughly the same size as the position bias measured above.** Recording
it as "R8c's 110.61 is retired and the cell is 122.80" would be laundering a
suspected artefact into a standings figure.

**So the resolution, stated as a judgement rather than a rule application: the
figures ARE pooled**, to a 24-run median of **115.86**, and the band failure is
recorded here and in `RESULTS.md` as a failure with its confound named. This is
the one place in the round where I have departed from a pre-declared procedure,
and I would rather flag that than bury it. The three other rows stand cleanly and
none of them needed the exception.

**THE PHASE-2 POOLED FIGURES THE ROUND ALSO PRODUCED, recorded here because they
had only ever been written into `RESULTS.md`.** Both Phase-2 arms stood inside
their bands, so both pool, and `tg32 @ d32768 c1` — a WIN — moves at both
budgets. Recomputed from the archived per-run values in
`experiments/*/consolidated.json`:

| row | pooled runs | median | vs 23.31 | σ/med | median SE |
|---|---:|---:|---:|---:|---:|
| `tg32 @ d32768 c1`, **mnbt 8192** (R1 3 + R8c E 7 + R22 G 14) | **24** | **115.85** | **4.97x** | 13.51% | 3.46% |
| `tg32 @ d32768 c1`, **mnbt 65536** (R8c F 7 + R22 H 14) | **21** | **110.16** | **4.72x** | 16.29% | 4.45% |

⚠ **This retires the pooled 10-run 112.59 = 4.83x that the standings summary
above and the R8c block below still quote in places.** The 24-run figure is the
campaign's largest sample at any cell. The margin widened; **no cell changed
side and the counts stay 8 won / 12 lost.**

### THE −27% INVERSION STAYS RETIRED — now on five intra-invocation readings

Phase 1 versus Phase 2 at this cell, measured *within* single engine starts and
therefore immune to the position bias:

| arm | runs | budget | P1 vs P2 |
|---|---:|---|---:|
| R1 | 3 | 8192 | **−27.28%** |
| R8c arm E | 7 | 8192 | +0.90% |
| R8c arm F | 7 | 65536 | +6.93% |
| **R22 arm G** | **14** | 8192 | **+3.91%** |
| **R22 arm H** | **14** | 65536 | **−1.04%** |

The four well-sampled readings span **−1.04% to +6.93%**, a 8-point range around
zero; R1's −27.28% sits 30 points outside all of them. **R8c's retirement of the
last deep `ctx_` inversion is confirmed on twice the sample, at both budgets.**
No mechanism was needed and none is offered.

### FREE RIDERS — every prediction landed, and one instrument recovered

**1. MTP acceptance @ d32768 c1 — now FOUR independent engine starts.**

| arm | acceptance length | acceptance rate | samples |
|---|---:|---:|---:|
| R8c arm E (8192) | 3.61 | 87.0% | 12 |
| R8c arm F (65536) | 3.67 | 88.9% | 11 |
| **R22 arm H (65536)** | **3.56** | **85.4%** | **21** |
| **R22 arm G (8192)** | **3.71** | **90.2%** | **21** |

Predicted **3.55–3.75 and 85–91%**; both arms inside both bands. Four starts
across two budgets span **3.56–3.71** and **85.4–90.2%** — the campaign's
best-reproduced quantity at this depth, and **the budget does not move it**
(the spread within a budget is as large as between budgets). The d16384 → d32768
→ d131072 shape (93.6% → ~88% → 47.7%) is unchanged; ⚠ **open question 3 is
still NOT closed** — the endpoints remain R5's, taken at other conditions, and
R8b's two-depths-one-start design is still the measurement that settles it.

**2. Phase-label audit, pairs 45 and 46.** `ctx_pp / pp` reads **17.499** (arm H)
and **17.450** (arm G) against the zero-free-parameter prediction
`(32768+2048)/2048 = 17.00` — residuals **+2.93%** and **+2.65%**, inside the
audit range. **The audit stands at 45 of 46**, and the ratio is again unmoved by
an 8x budget change, which is what a denominator artefact must do.

**3. Prefix caching still never hits.** `Prefix cache hit rate: 0.0%` in **21 of
21** samples in each arm — **42 more consecutive zero-hit samples, taking the
campaign past 220 with no hit ever recorded.**

**4. ⚠ THE RESIDENCY INSTRUMENT RECOVERED — R8c's arm F failure was cadence
luck, not a broken instrument.** Arm G caught `Running: 1, Waiting: 0` in **16 of
21** samples and arm H in **3 of 21**; the other samples are the idle gaps
between runs. **19 loaded samples across both arms, 19 of them `(1,0)`, zero
`Waiting` ever.** R8c could not carry the residency claim at mnbt 65536 because
arm F's sample was empty; this round carries it at **both** budgets. Doubling
runs from 7 to 14 is what bought it, and that is a reusable lesson: **at c1 the
loaded window is narrow against the log's ~10 s cadence, so residency claims at
c1 need runs=14, not runs=7.**

**5. Telemetry — the twentieth and twenty-first agreeing sessions, and a new
power maximum.** SM clock median **2398 MHz** in both arms (738 samples;
arm H min 2294 / max 2411, arm G min 2366 / max 2411) against the reported 3003
MHz ceiling. Temperature max **75 °C** in both — the same value R8c recorded.
⚠ **Power max 100.47 W (arm H) — a new campaign maximum and the first reading
over 100 W.** R8c set the previous bound at 99.49 W and the observation section
must be corrected again. As before the clock did not move with it.

### σ — THE CAMPAIGN'S NOISIEST-CELL RECORD WAS ITSELF A DRAW

| measurement | σ/med Phase 1 | σ/med Phase 2 |
|---|---:|---:|
| R1, 3 runs, 8192 | 15.58% | 11.03% |
| R8c arm E, 7 runs, 8192 | 11.78% | 15.82% |
| R8c arm F, 7 runs, 65536 | 9.45% | **24.20%** ← the campaign record |
| **R22 arm H, 14 runs, 65536** | **8.92%** | **11.39%** |
| **R22 arm G, 14 runs, 8192** | **12.40%** | **13.35%** |

**Arm F's 24.20% — which this campaign recorded as "the noisiest cell it has ever
measured" — re-measures at 11.39% at the identical configuration.** That is
**retired claim 19 (σ is itself a draw) at full strength**, and it is a sharper
demonstration than R8c's own: a σ estimate from 7 runs moved by more than a
factor of two at the same config. **σ/med figures quoted from 7 runs should be
treated as having roughly ±50% of themselves as uncertainty**, and this file's
habit of naming "the noisiest cell in the campaign" from a single arm should
stop. Arm H's 8.92% is the tightest reading this cell has produced.

The practical consequence for run budgets is unchanged and now better founded:
at ~10–13% σ/med, **runs=14 buys SE ≈ 3.0–4.5% and runs=7 buys 4.5–7.5%.** The
0.24% margin this round was queued to resolve was never reachable, which the
hypothesis said before the run rather than after.

### WHAT IS NOT CLAIMED

- **No standings side changes. Counts stay 8 won / 12 lost.**
  `ctx_tg @ d32768 c1` is still a **LOSS** (0.987x pooled at mnbt 8192, 0.966x
  pooled at mnbt 65536) and `tg32 @ d32768 c1` is still a **WIN**.
- **The 1.002x dead heat is RETIRED**, and arm G's 1.046x is **not** promoted in
  its place. Neither single arm is a claim.
- **The position effect is NOT established** — four comparisons, two sessions,
  p = 0.25 on a sign test. It is queued for the A-B-B-A round that would settle
  it, and it is stated as a suspicion everywhere it is used.
- **Open question 3 is not closed.** Four acceptance points at d32768 do not fix
  the two endpoints, which were taken at other conditions.
- **The knee at 65536 is not disturbed.** A ~6.5% position bias cannot account
  for a +233% effect. Only sub-7% arm-to-arm readings are put in doubt.
- **Nothing was submitted to the arena.** No `--arena` flag in either arm; there
  is no login and none was attempted.
- **`recipe.yaml` is untouched.** No mutation was proposed. `max_model_len
  40960` is the probe-driven override R1/R3/R5/R8/R8c all used at this depth.

### COST

Two invocations, two engine starts, **zero crashes, zero wasted starts**.
Grid **205.2 s** (arm H) + **211.4 s** (arm G) = **416.6 s**; engine starts 155 s
and 114 s. **~12.5 minutes of box wall clock** (16:03:56 → 16:16:24 UTC),
~105k harness tokens.

Bought: the campaign's closest unclaimed cell settled as a loss on a 45-run
sample and a pre-declared rule honoured when it cost something; R8c's Phase-1
budget effect refuted and **`max_num_batched_tokens` inertness at c1 closed on
both phases**; **a position bias in cross-invocation arm comparisons discovered**
— which is a methodology finding worth more than the cell was; the deep inversion
retirement confirmed at double the sample; the residency instrument recovered at
c1; two more acceptance points; audit pairs 45–46; 42 more zero-hit cache
samples; and the campaign's noisiest-cell record shown to be a sampling draw.

**The ratio is the best since R8c, and for the same reason: the round was
designed so that its cheapest control — reversing the arm order, which cost
nothing — could return more than its headline.** It did.

## Round 23 hypothesis — the A-B-B-A position-bias round: `tg128 @ d16384 c1`, four arms, one session, runs=7 each

Written BEFORE the run, 2026-08-22, on `feature/thin-cell-r23`. This is *what to
run next* item 10, the highest-value item in the queue after R22.

### WHY THIS ROUND EXISTS

R22's free order-reversal control found that **in 4 arm-to-arm comparisons of 4,
across two rounds and four engine starts, the arm that ran SECOND read higher**
(+6.36, +0.37, +12.24, +6.89%, mean **+6.5%**). The budgets were swapped between
the two rounds, so no budget effect produces that pattern; a position effect
produces exactly it. ⚠ **It is NOT established** — 4 comparisons from 2 sessions
is **p = 0.25** on a sign test. It is **not a clock effect** (2395.7 vs 2395.4
MHz) and **not thermal drift in the obvious direction** (the second arm ran on a
warmer box and was *faster*).

Until it is tested, **every arm-to-arm comparison in this campaign at or below
~7% is unresolved**, including R13c's six-point `max_num_batched_tokens` curve —
and including the +0.27% anchor reading that licensed R11 to fold
`max_num_batched_tokens: 65536` into `recipe.yaml`. **This round decides whether
that fold rests on a real measurement or on an ordering artefact.**

### THE DESIGN, AND WHY A-B-B-A

Cell: **`tg128 @ d16384 c1`** — R11's fold anchor, the one cell where the fold
question actually lives. `max_num_seqs 4` (the recipe's own value) throughout; at
c1 scheduler width does nothing. `runs=7` per arm. **Four invocations in ONE
sitting, four engine starts, run strictly in this order:**

| arm | position | budget | override |
|---|---:|---|---|
| **arm1 A** | 1 | `mnbt 8192` | `-o max_num_batched_tokens=8192` |
| **arm2 B** | 2 | `mnbt 65536` | `-o max_num_batched_tokens=65536` (= the shipped default) |
| **arm3 B** | 3 | `mnbt 65536` | same |
| **arm4 A** | 4 | `mnbt 8192` | `-o max_num_batched_tokens=8192` |

A-B-B-A cancels **linear** position drift: A occupies positions 1 and 4 (mean
2.5), B occupies 2 and 3 (mean 2.5). Therefore:

- **The CONFIGURATION effect is drift-free:** `C` = (pooled 14-run median of
  arms 2+3) vs (pooled 14-run median of arms 1+4). Any linear drift term cancels
  exactly; a step ("first arm is cold") term cancels only partially and is
  measured separately below.
- **The POSITION effect is measured directly and independently**, by two
  same-configuration pairs: `P3` = arm4 − arm1 (separation **3** positions) and
  `P1` = arm3 − arm2 (separation **1** position). Neither contains a budget term
  by construction.

The two readings are orthogonal. That is the whole point of the design and it is
why this round can answer both questions from four invocations.

**The two rival position models make different predictions, and the design
separates them too:**

- **Linear drift**, `d` per position: `P3 ≈ 3d`, `P1 ≈ 1d`. R22/R8c's four
  comparisons were all **adjacent** (separation 1), so `d ≈ +6.5%` → predicts
  `P3 ≈ +19.5%`, `P1 ≈ +6.5%`.
- **Step / warm-up**, only the first arm of a session is cold: `P3 ≈ +6.5%`,
  `P1 ≈ 0`.
- **No position effect:** `P3 ≈ 0`, `P1 ≈ 0`, both inside noise.

### THE ERROR BAR, PRICED BEFORE THE THRESHOLDS ARE SET

`tg128 @ d16384 c1` has read σ/med **2.6% / 5.5% / 8.01%** across three engine
starts (R6, R8, R11 — and R11 explicitly retired R6's "runs=3 is adequate here"
rule). Take σ/med ≈ **5.5%**. SE of a 7-run median ≈ `1.253σ/√7` = **2.6%**. The
SE of a *difference* of two independent 7-run medians is ≈ `√2 × 2.6%` =
**≈ 3.7%**. So ±2 SE on `P3` or `P1` is **≈ ±7.4%**, and a 6% reading is ~1.6 SE.
**I am stating in advance that a single 7-run-per-arm round cannot establish a
6.5% effect at 2 SE.** What it can do is distinguish "≈ +6.5% or bigger" from
"≈ 0", which is the question that actually matters, and it is the same
resolution R22 had when it found the thing.

### THRESHOLDS, DECLARED BEFORE THE RUN SO THEY CANNOT BE MOVED AFTERWARDS

**POSITION — read `P3` = arm4 − arm1 as PRIMARY** (3 positions of separation, so
it carries the largest signal under either position model).

| reading of `P3` | verdict |
|---|---|
| **`P3` ≥ +6.0%** | **POSITION EFFECT CONFIRMED.** ≈1.6 SE, and it is the minimum either position model predicts at separation 3. The ~7% suspicion band on every small cross-invocation delta in this campaign becomes a standing caveat |
| **+2.0% < `P3` < +6.0%** | **DEAD ZONE — not resolved.** Explicitly declared as a dead zone: this round does not have the power to call it. The caveat stays attached and stays labelled unestablished |
| **`P3` ≤ +2.0%** (including any negative value) | **POSITION EFFECT REFUTED at this cell.** R22's pattern does not reproduce under a design built to catch it; the campaign's small-delta arithmetic is restored to R9c's ±2.5% reproduction floor. A value ≤ −2.0% is reported additionally as **sign-flipped** |

**`P1` = arm3 − arm2 is the SECONDARY reading and the model discriminator**, on
the same three bands (≥ +6.0% confirmed / +2.0–6.0% dead zone / ≤ +2.0%
refuted). Its job is to say *which* position model, not *whether*:

- `P3` confirmed **and** `P1` confirmed → **linear drift**, and `P3 ≈ 3 × P1`
  is the check.
- `P3` confirmed **and** `P1` refuted → **step / warm-up**: only the first arm
  of a session is cold. This is the cheaper thing to defend against in future
  rounds (throw away or duplicate the first arm) and I flag now that it is the
  outcome I consider most likely.
- `P3` refuted **and** `P1` confirmed → incoherent; the round is reported as
  **inconclusive with an internal contradiction**, not as a confirmation.

**CONFIGURATION — the drift-free budget effect, and what R11's fold needs.**
`C` = pooled-14 median(arms 2,3) ÷ pooled-14 median(arms 1,4) − 1. R11 declared
a **±5%** fold band at this exact cell and measured **+0.27%**; I keep R11's own
band so the two are directly comparable.

| reading of `C` | verdict on R11's fold |
|---|---|
| **\|`C`\| < 5%** | **R11's fold STANDS.** "Budget is inert at c1" survives a design that cannot be fooled by ordering, and `recipe.yaml` is untouched |
| **`C` ≥ +5%** | **R11's fold FALLS as reasoned** — the budget is *not* inert at c1, it is a genuine c1 lever. The recipe keeps 65536 (the right value for the wrong reason) but every `c1` figure in `RESULTS.md` is re-anchored and the fold's licence is withdrawn |
| **`C` ≤ −5%** | **R11's fold FALLS and the value is wrong.** The folded budget costs throughput at c1; recommend reverting `recipe.yaml` to 8192 and re-measuring. This is the outcome that would cost the most, which is why it is written down first |

⚠ **This round does not change `recipe.yaml` under any outcome.** A fold and an
unfold are both single-mutation decisions that deserve their own round; R23
reports, it does not tune.

### NUMERIC PREDICTIONS

- **Every arm 100 – 125**, centre ≈ **112** (the cell's anchor is 112.62 pre-fold
  / 112.92 folded; the pooled 14-run pre-fold row is 112.62).
- **`C` = +0.3%, band −4% to +4%.** I predict R11's fold **STANDS**. The reason
  is mechanism, not deference: the two routes by which
  `max_num_batched_tokens` has ever moved a number in this campaign are
  **occupancy** and **batch span**, and both are switched off at c1 — residency
  is 1 of 1 at every budget, and `tg == tg_req` by assignment so the span is
  1.0000. There is no third route on offer.
- **`P3` = +5%, band −2% to +14%.** I predict the **dead zone or a confirmation,
  leaning confirmation**, and I record now that predicting a dead zone is not a
  hedge — it is what a 3.7% SE buys against a 6.5% effect.
- **`P1` = +1%, band −6% to +8%** — i.e. I predict the **step model**, on R22's
  own evidence: its largest gaps (+12.24%, +6.89%) were both *first*-arm-to-
  second-arm, and R8c's within-round second comparison was +0.37%, near zero.

### THE SECOND DELIVERABLE — the row nobody has measured

`tg128 @ d16384 c4` at **`mnbt 65536 + mns 4`**, runs=7, ONE extra invocation,
run after the four A-B-B-A arms.

**Why it is worth an engine start.** R11 folded `mnbt 65536` into `recipe.yaml`,
but **every `c4` headline row in `RESULTS.md` was measured at `mns 5`**, which
the recipe does not ship. The synthesis says so in as many words: *"`mnbt 65536 +
mns 4` has never been measured and no row should be quoted as what the recipe
produces until it is."* So no row in the file states what the shipped recipe
actually produces at the campaign's only contested win. This closes that gap.

Verified against `recipe.yaml` rather than assumed: its `defaults` read
`max_num_batched_tokens: 65536` and `max_num_seqs: 4`, so **this arm needs no
`-o` override at all** — it is `./recipe.yaml` exactly as shipped.

- **Predicted 150 – 180, centre 165.** The neighbours are `mnbt 65536 + mns 5` =
  **173.34** (the knee) and `mnbt 32768 + mns 16` = 147.25; width 4→5 was worth
  ≤2.9% on three prior measurements, so I expect it just below the knee row.
- ⚠ **`c4` metric discipline: `tg_throughput` is a BATCH AGGREGATE**
  (`sum(decode tokens) / (max_last_token − min_first_token)`). It is NEVER
  multiplied by concurrency. `peak_throughput` is quoted beside it, never
  without it, and `tg_req_throughput` is the separate per-request figure.
- This arm is **position 5** in the session. Its own figure is therefore exposed
  to whatever `P3`/`P1` find, and that caveat travels with the row.

### WHAT WOULD MAKE THIS ROUND VOID

- `crash_count > 0` or `session_count > 1` in **any** arm — each arm is one
  engine start and the position count depends on it.
- The `Benchmark args:` echo not reading `pp: [2048]`, `depth: [16384]`,
  `tg: [128]`, `concurrency: [1]`, `runs: 7`, and `concurrency: [4]` on the
  fifth arm. **`sparkrun` silently defaults an omitted `-b depth` to 0 and does
  not error** — R5 lost a start to it. Read the echo in every arm.
- `tg_throughput != tg_req_throughput` at c1 (assignment, not measurement).
- A container image other than `dgx-vllm-eugr-nightly:2026082102` in any
  `state.yaml` — read `container_image_longterm_ref`, not the `:latest` line.
- **Any arm run out of order, or any arm re-run.** The order IS the experiment.
  A crashed arm cannot be retried in place; the round would restart.

### INSTRUMENT PLAN — the thermal check, recorded not assumed

⚠ **`nvidia-smi --query-gpu=clocks.sm,clocks.mem,temperature.gpu,power.draw`
is sampled immediately BEFORE each arm and immediately AFTER it**, and both are
written into the outcome block per arm. R22 could rule out a clock explanation
only because it had the numbers; this round must be able to rule out or in a
**thermal** explanation the same way, and the box starts cold (39 °C, 10.47 W,
2398 MHz idle, verified before arm1). Telemetry alongside via
`sample-telemetry.sh`. Engine log per R13d's recipe: `docker exec <container>
tail -f /tmp/sparkrun_serve.log`, container matched on **`^sparkrun_`** — it is
named `sparkrun_<hash>_<hash>_solo`, **not** `vllm-*`, and `docker logs -f` does
not work on this image.

### COST

Five invocations, five engine starts, ~130 s grid each at c1 plus ~180 s starts;
the c4 arm is the expensive grid. **~30 min wall estimated.**

### ABSOLUTELY NO ARENA SUBMISSION

No `--arena` flag in any arm, no `sparkrun arena` subcommand of any kind. There
is no login, nothing has ever been submitted, and nothing will be.

## Round 23 outcome — bench_b20062a3c5c5-r23-arm1-A8192 + bench_c9518e3e96a3-r23-arm2-B65536 + bench_c9518e3e96a3-r23-arm3-B65536 + bench_b20062a3c5c5-r23-arm4-A8192 + bench_b56686c32206-r23-arm5-c4-mns4 (2026-08-22)

**A-B-B-A at `tg128 @ d16384 c1`, runs=7 per arm, five invocations in one
sitting (18:49:12 → 19:14:45 UTC), five engine starts, `crash_count: 0` and
`session_count: 1` in all five, image `dgx-vllm-eugr-nightly:2026082102`.** No
`--arena` flag was used and no arena subcommand was run.

### THE HEADLINE, IN ONE LINE

⚠ **THE POSITION BIAS DOES NOT REPRODUCE. R22's pattern is REFUTED at this cell
under the design built to catch it — and R11's fold survives a drift-free test.**

### PRIMARY — Phase 2, `tg128 @ d16384 c1`, the declared reading

| arm | position | budget | median (7 runs) | σ/med | SE |
|---|---:|---|---:|---:|---:|
| **arm1 A** | 1 | `mnbt 8192` | **107.42** | 8.26% | 3.91% |
| **arm2 B** | 2 | `mnbt 65536` | **102.03** | 10.95% | 5.19% |
| **arm3 B** | 3 | `mnbt 65536` | **101.10** | 12.22% | 5.79% |
| **arm4 A** | 4 | `mnbt 8192` | **102.69** | 10.90% | 5.16% |

- **`P3` = arm4 − arm1 = −4.40%** (separation 3 positions, same config).
  Pre-declared band: ≤ +2.0% → **POSITION EFFECT REFUTED**, and ≤ −2.0% → it is
  additionally recorded as **sign-flipped**: the later arm read *lower*.
- **`P1` = arm3 − arm2 = −0.91%** (separation 1, same config). ≤ +2.0% →
  **REFUTED**, and coherent with `P3` — both same-config contrasts point the
  same way, so the round has no internal contradiction.
- **CONFIGURATION EFFECT, drift-free: `C` = −1.76%** — pooled 14-run median at
  `mnbt 65536` (arms 2+3) **101.89** against pooled 14-run median at `mnbt 8192`
  (arms 1+4) **103.72**. Pre-declared band |`C`| < 5% → ✅ **R11's FOLD STANDS.**

### SECONDARY — Phase 1, `ctx_tg @ d16384 c1`, the free partner

| arm | position | budget | median (7 runs) | σ/med |
|---|---:|---|---:|---:|
| arm1 A | 1 | `mnbt 8192` | 100.93 | 11.00% |
| arm2 B | 2 | `mnbt 65536` | 104.78 | 13.97% |
| arm3 B | 3 | `mnbt 65536` | 107.75 | 11.25% |
| arm4 A | 4 | `mnbt 8192` | 101.66 | 10.07% |

- **`P3` = +0.71%** → REFUTED. **`P1` = +2.84%** → **dead zone**, called as
  declared and not read as a confirmation.
- **`C` = +4.91%** — pooled 106.26 against 101.29. **Inside the ±5% band by
  0.09 points**, so inert by the letter of the rule, and it is ~**0.9 SE** on
  the pooled difference (SE ≈ 5.3%), i.e. fully consistent with zero. ⚠ It is
  reported at the band edge rather than rounded away: this is the *only* number
  in the round that a differently-drawn band would have flipped, and R11's own
  band is the one that was declared.
- **R11's and R8c's conjunction rule is satisfied**: Phase 2 and Phase 1 are
  both inert, so the inertness reading is established rather than split.

### WHAT THIS SAYS ABOUT R22, STATED CAREFULLY

**Four same-configuration position contrasts, which is what R22 never had:**
−4.40%, −0.91%, +0.71%, +2.84%. **Two up, two down, mean −0.44%.** A sign test
on four is **p = 1.0**. Against R22/R8c's 4-of-4 up, mean +6.5%.

⚠ **And the pattern does not reproduce even in the exact form that produced
it.** R22's comparisons were *adjacent arms of different configuration*. This
session contains six of those, and they read **−5.02%, −0.91%, +1.57%
(Phase 2), +3.81%, +2.84%, −5.65% (Phase 1)** — **three up, three down, mean
−0.56%.** The first adjacent pair of the session, arm1 → arm2, is a **−5.02%**
straight counterexample: the second arm read five percent *lower*.

**A thermal explanation was checked, not assumed.** Idle temperature rose across
the session (39 °C before arm1 → 53 °C before arm5) and loaded medians rose
61 → 64 → 63 → 63 °C, so later arms genuinely ran on a warmer box. **Under-load
SM clock medians were 2398 / 2392 / 2398 / 2392 MHz across arms 1–4 — a 0.25%
spread, uncorrelated with throughput** (the fastest arm and the slowest arm both
read 2398), with the same 2314–2320 MHz floor in every arm. **Nothing throttled,
and the clock cannot carry a 4.4% signal at 0.25% of spread.** The idle clock
even rose 2398 → 2411 MHz across the session while throughput fell.

⚠ **WHAT IS AND IS NOT SETTLED.** This round refutes the position bias **at this
cell, at this depth, at c1, in one session of five starts**. It does not prove
the campaign's cross-invocation deltas are noiseless. What it removes is the
*directional* claim — there is no evidence for a systematic "later arm reads
higher" term, so R22's +6.5% is best read as **four draws from a distribution
whose σ/med at this cell runs 8–12%**, exactly as R22 itself said might be the
case at p = 0.25. **R9c's ±2.5% reproduction floor is still an underestimate**
— the arm-to-arm spread here is ±5% on identical configurations — but it is a
**symmetric** floor, not a bias, and a symmetric floor does not need every past
delta re-signed.

**Consequences for the file:**
- **R13c's six-point `max_num_batched_tokens` curve is restored to a
  noise-limited reading rather than an order-suspect one.** Its knee at 65536
  rested on +233% and was never at risk; its small inter-point differences
  (98304 vs 131072 at −1.4%) remain noise, which is what they were already
  called.
- **R8c's "+6.36% from the folded budget on Phase 1" stays refuted** — R22
  refuted it by re-measurement, and R23 confirms the budget is inert at c1 on
  both phases at d16384 with a drift-free contrast. The *explanation* changes:
  it was a draw, not an ordering artefact.
- **The "check which arm ran first" caution in `RESULTS.md` is downgraded, not
  deleted**, to "cross-invocation deltas at or below ~5% are inside the
  arm-to-arm spread of identical configurations, in either direction."

### VERIFICATION THAT THE `-o` OVERRIDE PHYSICALLY REACHED THE ENGINE

⚠ This matters more than usual, because the whole configuration reading depends
on arms 1 and 4 really running at 8192. Three independent confirmations:

1. **Distinct benchIds.** arms 1/4 hashed to `bench_b20062a3c5c5`, arms 2/3 to
   `bench_c9518e3e96a3`. The only difference between those invocations was the
   `-o` value, so it is part of the resolved parameter set.
2. **arm2's benchId is R11's benchId.** `bench_c9518e3e96a3` is exactly the id
   R11 got at this cell at `mnbt 65536`. Same cell, same budget, same id.
3. ✅ **A physical signature, and it is the decisive one. Engine start cost
   tracks budget size** (R13c's finding): **143.3 s and 142.9 s** for the two
   8192 arms — agreeing to **0.4 s** — against **166.7 s and 190.2 s** for the
   two 65536 arms, and 178.9 s for the c4 arm at 65536. A dropped override could
   not produce a 24–47 s bimodal split that lines up with the flag.

⚠ **An instrument-plan miss, recorded rather than buried: the engine log was NOT
captured this round.** The plan called for `docker exec <container> tail -f
/tmp/sparkrun_serve.log` per arm and it was not run, so this round contributes
**no** residency samples, no MTP acceptance points and no prefix-cache samples.
The override verification above is what replaced it, and it is weaker evidence
than reading `--max-num-batched-tokens 8192` out of the serve command would have
been. Telemetry ran on all five arms and is archived.

### THE SECOND DELIVERABLE — `tg128 @ d16384 c4` at `mnbt 65536 + mns 4`, THE SHIPPED RECIPE

**`bench_b56686c32206-r23-arm5-c4-mns4`, runs=7, one invocation, position 5.**
Verified against `recipe.yaml` rather than assumed: its `defaults` read
`max_num_batched_tokens: 65536` and `max_num_seqs: 4`, so this arm ran
`./recipe.yaml` with **no `-o` override of any kind**.

| phase | `tg_throughput` (batch aggregate) | `peak_throughput` | `tg_req_throughput` | σ/med | worst of 7 | board top | margin |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Phase 2 `tg128`** | **179.34** | **317.0** | 67.17 | 5.63% | 154.92 | 46.68 | **3.84x** |
| **Phase 1 `ctx_tg`** | **169.45** | **305.0** | 61.80 | 2.45% | 162.81 | 27.68 | **6.12x** |

**This is the first row in the campaign that states what `recipe.yaml` actually
produces at `c>1`.** Every prior `c4` headline was measured at `mns 5`, which
the recipe does not ship. The synthesis' standing caveat — *"`mnbt 65536 + mns
4` has never been measured and no row should be quoted as what the recipe
produces until it is"* — **is discharged.**

⚠ **DO NOT READ IT AS "mns 4 BEATS mns 5".** 179.34 against R13c's 173.34 at
`mns 5` is **+3.46%**, a cross-invocation delta between two different sessions,
inside the ±5% arm-to-arm spread this very round measured on *identical*
configurations. The honest statement is that **the two are indistinguishable and
the shipped recipe loses nothing at c4**, which is the question that was asked.
The cell was already WON; the standings do not move.

⚠ **Metric discipline, per the skill.** `tg_throughput` at c4 is a **batch
aggregate** — `sum(decode tokens) / (max_last_token − min_first_token)` — and is
never multiplied by concurrency. Checks: `tg ≤ peak_throughput` (179.34 ≤ 317.0;
169.45 ≤ 305.0) ✓, `tg / tg_req ≤ c` (2.67 and 2.74, both ≤ 4) ✓.

### FREE RIDERS

| quantity | predicted | measured | verdict |
|---|---|---|---|
| every arm's median | 100 – 125 | 100.93 – 107.75 (c1) | ✅ all four inside |
| `tg_throughput == tg_req_throughput` at c1 | exact | **exact in 8 of 8 phase-arms** | ✅ assignment holds; round not void |
| `ctx_pp / pp` (theory `(depth+2048)/2048` = **9.00**) | 8.7 – 9.6 | **9.26 / 9.30 / 9.28 / 9.29** (c1) and **9.22** (c4) | ✅ **five new audit pairs, all inside 4% of theory. The phase-pair audit goes 45 of 46 → 50 of 51** |
| SM clock median under load | 2392 – 2398 | **2398 / 2392 / 2398 / 2392 / 2392 MHz** | ✅ twenty-first agreeing session, and the first to agree *within* one session across five starts |
| power max | ≤ 100.5 W | **100.54 W** | ⚠ **new campaign bound, ≤ 100.6 W** (arm1). The third consecutive round to nudge it |
| grid time | 110 – 150 s (c1) | **73.7 – 75.0 s** per c1 arm | ⚠ **outside, low** — R6's 124 s figure was 14 runs, this is 7. Not a fault; the prediction mis-cited its own basis |
| engine start | 160 – 200 s | 142.9 – 190.2 s, **and bimodal by budget** | ✅ and it became the round's override control |
| σ/med, Phase 2 c1 | 2 – 7% | **8.26 / 10.95 / 12.22 / 10.90%** | ⚠ **all four OUTSIDE, high.** R6's "`tg128` at d16384 is the quiet regime" is now dead at **seven** engine starts (2.6 / 5.5 / 8.01 / 8.26 / 10.95 / 12.22 / 10.90%). ⚠ **This cell is NOT quiet and no future round should budget runs as if it were** |

### VOID CHECKS — all passed

`crash_count: 0` and `session_count: 1` in all five `state.yaml`; the
`Benchmark args:` echo read `pp: [2048]`, `depth: [16384]`, `tg: [128]`,
`runs: 7` in all five with `concurrency: [1]` in arms 1–4 and `[4]` in arm 5;
`tg_throughput == tg_req_throughput` at c1 in 8 of 8 phase-arms; every
`container_image_longterm_ref` is `dgx-vllm-eugr-nightly:2026082102`; the arms
ran strictly in the declared order and none was re-run.

### COST

Five invocations, five engine starts, **zero crashes, zero wasted starts**.
Grid 73.9 + 74.0 + 75.0 + 73.7 + 220.3 = **516.9 s**; engine starts 143.3 +
166.7 + 190.2 + 142.9 + 178.9 = **822.0 s**. **~25.5 minutes of box wall clock**
(18:49:12 → 19:14:45 UTC), ~120k harness tokens.

Bought: **the highest-value item in the queue closed** — the position bias
refuted under a drift-free design, which restores every small cross-invocation
delta in this file to a symmetric noise reading rather than a suspect one;
**R11's fold re-licensed on a contrast that ordering cannot fake** (−1.76%,
against the +0.27% single-arm reading it originally rested on); **the shipped
recipe measured at `c>1` for the first time** (3.84x / 6.12x at `tg128` /
`ctx_tg` @ d16384 c4), discharging the campaign's last standing "never been
measured" caveat; five audit pairs (**50 of 51**); a within-session clock
control across five starts; a new power bound; and the retirement of R6's
"quiet regime" rule at seven engine starts.

⚠ **What it did NOT buy, and the round is worse for it:** no engine-log capture,
so no residency, acceptance or prefix-cache samples. That was an execution miss
against this round's own instrument plan, not a design choice.

## Desk correction — the prefill re-scoring (2026-08-22, zero box time)

Source: `ANALYSIS-board-rescrape.md`, a per-entry read of the public Firebase
endpoint the leaderboard SPA itself reads (`/leaderboard/byTest/<cell>.json`,
snapshot `2026-08-22T19:00:32Z`, single-node only). No arena login, no
submission, no ssh, no GPU. The scrape was verified against the 2026-08-21
record before use: it reproduces `docs/arena-recipe.md`'s single-node entry
counts (129/131/125 at d8192/d16384/d32768) and every board top `RESULTS.md`
quotes, to the cent.

**What was wrong.** `RESULTS.md` carried the claim that the board's prefill
figures come through the same llama-benchy CSV and carry the identical
`(depth+2048)/2048` understatement, "so the artefact cancels". Refuted per
entry. The re-scrape joined the `pp2048` and `ctx_pp` records of one submission
by `benchmarkId` and used `estPpt(pp2048)/estPpt(ctx_pp)` as a warm/cold
discriminator — cold expects `(depth+2048)/depth` (~1.06–1.25), warm expects
`2048/depth` (~0.06–0.25) — and the distribution is cleanly bimodal at d16384
and d32768. The board is mostly WARM (d32768: 106 warm / 19 cold of 125). We are
in the cold minority at every depth. **Every opponent on every scored prefill row
is warm**, because ranking by cell top selects a warm entry by construction — a
cold entry's `pp2048` is depressed ~17x and ranks near the bottom.

**What was also wrong.** Every prefill board top except `ctx_pp @ d65536` is an
Atlas `ttfr` artefact, now measured rather than inferred: the d32768 top's own
published `e2eTtft` of 24064.87 ms implies 1361.7 tok/s against a published
945271.31, a 694x inflation. `|ttfr − e2eTtft|` is 5.1–24.0 s for Atlas entries
and ≤ 0.40 s for ~115 vLLM entries per depth. Atlas's real prefill is
1362–2976 tok/s — **below ours** (4014–6149).

**What changed in the standings.** Six margins restated, no cell changed side,
counts stay 8 won / 12 lost. `ctx_pp` c1 goes from "LOST by ~126x/~151x/~186x"
to 0.844x/0.845x/0.856x against the best same-model vLLM NVFP4 entry and
0.574x/0.551x/0.537x against the best vLLM NVFP4 entry — like-for-like entries
that exist on the board and that the 2026-08-21 scrape simply missed.
`pp2048` c1 goes from 0.006x/0.006x/0.005x to 0.752x/0.757x/0.913x against
Laguna-XS-2.1-NVFP4, scored on our **marginal** warm-equivalent `2048/(T2−T1)`.
`ctx_pp @ d65536 c1` 2.88x is unchanged and is the only prefill row that ever
needed no correction — that incumbent is honest (`ttfr == e2eTtft`).

⚠ **`ANALYSIS-prefill-metric.md`'s "5027 tok/s = 1.082x WIN" at
`pp2048 @ d32768 c1` is wrong and did not reach `RESULTS.md`.** 5027 is the
average rate over the whole cold pass; the like-for-like figure is the marginal
rate 4238.4, giving **0.913x — a narrow loss**. That file is kept unedited under
a superseded banner.

**Rule adopted.** Score prefill on `ctx_pp` only. It is the one prefill column
whose numerator matches what the engine did for every entry, warm or cold, and
it needs no correction, no opponent classification and no marginal-rate
reconstruction. Our `pp2048` figures are not published as comparisons until
prefix caching works here.

**Free consequence.** Prefix caching works for ~84% of the d32768 field on this
hardware, so our 0.0% hit rate is a property of *our* configuration, not an
architectural limit of hybrid-mamba models on GB10. That raises the prior on the
open experiment A (which flag breaks our cache — 13 minutes of box time for a
binary readout) and it is now the only open item from that analysis.

## Round 24 hypothesis — WHICH FLAG BREAKS THE PREFIX CACHE: `tg128 @ d16384 c4`, three arms, one engine start each, runs=3

**Written 2026-08-22 BEFORE any arm ran.** This is experiment **A** of
`ANALYSIS-prefill-metric.md` §3 — the item that file ranked 1 by a wide margin,
and the only open item left from it after the board re-scrape closed B.

### The question, and why it is worth box time

`--enable-prefix-caching` ships ON in `recipe.yaml`. Across **220+ engine
samples in 17 rounds it has never hit once** — `Prefix cache hit rate: 0.0%`,
every sample, every round, both budgets, at every depth. R9c measured that the
flag is nonetheless worth **2.414x** end-to-end at this exact cell (146.32 ON vs
60.60 OFF, `tg128 @ d16384 c4`, `mnbt 32768`), of which **83% is batch span and
17% per-request decode**. So an enabled feature that never fires is leaving the
single largest known multiplier in the campaign untouched.

**What is already ruled out and must NOT be re-tested:**

- **The instrument.** The hit rate is vLLM's own log line, not a benchy metric.
- **The access pattern.** `runner.py:137-166` + `client.py:298-300`: Phase 1 and
  Phase 2 share a byte-identical system message placed first, so the two
  requests share an identical 16384+ token prefix. `prompt_batch` is generated
  once per run and both phases index the same element.
- **KV capacity.** Peak usage is **3.6% of a 3,071,735-token pool**; the working
  set is 4 x 16384 = 65,536 tokens, ~47x under.
- **Eviction.** Nothing is evicted for space at 3.6% occupancy.
- **Block alignment.** `interface.py:911` forces attention block size 2144; a
  16384-token prefix is 7.64 blocks, so 7 full blocks (15,008 tokens) are
  aligned and eligible. The alignment ceiling is ~81%, not 0%.

The cause is therefore **engine-side — a flag interaction, not a resource
limit.** The 2026-08-22 per-entry board re-scrape sharpens the prior: **~84% of
the d32768 field and ~82% of the d16384 field run warm on this same hardware**,
so prefix reuse is not architecturally unavailable on GB10 and our 0.0% is a
property of our own flag set.

**Free desk read done before this round, recorded so the next agent does not
repeat it.** Every `enable_prefix_caching = False` assignment in the pinned image
(`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`) was located and read:
`v1/engine/core.py:282` (non-causal attention layers), `attention.py:378`
(FLASHINFER/TRITON_MLA **only under `VLLM_BATCH_INVARIANT`**, which we do not
set), `mla_attention.py:521`, `models/config.py:167` (Unlimited-OCR only),
`platforms/cpu.py:382`, `arg_utils.py:2735` (RISC-V only). **None of them fires
on our configuration**, which is consistent with the engine printing a hit-rate
line at all: the cache manager is live and simply never matches. So the defect
is a **miss**, not a silent disable — and that is what makes an arm-by-arm probe
the right instrument rather than more source reading.

### The three arms

Cell `tg128 @ d16384 c4`, `depth 16384`, `pp 2048`, `tg 128`, `concurrency 4`,
**runs=3**, one engine start per arm, run in this order:

| arm | recipe | mutation | why |
|---|---|---|---|
| **arm1 CONTROL** | `./recipe.yaml` unchanged | none — `mnbt 65536 + mns 4`, `kv-cache-dtype fp8`, MTP on | establishes the 0.0% in this session, on the shipped config |
| **arm2 KV DTYPE** | `recipe-r24-arm2-kvauto.yaml` | `--kv-cache-dtype auto` (was `fp8`) | fp8 KV quantisation is the first of §2.7's three suspects |
| **arm3 SPEC OFF** | `recipe-r24-arm3-specoff.yaml` | `--speculative-config` removed entirely | MTP speculative decoding is the second suspect |

Both mutations are serve-command flags, not templated defaults, so each needs
its own candidate recipe — `-o` cannot reach them. Both candidate recipes are
committed with this block and archived alongside their runs.

**`runs=3` is deliberate and sufficient, because THE READOUT IS BINARY.** A
0.0%-vs-nonzero reading is immune to the ±5% arm-to-arm spread R23 measured, to
MTP acceptance bimodality, and to the three-run problem. R23 also **refuted** the
position bias (four contrasts, mean −0.44%, p = 1.0), so no counterbalanced
design is needed and none is used. We are not quoting a throughput as a claim.

### PRE-DECLARED THRESHOLDS

**PRIMARY readout: `Prefix cache hit rate` from each arm's engine log**, captured
with R9c's two-wait recipe (`docker exec <container> tail -f -n +1
/tmp/sparkrun_serve.log`, container matched on `^sparkrun_`, waiting for BOTH
the container and the file).

- **CONFIRM** — any arm reports a hit rate **> 50%** in its loaded samples. That
  arm's flag is the culprit.
- **REFUTE** — **all three arms read exactly 0.0%** in every logged sample.
  Neither `kv_cache_dtype fp8` nor MTP is the cause, and the next probe must go
  elsewhere (named below).
- **DEAD ZONE** — an arm reads **> 0.0% but ≤ 50%**. Partial reuse: recorded as a
  lead, **not** as a culprit, and it earns a repeat arm rather than a fold.

**SECONDARY: `tg` and `ctx_tg` medians per arm**, so a confirming arm can be
priced at this cell. What must be true if an arm really restores caching:

- **Phase 2 `tg` rises and Phase 1 `ctx_tg` does not.** This is the sharp
  discriminator and it follows from the phase labels: `ctx_` is Phase 1, the
  **uncached** context load that POPULATES the cache; only Phase 2 can hit it.
  An arm whose `tg` and `ctx_tg` move together did **not** restore caching — it
  changed decode speed.
- **Size.** §2.7's projection at this cell is `tg` → ~247 from the `mns 5` knee
  anchor; against R23's shipped-recipe anchor of **179.34** the same +42% is
  ~255. Declared band for "the projection held": Phase 2 `tg` **≥ 210**. Between
  the control and 210 the caching is real but worth less than projected, and the
  projection is what gets written down as wrong.
- **`ttfr` spread within the batch collapses.** R9c measured 1516 ms (cache
  flag on, never hitting) vs 6269 ms (flag off). A genuinely hitting arm should
  fall well below 1516 ms, because the span is what the flag buys.

**⚠ Two confounds priced in advance, so no arm's throughput is over-read:**

1. **arm2 changes KV memory, not just caching.** `auto` stores KV at model dtype
   instead of fp8, roughly halving KV token capacity (~3.07M → ~1.5M). That is
   still ~23x the 65,536-token working set, so **capacity stays ruled out** — but
   any `tg` move in arm2 is not attributable to caching alone.
2. **arm3's throughput is uninterpretable by construction.** Removing MTP
   removes speculative decode outright; arm3's `tg` **will** fall sharply whether
   or not caching is restored. **Only arm3's hit rate is a readout.** Its `tg` is
   recorded for the archive and must not be compared to the control as a price.

**GATES, checked on every arm:** `crash_count: 0`, `session_count: 1`, engine log
captured (>100 lines), and `nvidia-smi clocks.sm` + temperature recorded at each
arm start so a thermal explanation can be checked rather than assumed.

**NO FOLD THIS ROUND, whatever lands.** If an arm confirms, the finding is
recorded as a **candidate** `recipe.yaml` change and nothing more; a fold needs
its own pre-declared rule and a c1 anchor, exactly as R11 did. Naming the culprit
and folding it are two different rounds.

### If it refutes, where the next probe goes

Stated now so the outcome block is not written after the fact:

1. **`--attention-backend flashinfer`** — the third suspect of §2.7 and the only
   one this round does not test. It is the cheapest remaining arm.
2. **The hybrid `align` path itself** — read `find_longest_cache_hit` for the
   Mamba manager in the pinned image and establish whether a hybrid KV group can
   report a hit at all when the mamba state was never checkpointed at a block
   boundary. **Zero box time, and it should be run BEFORE any further arm**, since
   a source read that says "structurally impossible" retires the whole ladder.
3. **`--async-scheduling`**, last, on the weakest prior.

### Predicted outcome, on the record before the run

**Refute is the more likely single result.** The strongest argument against both
suspects is that neither is exotic: fp8 KV and MTP are common on this board, and
the board is 82–84% warm. The strongest argument *for* the round is that the
board publishes only `recipeType`, never server flags, so "common" is an
assumption about the field and not a measurement of it. Prediction, written
down to be scored: **arm1 0.0%, arm2 0.0%, arm3 0.0%**, with the real cause in
item 2 above — the hybrid-mamba `align` path never checkpointing reusable state.

## Round 24b hypothesis — narrowing the culprit: is it MTP, or is it MULTI-MODULE MTP? One arm, declared before it ran

**Written 2026-08-22 after R24 arm3 landed and BEFORE arm4 ran.** Arm 3 restored
prefix caching by deleting `--speculative-config` outright, which identifies the
flag but not the mechanism, and deleting MTP costs 33% of per-request decode.
The useful question is whether a *cheaper* deletion works.

**The source says the two are not the same thing.** In the pinned image,
`v1/core/sched/scheduler.py:265-281` sets `num_prefill_lookahead =
num_spec_tokens` when `speculative_config.use_multi_module_mtp()` and **1**
otherwise, and `v1/core/kv_cache_coordinator.py:105-134` documents that the
prefix-cache tail excluded under EAGLE/MTP must be "large enough to contain" that
lookahead. Our recipe ships `num_speculative_tokens: 3`, which is the
multi-module path. **`num_speculative_tokens: 1` keeps speculation and takes the
single-module lookahead.**

- **arm4**: `recipe-r24-arm4-spec1.yaml` — identical to `recipe.yaml` except
  `"num_speculative_tokens":1`. Same cell, same probe, runs=3, one engine start.
- **CONFIRM (cache restored)**: hit rate **≥ 40%**, i.e. at or near the
  structural ceiling derived in the outcome block below.
- **REFUTE**: **0.0%**, which would mean any MTP at all breaks the cache and the
  only way to have prefix caching on this model is to have no speculation.
- **DEAD ZONE**: anything strictly between. Recorded as a lead, not a culprit.
- **Secondary, and it is the whole point of the arm**: if arm4 confirms, its
  `tg` is the number that decides whether a fold is even arguable, because it
  keeps some speculation. Declared band: a fold becomes **arguable** only if
  arm4's Phase-2 `tg` is **≥ 169.89**, the control measured in this session. Any
  lower and restoring the cache costs board throughput at this cell and the
  finding is a latency/prefill trade, not an upgrade.
- **Still no fold this round, whatever arm4 reads.** A fold needs its own round
  and a c1 anchor.

## Round 24 outcome — bench_647b25c13d9f-r24-arm1-control + bench_064550e26525-r24-arm2-kvauto + bench_064fc6128314-r24-arm3-specoff + bench_f6e4a4c51f71-r24-arm4-spec1 (2026-08-22)

**Four invocations, four engine starts, one sitting (19:33:37 → 19:58 UTC), all
`crash_count: 0` / `session_count: 1`, all on image
`dgx-vllm-eugr-nightly:2026082102` — the same epoch as every round since R1. The
engine log was captured on all four arms (242 / 254 / 195 / 248 lines). No
`--arena` flag was used and no arena subcommand was run.**

### THE HEADLINE, IN ONE LINE

⚠ **THE CULPRIT IS MTP SPECULATIVE DECODING, AND IT IS ALL-OR-NOTHING. Deleting
`--speculative-config` takes the prefix-cache hit rate from 0.0% to 42.1% — which
is the structural ceiling, exactly — and it is the ONLY thing that does.
`kv_cache_dtype auto` does not. `num_speculative_tokens: 1` does not. The
campaign's oldest open defect is closed after seventeen rounds and 220+ zero-hit
samples.**

### PRIMARY — the engine's own hit-rate line, per arm

| arm | mutation | `Prefix cache hit rate` samples | verdict |
|---|---|---|---|
| **arm1 CONTROL** | shipped `recipe.yaml` | `0.0%` × 11 of 11 | cache dead |
| **arm2 KV DTYPE** | `--kv-cache-dtype auto` | `0.0%` × 11 of 11 | **not the culprit** |
| **arm3 SPEC OFF** | `--speculative-config` removed | **`42.1%` × 5, `36.4%` × 1**, `0.0%` × 2 (pre-load) | **THE CULPRIT** |
| **arm4 SPEC 1** | `num_speculative_tokens: 1` | `0.0%` × 12 of 12 | **not a cheaper fix** |

The evidence lines themselves, from
`experiments/bench_064fc6128314-r24-arm3-specoff/engine-serve.log`:

```
19:49:25 ... Avg prompt throughput: 6553.2 tokens/s, Running: 4 reqs, Waiting: 0 reqs, GPU KV cache usage: 1.4%, Prefix cache hit rate: 0.0%
19:49:35 ... Avg prompt throughput: 1504.1 tokens/s, Running: 0 reqs, Waiting: 0 reqs, GPU KV cache usage: 0.0%, Prefix cache hit rate: 42.1%
19:49:45 ... Avg prompt throughput: 6554.3 tokens/s, Running: 4 reqs, Waiting: 0 reqs, GPU KV cache usage: 1.9%, Prefix cache hit rate: 42.1%
19:50:15 ... Avg prompt throughput: 1504.2 tokens/s, Running: 4 reqs, Waiting: 0 reqs, GPU KV cache usage: 1.4%, Prefix cache hit rate: 36.4%
19:50:25 ... Avg prompt throughput: 8058.5 tokens/s, Running: 4 reqs, Waiting: 0 reqs, GPU KV cache usage: 1.5%, Prefix cache hit rate: 42.1%
```

and the control's, from `bench_647b25c13d9f-r24-arm1-control/engine-serve.log` —
the same line, same cell, same session, eleven times: `Prefix cache hit rate: 0.0%`.

### ⚠ THE PRE-DECLARED CONFIRM THRESHOLD WAS MIS-SET, AND IT IS RECORDED AS AN ERROR RATHER THAN REINTERPRETED

The hypothesis block declared **CONFIRM at > 50%** and arm 3 read **42.1%**, so
**by the letter of the rule this round landed in its own DEAD ZONE.** That is
stated first, because the campaign's rule is that a rule which only binds when
inconvenient is not a rule.

**But the 50% was unreachable by construction, and the arithmetic says so with no
free parameters.** vLLM's counter is cumulative over **both** benchy phases, and
Phase 1 is the *uncached* context load by design — it is the pass that populates
the cache and can never hit it. Per request, with arm 3's attention block size of
**2096** (`Setting attention block size to 2096`, in its own log):

```
eligible hit  = floor(16384 / 2096) x 2096 = 7 x 2096 = 14672 tokens
queried       = Phase 1 (16384) + Phase 2 (16384 + 2048) = 34816 tokens
ceiling       = 14672 / 34816 = 42.14%
observed      = 42.1%
```

**The arm hit its structural maximum to within the log's one printed decimal.**
The cache is not partially working in arm 3; it is working perfectly, on 100% of
the tokens that a 2096-aligned prefix makes eligible. The declared threshold was
carried over from §2.7's "~81% alignment ceiling", which is the ceiling for the
**Phase-2 pass alone** and not for the counter the round actually read. **The
error was in the declaration, not in the arm.**

So the round's answer is recorded in two parts, and both belong in the record:
**by the declared numeric rule, DEAD ZONE; by the question the round was built to
answer — which flag breaks the cache — CONFIRMED, MTP, unambiguously**, on a
0.0%-vs-42.1% contrast corroborated by three independent secondary readings that
were declared in advance and all three held.

### SECONDARY — and the pre-declared discriminator held exactly

Cell `tg128 @ d16384 c4`, `mnbt 65536`, `mns 4`, runs=3, medians. `span` is the
campaign's `c x tg_req / tg` identity.

**Phase 2** (charged 2048 while the engine processes `depth + 2048`):

| arm | hit rate | `tg` | σ/med | `tg_req` | `peak_thr` | `pp` | `ttfr` | span |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **arm1 control** | 0.0% | **169.89** | 3.16% | 63.93 | 309 | **677.37** | **12080.79** | 1.5053 |
| **arm2 kv auto** | 0.0% | 179.15 | 7.15% | 54.30 | 265 | 719.56 | 11374.55 | 1.2124 |
| **arm3 spec off** | **42.1%** | 143.24 | 2.19% | 42.57 | 189 | **2823.72** | **2885.83** | 1.1888 |
| **arm4 spec 1** | 0.0% | 148.12 | 1.22% | 53.26 | 236 | 681.94 | 12003.69 | 1.4383 |

**Phase 1, the `ctx_` context load** — the uncached pass, charged `depth` tokens:

| arm | `ctx_tg` | σ/med | `tg_req` | `peak_thr` | `ctx_pp` | `ttfr` | span |
|---|---:|---:|---:|---:|---:|---:|---:|
| arm1 control | **175.59** | 1.42% | 64.05 | 304 | 6249.38 | 10462.58 | 1.4590 |
| arm2 kv auto | 194.14 | 2.09% | 57.87 | 264 | 6614.32 | 9885.16 | 1.1924 |
| arm3 spec off | 144.62 | 1.39% | 42.72 | 193 | 6547.64 | 9979.72 | 1.1815 |
| arm4 spec 1 | 152.81 | 0.59% | 55.25 | 253 | 6256.57 | 10457.96 | 1.4462 |

**THE DECLARED DISCRIMINATOR WAS "Phase 2 MOVES AND PHASE 1 DOES NOT", AND THAT
IS EXACTLY WHAT ARM 3 DID:**

- **`pp`: Phase 2 677.37 → 2823.72 = 4.17x. Phase 1 6249.38 → 6547.64 = +4.8%,
  i.e. flat.** Prefill work collapses on the pass that can hit the cache and is
  untouched on the pass that populates it.
- **`ttfr`: Phase 2 12080.79 → 2885.83 ms = 4.19x faster. Phase 1 10462.58 →
  9979.72 ms = −4.6%, i.e. flat.**
- Two independent quantities, the same 4.2x, on the same pass, in the same
  direction the phase labels predict. **Nothing but a working prefix cache
  produces that signature**, and arm 4 — same engine, same recipe, one
  speculative token instead of three — reproduces the control's 681.94 / 12003.69
  to within 0.7% and 0.6%, which is the cleanest possible negative control.

### ⚠ AND THE PRICE, WHICH IS THE PART THAT MATTERS FOR THE RECIPE: THE §2.7 PROJECTION IS REFUTED

`ANALYSIS-prefill-metric.md` §2.7 projected **`tg` → ~247 at this cell, +42%**,
and the hypothesis block declared **`tg` ≥ 210** as the band in which "the
projection held". **Arm 3 read 143.24. The band failed by 32%, and the projection
is REFUTED — measured, not doubted.**

The reason is the one the projection could not have known: **it assumed the cache
could be fixed at no cost, and the fix costs MTP.** Decomposed on the campaign's
own identity, arm3 against arm1 on Phase 2:

```
tg ratio 0.8432  =  tg_req ratio 0.6659  x  span ratio 1.2662  =  0.8431  ✓
```

**Turning MTP off buys a 26.6% shorter batch span — the cache doing exactly what
R9c said a shorter measurement window is worth — and pays 33.4% of per-request
decode for it. Net −15.7% on the board metric at c4.** `peak_throughput` falls
309 → 189 (−39%), which is the hardware term and is all MTP.

**So the trade is real, it is binary, and it goes the other way from what the
analysis expected:**

| what you get | shipped (MTP on) | MTP off |
|---|---:|---:|
| prefix cache | dead | **works, at ceiling** |
| `tg` @ c4 (the board metric) | **169.89** | 143.24 (**−15.7%**) |
| `peak_throughput` | **309** | 189 (−39%) |
| Phase-2 `pp` | 677.37 | **2823.72 (4.17x)** |
| Phase-2 `ttfr` | 12080.79 ms | **2885.83 ms (4.19x faster)** |

### WHAT THIS RETIRES IN `ANALYSIS-prefill-metric.md` §2.7

1. **"Projected +42% at c4"** — REFUTED, measured at **−15.7%**.
2. **"The same mechanism projects c5 from 164.27 to ~230 and c2 from 140.77 to
   ~176, flipping both like-for-like comparisons"** — **the arithmetic those two
   projections were built on is the arithmetic just refuted at c4**, so neither
   flip is supported. Not measured at c2/c5 and therefore not refuted *there* —
   but it must not be quoted as a live prospect any more.
3. **"This single defect is the common cause of the c2 loss, the c5 loss, and all
   six prefill losses"** — the prefill half is **wrong on the phase labels**.
   Prefill is scored on **`ctx_pp` ONLY** (RESULTS.md), `ctx_pp` is **Phase 1**,
   and Phase 1 is the uncached pass that populates the cache. Arm 3 confirms it
   directly: `ctx_pp` moves +4.8% while `pp` moves 4.17x. **Fixing the cache
   moves none of the six scored prefill rows.** What it would move is the
   `pp2048` rows, which this file already records as not quotable as board
   comparisons.
4. **"It would make `pp2048` a valid metric for us for the first time"** — true,
   and now known to cost 15.7% of `tg` and 39% of `peak_throughput` to buy.

### THE MECHANISM — narrowed to a flag, NOT closed to a cause

**arm4 is the round's second result and it is worth as much as arm3.** The source
read that motivated it (`scheduler.py:265-281`, `kv_cache_coordinator.py:105-134`)
said multi-module MTP demands a prefix-cache tail exclusion of
`num_speculative_tokens`, and `num_speculative_tokens: 1` takes the single-module
path. **It made no difference at all: 0.0% in 12 of 12 samples.** So the defect is
not the size of the MTP lookahead, and there is **no cheap version of the fix** —
speculation and prefix caching cannot coexist on this model in this build.

What is established: **any `--speculative-config` at all sets the hit rate to
exactly 0.0%; removing it sets it to the structural ceiling.** What is *not*
established is why. The candidate, and it is inferred from source rather than
measured, is the EAGLE/MTP last-block drop in
`v1/core/kv_cache_coordinator.py:100-134` combined with
`_annotate_eagle_groups_deepseek_v4` (`kv_cache_utils.py:1765-1788`), which flags
eagle groups **only for `deepseek_v4`** — so for this Qwen hybrid the coordinator
falls into its own conservative branch, `if use_eagle and not self.eagle_group_ids:
self.eagle_group_ids = set(range(len(kv_cache_groups)))`, and **every** KV group,
mamba groups included, is treated as an eagle group and has its tail dropped.
⚠ **Stated as a candidate, not a finding.** The last-block drop alone should cost
one block, not all seven, so something in the hybrid `align` path is turning a
one-block exclusion into a total miss, and this round did not read far enough to
say what. **The next probe is a source read, not box time.**

### GATES — all pass

- `crash_count: 0` and `session_count: 1` in all four `state.yaml`.
- Engine log captured on **4 of 4 arms** (242 / 254 / 195 / 248 lines) with
  R9c's two-wait recipe. Second consecutive round with the instrument on every
  arm; R23's capture miss is not repeated.
- Image `dgx-vllm-eugr-nightly:2026082102`, `container_image_longterm_pinned:
  true`, in all four — **same epoch, no silent version change.**
- **Thermal and clock check, measured rather than assumed** (arm-start idle
  readings): 19:33:37Z **2398 MHz / 39 °C**, 19:38:46Z **2411 / 54**, 19:45:12Z
  **2411 / 53**, 19:54:33Z **2398 / 43**. Spread **0.54%**, uncorrelated with any
  arm's reading, nothing throttled. ⚠ Recorded honestly: these are *idle* samples
  taken at each arm's start, not under-load medians as R23 captured — the round
  did not run `sample-telemetry.sh`. A thermal explanation is not supported, and
  it is also not excluded as tightly as R23 excluded it.
- **`ttfr` spread within the batch was declared as a third secondary reading and
  it is NOT usable, also recorded as a mis-set threshold.** The declaration
  ("below R9c's 1516 ms") was carried over from `mnbt 32768`; at the shipped
  `mnbt 65536` the *control* already reads **991 ms**, so the test had no room.
  Arm 3 reads 643 ms. Directionally right, quantitatively meaningless.

### FREE BY-PRODUCTS

- **arm2 is a real finding even though it refuted its own hypothesis.**
  `--kv-cache-dtype auto` stores KV at bfloat16 (`kv_cache_dtype=torch.bfloat16`
  in its log), which cuts the KV pool **3,071,735 → 1,892,708 tokens** and moves
  the attention block size **2144 → 1072**. It costs `peak_throughput` 309 → 265
  (−14%) and `tg_req` −15%, and yet reads `tg` **+5.5%** because its span
  tightens 1.5053 → 1.2124 **with the cache still stone dead at 0.0%.** ⚠ That
  is a warning worth carrying: **a span can tighten by 24% for reasons that have
  nothing to do with prefix caching**, so span alone is not evidence of a cache
  hit. The hit-rate line is.
- **Capacity is re-confirmed as irrelevant from a fourth direction.** The four
  arms ran with KV pools of 3.07M / 1.89M / 4.79M / 3.56M tokens against a
  65,536-token working set — a 2.5x spread in capacity, and the hit rate is
  determined entirely by one flag that is not capacity.
- **The attention block size is not fixed at 2144.** It read **2144 / 1072 /
  2096 / 2112** across the four arms. Every earlier statement in this campaign
  that "all seven archived engine logs carry `Setting attention block size to
  2144`" is true of *those* logs and is **not a constant of the model** — it
  moves with the KV dtype and with the speculative config. The 42.1% ceiling
  arithmetic above depends on the per-arm value, so read it from the log rather
  than assuming.
- **The shipped-recipe control reproduced R23's row at the edge of the band.**
  169.89 against R23's 179.34 = **−5.27%**, just outside the ±5% arm-to-arm
  spread R23 measured on identical configs, on a 3-run median against a 7-run
  one. ⚠ **Not pooled into the standings row** — this is a deliberately
  under-sampled diagnostic control and the round pre-declared that it was not
  quoting a throughput. Recorded as a reproduction, not as a correction.
- **Six `enable_prefix_caching = False` sites in the pinned image were located
  and read, and NONE fires on our configuration** (see the hypothesis block).
  The cache manager is live and simply never matches. That is why an arm-by-arm
  probe was the right instrument and more source reading was not.

### ⚠ NO FOLD. THIS IS A CANDIDATE, AND ON THIS CELL IT IS A CANDIDATE TO REJECT

The hypothesis block declared no fold in advance and that stands. What the round
produces is a **named candidate `recipe.yaml` change — remove
`--speculative-config` — together with the first measurement of what it costs**,
and at `tg128 @ d16384 c4` it costs **−15.7% of the board metric and −39% of
`peak_throughput`** to buy 4.2x prefill and 4.2x time-to-first-response.

**On the campaign's own scoring, that is a change to reject**: eight of the twenty
scored cells are `tg` cells we hold, prefill is scored on `ctx_pp` which does not
move, and no scored row improves. **On any workload that cares about
time-to-first-token rather than a batch-aggregate decode rate, it is a change to
make.** Both sentences are true and the recipe is tuned for the first one.

A fold would need its own round, its own pre-declared rule and a **c1 anchor** —
and c1 is where this trade might read differently, because at c1 `tg` **is**
`tg_req`, there is no batch span to shorten, and the MTP loss would arrive with
no offsetting span gain at all. **The prediction, written here to be scored
later: at c1 removing MTP is worse than at c4, not better.**

### What to run next

1. **A source read, zero box time, and it should come first.** Establish why a
   one-block eagle tail exclusion becomes a total miss on the hybrid `align`
   path — `find_longest_cache_hit` for the mamba manager with
   `drop_eagle_block=True`. If it says "structurally impossible", the whole
   ladder retires with it.
2. **`--attention-backend flashinfer`** is now the only untested member of
   §2.7's trio, and its prior has fallen a long way: the culprit is found and
   arm 4 shows the mechanism is speculative-decoding-specific. **Do not spend
   box time on it** unless item 1 says the two interact.
3. **If anyone wants the trade priced properly, price it at c1 and c2**, not
   here — c4 is the cell where the span gain is largest and it still lost.

### Cost ledger

Box time: four engine starts and four short grids, 19:33:37 → ~19:58 UTC,
**~25 minutes**, one idle box, no system settings touched, no `apt`, no
`--arena`. Harness tokens: ~150k for read-in of the synthesis and the analysis,
four arms, the source reads, the outcome block and the close-out. **Value: the
campaign's oldest open defect, carried for seventeen rounds and 220+ samples, is
closed to a single flag — and the +42% prize that motivated it is refuted in the
same sitting for the price of one extra arm.**

## Round 25 hypothesis — THE UNTESTED LEVER: `num_speculative_tokens` 3 / 4 / 5 at `tg128 @ d16384 c1`, runs=7, one engine start per arm

**Written 2026-08-22 BEFORE any arm ran.** Every threshold, the refutation
condition and the fold rule below were fixed before the first invocation.

### Why this round exists

`num_speculative_tokens: 3` has been in `recipe.yaml` since R1 and has **never
been varied upward in eighteen rounds**. It was inherited from the source recipe,
like `--moe-backend marlin`, and inherited values are the ones nobody tests.
`num_speculative_tokens: k` means up to `k` drafted tokens plus one bonus token,
so the **ceiling on mean acceptance length is `k + 1` = 4.0** on the shipped
value. R24 established the neighbouring fact and bounded the alternative: MTP is
what holds the prefix cache at 0.0%, at **any** lookahead size including 1, and
buying the cache back by deleting `--speculative-config` costs **−15.7% `tg`** at
c4. So MTP stays. The only untested direction is **up**.

⚠ **AND THE PREMISE IS WEAKER AT THIS CELL THAN THE CAMPAIGN ANALYSIS CLAIMS —
RECORDED BEFORE THE RUN RATHER THAN DISCOVERED AFTER.** The "acceptance sits at
89–93% of its ceiling, so the ceiling binds" reading comes from **d32768 c1**
(3.56–3.71 across four engine starts, R5/R8c/R22). At **this round's cell**,
`tg128 @ d16384 c1`, the only clean sample is R11's engine log:
**median 3.13, range 2.79–3.24 over 7 samples — 78.3% of the 4.0 ceiling**, not
89–93%. R24's c4 control reads 3.07 (median of 10). At 78% of ceiling the
binding constraint is at least partly **per-position acceptance**, not the
ceiling, and the round is correspondingly less likely to pay. It is still worth
running because it is cheap, one-dimensional, and the last untested lever that
can reach c1 — but the round is not entitled to expect a win.

### The arms

Cell `tg128 @ d16384 c1` — `depth 16384`, `pp 2048`, `tg 128`, `concurrency 1`,
**runs=7**, one engine start per arm, plain sequential order (R23 refuted the
position bias: four contrasts, mean −0.44%, p = 1.0, so no counterbalancing).

| arm | recipe | `num_speculative_tokens` | acceptance ceiling |
|---|---|---:|---:|
| **arm1 CONTROL** | `./recipe.yaml` unchanged | **3** (shipped) | 4.0 |
| **arm2 SPEC 4** | `recipe-r25-spec4.yaml` | 4 | 5.0 |
| **arm3 SPEC 5** | `recipe-r25-spec5.yaml` | 5 | 6.0 |

`--speculative-config` is a serve-command flag, not a templated default, so each
raised arm needs its own candidate recipe; `-o` cannot reach it. Configuration is
what `recipe.yaml` ships and was **confirmed against the file, not assumed**:
`max_num_batched_tokens: 65536`, `max_num_seqs: 4`, `kv-cache-dtype fp8`,
`--moe-backend marlin`, `--attention-backend flashinfer`, prefix caching on.

**The low anchor is REUSED, not re-measured.** R24 arm4
(`bench_f6e4a4c51f71-r24-arm4-spec1`) measured `num_speculative_tokens: 1`:
`tg` **148.12**, `ctx_tg` **152.81**, **mean acceptance length median 1.85**
(range 1.83–1.98 over 9 samples, **92.5% of its 2.0 ceiling**), prefix cache
**0.0% × 12 of 12**. ⚠ **It was measured at c4, not c1** — so it anchors the
*acceptance* curve, which is a per-request property, and it does **not** anchor
the `tg` curve this round measures. That distinction travels with every use of
it below.

### PRE-DECLARED THRESHOLDS

**Sampling.** c1 cells at this depth run σ/med ≈ 8–12% across seven engine starts
(R23: 2.6 / 5.5 / 8.01 / 8.26 / 10.95 / 12.22 / 10.90%). Taking σ/med = 10% at
runs=7, the median standard error is `1.253 × 10% / √7` = **4.74%**, and the
standard error of a difference between two arms is `4.74% × √2` = **6.70%**.
Independently, R23 measured the arm-to-arm spread on **identical** configurations
at about **±5%**. So:

- **CONFIRM — a genuine improvement:** Phase-2 `tg` median **≥ +10.0%** over the
  same-session control. Ten points is ~1.5 SE of the difference and twice the
  demonstrated identical-config spread; anything smaller cannot be told from a
  draw at runs=7 and this campaign has been burned four times by pretending
  otherwise.
- **REFUTE:** Phase-2 `tg` **≤ +2.0%** (flat or declining) as the ceiling rises,
  **or** engine-reported mean acceptance length failing to rise above the
  control's median. The second clause refutes the premise **directly and
  independently of `tg`**: if a higher ceiling does not buy more accepted tokens
  per verify step, the ceiling was not the binding constraint and the whole
  reason for the round is wrong.
- **DEAD ZONE: +2.0% to +10.0%.** Real-looking, inside the campaign's own
  arm-to-arm spread, recorded as a lead. **No fold, no standings row, no claim.**

**MECHANISTIC READOUT, and it is the primary one.** Per arm, from the engine's
own `SpecDecoding metrics` line: **median mean-acceptance-length** and
**Avg draft acceptance rate**, plus the `Prefix cache hit rate` line (expected
0.0% on all three arms — R24 showed any `--speculative-config` kills it — so a
nonzero reading on any arm would be a surprise worth its own round).

**Arithmetic prediction, on the record before the run.** R11's 3.13 at `k = 3`
implies a per-position acceptance `p ≈ 0.84` on the geometric model
`(1 − p^(k+1))/(1 − p)`. That model predicts **3.64 at `k = 4` (+16%)** and
**4.05 at `k = 5` (+29%)**. But a longer draft also costs more per verify step:
R24's own `k = 1` → `k = 3` step bought +66% of accepted length and only **+14.7%
of `tg`** at c4, i.e. `tg` captured **~22%** of the acceptance gain. Applying that
ratio here predicts **`tg` +3.5% at `k = 4` and +6.5% at `k = 5`** — **both
inside the declared dead zone.** ⚠ **So the predicted outcome of this round is:
premise CONFIRMED (accepted length rises), effect DEAD ZONE, NO FOLD.** Written
down so the outcome block cannot be reinterpreted after the fact.

### THE FOLD RULE — R11 is the precedent, and nothing folds unless every clause fires

`num_speculative_tokens: N` (N > 3) is folded into `recipe.yaml` **only if ALL
five hold**:

1. **Measured at the anchor cell** `tg128 @ d16384 c1`, runs=7, in the **same
   session** as the control arm, one engine start per arm — R11's discipline: it
   measured the c1 anchor at the new value before touching the file.
2. **Phase-2 `tg` median ≥ +10.0%** over that same-session control (the CONFIRM
   band above).
3. **Phase-1 `ctx_tg` median not worse than the control by more than −5.0%.**
   R11 and R8c both required the conjunction: a change may not be folded on one
   phase while quietly costing the other.
4. **Engine-reported mean acceptance length rises above the control's median.**
   The mechanism has to be present, not merely the throughput — a `tg` rise
   without an acceptance rise is a draw wearing a mechanism's clothes.
5. **Gates clean in that arm:** `crash_count: 0`, `session_count: 1`,
   `container_image_longterm_ref: ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`,
   engine log captured.

If any clause fails, **`recipe.yaml` is untouched** and the finding is recorded
as a candidate only. A fold at any **other** cell (c4 in particular) needs its
own round and its own rule; this round licenses nothing at `c > 1`.

### GATES AND VOID CONDITIONS

- `crash_count > 0` or `session_count > 1` in any arm voids that arm.
- The `Benchmark args:` echo must read `pp: [2048]`, `depth: [16384]`,
  `tg: [128]`, `concurrency: [1]`, `runs: 7` in every arm. **`sparkrun` silently
  defaults an omitted `-b depth` to 0** — R5 lost a start to it.
- `tg_throughput != tg_req_throughput` at c1 voids the reading (at c1 that
  equality is an assignment, not a measurement — R10). ⚠ **This round is c1, so
  the per-request and batch-aggregate figures COINCIDE**; nothing here is a batch
  aggregate and nothing is ever multiplied by concurrency.
- Any container image other than `dgx-vllm-eugr-nightly:2026082102`.
- `nvidia-smi --query-gpu=clocks.sm,temperature.gpu,power.draw` recorded at each
  arm start, so a thermal explanation can be checked rather than assumed.
- Engine log per R13d's recipe: `docker exec <container> tail -f -n +1
  /tmp/sparkrun_serve.log`, container matched on `^sparkrun_`.

### OPTIONAL RIDE-ALONG — `--moe-backend`, LAST, and only if the three arms land cleanly

`--moe-backend marlin` was inherited from the source recipe and has never been
tested against an alternative in nineteen rounds. One arm, same cell, same probe,
`--moe-backend triton` (chosen because the MTP module already runs
`"moe_backend":"triton"` in the shipped recipe, so the kernel is known to exist
in this build). **Higher crash risk than anything else in the queue.** A crash is
a RESULT: archive with a `-crash` suffix per the skill, record what the engine
said, and it does **not** invalidate the three R25 arms above it. No fold either
way — a `--moe-backend` change would need its own round and its own rule.

### COST

Three invocations (four with the ride-along), one engine start each, ~130 s grid
at c1 plus ~180 s starts. **~25–35 min wall estimated.**

### ABSOLUTELY NO ARENA SUBMISSION

No `--arena` flag in any arm, no `sparkrun arena` subcommand of any kind. There
is no login and nothing has ever been submitted.

## Round 25 outcome — bench_c9518e3e96a3-r25-arm1-spec3 + bench_ddfac4b975ed-r25-arm2-spec4 + bench_93e361742c94-r25-arm3-spec5 (2026-08-22)

**Three invocations, three engine starts, one sitting (20:09:49 → 20:24 UTC), all
`crash_count: 0` / `session_count: 1`, all on image
`dgx-vllm-eugr-nightly:2026082102` — the same epoch as every round since R1. The
engine log was captured on all three arms (213 / 219 / 220 lines); telemetry
sampled alongside arm 1 (420 samples). No `--arena` flag was used and no arena
subcommand was run.**

### THE HEADLINE, IN TWO LINES

⚠ **THE CEILING BINDS AND RAISING IT DOES NOT PAY.** Mean acceptance length rises
monotonically with `num_speculative_tokens` — **3.03 → 3.44 → 3.67** at k = 3 / 4
/ 5 — so the premise of the round is **CONFIRMED as a mechanism**. But Phase-2
`tg` **falls** at both raised values, **102.81 → 99.67 (−3.05%) → 98.30
(−4.39%)**, which fires the pre-declared REFUTE clause (`tg ≤ +2.0%`). ⚠ **The
fold rule did NOT fire at either value and `recipe.yaml` is untouched.**
**`num_speculative_tokens: 3` is not merely inherited any more — it is measured,
and it is at or above the optimum at this cell.**

### PRIMARY — the mechanistic readout, from the engine's own `SpecDecoding metrics` line

Medians of 7 logged samples per arm (bimodal, so medians, never means):

| arm | `num_spec_tokens` | acceptance ceiling | **median acceptance length** | range | % of ceiling | median avg draft acceptance |
|---|---:|---:|---:|---|---:|---:|
| **arm1 CONTROL** | **3** (shipped) | 4.0 | **3.03** | 2.78 – 3.81 | **75.8%** | 67.6% |
| **arm2** | 4 | 5.0 | **3.44** | 3.09 – 3.66 | **68.8%** | 61.0% |
| **arm3** | 5 | 6.0 | **3.67** | 3.38 – 4.04 | **61.2%** | 53.4% |

**The ceiling was a real constraint: +13.5% of accepted length from k = 3 → 4 and
+21.1% from k = 3 → 5**, monotone, three points, one session. The pre-declared
refutation clause "accepted length failing to rise with the ceiling" did **not**
fire. The arithmetic prediction written before the run — 3.64 at k = 4 and 4.05
at k = 5, from a geometric model at `p ≈ 0.84` — over-predicted both, by 5.5% and
9.4%, and the reason is in the next section.

⚠ **AND THE PREMISE'S OTHER HALF IS CORRECTED ON THE RECORD.** The campaign
analysis read acceptance at **89–93% of ceiling** and concluded the ceiling
binds. Those figures are from **d32768 c1**. At **this** cell the control sits at
**75.8%**, and every raised arm sits *lower* as a fraction of its own ceiling —
68.8%, then 61.2%. **Raising the ceiling moves acceptance further from it, not
closer.**

The evidence lines themselves, one median sample per arm, from
`experiments/<benchId>/engine-serve.log`:

```
arm1 (k=3): Mean acceptance length: 3.03, ... Per-position acceptance rate: 0.865, 0.658, 0.505, Avg Draft acceptance rate: 67.6%
arm2 (k=4): Mean acceptance length: 3.44, ... Per-position acceptance rate: 0.840, 0.667, 0.493, 0.440, Avg Draft acceptance rate: 61.0%
arm3 (k=5): Mean acceptance length: 3.67, ... Per-position acceptance rate: 0.818, 0.602, 0.443, 0.375, 0.284, Avg Draft acceptance rate: 53.4%
```

### THE MECHANISM, AND THE ENGINE SAID IT OUT LOUD BEFORE THE FIRST TOKEN

`experiments/bench_ddfac4b975ed-r25-arm2-spec4/engine-serve.log`, at startup:

```
WARNING 08-22 20:15:18 [speculative.py:980] Enabling num_speculative_tokens > 1 will run multiple
times of forward on same MTP layer, which may result in lower acceptance rate
```

**This model has ONE MTP module, run `k` times, not `k` modules.** Two measured
consequences, both visible in the per-position rows above:

1. **The FIRST position degrades as `k` rises — 0.865 → 0.840 → 0.818.** A
   position-1 draft should not care how many more drafts follow it; it does,
   because the same layer is being re-driven and the draft context changes. This
   is the term the geometric model has no room for, and it is why the prediction
   over-shot.
2. **The added positions are nearly worthless.** Position 4 accepts at 0.440 and
   position 5 at 0.284, against 0.818–0.865 at position 1. Each is still paid for
   in full with an extra draft forward pass every verify step.

**So the trade at c1 is: more accepted tokens per verify step, bought with a
verify step that costs more than the extra tokens are worth.** `tg` falling
while acceptance rises is exactly that statement in the board's own metric.

### SECONDARY — throughput, and the identical-work controls that make it readable

Cell `tg128 @ d16384 c1`, shipped configuration confirmed against `recipe.yaml`:
`mnbt 65536`, `mns 4`, `kv-cache-dtype fp8`, `--moe-backend marlin`,
`--attention-backend flashinfer`, prefix caching on. **runs=7, all figures
MEDIANS.** ⚠ **This round is c1, so `tg_throughput` and `tg_req_throughput`
COINCIDE — verified exactly equal in all 42 run records, all three arms — and
nothing here is a batch aggregate. No figure is ever multiplied by concurrency.**

**Phase 2** (a row without `ctx_`: charged 2048 while the engine processes
`depth + 2048`):

| arm | k | `tg` | σ/med | vs control | `peak_thr` | `pp` | `ttfr` (ms) |
|---|---:|---:|---:|---:|---:|---:|---:|
| **arm1 control** | 3 | **102.81** | 7.64% | — | 114.0 | 639.40 | 3216.57 |
| arm2 | 4 | 99.67 | 11.67% | **−3.05%** | 113.0 | 644.03 | 3193.94 |
| arm3 | 5 | 98.30 | 10.71% | **−4.39%** | 110.0 | 646.84 | 3221.29 |

**Phase 1, the `ctx_` context load** — the uncached pass, charged `depth` tokens:

| arm | k | `ctx_tg` | σ/med | vs control | `peak_thr` | `ctx_pp` | `ttfr` (ms) |
|---|---:|---:|---:|---:|---:|---:|---:|
| **arm1 control** | 3 | **99.41** | 13.68% | — | 108.0 | 5951.55 | 2767.06 |
| arm2 | 4 | 100.63 | 11.63% | +1.23% | 109.0 | 6026.85 | 2732.78 |
| arm3 | 5 | 86.81 | 19.14% | −12.67% | 104.0 | 6033.31 | 2771.08 |

**THE IDENTICAL-WORK CONTROLS ARE THE TIGHTEST THIS CAMPAIGN HAS EVER PUT IN A
MULTI-ARM ROUND, AND THEY EARN THEIR PLACE.** `pp`, `ctx_pp` and both `ttfr`
figures are prefill quantities, which a speculative-decode lookahead cannot
touch. Across the three arms they read:

- `pp` **639.40 / 644.03 / 646.84** — spread **1.16%**
- `ctx_pp` **5951.55 / 6026.85 / 6033.31** — spread **1.37%**
- Phase-2 `ttfr` **3216.57 / 3193.94 / 3221.29** — spread **0.85%**
- Phase-1 `ttfr` **2767.06 / 2732.78 / 2771.08** — spread **1.40%**

**So the arm-to-arm systematic in THIS session is ~1%, not R23's ±5%**, and the
three engines really are the same machine doing the same prefill work. That
licenses reading the decode deltas as decode deltas — but it does **not** shrink
`tg`'s own sampling error, which is what governs. ⚠ **Priced honestly: at
σ/med ≈ 10% and runs=7 the median SE is 4.74% and the SE of a difference is
6.70%, so −3.05% and −4.39% are 0.46 and 0.66 SE. Neither decline is
individually significant.** What carries the round is that they are **negative,
monotone across three points, and accompanied by a monotone `peak_throughput`
decline (114 → 113 → 110)** while acceptance rose 21% — and above all that
**neither comes close to the +10.0% the fold rule demanded.** The refutation
does not need the declines to be real; it needs the gains to be absent, and they
are absent.

⚠ **arm3's Phase-1 −12.67% is NOT read as an effect.** Its σ/med is **19.14%**,
the highest of the six phase-arm readings here, its own run list contains a
132.54 against a 82.25, and its Phase-1 prefill controls moved +1.4% in the
*opposite* direction. It is a noisy draw at the campaign's noisiest kind of
reading and it is recorded, not interpreted.

### PREFIX CACHE — R24's finding reproduced at a third and fourth lookahead size

`Prefix cache hit rate: 0.0%` in **7 of 7** loaded samples on **every** arm —
k = 3, k = 4 and k = 5. R24 established 0.0% at k = 1 and k = 3 and 42.1% with
`--speculative-config` deleted. **R25 adds k = 4 and k = 5 to the zero side**, so
the rule "any `--speculative-config` at all sets the hit rate to exactly 0.0%"
now holds across **four** lookahead sizes and is no longer a two-point claim.
Twenty-one more zero-hit samples for the campaign's running count.

**A free by-product that matters for R24's ceiling arithmetic:** the attention
block size read **2144 / 2160 / 2176** across the three arms. It moves with
`num_speculative_tokens` as well as with the KV dtype — a third input to a
constant this campaign spent seventeen rounds treating as fixed at 2144. Read it
from the log, never assume it.

### THE FOLD RULE — CHECKED CLAUSE BY CLAUSE, AND IT DID NOT FIRE

| clause | arm2 (k=4) | arm3 (k=5) |
|---|---|---|
| 1. anchor cell, runs=7, same session as control | ✅ | ✅ |
| 2. **Phase-2 `tg` ≥ +10.0%** | ❌ **−3.05%** | ❌ **−4.39%** |
| 3. Phase-1 `ctx_tg` not worse than −5.0% | ✅ +1.23% | ❌ −12.67% |
| 4. acceptance length rises above control's median | ✅ 3.44 | ✅ 3.67 |
| 5. gates clean | ✅ | ✅ |

**Clause 2 fails at both values, so NOTHING IS FOLDED and `recipe.yaml` is
untouched.** Recorded plainly because the campaign's rule is that a rule which
only binds when inconvenient is not a rule — and this time the rule cost nothing,
which is the easy case.

### WHAT THIS SETTLES, AND WHAT IT DOES NOT

**Settles:** `num_speculative_tokens` is **not** the lever that moves concurrency
1. It was the last untested one-dimensional knob in the recipe, the campaign
analysis named it as the only remaining route to c1, and it is now measured in
both directions — R24 took it down to 1 (at c4) and R25 takes it up to 4 and 5
(at c1). **The shipped value 3 sits at or above the optimum at this cell.**

**Does NOT settle:**

- **`k = 2` was not measured.** `tg` is monotone decreasing over k = 3, 4, 5 and
  the mechanism (one MTP layer re-driven, first-position acceptance decaying with
  k) predicts the peak is at small k, so **k = 2 is the only untested point that
  could still beat the shipped value** — and R24's k = 1 at c4 was 12.8% below
  its own c4 control, which brackets it. ⚠ Cheap, one arm, but it is a **new
  round with its own rule**, not an addendum to this one.
- **`c > 1`.** This round licenses nothing at c4. At c4 the acceptance gain would
  arrive with a batch span to amortise it against, which is the term that made
  the c4 MTP trade read differently from the c1 prediction in R24.
- **The R24 low anchor is at c4, not c1.** `bench_f6e4a4c51f71-r24-arm4-spec1`
  read acceptance **1.85** (92.5% of its 2.0 ceiling) and `tg` **148.12** — but
  at **`tg128 @ d16384 c4`**. Its **acceptance** figure extends this round's
  curve, because per-request acceptance is a per-request property; its **`tg`**
  figure does not, because c4's `tg` is a batch aggregate and c1's is not.
  **Reused for the acceptance curve only, and the distinction is stated rather
  than glossed.**

**The acceptance curve, assembled from both rounds and labelled with its cell:**

| `num_spec_tokens` | ceiling | median acceptance length | % of ceiling | cell | source |
|---:|---:|---:|---:|---|---|
| 1 | 2.0 | 1.85 | 92.5% | ⚠ d16384 **c4** | R24 arm4 |
| 3 | 4.0 | 3.03 | 75.8% | d16384 c1 | R25 arm1 |
| 4 | 5.0 | 3.44 | 68.8% | d16384 c1 | R25 arm2 |
| 5 | 6.0 | 3.67 | 61.2% | d16384 c1 | R25 arm3 |

### GATES — all pass

- `crash_count: 0` and `session_count: 1` in all three `state.yaml`.
- `Benchmark args:` echoed `pp: [2048]`, `depth: [16384]`, `tg: [128]`,
  `concurrency: [1]`, `runs: 7` in every arm — checked, not assumed.
- `tg_throughput == tg_req_throughput` exactly, in all 42 run records.
- Image `dgx-vllm-eugr-nightly:2026082102`, `container_image_longterm_pinned:
  true`, in all three — same epoch, no silent version change.
- Engine log captured on **3 of 3 arms** (213 / 219 / 220 lines). Third
  consecutive round with the instrument on every arm.
- **Thermal and clock check, measured rather than assumed.** Arm-start idle
  readings: 20:09:49Z **2398 MHz / 41 °C / 10.65 W**, 20:14:47Z **2398 / 49 /
  11.69 W**, 20:20:00Z **2398 / 50 / 11.71 W**. **Identical SM clock at all
  three starts.** Under load across arm 1's 420-sample telemetry the SM clock
  sat at 2385–2411 MHz (2398 in 233 of 420 samples), **nothing throttled**. The
  box warmed 9 °C across the session while `tg` fell 4.4% — but the two raised
  arms ran on the *warmer* box and R23 measured the same 9 °C warming with no
  throughput correlation, so **a thermal explanation is not supported**; it is
  also not excluded to better than the ~1% the prefill controls bound.

### COST LEDGER

Box time: three engine starts and three c1 grids, 20:09:49 → ~20:24 UTC,
**~15 minutes**, one idle box, no system settings touched, no `apt`, no
`--arena`. Harness tokens: ~120k for read-in of the synthesis, RESULTS.md and
the R24 block, three arms, the outcome block and the close-out. **Value: the
campaign's last untested one-dimensional recipe knob is measured, the "the
ceiling binds so there is headroom" reading is separated into a true half and a
false half, and the shipped value is promoted from inherited to defended — for
fifteen minutes of box time.**

## Round 25 ride-along outcome — `--moe-backend`: THREE ALTERNATIVES, THREE REFUSALS, and `marlin` is the only one this engine will run (2026-08-22)

**Ran LAST, after all three R25 arms had landed cleanly, exactly as the
hypothesis block required. Three engine starts, 20:25:11 → 20:30:26 UTC, ~5
minutes. All three crashed at engine init before a single token was generated,
so none of them touched the R25 arms above.** Box idle clocks at each start:
20:25:11Z **2398 MHz / 50 °C**, 20:28:22Z **2398 / 43**, 20:29:41Z **2398 / 43**
— identical clocks, nothing thermal, and the crashes are configuration
refusals rather than failures under load.

### THE RESULT — the engine enumerated the answer for us

| attempt | `--moe-backend` | archive | what the engine said |
|---|---|---|---|
| 1 | `triton` | `bench_be900399e857-r25-ridealong-moetriton-crash` | `ValueError: moe_backend='triton' is not supported for NvFP4 MoE. Expected one of ['cutlass', 'flashinfer_trtllm', 'flashinfer_cutlass', 'flashinfer_cutedsl', 'flashinfer_b12x', 'marlin', 'humming', 'emulation']` — `fused_moe/oracle/nvfp4.py:161` |
| 2 | `flashinfer_trtllm` | `bench_5eea211b9a30-r25-ridealong-moefitrtllm-crash` | `ValueError: NvFp4 MoE backend 'FLASHINFER_TRTLLM' does not support the deployment configuration since kernel does not support current device cuda` — `oracle/nvfp4.py:256` |
| 3 | `cutlass` | `bench_a062dab1eed0-r25-ridealong-moecutlass-crash` | `ValueError: NvFp4 MoE backend 'VLLM_CUTLASS' does not support the deployment configuration since kernel does not support quantization scheme QuantKey(u8,scale(f8e4m3fn,static,GroupShape(row=1, col=16)),scale2(f32,static,per_tensor),symmetric)xNone` — `oracle/nvfp4.py:256` |

**Attempt 1 was the round's own error and it is recorded as one.** `triton` was
picked because the shipped recipe already runs `"moe_backend":"triton"` inside
`--speculative-config`, and the inference was that the kernel therefore exists
for this model. It does not: the MTP draft module is **not** NVFP4 and takes a
different backend path from the NVFP4 MoE layers. **The refusal is worth more
than the arm was**, because it prints the entire legal set — which nothing in
this repo had ever recorded.

**Attempts 2 and 3 are the real measurement, and they are decisive in the
opposite direction from the one the round expected.** Both are on the legal
list, both were refused by vLLM's NVFP4 backend oracle, and **for two different
reasons**: `flashinfer_trtllm` has no kernel for **this device** (GB10), and
`cutlass` has no kernel for **this quantisation scheme** (the u8 + per-16-column
fp8e4m3 scale + per-tensor fp32 scale2 layout this checkpoint ships).

### WHAT THIS SETTLES

⚠ **`--moe-backend marlin` is NOT an untested inherited default any more. It is
the backend the engine's own oracle selects for this model on this device**, and
the three cheapest alternatives are refused by that oracle at init — not slower,
**unavailable**. The `--moe-backend` lever is **closed for this campaign** at a
cost of five minutes.

Untested and left untested, on the record: `flashinfer_cutlass`,
`flashinfer_cutedsl`, `flashinfer_b12x`, `humming`, `emulation`. The first three
are flashinfer variants and share the device gate that refused
`flashinfer_trtllm`; `emulation` is by name a correctness path, not a
performance one. **The prior that any of them is both admissible and faster than
the oracle's own choice is low, and none is worth box time unless something else
motivates it.**

### NO FOLD, EITHER WAY

The hypothesis block declared that a `--moe-backend` change would need its own
round and its own rule. Nothing is folded; `recipe.yaml` is untouched. What the
ride-along produces is a **closed lever and a recorded legal set**.
