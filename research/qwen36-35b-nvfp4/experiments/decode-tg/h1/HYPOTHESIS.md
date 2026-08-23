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
| run-0001 | none — the baseline as shipped | control, and this epoch's spread | 633.1 | 109.3 | 3246.4 | bench_c9518e3e96a3 |
| run-0002 | `gpu_memory_utilization: 0.8 → 0.65`, `max_model_len: 32768 → 262144`, `max_num_batched_tokens: 65536 → 32768` | the whole diff at once: is it the gap? | 636.1 | 111.3 | 3231.2 | bench_00f6e273f26c |
| run-0003 | `--speculative-config` removed | diagnostic: what is the 25% `tg` spread made of? | 2420.2 | 70.3 | 858.0 | bench_0a988a464b5a |
| run-0004 | `exact_tg`, `temperature 0`, cache reset added | harness verification, not an arm | 635.9 | 116.2 | 3232.1 | bench_7d27a25ac7f2 |
| run-0005 | `post_run_cmd` fixed, `emit_progress` added | harness verification, not an arm | 632.7 | 118.9 | 3248.7 | bench_c77f38339d26 |
| run-0006 | fixed corpus installed | harness verification, not an arm | 633.2 | 115.8 | 3246.0 | bench_7e811800d715 |
| run-0007 | `seed=42` added | discriminator: is decode greedy? | 635.0 | 122.8 | 3244.9 | bench_26c64e5c27b8 |
| run-0008 | `no_adapt_prompt: true` | pin the prompt for real | 635.4 | 119.6 | 3234.9 | bench_ff46b9fac055 |

Figures are medians of the seven values from the `tg128 @ d16384` phase. The
result carries two phases; the other is `ctx_tg`, a different cell.

The harness runs are 0003 to 0008. They belong to this round only because it
was open while the measurement protocol was built, and between them they took
`tg` max/min from 1.31 to 1.11. What each established, once:

- **run-0003** — removing `--speculative-config` collapsed `tg` sd from 8.6 to
  0.24 while `pp` did not move. The scatter is MTP, not Triton JIT (whose
  compilations fire inside llama-benchy's warmup, before the timed runs). MTP
  costs 36% of decode and returns 3.8x on prefill and ttfr, so it stays — but
  every `tg` figure here is drawn from a distribution it widens.
- **run-0006** — the fixed corpus landed and did not fix the spread. Both
  `tokenizers` and `transformers` count the installed file at exactly 18433, so
  the slice was correct; max/min still read 1.24.
- **run-0007** — `seed=42` changed nothing, ruling out sampling. Its tell was
  `prompt_tokens` varying *within* the run, four at 18432 and three at 18433. A
  fixed slice cannot do that, so the prompt was never actually fixed.
- **run-0008** — `no_adapt_prompt: true` pinned it. `prompt_tokens` became a
  single value and max/min fell to 1.108.

The cause was `adapt_prompt`, on by default and exposed only as
`--no-adapt-prompt` (`store_false`). It rewrites the grid before the prompt is
built:

    current_depth = max(1, depth - self.delta_context)
    max_start     = len(corpus) - (current_pp + current_depth)

`delta_context` is chat-template overhead measured at warmup, so `max_start`
becomes `1 + delta` rather than 1 and `np.random.randint` draws a fresh start
every run. The corpus fix closed a window adaptation reopened one line later.

Pinning the prompt did not make decoding deterministic. With identical prompt,
`temperature 0` and a seed, four of seven generations are byte-identical and
three diverge — greedy decoding occasionally taking a different branch under
MTP, not sampling. run-0003 bounds that residue at max/min 1.01 with
speculation off. That is the instrument's floor, and it has a known cause we
are choosing to keep.

Two consequences worth keeping. With adaptation off the request carries 18432
corpus tokens *plus* the template, so the served prompt runs a few tokens past
the nominal `pp + depth`; adaptation traded reproducibility for hitting the
nominal size, and this experiment wants the reproducibility. And the ctx phase
stays unstable by construction — it needs only 16384 tokens from an
18433-token corpus, leaving `max_start` 2049, so its prompts really are random
slices. The Objective's cell is unaffected.

## Conclusion

**Lever spent.** The three fields are not the gap.

The combined arm (run-0002) read `tg` 111.3 against the control's 109.3 — 2.0
apart, against interquartile ranges of 11.3 and 9.8. The rule as written calls
that spent: a difference smaller than the larger IQR is not a result. Nothing
gets split, because there is nothing to attribute.

`pp` is the stronger finding and it points the same way. The mechanism argued in
the Hypothesis ran through prefill: halving `max_num_batched_tokens` should
change how a 16384-token prompt is chunked, and the reference recipe's 2.25x
prefill advantage was the evidence it mattered. `pp` moved 633.1 → 636.1. Half a
percent, inside the 1.02 max/min this cell shows with the field untouched. The
chunking mechanism did not fire, so the prefill gap is not made of these three
numbers and no decode win was ever going to arrive downstream of it.

Two things this round settled that outlast it:

- **The spread is speculation.** run-0003 removed `--speculative-config` and
  `tg` standard deviation fell 8.6 → 0.24 while `pp` did not move. Triton JIT
  was the earlier suspect and is ruled out — the compilations fire inside
  llama-benchy's warmup requests, before the timed runs. Every `tg` figure this
  experiment records is a sample from a distribution MTP widens, and MTP stays
  because it is worth 36% of decode and 3.8x on prefill and ttfr.
- **The 116.03 target was the wrong quantity**, not the wrong number. Seven
  documented protocol differences, and its `±` is a population standard
  deviation over three requests inside one invocation against our across-
  invocation spread. The Objective now carries a board-comparable figure
  instead, measured by running their profile.

run-0004 through run-0006 are harness verification, not arms. They belong to
this round only because it was open while the measurement protocol was built.
The standing best they leave behind — 118.9 at run-0005 — is not a claim this
round earned; it is what the baseline reads under a protocol that pins output
length, sampling and cache state.

What follows is not a split of these three fields. h2 takes the prefix cache,
which the harness runs showed never hits at all.
