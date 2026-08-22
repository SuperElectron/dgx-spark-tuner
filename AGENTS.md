# Project rules

Benchmark-tuning research on a DGX Spark box. The work is hypothesis-driven:
we are trying to understand what governs throughput on this hardware and this
model, and to fold what we learn into `recipe.yaml`.

Nothing is ever submitted to Spark Arena. There is no login and one is not
wanted. Never pass `--arena`; never run `sparkrun arena` anything.

## The loop

One pass of the loop is one **hypothesis**, not one benchmark.

1. **State the hypothesis.** It must name an **objective** (what is being
   maximized or decided), a **claim**, the **variables** and the direction they
   move, and what would **confirm or refute** it — all written down before any
   run. Without an objective a result cannot be judged: every setting is a
   trade, and "better" is meaningless until we say better at what.
2. **Run it.** Each invocation produces one `bench_*` archive under the
   hypothesis directory. One agent owns one round start to finish.
3. **Conclude.** Read the archives, write the conclusion into `EXPERIMENT.md`.
   State the trade-off in both directions — what got better AND what got worse.
   A conclusion that only reports the gain is incomplete.
4. **Record.** Write memories from the runs (see `## Memory`).
5. **Decide what is next.** The conclusion ends with what it implies for the
   next hypothesis: a direction still untested, a mechanism now worth probing,
   or the honest finding that the lever is exhausted.

A hypothesis that only asks "what does this cell measure" is a survey, not a
hypothesis. Prefer questions about mechanism — what governs the number — since
those are the ones whose answers transfer to the next model.

**Budget engine starts, not wall-clock.** Probe axes (`depth`, `concurrency`,
`tg`, `runs`) sweep inside a single engine start via comma lists:
`-b depth=8192,16384,32768`. Serve settings (`max_num_batched_tokens`,
`max_num_seqs`, `num_speculative_tokens`, backends) cannot sweep — each value
costs a full model load. So plan a hypothesis as "what can I learn from N
engine starts", and carry the widest free probe sweep on every one.

## Experiments

```
research/<series>/
├── recipe.yaml                     the tuned artifact — the ONLY thing we tune
├── RESULTS.md                      Mat's lookup table (see ## Records)
└── experiments/<hypothesisId>/
    ├── HYPOTHESIS.md               written BEFORE the runs
    │   └── renamed EXPERIMENT.md   once the conclusion is written
    └── bench_<id>-<label>/         one directory per invocation
```

- The series root holds exactly those files plus `docs/`, `scripts/`,
  `experiments/`. **Creating any other file at that level is a bug.** Analysis
  belongs in `EXPERIMENT.md`; candidate recipes belong in the run's archive.
- Hypothesis directories are named for the **claim**, not the cell —
  `R24-prefix-cache-cause`, not `R24-tg128-d16384-c4`. Zero-pad the id.
- Never edit anything inside a `bench_*` directory. Those exports are immutable.
- `sparkrun` reuses a benchId for identical recipe+params; pass a suffix
  (`-verify`, `-crash`, or the setting under test) so a run never overwrites one.
- **A round without an engine log is incomplete.** `engine-capture.log` is the
  only artifact recording the serve command actually executed including `-o`
  overrides, and the only place the prefix-cache hit rate and the scheduler's
  `Running/Waiting` lines appear. It is not in `~/.cache/sparkrun`. Capture it.

`.gitignore` allow-lists what is tracked per run and explains why, inline. The
short version: inputs (what we ran) and measurements (what we got) are both
kept, because a benchmark is stochastic and re-running never reproduces a past
number. Duplicate encodings are not kept.

## Records

| What | Where | Canonical for |
|---|---|---|
| The tuned config | `recipe.yaml` | what we ship |
| Hypothesis + conclusion | `experiments/<hypId>/EXPERIMENT.md` | why we ran it, what it meant |
| Raw measurements | `experiments/<hypId>/bench_*/` | what was measured |
| Findings index | mem0 | recall across series |
| Standings | `RESULTS.md` | **Mat's personal lookup table** |

`RESULTS.md` is a quick-reference table for Mat and nothing else. **Nothing
derives from it** — not memories, not conclusions, not tooling. It is an output
of the work, never an input to it.

Memories derive from the `bench_*` archives, which are the primary record.

## Git

`main` ← `staging` ← `feature/*`. Never commit directly to `main` or `staging`.

**Branch before the first commit, then verify:**

```
git checkout -b feature/<name> staging     # branch off staging, not main
git branch --show-current                  # confirm before committing
```

A prohibition is evaluated only once you are already committing, which is too
late — this failed exactly that way and cost a history repair. Run the commands.

**One agent owns the working tree at a time.** Every agent shares one checkout.
While a round holds the box, no other agent runs git operations — a stray
checkout mid-round corrupts a benchmark that cost real box time.

An agent commits and pushes **only its own branch**. Merging up is the
orchestrator's call, and the orchestrator verifies the branch actually landed
what it claimed before merging.

Never commit `QUEUE.md` (gitignored).

## Memory

The mem0 skill (`.claude/skills/mem0/SKILL.md`) is the full contract. Standing
rules:

- **Three classes.**
  `[EXPERIMENT]` — one per `bench_*` archive, derived from the archive itself.
  Carries the objective, the configuration, what was measured, and the
  trade-off against what it is compared to.
  `[OBSERVATION]` — written when a hypothesis closes. The reasoning: whether
  the claim held, why it failed if it did, and what it implies next.
  `[LESSON]` / `[ENV]` / `[IDEA]` — general findings, environment facts, and
  dated future work.
- **A memory reports what was found, never a standing verdict.** Date,
  provenance and comparison basis go in the memory TEXT — `recall.sh` returns
  only the text, so anything in metadata is invisible at the point of use.
  Keep ratios, but always say what they are over and where that figure came from.
- **Never hand-write `[EXPERIMENT]` under an `experiment:` entity.** It has no
  archive to reconcile against, and `memory-backfill.sh --reconcile` will treat
  it as stale and delete it.
- **Scope to the widest entity that is truly true** — `experiment:` / `model:` /
  `family:` / `stack:` / `box:` / `flag:`. `recall.sh` filters entity exactly,
  server-side, so a near-duplicate spelling is invisible to the canonical one.
- **Memory ops never block work.** `remember.sh` / `recall.sh` always exit 0 on
  failure. Never retry in a loop or ask what to do. On failure, continue and
  spawn a background agent to run `memory-doctor.sh`, then drain the outbox.
- The stack runs on the box under docker compose project `sparkmem`, managed
  via `memory.sh`.

## The box

- **Never change system state autonomously**: clocks, power policy, driver,
  kernel, `apt`. Measure it, record it, leave the decision to Mat.
- The box hostname comes from `.claude/box.json` (gitignored).
- An image or vLLM version change is a new epoch — re-measure the incumbent
  before comparing across it.

## Reading the metrics

- Every figure is a **median**, never a mean. MTP acceptance is bimodal.
- At concurrency > 1, `tg_throughput` is a **batch aggregate** — the sum of
  decode tokens over the whole batch span. **Never multiply it by concurrency.**
  The per-request figure is `tg_req_throughput`.
- A `ctx_` row is llama-benchy **Phase 1**, the uncached context load charged
  `depth` tokens. A row without `ctx_` is **Phase 2**, charged 2048. The
  campaign had this backwards for thirteen rounds.
- Prefill is scored on `ctx_pp` only. `pp_throughput` divides by a 2048
  numerator while the engine prefills `depth + 2048`, so it understates
  whenever the prefix cache misses.
- Treat any 3-run figure as provisional.

## Skills

- `spark-autoresearch` — the research loop, round procedure, helper scripts
- `mem0` — memory service, markers, entity scopes, reconcile
- `observe` — observation pass over runs, telemetry and logs
- `gh-issues` — issue body structure and closing rules

## Code rules

- Minimize comments; keep them friendly for a human developer to read.
- Keep files small — aim under 400 lines; when a file grows, split it.
