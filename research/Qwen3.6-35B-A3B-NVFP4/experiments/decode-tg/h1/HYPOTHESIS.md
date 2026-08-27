# h1 — the three numeric fields the reference recipe differs on

This file is the contract for the round: hypothesis, method, decision rule, and
runs. It is not the notebook — per-round analysis belongs in the memory store,
not here.

## Verdict

**LEVER SPENT** — the combined arm read `tg` 111.3 against the control's 109.3,
2.0 apart against interquartile ranges of 11.3 and 9.8.

## Runs

<!-- RUNS:BEGIN -->
| run | changed | why | cell | pp | tg | ttfr | bench |
|---|---|---|---|---|---|---|---|
| run-0001 | none — the baseline as shipped | control, and this epoch's spread | d16384 c1 | 633.1 | 109.3 | 3246.4 | bench_c9518e3e96a3 |
| run-0002 | `gpu_memory_utilization: 0.8 → 0.65`, `max_model_len: 32768 → 262144`, `max_num_batched_tokens: 65536 → 32768` | the whole diff at once: is it the gap? | d16384 c1 | 636.1 | 111.3 | 3231.2 | bench_00f6e273f26c |
| run-0003 | `--speculative-config` removed | diagnostic: what is the 25% `tg` spread made of? | d16384 c1 | 2420.2 | 70.3 | 858.0 | bench_0a988a464b5a |
| run-0004 | `exact_tg`, `temperature 0`, cache reset added | harness verification, not an arm | d16384 c1 | 635.9 | 116.2 | 3232.1 | bench_7d27a25ac7f2 |
| run-0005 | `post_run_cmd` fixed, `emit_progress` added | harness verification, not an arm | d16384 c1 | 632.7 | 118.9 | 3248.7 | bench_c77f38339d26 |
| run-0006 | fixed corpus installed | harness verification, not an arm | d16384 c1 | 633.2 | 115.8 | 3246.0 | bench_7e811800d715 |
| run-0007 | `seed=42` added | discriminator: is decode greedy? | d16384 c1 | 635.0 | 122.8 | 3244.9 | bench_26c64e5c27b8 |
| run-0008 | `no_adapt_prompt: true` | pin the prompt for real | d16384 c1 | 635.4 | 119.6 | 3234.9 | bench_ff46b9fac055 |
<!-- RUNS:END -->

Script-written by `spark-autoresearch`'s CREATE/RECORD steps. Never hand-edit.

## Hypothesis

Adopting `gpu_memory_utilization 0.65`, `max_model_len 262144` and
`max_num_batched_tokens 32768` together brings `tg` to 116.03 at this cell.
Mechanism: the two recipes agree on every field that governs how a token is
computed, so the whole 13.7% sits either in these three numbers or in the
sampling config, and these three are the set that touches memory and
scheduling. They run through prefill — our budget admits an 18432-token prompt
whole where theirs takes it in halves, and their prefill runs 2.25x ours.

Worth, if right: the full gap, 102 → 116.03. If the three carry only part of
it, the remainder names the next round; if they carry none, h2 takes the
sampling config.

## Method

### Variables to test

    gpu_memory_utilization: 0.8, 0.65
    max_model_len: 32768, 262144
    max_num_batched_tokens: 65536, 32768

Order: all three move together first, because one run answers whether the diff
is the whole gap where three cannot; split them only if the combined arm lands
part-way, which is a different question worth its own runs.

### Constant for this round

Beyond what Held closes: `max_num_seqs 4`, `--kv-cache-dtype fp8`,
`--attention-backend flashinfer`, `--moe-backend marlin`,
`num_speculative_tokens 3` on triton, chunked prefill, async scheduling, prefix
caching, `--load-format fastsafetensors`, `VLLM_MARLIN_USE_ATOMIC_ADD=1`. The
sampling config and chat-template mod are held too — they are the other half of
the diff, they belong to h2, and moving them here would make a combined arm
unreadable.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

## Decision rule

Sized against Strategy's `tg ±20%`, and stated on interquartile range because
our spread comes mostly from one high outlier per set.

- **Target met** if the arm's median `tg` reaches 116.03 and its worst of seven
  stays above the baseline's median. A target claimed on one lucky value is not
  a target reached.
- **Lever alive** if the arm's median beats the baseline's by more than the
  larger of the two interquartile ranges but falls short of 116.03. Split the
  three fields to find which carried it.
- **Lever spent** if the medians differ by less than that. The three numbers
  are not the gap, and h2 takes the sampling config.

Record `pp` at every run whatever `tg` does. Their prefill advantage is 2.25x,
far outside any spread here, so if `pp` moves while `tg` does not, that is the
finding.

## Conclusion

**Lever spent.** The combined arm (run-0002) read `tg` 111.3 against the
control's 109.3 — 2.0 apart, against interquartile ranges of 11.3 and 9.8, so
nothing gets split because there is nothing to attribute. `pp` is the stronger
finding and points the same way: 633.1 → 636.1, half a percent, inside what
this cell shows with the field untouched. The chunking mechanism did not fire.

Three caveats. The `tg` spread is **MTP** — run-0003 removed
`--speculative-config` and `tg` standard deviation fell 8.6 → 0.24 while `pp`
did not move. The **116.03 target was the wrong quantity**, not a number we
missed; the Objective now carries a board-comparable figure instead.
run-0004 through run-0006 are **harness verification, not arms**, and the 118.9
at run-0005 is what the baseline reads under a pinned protocol, not a win this
round earned. The round's reasoning is in the memory store — every record
carries `decode-tg/h1` in its `basis`.
