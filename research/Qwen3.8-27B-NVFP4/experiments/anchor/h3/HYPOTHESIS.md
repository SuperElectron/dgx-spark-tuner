# h3 — `--language-model-only`, the memory the vision tower is holding

## Verdict

<one line, filled at conclusion: TARGET MET / LEVER ALIVE / LEVER SPENT — the
number that decided it>

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | language_model_only: absent -> true (at max_num_batched_tokens 65536) | h2 closed LEVER SPENT at 36.56 on a memory ceiling, not an exhausted mechanism. This isolates the flag against h2 run-0002 at an identical budget | d16384 c10 | 126.74 | 36.96 | 156861.77 | bench_40238cb03dbc |
| run-0002 | language_model_only: true, max_num_batched_tokens: 16384 -> 81920 | arm 1 showed the flag's freed memory going to KV rather than headroom. CRASHED in the FlashInfer autotune at profile 24, twice, with an escalation numerically identical to the without-flag 81920 failure. Box survived both; watchdog aborted on the first NV_ERR_NO_MEMORY | d16384 c10 | — | — | — | — |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Dropping the vision tower with `--language-model-only` lifts `tg128 @ d16384
c10` above 42.0 t/s, because the memory it returns is the memory h2 ran out of.

Mechanism, from a measured row rather than the doc. h2's best measurable arm,
`max_num_batched_tokens` 65536, read **36.56 t/s and was still climbing
steeply** — 11.22 -> 14.37 -> 36.56, no sign of saturation. It stopped because
81920 and above die inside the FlashInfer `fp4_gemm` autotune, whose per-profile
workspace scales with the budget and takes host memory to 620 MB in one step
allocation. That is a **memory ceiling, not an exhausted mechanism**, so a field
that returns memory reopens a lever we know is still buying.

Which field, from [`../../../docs/runtime.md`](../../../docs/runtime.md) — the
levers vLLM's own recipe names and this tree has never tried. This is the one
that acts on the constraint h2 actually hit: we load a 0.858 GiB vision tower on
every boot and never send an image, and vLLM's published 1x5090 figures put the
KV pool at 91,022 tokens without the flag and **135,926 with it, +49%**. Board
entry `sub1786766781072` runs it. Recipe-level, checkpoint untouched.

Worth, if right: two claims on the Objective. Directly, more KV at the same
budget — h2 measured KV falling monotonically as the budget rose (66.12 / 63.01
/ 56.98 GiB) and the flag pushes back on exactly that. Indirectly and worth
more, headroom in the autotune phase: h2's single step 32768 -> 65536 was
**2.54x** and the gap from 36.56 to 72.5 is 1.98x, so one further budget step
carries the round if the ceiling can be made to move. 36.56 is 44% of the c10
roofline of 84 t/s — the room is in bytes, not in hope.

## Method

### Variables to test

    language_model_only: true          (at max_num_batched_tokens 65536)
    max_num_batched_tokens: 81920      (with language_model_only true)

Order: strictly sequential. Arm 1 isolates the flag against run-0002's 36.56 at
an identical budget — one field, like for like. Arm 2 moves the budget only
after arm 1 has priced the flag alone, so the two are never confounded. Stop
early if an arm exceeds 72.5.

**Box guard, from h2's cost.** 81920 refused cleanly and left the box
responsive; 98304 and 131072 wedged the host and cost a power cycle only Mat can
perform. Arm 2 aborts on the first `NV_ERR_NO_MEMORY` in `journalctl -kf`, as
run-0005 did. **No arm above 81920 opens without Mat's explicit approval.**

### Constant for this round

Everything else in `recipe.yaml`. `max_num_seqs` stays unset. `max_model_len`
stays 262144: h2 retired the reading that motivated moving it — KV and computed
max concurrency fell monotonically across every arm (7.12x -> 5.47x) while
throughput rose 3.26x, so a computed max concurrency below the offered 10 is
demonstrably not governing this cell. `enable_thinking` stays default; it is the
next lever in `runtime.md`, not this one.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 16384 · concurrency 1, 10 · runs 5

c1 rides along as a null control. **`runs: 5`, not h2's 3** — h2's arm 2 read
cv 13.7% at c10 (36.05 / 36.56 / 47.97) against the 0.9% h1 measured, and three
values cannot separate an outlier from a bimodal cell.

Recorded, not scored: KV and computed max concurrency per arm, autotune duration
and per-profile escalation, engine start time, ttfr, short returns per cell,
MTP acceptance.

## Decision rule

Read on the **median** at `tg128 @ d16384 c10`, best arm.

- **Target met** — ≥ 72.5 t/s at any arm.
- **Lever alive** — 42.0 to 72.5 t/s. Memory headroom is buying and h3 gets
  more arms.
- **Lever spent** — under 42.0 t/s at every arm. This includes the case where
  no arm above 65536 starts at all: if the vision tower's memory does not move
  the autotune ceiling, this field cannot reopen h2's lever.

Sizing: 42.0 is h2's best measurable arm (36.56) plus 15%, one full band above
it. **The band is h2's own 13.7%, not h1's 0.9%** — the wider figure governs
until a c10 cell is measured at n ≥ 5, which this round does. Every branch
resolves on figures this grid can produce, the all-crash case included; that is
the fault h2's rule had.

## Conclusion

<pending>

Budget: 15 lines — the verdict, the deciding figure, what varied, one line of
why. Everything else goes to the memory store.
