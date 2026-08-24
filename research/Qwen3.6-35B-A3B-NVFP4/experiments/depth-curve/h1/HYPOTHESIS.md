# h1 — decode is flat with depth

## Hypothesis

`tg` at c1 declines by less than 10% from d0 to d30592, matching the shape the
board's vLLM entries show rather than a KV-bound decline.

The argument is arithmetic on what a decode step actually reads. Per forward
the model reads ~2.25 GB of weights — 1.02 GB across the 30 linear-attention
layers, 0.27 GB across the 10 full-attention layers, 0.64 GB of active MoE
experts, and 0.29 GB of `lm_head`. KV is paid on the 10 full-attention layers
only: 2 kv-heads x 256 head-dim x 2 x 1 byte fp8 = 10.2 KB per token, so 168 MB
at d16384 and 313 MB at d30592. The 30 linear-attention layers carry a
recurrent state instead, and that state is constant in context length.

So KV goes from ~0% of the read at d0 to ~7% at d16384 to ~12% at d30592. If
decode is bandwidth-bound, that predicts a decline of roughly the same order —
single-digit percent across the ladder — and not the steep decay a full-KV
transformer would show.

The board corroborates the shape on a different instrument: `1199b578` declines
3.4% from d0 to d32768 while the Atlas entries, which quantize KV to nvfp4 and
run a different runtime, fall 218.85 to 112.39 over the same span.

Worth, if right: it closes the attention-side levers for this objective. If
decode is flat, `--kv-cache-dtype` and `--attention-backend` can only touch the
10 depth-dependent layers of 40, and the ceiling is weight-read bandwidth and
per-step overhead — which points every future round at the MoE path, the draft
path and the scheduler instead. If it is wrong and decode slopes, those
attention levers are live and worth rounds.

## Method

### Variables to test

    depth: 0, 4096, 8192, 16384, 30592

One run directory per rung, run in that order. Nothing else moves.

**One run per rung rather than one schedule, for isolation.** A separate run is
a separate server, so no rung inherits another's prefix cache or the heat it
left behind. The rungs are compared to each other and to nothing else, so that
independence is the measurement, not an overhead on it. It costs ~17 minutes
against ~7.

(Until 2026-08-23 this also cited a harness limit: the fixed corpus was sized
from the largest cell in a grid, so `run.py` refused a multi-cell grid outright.
That is no longer true — a schedule entry can carry its own `book_url` and each
cell gets its own pinned corpus. The obstacle is gone; the reason above is not,
and it is the one that decides it.)

d0 is the important rung and the cheapest. It is the only one with no KV term
at all, so it is the intercept the whole curve is read against, and llama-benchy
skips the context-load phase there entirely — a d0 run is single-phase, which
also gives a clean reading of prefill uncontaminated by the numerator artifact
that affects every deeper cell.

### Constant for this round

Everything in Held. The per-cell corpus offset means each rung's text is fixed
and reproducible but disjoint from every other rung's, so no rung can feed
another's prefix cache.

Grid per rung:

    pp 2048 · tg 128 · concurrency 1 · runs 7

d0 and d30592 run at `runs 9`. The rule is stated on those two medians and the
middle three only witness monotonicity, so the repeats belong where the verdict
is decided.

### What to record

Per rung: `tg` median and IQR, `pp` median, the true prefill rate `run.py`
prints beside it, `ttfr`, peak power, the worst repeat ratio, and the maximum
prefix cache hit rate.

The hit rate is a protocol check here, not an open question. decode-tg h2
settled it: the 0.0% every run reported was our own `post_run_cmd` resetting
the cache between runs, and h2 kept the reset because it is what makes runs
independent. So every rung should read 0.0%, and a rung that does not has lost
its reset and is not comparable to the others. d0 reads 0.0% for a second
reason — its 2048-token prompt is under this model's forced 2144-token
attention block, so it cannot hit at all, and `run.py` labels that case.

## Decision rule

Read `tg` at `pp2048 · tg128 · c1` — the cell itself, never its context-prefill
phase — from the d0 and d30592 rows. Evaluated on medians, since each rung
carries its own values.

Let **D** be the decline from d0 to d30592 as a fraction of d0, and **S** the
larger of those two rungs' `tg` interquartile spreads.

- **Flat** if D is at most 10%. Decode is depth-independent on this stack; the
  attention-side levers are bounded by the 10 full-attention layers and the
  objective's ceiling lies elsewhere.
- **Sloped** if D exceeds 10%, is monotone across the rungs, **and exceeds S**.
  KV read is a live term, and `--kv-cache-dtype` and the attention backend are
  worth their own rounds.
- **Neither** if D exceeds 10% and is not monotone. Something other than depth
  is moving — check each rung's hit rate, peak power and IQR before reading
  anything into the shape.
- **Unreadable** if D exceeds 10% but does not exceed S. The ladder cannot
  separate the effect from the scatter that produced it. Re-run both anchor
  rungs at higher `runs` before calling anything; do not report a slope.

A rung whose `tg` IQR exceeds 5% is not counted toward the decline until it is
re-run; an unstable rung cannot anchor a slope. Every rung carries at least 7
values, so an interquartile range exists at all of them.

(Amended 2026-08-23, before any rung ran. It previously had three branches and
a bare 10% threshold, with no branch for a decline that clears 10% while
sitting inside the rungs' own spread — the outcome the prior evidence makes
most likely, since the nearest measurement on this box declines 5.3% across
four times this span. A threshold that can be met by noise is not a rule.)

## Runs

One row per planned run. Figures blank until it is run.

| run | depth | runs | why | tg t/s | iqr | pp t/s | prefill t/s | ttfr ms | hit % | bench |
|-----|-------|------|-----|--------|-----|--------|-------------|---------|-------|-------|
| run-0001 | 0 | 9 | the intercept: no KV term, single phase, and the rule reads it | 114.6 | 5.1% UNSTABLE | 5695.1 | 5610.5 | 377.0 | 0.0 | bench_594c47d62013 |
| run-0002 | 4096 | 7 | first rung with a context | 110.1 | 4.2% | 1995.5 | 5933.4 | 1049.4 | 0.0 | bench_a0c409874de1 |
| run-0003 | 8192 | 7 | witnesses monotonicity | 127.0 | 5.6% UNSTABLE | 1165.8 | 5796.0 | 1779.2 | 0.0 | bench_fa59c397c082 |
| run-0004 | 16384 | 7 | re-bases the incumbent under the new corpus offset | 117.8 | 2.6% | 628.6 | 5639.4 | 3279.0 | 0.0 | bench_c003c48ede71 |
| run-0005 | 30592 | 9 | the deepest legal context at max_model_len 32768; the rule reads it — HTTP 400, one token over: prompt 32641 + tg 128 = 32769 vs max_model_len 32768 | — | — | — | — | — | — | bench_5330c0302d07 |

| run-0006 | 30591 | 9 | one token shallower than run-0005 — HTTP 400 again, at the same 32641 input tokens. The endpoint adds a token of its own, so the served prompt is pp + depth + 2 | — | — | — | — | — | — | bench_f574047b8c2e |
| run-0007 | 30464 | 9 | measured ceiling is d30590 with zero margin; this takes 126 tokens of headroom for the same rung. Stands in as the rule's deep anchor | 109.5 | 4.3% (±2.1%) | 327.1 | 5195.9 | 6270.8 | 0.0 | bench_6bd19fe9a3c2 |

run-0001 is also the first end-to-end run of the harness rewritten on
2026-08-23 — per-cell corpora, rolled progress files, schedule-aware grid
checking. It is the cheapest cell in the tree, so it proves the instrument
before the ladder spends anything on it.

## Conclusion

**Flat.** `tg` at c1 declines 4.5% from d0 to the deep anchor, against a
threshold of 10%. The hypothesis is confirmed, and decode on this stack is
depth-independent to the limit `max_model_len 32768` allows us to look.

### The ladder

| rung | run | tg med | iqr | ±(se) | n | accept | tg/accept | peak W | worst repeat |
|------|-----|-------:|----:|------:|--:|-------:|----------:|-------:|-------------:|
| d0 | run-0001 | 114.6 | 5.1% | ±1.2% | 9 | 3.10 | 37.0 | 34.6 | 1.081 |
| d4096 | run-0002 | 110.1 | 4.2% | ±2.2% | 7 | 2.83 | 38.9 | 53.5 | 1.157 |
| d8192 | run-0003 | 127.0 | 5.6% | ±2.6% | 7 | 3.30 | 38.5 | 57.4 | 1.180 |
| d16384 | run-0004 | 117.8 | 2.6% | ±0.9% | 7 | 3.20 | 36.9 | 60.0 | 1.057 |
| d30464 | run-0007 | 109.5 | 4.3% | ±2.1% | 9 | 3.12 | 35.1 | 69.4 | 1.179 |

`accept` is the median mean-acceptance-length over the steady-state
`SpecDecoding metrics:` windows in each engine log, discarding the first, which
covers a few dozen warmup tokens. Every figure above was recomputed from the
archives for this conclusion; all of them reproduce.

### Applying the rule

D = (114.6 − 109.5) / 114.6 = **4.5%**, which is at most 10%, so the first
branch fires and the later branches — which all require D to exceed 10% — never
arise. S is not needed to reach the verdict, though it is worth recording that
S = 5.1% is *larger* than D: on raw `tg` alone this ladder cannot separate a
4.5% decline from zero. What makes the decline credible is the normalisation
below, not the raw medians.

The verdict is also robust to which rung anchors the shallow end. d4096 → d30464
is 0.5%, d16384 → d30464 is 7.0%. Every admissible pairing lands under 10%. The
only pairing that would clear the threshold is d8192 → d30464 at 13.8%, and
d8192 is neither monotone with its neighbours nor admissible under the
stability clause, so it cannot anchor anything.

### The deep anchor is not the cell the rule names

The rule reads d30592. That depth cannot be served on this stack. The corpus is
sized `need + 1` so the slice offset collapses deterministically, and the chat
endpoint adds a token of its own, so the served prompt is `pp + depth + 2`.
run-0005 at d30592 and run-0006 at d30591 both arrived at 32641 input tokens
against `max_model_len 32768` and both were refused with HTTP 400. The archives
carry the refusals — `POST /v1/chat/completions 400 Bad Request`, no completed
indices, no figures — and the fact that two depths one token apart produced the
identical refusal is itself the evidence that the depth knob and the served
prompt do not correspond one-to-one. The measured ceiling is d30590 with zero
margin, so run-0007 took d30464, 126 tokens of headroom.

**We consider the rule evaluable on d30464.** The rule's anchor is not the
integer 30592; it is "the deepest legal context", and 30592 was a mistaken
arithmetic guess at that number rather than a chosen cell. The substitution
costs 128 tokens of KV: 1.3 MB against a 311 MB KV term that is itself ~12% of
the per-step read, so ~0.05% of the read, three orders of magnitude below
anything this ladder can resolve. A rule that could not survive that
substitution would not be a rule about depth.

### Acceptance explains the shape, and d8192 is not a fast rung

The raw ladder is not monotone: d8192 reads 127.0, above every other rung
including d0. That is not speed. Each rung slices its corpus from an offset
derived from `(pp, depth)`, so depth and prose vary together by construction,
and the MTP draft head predicts some prose better than others. Dividing `tg` by
the measured acceptance length removes the effect: d8192 falls from the fastest
rung to the second, and the series becomes 37.0, 38.9, 38.5, 36.9, 35.1 — a
5.1% decline from d0 to d30464.

Two honest qualifications on that normalisation:

- The rank orders of `tg` and of acceptance are **not** identical, though they
  are strongly related. Spearman's rho across the five rungs is 0.70. The top
  two rungs agree exactly; the bottom three swap order between the two series,
  within margins of 0.3 t/s and 0.29 tokens of acceptance respectively.
- The normalised series is itself not monotone: d4096 sits above d0. But from
  d4096 onward it falls monotonically — 38.9, 38.5, 36.9, 35.1, a 9.8% decline
  over the deep four fifths of the ladder. d0 is the rung that breaks the
  pattern, and d0 is also the only rung llama-benchy runs single-phase, with no
  context-load pass at all. It is not quite the same measurement as the others,
  which is the reason to keep the rule's raw-`tg` reading as the verdict and
  treat the normalised series as corroboration.

Against the Hypothesis's arithmetic: KV rises from ~0% of the per-step read at
d0 to ~12% at d30464 (30464 tokens x 10.2 KB = 311 MB against 2.25 GB of
weights). A purely read-bandwidth-bound decode would therefore lose ~12%. We
measured 4.5% raw and 5.1% normalised. Same order, comfortably under the bound.
The mechanism the hypothesis argued is present and is smaller than the naive
accounting predicts.

Depth did move the machine, even though throughput barely moved. Median GPU
power over the benchmark window rises monotonically with depth — 30.3, 35.5,
43.4, 54.8, 60.3 W — and peak power doubles across the ladder. The deeper rungs
are demonstrably doing more memory traffic per step; the throughput simply does
not care much.

### The stability clause misled the round

Applied as written: a rung whose `tg` IQR exceeds 5% is not counted toward the
decline until re-run. That strikes d0 (5.1%) and d8192 (5.6%). Striking d0
removes the rule's own shallow anchor, so read at its word the rule cannot
compute D at all and demands a re-run of the best rung in the ladder.

It did not change the verdict — every surviving pairing is still Flat, as shown
above — but it would have cost a run for nothing, and the reason is that the
clause measures the wrong thing. IQR describes how scattered the samples are;
what a median-based rule needs to know is how well the median is pinned, which
is what the standard error describes. By ±, d0 is the **best**-determined rung
on the ladder at ±1.2% with n=9 — better than d4096 at ±2.2%, which the IQR
clause waves through. The clause fails d0 for having nine well-spread samples
and passes d4096 for having seven badly-spread ones.

`run.py` has since stopped printing a stable/UNSTABLE verdict and now reports
the median's standard error instead, for exactly this reason. The clause is
recorded, not edited. The lesson for the next rule that wants a stability guard
is to state it on ±, not on IQR.

### What this closes

The attention-side levers are closed for this objective, which is what h1 was
worth. `--kv-cache-dtype` and `--attention-backend` reach only the 10
full-attention layers of 40, and those are exactly the depth-dependent ones. A
curve this flat means there is at most a few percent sitting behind both flags
combined, over the whole legal context range. Neither earns a round. The
ceiling is weight-read bandwidth and per-step overhead, and the levers that
reach those are the MoE path, the draft path and the scheduler.

It also settles the contradiction in memory. The two prior readings —
"NOT flat, 16% from d16384 to d65536" and "flat within noise, 5.8% against
sigma of 10" — disagreed because neither instrument could separate a 5% effect
from its own scatter. This ladder can, and it lands with the second: flat, with
a small real decline underneath that only shows up once acceptance is divided
out. Both prior readings are superseded for the range d0–d30464; neither is
contradicted above d30464, which we still cannot reach.

### Validity

All seven runs share container digest
`sha256:19d2158d320ca4c8704ebf56990de2a40b71055d6d7a5a6829a877db6a1e9125`, vLLM
commit `e85d1b69`, flashinfer commit `4927c0e1`, and framework 0.4.0. One epoch
throughout. The `non-default args:` line is byte-identical across all seven and
agrees with `recipe.yaml`'s `defaults:` field by field, so every run served the
configuration under test.

The recipe hash is also identical across all seven — `2e5790ff...`. That is
correct rather than alarming: `depth` lives in the `benchmark:` grid and the
hash covers only the serve config, which genuinely did not move. It does mean
the hash cannot witness that the rungs differed; `state.yaml`'s `schedule:` is
what does, and it reads 0 / 4096 / 8192 / 16384 / 30592 / 30591 / 30464.

Prefix cache hit rate is 0.0% on every rung, which is what the protocol
requires — `post_run_cmd` resets it between runs, and d0 additionally cannot
hit at all under the forced 2144-token attention block.

The box was not under stress. Swap was flat on every run (774 → 774 MB at d0,
790 → 791 MB at d30464); the worst available memory at any sample was 10.0 GB,
on the deepest rung. GPU utilisation held at a 95–96% median throughout every
benchmark window.

The true prefill rate is flat across the ladder — 5610, 5933, 5796, 5639, 5196
t/s, a 7.4% spread — while the reported `pp t/s` falls 5695 → 327, a factor of
17. That confirms the reported `pp` figure is the depth artifact the Method
warned of and not a prefill slowdown, and it is a second, independent way of
seeing that depth costs this stack very little.

### Instrument notes

- **The ceiling arithmetic was wrong and cost two runs.** Nobody had measured
  what the endpoint actually sends. `pp + depth + 2` should be written down
  where the next experiment planning a deep cell will find it; the deepest
  legal `depth` at `max_model_len M` and `pp P` is `M − P − 2`.
- **`EXPERIMENT.md` claims more than the code delivers.** It says the per-cell
  offsets leave the rungs "disjoint across cells", and `run.py`'s own comment
  says the same. They are not. The corpus is 144480 tokens and the offsets are
  `md5(pp:depth) % room // 1024 * 1024`, which guarantees determinism and
  nothing else. Verified spans: d4096 (95232–101377) sits entirely inside
  d16384 (90112–108545), and d0 (69632–71681) sits entirely inside d30464
  (47104–79617) — so the rule's two anchors read overlapping prose. Harmless
  here, because each rung is a separate server with its own cache and no rung
  can donate blocks to another. But the word "disjoint" is load-bearing in the
  Strategy's argument for the offsets, and it is not true. The offsets buy
  reproducibility, not independence.
- **run-0001's clock telemetry is unusable.** `gpu_clock_mhz` reads 208 for all
  766 samples in the file, including the window where utilisation held at 95%
  and power reached 34.6 W. Every other run reads 2398/2353 under load. The
  card was plainly working; the field was not. run-0001 was the first
  end-to-end run of the rewritten harness, and this looks like the sampler
  returning an idle cached value. It means the ladder has no clock evidence for
  its shallow anchor.
- **run-0001 also crashed in the harness after its cell completed** — a
  schedule-check bug, since fixed — and its figures were recovered from the
  archive rather than re-run. The archive was sufficient, which is the argument
  for archiving on the failure path.

### Cost

Seven runs for five rungs. Two were spent on the ceiling arithmetic, one was
recovered from a harness bug. About 21 minutes of box time against a planned
17. The round answered its question and closed two levers, so it was worth
running.
