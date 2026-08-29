# depth — convert the two deep cells we still lose at tg128 c10

## Objective

`tg128 (c10)` on LFM2.5-350M at the two depths we do not hold. Read live
2026-08-28 (snapshot `generatedAt` 17:30:43Z, `.cache/results/2026-08-28-2100.md`);
LFM2.5-350M is the outright #1 in every one of these cells, so peer rank and
overall rank coincide.

    cell                  board #1   ours (slots recipe-new, mns 16)   standing
    tg128 (c10) d0         1042.20   2197.72 ± 32.2  (n=3)             WIN  +111%
    tg128 @ d4096 (c10)     750.01   1130.10         (n=3)             WIN   +51%
    tg128 @ d8192 (c10)     745.70    693.40         (n=3)             LOSE  -7.0%
    tg128 @ d16384 (c10)    613.31    347.20 ± 70.0  (n=3)             LOSE  -43%

The two "ours" losing figures are the secondary cells of `slots/h1/run-0004`,
the `max_num_seqs 16` arm, which is what `recipe.yaml` here carries. They are
**not** the 713.33 / 387.26 that circulated in the handoff — those are
`run-0003`'s `mns 10` figures, and reading them as the incumbent understates
both gaps. `slots`' verification run of `recipe-new.yaml` is the same recipe as
this experiment's baseline.

Target: exceed **745.70 t/s at `tg128 @ d8192 (c10)`** and **613.31 t/s at
`tg128 @ d16384 (c10)`**, both measured on our box on the same checkpoint.

Reached when: both figures are exceeded in the same run, without d0 or d4096
falling below their board numbers (1042.20 and 750.01) in that run.

Out of scope: d0 and d4096 margin. We hold both by more than 50%; extra margin
there converts no standing and is not worth a run.

## Strategy

The incumbent loses at depth and wins shallow, and the gap grows monotonically
with depth (+111%, +51%, -7.0%, -43%). That shape is the signature of a cost
that scales with context, not of a decode rate that is simply too slow — a
uniformly slow decode would lose everywhere by roughly the same factor.

Two context-scaling costs are on the table on this stack, and both are
scheduler-side rather than model-side:

**The prefill token budget.** `max_num_batched_tokens` is 8192 in the baseline,
inherited unexamined from the board entry. llama-benchy's headline `tg` row
sends context and prompt in one request, so a request's prefill is `depth + pp`
tokens, not `depth` (`ddb69b66`, `--get` 2026-08-28: dated 2026-08-22,
stack-level, source-read). At d8192 that is 10240 tokens against a 8192 budget;
at d16384, 18432. Every request's prefill must therefore be chunked across
several scheduler steps, and chunked prefill interleaves into decode steps.
At d0 and d4096 — the two cells we win — `depth + pp` is 2048 and 6144, both
inside the budget. The budget crosses from sufficient to insufficient at exactly
the depth where our standing flips.

**Mamba cache alignment.** This is a hybrid `Lfm2ForCausalLM`; with
`--enable-prefix-caching` on, vLLM forces `mamba_cache_mode = align` and pads
the mamba page, a cost that also scales with context — while the cache itself
measured 0.0% hit rate in every sample of every `slots` run, because
llama-benchy's prompts share no prefix (`a509844a`, `--get` 2026-08-28). That is
h2's lever, not h1's.

What the store already measured about the token budget, all on this box but
**all on `nvidia/Qwen3.6-35B-A3B-NVFP4`, never on this 350M checkpoint**. The
transfer argument is mechanism, not magnitude: the vLLM scheduler's prefill
admission and chunking path is model-independent code, and the arithmetic that
decides whether a prefill is chunked is `depth + pp` against `mnbt`, which
contains no model term. Magnitude does not transfer — a 35B MoE and a 350M dense
model spend their step time on different things.

- Raising `mnbt` lifts per-request decode rate, not just the batch-span
  denominator: 32768→98304 at d16384 raised `tg_req` by +15.5% at c4 and c5.
  The candidate mechanism is exactly ours — a whole-batch prefill stops
  interleaving into decode steps. (`624a27fe`, `--get`: 2026-08-22, d16384,
  stack:vllm.)
- But it saturates. `mnbt` buys throughput only until the batch is resident and
  its prefill stops being split; past that it is flat, and 98304 and 131072 added
  nothing over 65536. The saturating budget is cell-derived, roughly where
  `c × (depth + pp)` fits in about two steps. (`a2f190d6`, `--get`: 2026-08-22,
  tg128 d16384 c4.) For our cells that predicts ≈51 200 at d8192 and ≈92 200 at
  d16384 — so a 65536 arm should saturate d8192 and may still be short at
  d16384.
- vLLM has no validator requiring `mnbt ≤ max_model_len` while chunked prefill
  is on, so `mnbt` can pass 32768 without touching `max_model_len` and moving KV
  reservation. (`bdf368bd`, `--get`: 2026-08-22, source-read of
  `vllm/config/scheduler.py`.)
- The lever is inert at c1 and works through occupancy and the batch-span
  denominator; we are at c10, so both routes are open. (`abe16c87`.)
- Engine start costs 110–190 s across budgets 8192–98304 on this box, and tracks
  the size of the budget rather than whether the value is new to the compile
  cache. Three arms is ~8 minutes of engine start. (`18708ed5`.)

Three ids carried in the handoff — `97250b99`, `f7eddab5`, `780cfd5b` — **do not
exist in the store**; `recall.sh --get` returns "no memory" for each and none
appears in the unfiltered 2000-record sweep. They were cited in `slots`'
Strategy too, so the error is inherited, not new. Two of them are superseded
anyway: the `floor(mnbt/depth)` admission arithmetic they assert is explicitly
retired by `ddb69b66`. The third, the claim that lowering `mnbt` moved `tg`
monotonically down, is unverifiable and this experiment does not lean on it.

Measured scatter, per cell — what a decision rule here has to clear. From
`slots/h1/run-0004`, the same recipe as this baseline, n=3:

    tg128 (c10) d0:      2197.72, sd 32.2   — 1.5% CV
    tg128 @ d4096:       1130.10            — CV not recorded
    tg128 @ d8192:        693.40            — CV not recorded
    tg128 @ d16384:       347.20, sd 70.0   — 20% CV, values 427.12/296.97/317.59

d16384 is the noisy end of this grid and the noise is not small: at 20% CV and
n=3 the cell cannot resolve anything under about 20%. Every round here must
state what it can and cannot read at d16384 before it runs. d8192 and shallower
have behaved as the quiet end throughout `slots`; treat sub-3% differences there
as ties.

### Lever ladder

One lever per round. h4 is a new epoch and is the last resort.

    h1  max_num_batched_tokens 8192 -> 32768 -> 65536
        the prefill budget is smaller than depth+pp at exactly the two cells we
        lose, and larger at the two we win
    h2  --no-enable-prefix-caching
        the cache measured 0.0% hit in every sample of every slots run, while
        enabling it forces mamba_cache_mode=align on this hybrid architecture
        and logs "Padding mamba page size by 300.00%" — a context-scaling cost
        that buys nothing
    h3  h1's winning budget together with h2
        only if both move their cells alone; a combined arm read before its
        parts is unattributable
    h4  image ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082601
        the 0.26.1rc1 build line the fleet moved to on 2026-08-22; ours is
        0.27.2rc1 and is the only entry still on the older line. A NEW EPOCH —
        the incumbent is re-measured on it before anything is compared across
        it, and it is only opened if h1-h3 leave the target unreached.

**What h1 changed about this ladder** (appended at h1's close; the Objective,
Strategy and Held above are frozen and were not edited):

- The scatter figures in Strategy are too optimistic and every later round must
  size against the measured ones instead: within-arm CV at d8192 ran 6.9–14.5%,
  and a byte-identical recipe moved ~7% run to run between `slots/h1/run-0004`
  and `depth/h1/run-0001`. A 3% tie band cannot be read on this box. A round
  that needs to resolve a few percent at d8192 must spend `runs: 7` on that cell
  alone rather than sweep four depths at 3.
- A budget revisit at d16384 is **not** closed by h1's verdict and belongs on
  this ladder. Whole-prefill admission at that cell is `floor(mnbt/18432)`, so
  65536 admits three of ten offered requests and the queue never cleared in any
  arm (Waiting 3–4 throughout). Clearing it needs ≈ `c × (depth + pp)` = 184320,
  which no arm reached — and which is well above the ≈92 200 that `a2f190d6`'s
  "fits in about two steps" heuristic predicts. h1 measured that no budget up to
  65536 helps d16384; it did not measure that none can.
- Sweeping this flag is cheap on this model: engine start ran 36–37 s across all
  three arms, warm cache or rebuilt, against the 110–190 s `18708ed5` calibrates
  from the Qwen campaign. Cost is not a reason to skip a budget arm here.
- **A measurement-integrity problem now blocks clean reading of every deep cell,
  and should be settled before another round is spent.** Requests are returning
  fewer than the 128 tokens asked for at every depth — at 65536 the counts were
  d0 2/30, d4096 5/60, d8192 7/60, d16384 13/60, with ten of the d16384 shortfalls
  under 25 tokens and two returning a single token. There are no transport
  errors, so this is early EOS. llama-benchy sends no sampling parameters and the
  engine logs no resolved temperature/top_p/top_k, so the checkpoint's own
  `generation_config.json` governs unrecorded and unpinned. A `tg128` cell that
  does not generate 128 tokens is not measuring what its name says, and this is
  the leading candidate for the per-request spread at depth (max/min 23.9 at
  d16384, 26.2 at d8192) and hence for the scatter that made h1 unreadable.

Not levers: `max_num_seqs`, which `slots` settled at 16 and which Held closes;
`max_model_len`, because moving it moves KV reservation and confounds any
budget arm; `--quantization fp8`, which is already ours and is what the board
entry has.

## Held

- `max_num_seqs: 16`. `slots`' winner. This experiment does not move it, and no
  round may treat it as an arm. Note what the held value sits on: at `mns 16`
  vLLM logged `cudagraph_capture_sizes = [1,2,4,8,16,24,32]`, so 16 is an exact
  capture size and 10 is not — the leading explanation for `slots`' unexplained
  +15.0% of 16 over 10, which admission could not account for. A scheduler lever
  that changes the batch shape a step is dispatched at may therefore interact
  with graph capture, and no round here should read a budget effect without
  checking whether the captured size it lands on changed.
- Checkpoint `LiquidAI/LFM2.5-350M` at sha
  `9e6c6ccf47cd318696e137d381a7ded8fe4df09f`. Unmodified — no requant, no local
  conversion.
- Box `spark-6f0e`. Container image
  `sha256:4894c3f1069ac93f4b28feeab8d7f06cd60eb36fa4739a5381427d00f3818990`
  (`ghcr.io/spark-arena/dgx-vllm-eugr-nightly:2026082102`, vLLM
  `0.27.2rc1.dev360+ge85d1b69c`). A digest change is a new epoch; the incumbent
  is re-measured before anything crosses it. h4 is exactly such a crossing and
  carries that obligation.
- Runtime vLLM, container `vllm-node`, `recipe_version: '1'`. At
  `recipe_version: '2'` sparkrun does not select the eugr builder, the
  `vllm-node` alias goes to docker verbatim, and the run dies at image
  distribution before the engine launches (`61f4601f`).
- The cell we are scored in is `tg128`, concurrency 10. Only `tg` is compared —
  our `pp` and `ttfr` are cold-cache and comparable to nothing on the board.
- Cell order within a run is the recipe's `benchmark:` block order, ascending
  depth: 0, 4096, 8192, 16384. Order decides what is warm and no figure reveals
  which order produced it.
- Nothing is submitted to Spark Arena. Submission is Mat's decision and it has
  not been given.

Not "every field not under test" — a round holds its own fields constant, and
says so in its own Method. Anything named here is closed to every round.

## Rounds

| round | hypothesis | outcome |
|-------|------------|---------|
| h1 | a `max_num_batched_tokens` of 8192 is smaller than `depth + pp` at d8192 and d16384, so raising it stops prefill chunking into decode and lifts `tg` at exactly the two cells we lose | LEVER SPENT — d8192 741.1 → 773.3 → 709.8 across 8192/32768/65536, rose then fell; mechanism confirmed (queue cleared 4/6 → 10/0), target not met at d16384 (375.9 vs 613.31) |
| h2 | `--enable-prefix-caching` never hits on this harness yet forces `mamba_cache_mode=align` on this hybrid architecture, so it is a context-scaling cost bought for nothing | <pending> |

## Conclusion

<pending — written when the objective is reached or the levers are exhausted>
