# h1 — the three numeric fields the reference recipe differs on

## Hypothesis

Adopting `gpu_memory_utilization 0.65`, `max_model_len 262144` and
`max_num_batched_tokens 32768` together brings `tg` to 116.03 at this cell.

The argument is not mechanical, it is arithmetic on the diff. Our recipe and
the reference recipe agree on every field that governs how a token is computed
— same checkpoint, same kernels, same KV format, same speculative config, same
loader, same container. They disagree on three numbers and a sampling config.
One of those sets contains the whole 13.7%, and the three numbers are the set
that touches memory and scheduling.

There is a mechanism to point at, and it runs through prefill. Our
`max_num_batched_tokens` is 65536 against their 32768, so at depth 16384 we
admit the entire prompt in one chunk where they take it in halves. Our
`max_model_len` is 32768 against their 262144, and `gpu_memory_utilization` 0.8
against their 0.65 — so we reserve a fraction of their KV pool out of a larger
slice of the card. The visible consequence is that their prefill runs 2.25x
ours. A decode win may be downstream of that rather than separate from it.

Worth, if right: the full gap, 102 → 116.03. These three fields are all that
separates our recipe from one measured at 116.03, so if the diff is the story
they carry all of it. If they carry part, the remainder names the next round.

## Method

### Variables to test

    gpu_memory_utilization: 0.8, 0.65
    max_model_len: 32768, 262144
    max_num_batched_tokens: 65536, 32768

Order: all three move together first. The question this round asks is whether
the diff is the whole gap, and one run answers that where three cannot. Split
them only if the combined arm lands part-way — then the split says which of the
three carried it, and that is a different question worth its own runs.

A combined arm that reaches 116.03 closes the experiment. A combined arm that
moves nothing says the gap is in the sampling config, and h2 takes it.

### Constant for this round

Beyond what Held closes: `max_num_seqs 4`, `--kv-cache-dtype fp8`,
`--attention-backend flashinfer`, `--moe-backend marlin`,
`num_speculative_tokens 3` on triton, chunked prefill, async scheduling, prefix
caching, `--load-format fastsafetensors`, `VLLM_MARLIN_USE_ATOMIC_ADD=1`.

The sampling config and chat-template mod are held too. They are the other half
of the diff and belong to h2 — moving them here would make a combined arm
unreadable.

Grid, from the recipe's `benchmark:` block:

    pp 2048 · tg 128 · depth 16384 · concurrency 1 · runs 7

`max_model_len 262144` at `gpu_memory_utilization 0.65` reserves a much larger
KV pool from a smaller slice of the card than we have ever asked for. If it
will not fit, the engine will say so at init. That is a result, not a failure —
record what it reported and which of the three has to give.

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
far outside any spread here, so it will read clearly even where `tg` does not —
and if `pp` moves while `tg` does not, that is the finding.

## Runs

One row per planned run. Figures blank until it is run.

| run | changed | why | pp t/s | tg t/s | ttfr ms | bench |
|-----|---------|-----|--------|--------|---------|-------|
| run-0001 | none — the baseline as shipped | control, and this epoch's spread | | | | |
| run-0002 | `gpu_memory_utilization: 0.8 → 0.65`, `max_model_len: 32768 → 262144`, `max_num_batched_tokens: 65536 → 32768` | the whole diff at once: is it the gap? | | | | |

Figures are medians of the seven values from the `tg128 @ d16384` phase. The
result carries two phases; the other is `ctx_tg`, a different cell.

## Conclusion

Pending.
