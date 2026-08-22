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

## CAMPAIGN SYNTHESIS — rounds 1 through 12 (2026-08-22)

Twelve rounds, one model, one box, one image epoch. This section is the handoff:
it is written to be read by someone who was not here, and it does not assume any
of the rounds above have been read. Where a round's headline was later retracted,
the retraction is here rather than the headline.

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
untouched recipe, and the deep cells at d65536 fell by 4.5-5.7x. Nine of the ten
cells we hold were taken with `recipe.yaml` exactly as it started.

It failed in two distinct ways. First, thin does not mean weak — `ctx_tg` at
d8192/d16384/d32768 c1 are thin-looking on the surface but crowded underneath
(125-130 entries), and we lose all three. Every prefill cell is held by the Atlas
runtime by two orders of magnitude, so those were never reachable. Second, and
more important: **where the incumbent was our own model, the gap turned out to be
config, and probe-only variation could not touch it.** At c2 and c5 the board's
own `Qwen3.6-35B-A3B-NVFP4` on vLLM beat us 2-5x. R10 and R12 then closed most of
that gap with a single scheduler flag the campaign had never moved. So from R9
onward the campaign's largest results came from **mutations**, not from probes —
`tg128 @ d16384 c4` went from 1.13x to 3.15x on `max_num_batched_tokens` alone.

`recipe.yaml` is still untouched, deliberately (see R10's fold argument and R11).
But four headline figures now depend on mutations that are not in it, and that is
an unresolved tension a future session inherits rather than a finished state.

### The standings, wins and losses both

Eight board cells won, twelve lost, and a long tail that cannot be scored because
the board publishes no figure for it. (The wins occupy ten rows in RESULTS.md,
because two of the eight cells carry both a campaign-config and a raised-budget
figure.) Full rows with configurations in `RESULTS.md`;
the shape of it:

- **Widest wins:** `tg128 @ d65536 c1` 94.10 vs 16.48 (**5.71x**),
  `tg32 @ d32768 c1` 115.56 vs 23.31 (**4.96x**), `ctx_tg @ d16384 c4` at the
  raised budget 126.35 vs 27.68 (**4.56x**), `ctx_tg @ d65536 c1` 92.98 vs 20.70
  (**4.49x**), `tg32 @ d16384 c1` 116.43 vs 28.11 (**4.14x**).
- **The transformed cell:** `tg128 @ d16384 c4` — the only contested cell we won
  (8 entries, a real field) — 1.13x on the campaign config, **3.15x** on the
  raised token budget, verified across two engine starts at runs=7.
- **Losses:** `tg128 @ d131072 c1` 0.95x, short by 5.5% (queued as a probable
  loss, run for the curve, never tuned for). `tg128 @ d16384` c2 and c5 at 0.86x
  and 0.57x against the board's own like-for-like entry — improved from 0.51x and
  0.21x, and still losses. `ctx_tg` c1 at d8192/d16384/d32768, 0.61x/0.64x/0.72x.
  All six prefill cells at c1, by 15x-200x. Nine of those twelve losses were
  scored for the first time by this synthesis pass, from a scrape R5b took on
  2026-08-21 that no round ever carried into the standings.
- **Unscoreable:** c8 and c16 at any budget, every `c>1` prefill and context cell,
  and all sixteen R9b rows.

Two of the losing figures and three of the winning ones are still 3-run medians.
They are flagged in `RESULTS.md` and they should be read as provisional, for the
reason the next section gives.

### THE CENTRAL METHODOLOGICAL RESULT — single-invocation controls kept overturning cross-invocation inference

This is what the campaign found out that generalises past this model, this box
and this board. Four times, a conclusion drawn by comparing numbers from
*different benchmark invocations* was overturned by a round that put the compared
quantities under **one engine start**:

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

**And here is the part worth carrying forward as a warning: BOTH retired 3-run
medians were TOO HIGH.** R1's tg32 was 11% above its 7-run value; R3's d65536 was
13% above. That is not chance. A 3-run median at a cell whose σ is ~9% has a
standard error near 6.5%, so draws land on both sides — but a high draw becomes a
claimed win and gets defended, while a low draw looks like a bad run and gets
re-measured. **The sampling error is symmetric and the surviving error is
one-sided.** Any figure in this campaign that was flattering and never repeated
should be assumed high until it is repeated.

Practical form of the rule, for the next campaign: never infer from two numbers
taken under two engine starts if the design can put them under one; declare the
resolution budget and the reading thresholds **before** the run (R8, R9, R9b, R10
and R12 all did, and it is what made their refutations worth anything); and put
an identical-work control (`pp2048`, `ttfr`) in every multi-arm invocation, so the
arm-to-arm systematic is priced instead of assumed away.

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

- `tg128` at d16384, any `c` >= 1: **runs=3** is adequate (σ 0.15-2.6%).
- Anything `tg32`, and anything at **d65536 or deeper**: **runs=7**, non-negotiable.
  R3 skipped this and put a 13%-wrong number in the standings for five rounds.
- Price the round on **the estimator the verdict actually rests on.** R10 needed
  runs=7 not because `tg` is noisy (0.52%) but because `peak_throughput` is
  (3-9%). The sampling budget belongs to the number being read.
- The distribution is a **mode plus low outliers**, not a spread (R8: six runs in
  112.51-114.36, the seventh at 95.56). Medians are the verdict; means are not.

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

**What it implies for the recipe.** The lever is real, verified at runs=7 across
separate engine starts, and it is the difference between 1.13x and 3.15x on our
best contested cell. It is still NOT folded into `recipe.yaml`, for one good
reason: at d16384 a prefill is two chunks at 8192 and one at 32768, so the change
is not inert at c1 either, and the c1 anchor (112.62, pooled over R6+R8) that
every depth and concurrency comparison hangs from was measured at 8192. Folding
without re-measuring that anchor silently creates a new epoch. **R11 is exactly
that measurement and it is the highest-value round left.** Two things must go into
the recipe note whichever way R11 lands: at c2 the hardware ceiling did not move
at all (181 vs 182) while the board metric rose two thirds, so this buys a
*ranking*, not throughput; and **time-to-first-response gets worse at every
concurrency tested** (+7.3% c2, +15.6% c4, +19.8% c5, +32.4% c16 — c16 becomes a
39-second cell). It is a throughput-versus-latency trade and must be written as
one.

**2. Prefix caching has never once hit on this benchmark — and the flag is worth
57% of the headline metric anyway.** vLLM's own counter reads `Prefix cache hit
rate: 0.0%` in all 22 engine samples of R9's A1 and all 92 of R10, **with the flag
ON**; total prompt tokens processed differ by 1.7% between caching on and off. No
prefill work was ever saved. Yet turning the flag off drops `tg` at c4 from 143.08
to 62.13 (**-56.6%**) while `peak_throughput` is identical to the token (297 vs
297) and `pp2048` moves 0.8%. The entire effect is the batch span, and **nobody
knows the mechanism.** The leading suspect is what the source says rides along:
prefix caching off also moves `mamba_block_size` from 16 to `max_model_len`,
changing Gated DeltaNet state granularity for 30 of 40 layers by 2048x.

Two consequences, and both are corrections rather than discoveries:

- **Nothing in this campaign's `c>1` gains should be described as "prefix caching
  working".** It is not working. Something riding along with the flag is, and
  R9c separates them in one invocation.
- **The `ctx_` and cold labels have been backwards since R1.** llama-benchy's
  `ctx_` row is Phase 1, the **context load** — the uncached pass that establishes
  the cache. The rows this campaign calls "cold" are Phase 2, the cache-eligible
  one. And the two phases are charged different prompt-token counts (16384 vs
  2048), so the ~9x `ctx_pp` advantage read at every depth for twelve rounds is
  `16384/2048` and not a cache effect. Every ctx-versus-cold reading in this
  journal before R9b is mislabelled; the `tg` comparisons survive the token-count
  problem but not the labelling.
  **Since measured, not just asserted:** `ctx_pp / pp = (depth+2048)/2048` holds
  in **29 of 30** archived phase pairs across five depths, residuals −0.7% to +3.6%.
  The two phases prefill at the same rate to within 4% and **no prefill speedup
  exists anywhere in this campaign's data.** Two of the 18 are the
  prefix-caching-OFF arms and they do not move, which is an independent proof
  that the cache never hits. Full audit at the end of this file.

### The depth curve, as finally measured

| depth | tg128 c1 median | vs previous | per doubling | source |
|---:|---:|---:|---:|---|
| 16384 | **113.06** | — | — | R8, runs=7, one engine start |
| 65536 | **94.10** | **-16.8%** (4x) | -8.8% | R8, runs=7, same engine start |
| 131072 | 77.13 | **-18.0%** (2x) | -18.0% | R5, runs=3, separate invocation |

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

The d131072 point is a 3-run median from a separate invocation at σ 9.3% — the
same instrument that has now failed twice — so the last leg of the curve is the
least trustworthy part of it.

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
9. "The ctx inversion deepens with depth" — R3, unreproduced. -27% at d32768 (3
   runs, never repeated) is the only surviving evidence; R8 measured -1.2% at
   d65536 and R5 -0.6% at d131072.
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

Note what is NOT on this list: **any board margin.** Both sides of every `ctx_`
comparison are Phase 1 against Phase 1, so the standings are untouched at 8 won
/ 12 lost. Item 7's premise also failed retrospectively — "removing prefill
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
| R12 | 359 s | 1 | ~65k | c2 and c5 transformed; the gap priced as 83-93% stagger | **yes** — the decomposition is worth more than either cell |

**Totals:** ~4,460 s of measurement grid time (≈74 minutes) across 19 engine
starts, of which two produced nothing (R5's aborted invocation, R9's arm B that
refused to start). Roughly 4-5 hours of box wall clock. ~595k harness tokens
across the ten rounds that recorded them. Twenty board cells scored.

**The pattern in that table is the campaign's most reusable cost lesson: the
cheapest rounds were the most valuable ones.** R6 (124 s) and R8 (322 s) each
corrected a headline figure. The two single largest results — what
`tg_throughput` measures, and that prefix caching never hits — **cost zero box
time**, and came from reading llama-benchy's source and a counter that was
already in the engine log. Meanwhile the most expensive round by box time (R5)
and the most expensive by tokens (R9b) produced no claimable cell between them.
**Read the instrument before spending the box.** This queue under-scheduled
control rounds and source-reading for nine rounds running.

### OBSERVATIONS — campaign-wide sweep (per the `observe` skill)

Wider scopes (`stack:`, `box:`, `family:`, `model:`) were recalled before this
pass; most per-round facts were already stored by the round agents and are not
re-stored here. What follows is what was new at campaign level.

**Hardware.** Eleven telemetry sessions across nine rounds agree: SM clock **2392-2398 MHz** median against a reported 3003 MHz ceiling, ≤79 °C, ≤97.3 W, under every load the campaign produced — from a 7-minute shallow grid to 16-way concurrency to a 400-second d131072 run. The clock never moved with temperature or load. R1's outlying 2554 MHz is a bad reading, outnumbered ten to one. *Surprise: none left — this is the campaign's most reproduced fact.* *Headroom: the box runs at 80% of its clock ceiling by policy; if that policy is a fleet-wide arena condition then it is not headroom at all, and if it is local then ~20% of decode is sitting on the table. Nobody has established which, and changing it is Mat's call, not the loop's.* *Blindness: no memory-bandwidth counter was ever sampled — every bandwidth argument in twelve rounds is arithmetic, never measurement, which is precisely why the naive depth model went unchecked for so long.*

**System.** `sparkrun` cannot clear the page cache (no passwordless sudo), so every round in the campaign carries the same uncontrolled cold-read state. Uniform across rounds, so it biases nothing between them, but it is a floor on how quiet any single measurement can be and it is not measured. Image epoch was pinned and identical (`dgx-vllm-eugr-nightly:2026082102`) in all twelve rounds — checked per round in `state.yaml`, which is what makes any cross-round comparison legitimate at all. Note the console line saying it is distributing `:latest` is not evidence of an epoch change; `container_image_longterm_ref` is the field to read.

**Serving stack.** The flag space is far more coupled than the campaign assumed: `--enable-prefix-caching` moves **four** things at once (`mamba_cache_mode`, the chunked-prefill requirement, `mamba_block_size`, and caching itself), and R9 spent an engine start discovering one of those the expensive way. R9b's practice — grep the validators out of the pinned image with a throwaway `docker run --rm --entrypoint bash` before writing the hypothesis — cost two minutes and cleared both arms in advance. Make it the default. *Headroom: `max_num_batched_tokens` is a live and largely unexplored axis; the campaign has measured 8192 and 32768 only, and at c16 even 32768 leaves the gate half-closed (`Running` 11 of 16). A proper curve over 16384/32768/65536/131072 at one concurrency has never been run.* *Blindness: the scheduler log is the primary occupancy instrument and it was LOST in two of the four rounds that planned to use it; the working command is now proven (`docker exec <container> tail -f /tmp/sparkrun_serve.log`, verified live with `grep -c 'Running:'`).*

**Model.** MTP acceptance is now measured against depth (R5), concurrency (R7), the token budget (R10), prefix caching and chunked prefill (R9b). It moves with **depth** and it moves with **concurrency**; it does **not** move with any scheduler knob — flat at 2.85-3.09 acceptance length and 61.7-69.8% across every scheduling change tested, in four consecutive rounds. That is a genuinely useful negative: **MTP acceptance is ruled out as an explanation for anything the scheduler does on this model**, which is why every c>1 result in this campaign resolves to admission behaviour. *Headroom, and it is the largest un-taken lever in the campaign: acceptance collapses from 93.6% to 47.7% between d16384 and d131072, and with `num_speculative_tokens=3` halving acceptance roughly halves tokens per verify step. The MTP module ships BF16 in every Qwen3.6-35B quant arm, so it is a full-precision draft head being asked to draft over long contexts. Calibrating or fine-tuning it on long-context text is a quality-neutral throughput lever — needs a training-infra decision, and is out of scope for this loop.*

**Workload and measurement.** The benchmark did not measure what the campaign thought, in three separate ways, and each was found by reading rather than by benchmarking: `tg_throughput` is a batch aggregate charged for admission stagger (R10); the `ctx_`/cold phase labels are inverted and the two phases are charged different token counts (R9b); prefix caching never hits (R9b). *Surprise: the headline metric is a **scheduling** measurement wearing a throughput's units — R12 moved it +67.6% at c2 while the sustained hardware ceiling moved -0.5%.* *Blindness, and this is the sharpest one left: the prefill cells. Our `pp2048 @ d32768 c1` reads 295.71 against 4644.54 for another vLLM NVFP4 entry in the same board cell — a 15x gap — while our decode rate sits within 3% of what a like-for-like incumbent's headline requires. A 15x like-for-like gap in one metric family and a 3% gap in another is the signature of a definition mismatch, not of a slow box, and nobody has read `pp_throughput`'s definition or the board's prefill test-type mapping.*

**Process and cost.** Covered in the ledger above. One addition: the campaign's own predictions got sharply better once they were built by **decomposing the metric** rather than by scaling the previous round's percentages — R12 was the first round where both headline bands held, and it built them from `tg = c x tg_req / stagger`. R10 and R12 both wrote the same post-mortem: *the mechanism section was right and the numeric band was wrong, in the same document*, because the band was set by scaling while the generating model sat one paragraph above. That is a repeatable failure and it has a repeatable fix.

Memories written by this pass (widest true scope, deduped against existing):
one `stack:vllm` lesson on cross-invocation inference and the one-sided
survival of flattering draws; one `stack:vllm` lesson on reading the
instrument's source before spending the box; one `stack:vllm` idea on the
unexplained prefill gap; one `box:spark-6f0e` lesson that twelve rounds found
no hardware-limited effect; one `family:` retraction covering the ctx-vs-cold
regularities; and one campaign `[COST]` total.

### Open questions that are genuinely still open

1. **Why is `--enable-prefix-caching` worth 57% of the headline metric when it
   never hits?** Zero cache hits, identical prompt-token work, identical
   `peak_throughput`, and the entire difference in the batch span. The suspect is
   `mamba_block_size` 16 -> 32768 riding along with the flag. Separable in one
   invocation (**R9c**). Either answer reprices every `c>1` figure the campaign
   has.
2. ~~**Why does removing prefill work make the batch stagger WORSE?**~~
   **CLOSED — the question is dissolved, not answered.** It presupposed that the
   `ctx_` phase removes prefill work. It does not: `ctx_` is Phase 1, the
   context load, which prefills `depth` tokens against Phase 2's `depth + 2048`.
   The regularity underneath it (1.17 vs 1.13, 1.80 vs 1.57, 2.12 vs 1.70) was
   separately **refuted by R13** at `mnbt 98304`, where Phase 1 staggers LESS at
   both arms. Both halves gone. **Do not spend a cell here and do not pose a
   third form of it.** The `ctx_` cells remain real board cells worth winning —
   one of them, `ctx_tg @ d16384 c4`, is the campaign's widest margin at 6.16x.
3. **What accounts for the two thirds of the depth term the bandwidth model does
   not predict, and what makes the curve steepen?** -16.8% measured against -44.8%
   naive. MTP acceptance decay is the candidate and has never been measured
   unconfounded across depths.
4. **Is our `pp_throughput` the same quantity the board ranks?** A 15x
   like-for-like gap says probably not. Zero box time to check.
5. **Does the c16 aggregate keep climbing past 16?** Still climbing at +24% (c8
   -> c16) and the gate is only half-open even at mnbt 32768. c32 is a
   one-invocation question but should not be run until the budget question is
   settled, or it measures the same gate again.
6. **Is the box's 80%-of-ceiling clock a fleet-wide arena condition or a local
   one?** Closed as a *measurement* question — the clock is flat policy — but the
   headroom question behind it was never asked of anyone who would know.

### What to run next, in priority order

1. **R11 — the fold decision.** Re-measure `tg128 @ d16384 c1, runs=7, -o
   max_num_batched_tokens=32768` and compare against the pooled 112.62 anchor. If
   c1 is unchanged within noise, fold the flag into `recipe.yaml` and restate the
   c4 win as the campaign's headline; if it moves, the flag stays a per-round
   mutation and every `c>1` row keeps naming its configuration. **A verified 2.8x
   on our most contested cell is waiting behind this, and four headline figures
   currently sit outside the recipe.** ~120 s of grid time.
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
3. **R9c — separate prefix caching from `mamba_block_size`.** One engine start,
   c4 only, runs=3, ~115 s: prefix caching off with an explicit `-o
   mamba_block_size=16`. Check the validators from the image first. If `tg`
   returns toward 143 the effect is the block size and prefix caching is a red
   herring.
4. **R13 — c5 at `max_num_batched_tokens 81920`.** The only cell with a live
   route to a win: c5's gap is 93% admission stagger, and 81920 admits the whole
   5-request batch in one step, the configuration that gave c2 its 1.13 stagger.
   Needs `-o max_model_len=81920` as a second mutation; state the discriminator
   (does `tg_req` lift when the prefill stops being split?) before running.
5. **R8c — re-measure `ctx_tg @ d32768 c1` and its cold arm at runs=7.** The
   -27% inversion is the only surviving deep inversion and it is a 3-run figure
   from the instrument that has since failed at two other depths. Cheap.
6. **R8b's acceptance-vs-depth measurement**, riding along with any deep round —
   d16384 and d65536 under one engine start with the engine log captured. It is
   the missing half of open question 3 and it costs nothing extra now that the
   capture command is proven.

Not worth running: anything at d131072 (~8x R3's box time, the cell is lost and
was never tunable within the campaign's rules); c32 before the budget question is
settled; and any further round premised on the `ctx_` rows being the cached pass.

### HANDOFF

A new session should start here, and then read **THE `ctx_` PHASE-LABEL
CORRECTION** at the very end of this file before touching any `ctx_` figure —
it post-dates this synthesis and retires five more claims. The state is: `recipe.yaml`
**untouched** and identical to the one the campaign opened with; twelve rounds
archived under `experiments/`; `RESULTS.md` carrying eight won cells, twelve lost and
the unscoreable remainder, with every row naming its configuration; four headline
figures depending on mutations that are deliberately not in the recipe; and one
image epoch throughout, so every number in the file is comparable to every other.
The single most consequential thing outstanding is **R11**, because it decides
whether the token-budget lever — the largest effect the campaign found, worth
1.13x -> 3.15x on our best contested cell — becomes the config or stays a
footnote. Run it first, before any new cell. Then spend the zero-box-time items
(the prefill metric check) while the next benchmark runs, because this campaign's
record is unambiguous that reading the instrument beats measuring around it. And
carry the one rule that would have saved the most rounds: **put the compared
quantities under one engine start, declare the thresholds before the run, and
treat any flattering figure that was never repeated as too high.**

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
**6.15x**, comfortably past `tg128 @ d65536 c1`'s 5.71x.

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
which is still the campaign's widest), the budget response was curved for the
first time and knees at 65536 — so R13's 98304 buys nothing and R11's fold value
is 65536 — and six-for-six low reproductions put a measured ~2% error bar on
every figure this campaign has taken exactly once.**
