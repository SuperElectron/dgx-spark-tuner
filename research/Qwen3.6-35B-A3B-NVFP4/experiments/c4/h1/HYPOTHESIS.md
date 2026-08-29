# h1 — the tuned recipe, unchanged, run at the concurrency nobody measures

This file is the contract for the round: hypothesis, method, decision rule,
and runs. It is not the notebook — per-round analysis belongs in the memory
store, not here.

## Verdict

TARGET MET — all five cells clear their leader; d0 212.66 t/s against 82.85.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

`recipe-new.yaml`, run unchanged at concurrency 4, already exceeds every
published c4 leader at d0, d4096, d8192 and d16384 — no lever required.

The mechanism is not ours; it is the field's. arena-v2's profile is
concurrency `1/2/5/10` (`26121b1f`), so a c4 submission requires deliberately
stepping outside the standard profile and almost nobody has. The cells hold 4
to 8 entrants against 140-260 in the c10 cells, and the incumbents are large
slow-decode models — Qwen3.5-122B-A10B-int4 and Gemma-4-26B-A4B — measured at a
concurrency their own recipes were not tuned for either. A 35B MoE with ~3B
active parameters decodes far faster than a 122B dense-ish model regardless of
tuning, and that architectural gap is what the figures below rest on.

Worth, if right: the c2 and c5 columns we measured on 2026-08-24 bracket c4 at
146.57/211.29 (d0), 135.69/182.79 (d4096), 140.65/183.14 (d8192) and
135.68/177.23 (d16384). Linear interpolation puts c4 at roughly 179, 159, 162
and 156 against board tops of 82.85, 54.54, 44.29 and 46.68 — margins of
+116%, +192%, +266% and +234%. Even the *lower bracket* — the c2 figure, which
c4 cannot plausibly fall below on a monotone interval — clears every one of
those four leaders. That is what makes the round worth running as a control
rather than as a tuning arm.

d32768 is excluded from this arithmetic. Its c5 figure (125.87) has already
fallen below its c2 figure (128.58), so the interval is not monotone and
interpolation says nothing. Its c2 value of 128.58 against a board top of 36.51
suggests a win, but the round measures it rather than predicting it.

## Method

### Variables to test

    none — this is a control

The recipe is `research/Qwen3.6-35B-A3B-NVFP4/experiments/concurrency/recipe-new.yaml`
copied unchanged, with one edit confined to the `benchmark:` block:
`concurrency: [4]` in place of `[1, 2, 5, 10]`. No `defaults:` field moves.

Order: single run. If it fails to clear a cell, the failing cell chooses the
lever for h2, and that lever must name a mechanism other than admission —
`00b3d74d` predicts `max_num_seqs` is null at c4 and `1084d7c0` removes the
capture-size rationale for it.

### Constant for this round

Every `defaults:` field: `max_num_seqs 10`, `max_num_batched_tokens 65536`,
`gpu_memory_utilization`, `max_model_len`, the mtp speculative config at 3
tokens, `async-scheduling`, `enable-prefix-caching`, `kv-cache-dtype fp8`,
`attention-backend flashinfer`, `moe-backend marlin`, `load-format
fastsafetensors`.

`max_num_batched_tokens` stays at 65536 deliberately: at c4/d32768 the demand
is 4x34816 = 139,264 tokens, about 2.1 steps at that budget, which `a2f190d6`
measured as already inside the saturating regime for this model.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 0, 4096, 8192, 16384, 32768 · concurrency 4 · runs 3

Three runs because `8950a696` measured, at c4 on this model, that the
4-sequence average holds sigma under 1.5% at runs=3 — even though individual
per-request values span 5.4x inside a single run.

## Decision rule

Read on the mean of `tg128 (c4)` per cell, n=3, against the live board figures
in the Objective, re-read immediately before any claim.

- **Target met** if all five cells clear their leader by more than 3%.
- **Lever alive** if d0 clears its leader but any of the other four does not.
  The Objective's primary cell is won and the failing cells name h2's lever.
- **Lever spent** if d0 fails to clear 82.85. That would mean the c2/c5
  bracket does not transfer to c4 at all, and the interpolation this round
  rests on is wrong — in which case no lever chosen from that arithmetic is
  worth running, and h2 must start from the measured c4 row instead.

3% is the tie band: it exceeds c4's measured 1.5% sigma with room, and every
figure here is a with-MTP figure, where MTP is the dominant term in tg spread
(`309b7175`). A margin inside 3% is not a result whatever the medians say.

A caveat this rule cannot resolve: `187c85b1` records that margins computed
from a stale five-entry scrape were voided once already. The Objective's
figures are a live 2026-08-29T13:00:07Z read, and they must be re-read before
anything is claimed or submitted, not because the rule is soft but because the
board regenerates every 30 minutes.

## Conclusion

Target met on the control, with no lever spent. `recipe-new.yaml` run
unchanged at c4 gives 212.66 / 182.89 / 178.62 / 173.51 / 138.89 t/s across
d0 / d4096 / d8192 / d16384 / d32768, against leaders of 82.85 / 54.54 /
44.29 / 46.68 / 36.51 — margins of +157% to +303%, every one far outside the
3% band. `served matches recipe defaults (6 fields)`; no field moved.

The hypothesis held for the reason it argued: the queue read max Running 4,
max Waiting 0, so all four offered requests were admitted and nothing
competed for slots. That also confirms `00b3d74d` prospectively — the
`max_num_seqs` lever has nothing to act on at c4.

Two things the round did not predict. d32768 measured 138.89, above both its
c2 (128.58) and c5 (125.87) brackets, so the non-monotone interval resolved
upward rather than being unreadable. And the served cudagraph list was
[1,2,4,8,16,24,32,40,48,56,64,72,80], which is not `1084d7c0`'s
truncate-at-2xmns rule; that memory is bounded to the model it was read on.

Scatter ran above Strategy's figure — cv 5.2% at d4096 against the 1.5%
`8950a696` recorded at c4. Margins this size are unaffected, but a later
round reading a small effect at c4 must re-measure the spread first.

Budget: 15 lines. State which of the three the decision rule gave and the
number that decided it; anything beyond that — per-run analysis, discarded
theories, exploratory reasoning — goes to the memory store, not here. 15
lines is enough to name the verdict, the deciding figure, and one line of
why; it is not enough to re-derive the round.
