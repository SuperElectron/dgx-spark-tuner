---
name: memory
description: Read, write and prune the research memory. Use to recall what past rounds measured before opening a hypothesis, and to record findings when an experiment closes.
---

# memory

## Role

Owns the memory store and the four scripts that reach it. `spark-autoresearch`
is the only skill that WRITES, and only once, when an experiment closes.

Any round may READ, and should — the store already holds what earlier campaigns
measured, and re-deriving it costs runs.

## How to use this skill

1. RECALL before writing a hypothesis. Search the widest scopes first.
2. QUESTION what comes back — see below. This is the part that matters.
3. WRITE once, when an experiment closes, at the widest scope the observation
   is true for.

## Scripts

    scripts/memory.sh start|stop     the embedder is a vLLM instance on the
                                     same GB10 as the benchmarks. `start` to
                                     search, `stop` before any run.
    scripts/recall.sh "<query>" [entity] [k]    relevance search — needs `start`
    scripts/recall.sh --list [entity] [limit]   every memory, no vector search,
                                                works with the embedder down
    scripts/remember.sh "<text>" <entity>       write one
    scripts/forget.sh [--yes] <id>...           delete; refuses without --yes

`recall.sh` and `forget.sh` print `<id>\t<entity>\t<text>`, so a scan pipes
into a prune: `recall.sh --list | cut -f1 | forget.sh --yes -`.

Memory never blocks work. `remember.sh` exits 0 with the service down and says
on stderr whether the write landed — check it; a 2xx is not proof you can read
it back.

## QUESTION THE MEMORY

A memory is a record of what one benchmark measured under one protocol on one
day. It is evidence about **that** measurement, not about yours. Before you let
one shape a hypothesis, answer:

- **What cell was it measured at?** A finding at `d16384` may not transfer to
  `d0`, and the reason is usually mechanical. Worked example: a memory recorded
  `tg32` reading faster than `tg128` at `d16384`. At depth, every generated
  token is KV that every later step reads back, so longer generation costs more
  traffic — no transient needed. At `d0` that mechanism is absent. The memory
  was measuring KV growth wearing a generation-length label.
- **What epoch?** Image, vLLM and flashinfer commits, and the measurement
  protocol. A figure taken before `exact_tg`, `temperature 0` or a pinned
  prompt is a different quantity, not an older version of the same one. If the
  embedder was resident on the card, it was sharing the GPU with the benchmark.
- **What was the objective it served?** A round chasing throughput records
  spread differently from one chasing stability. The figure may be sound and
  the emphasis still misleading.
- **Is it an observation or a judgement?** `bench_X measured 129.32 at runs=3`
  stays true forever. `WIN 4.60x, settled` expires the moment something is
  re-measured. Keep the first, distrust the second.
- **Does a contradiction mean one is wrong?** Not necessarily — two memories
  disagreeing about the same cell usually means they measured different epochs
  or different protocols. That is a reason to run the experiment, not to pick
  the one you prefer.

A memory is a reason to look. It is not evidence for your cell until you have
said why it transfers.

## Writing one

One line, one marker, and everything needed to judge it must be IN the text —
`recall.sh` shows the entity but the date, benchId, cell and basis live in the
line or they are lost at the point of use.

    [EXPERIMENT] <date> <benchId>: <cell> runs=<n> <metric> <figure> at <config> — <what varied>
    [ENV]        an environment fact: image, driver, clock policy, a box quirk
    [LESSON]     a takeaway not tied to one row
    [IDEA]       a candidate intervention, with its date and the evidence it rests on

State comparisons as observations with their basis and date, never as standing
verdicts. `WIN 4.6x over board 28.11 (scraped 2026-08-21)` survives; `WIN 4.6x`
does not.

## Entity scope

Pick the WIDEST scope the observation is actually true for — that is what makes
it findable from another experiment.

    experiment:<name>   only this series' cell and config
    model:<hf-id>       this exact checkpoint
    family:<name>       across a family — family:qwen3.6-35b-a3b spans its
                        NVFP4/FP8/BF16 builds
    stack:<runtime>     the serving stack, any model — stack:vllm
    box:<alias>         this hardware, any model or stack — box:spark-6f0e
    flag:<vllm-flag>    this flag — flag:--async-scheduling

`experiment:` is the narrowest and ages worst: when a campaign closes, its
experiment-scoped memories are dead weight unless the finding was also written
wider.
