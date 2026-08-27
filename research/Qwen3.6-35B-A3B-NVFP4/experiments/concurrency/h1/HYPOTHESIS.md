# h1 — our token budget is twice the reference's and starves decode under load

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**Lever spent** — c10 falls monotonically as the token budget falls, 49.0 →
48.0 → 44.2, so the hypothesis is refuted with the sign reversed.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c10 | — | 49.0 ±0.3% | — | bench_685e42bde522 |
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c1 | — | 96.0 ±4.1% (n=7) | — | bench_685e42bde522 |
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c5 | — | 84.3 ±0.6% | — | bench_685e42bde522 |
| run-0001 | baseline, `mnbt` 65536 | the control, on this screen's schedule | d16384 c2 | — | 136.1 ±1.6% | — | bench_685e42bde522 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c10 | — | 48.0 ±0.6% | — | bench_da8989775690 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c1 | — | 107.2 ±4.1% (n=7) | — | bench_da8989775690 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c5 | — | 80.8 ±0.5% | — | bench_da8989775690 |
| run-0002 | `mnbt` 65536 → 32768 | the reference recipe's value | d16384 c2 | — | 131.3 ±2.9% | — | bench_da8989775690 |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | d16384 c10 | — | 44.2 ±0.5% | — | bench_fbb28a3df00f |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | d16384 c1 | — | 106.2 ±2.9% (n=7) | — | bench_fbb28a3df00f |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone — this cell is DAMAGED, do not quote | d16384 c5 | — | 61.3 | — | bench_fbb28a3df00f |
| run-0003 | `mnbt` 65536 → 16384 | is the mechanism monotone | d16384 c2 | — | 130.5 ±1.6% | — | bench_fbb28a3df00f |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Lowering `max_num_batched_tokens` 65536 → 32768 raises `tg` at `d16384 c10`
above h5's 48.9 without dropping `d16384 c1` below 103.7. Mechanism: prefill and
decode compete for one step budget; at c10 ten 18432-token prompts queue against
four slots, so one 65536-token step swallows three and a half while decode waits.

Worth, if right: the c10 deficit is 53.4 t/s against the board's 102.31 — the
largest field difference left, and the only one acting on aggregate decode under
queueing. Memory calls a large budget good for throughput, so the sign may flip.

## Method

### Variables to test

    max_num_batched_tokens: 65536 (control) -> 32768 -> 16384

Order: control first, one arm per run; 16384 tests monotonicity.

### Constant for this round

Everything else in `recipe.yaml`, byte for byte: `max_model_len 262144`,
`gpu_memory_utilization 0.8`, `max_num_seqs 4`, same serve command and sampling,
MTP depth 3 on triton. **`max_num_seqs` does not move** — two scheduler fields
at once confound both. Acceptance, prefix cache and KV capacity are ruled out in
advance and captured only as controls; c5 sits below trend at four slots.

Grid, from the recipe's `benchmark:` block — a reduced screen, **not
board-comparable**:

    depth 16384 · concurrency 1, 10, 5, 2 · runs 7, 3, 3, 3

## Decision rule

Read `d16384 c10` and `d16384 c1`, aggregate `tg` medians, from each arm.

- **Target met** — c10 exceeds 102.31 *and* c1 holds at or above 102.8. Then
  the field carries the whole gap on its own, which would be surprising; go
  straight to a full 28-cell arena run to earn the board-comparable figure.
- **Lever alive** — c10 rises more than 5% over the control and c1 holds at or
  above 102.8, but c10 is still below 102.31. The mechanism is real and
  partially spent; the remaining reference diffs are worth taking next, and
  this field's best value carries forward.
- **Lever spent** — c10 moves less than 5% either way, or it rises while c1
  falls below 102.8. In the second case the field is a genuine trade rather
  than a free win, the guard governs, and the control value stands.

Sized against h5's scatter at these cells, ±0.5% at c10 and ±5.2% at c1, the c1
floor one scatter width below h5's 103.7. The rule reads **aggregate** `tg`,
what the board scores; `tg/req` carries iqr to 141.6% here and no branch may be
read on it. Three values per arm means no iqr, hence medians and a 5% threshold.

## Conclusion

**Lever spent, sign reversed.** c10 falls monotonically as the budget falls,
49.0 → 48.0 → 44.2 (arms tight at ±0.3/0.6/0.5%, n=3): the prefill-hogs-the-
budget mechanism is refuted, not unproven, and the control's 65536 stands. The
32768 arm's −2.0% fires *lever spent*; the 16384 arm's −9.8% is outside every
clause verbatim, the rule having written no branch for a large fall.

Three caveats, without which this misleads. The rule is **mis-specified** — its
c1 guard of 102.8 came from another schedule against a control of 96.0, so only
*lever spent* could ever fire — and is recorded as written, not repaired. Every
figure is **cold-cache**, prefix cache 0.0%. The c1 step 96.0 → 107.2 → 106.2 is
**unresolved**, the cell drifting 19% within itself; no later round may rest on
it. The round's reasoning is in the memory store — every record carries
`concurrency/h1` in its `basis`.
