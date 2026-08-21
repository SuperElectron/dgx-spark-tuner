---
name: mem0
description: Use when you need to remember a finding, recall prior context before starting a hypothesis, manage the mem0 memory service (start/stop/status), or diagnose and self-heal memory failures. Triggers include "remember this", "recall", "what do we know about", "memory service is down", and after any experiment verdict.
---

# mem0

Self-hosted agentic memory for the DGX Spark research harness. mem0 REST
(port 8888) + vLLM embeddings (port 8001) run on the box under docker
compose project `sparkmem` (`memory/docker-compose.yml`). Both ports bind
to `127.0.0.1` on the box, so every script talks to them over `ssh <host>`
— never directly. The box hostname is never hardcoded; it's read from
`.claude/box.json` (gitignored) via `scripts/_common.sh`.

## Marker scheme

Every memory is a single line of text, prefixed with one marker:

- `[VERDICT]` — an experiment outcome (keep/revert), from RESULTS.md or journal.md
- `[ENV]` — an environment fact (image version, driver, clock policy, ...)
- `[CRASH]` — a run that crashed, and why
- `[LESSON]` — a general takeaway not tied to one benchmark row

Entity metadata (stored in `metadata.entity`, not in the text) scopes a
memory for filtered recall:

- `experiment:<name>` — e.g. `experiment:qwen35-08b-tg128-c1`
- `box:<alias>` — e.g. `box:spark-6f0e`
- `flag:<vllm-flag>` — e.g. `flag:--async-scheduling`

## Scripts

All scripts live in `scripts/` and are self-contained bash (source
`_common.sh` for box/endpoint resolution). Run them from anywhere; they
`cd` to their own directory first.

### `memory.sh start|stop|status|logs [service]`

Controls the stack via `ssh <host> docker compose -p sparkmem ...`.
`start` brings the stack up and polls `:8888` and `:8001` health until
both answer 2xx (or times out). `status` prints per-container state plus
per-service health. `logs [service]` tails the last 200 lines.

### `remember.sh "<text>" [entity]`

Outbox-first write. Appends `{ts, text, entity}` to
`.cache/memory-outbox.jsonl` at the repo root, then tries to POST it to
mem0 (`user_id=dgx-spark-tuner`, `infer=false`). On success it removes
that line and drains any other pending lines in the outbox. On failure it
leaves the line queued, warns on stderr, and **exits 0** — a down memory
service is never a hard error. `remember.sh --drain` retries everything
currently queued without adding anything new (this is what
`memory-doctor.sh` calls to flush the backlog).

Example: `remember.sh "[VERDICT] bench_4f9da10931e0: ngram spec decode (n=4) — KEEP: +3.9 tg over band" experiment:qwen35-08b-tg128-c1`

### `recall.sh "<query>" [entity] [k=10]`

POSTs to `/search`, optionally filters results to a given entity
client-side, and prints newest-first `- <text>` bullets capped at ~1200
total characters. Empty output and exit 0 on no hits or a down service —
callers should never branch on recall failing.

### `memory-doctor.sh`

Self-heal chain, one step at a time, each printed as `PASS`/`FIXED`/`FAIL`:
box reachable (ssh) -> containers up (`docker compose ps`, `up -d` if not)
-> mem0 `:8888` healthy (restart if not) -> embeddings `:8001` `/v1/models`
answers (restart if not) -> add/search/delete roundtrip -> outbox drained
(`remember.sh --drain`). Idempotent — safe to run repeatedly. Exits
nonzero only if something is still broken at the end.

### `memory-backfill.sh [-n] <experiment-dir>`

Rebuilds mem0's index for one experiment from its canonical files:
`RESULTS.md` table rows become `[VERDICT]`/`[CRASH]` one-liners, and
`journal.md` `## Round N outcome ... — keep/revert/crash` headings become
one-liners too. Every entry is tagged `entity=experiment:<dirname>` and
deduped by exact text (searches before adding). `-n` prints what would be
posted instead of posting it. Use this any time mem0's data looks wrong —
it's a derived index, not a source of truth.

## GUARDRAIL: memory ops must never block main work

Files are canonical (journal.md, RESULTS.md); mem0 is a rebuildable index
(`memory-backfill.sh` reconstructs it from files at any time). Given that,
memory operations must never gate or delay the actual research work:

- `remember.sh` and `recall.sh` always exit 0 on service failure. Never
  treat their stderr warnings as reasons to stop, retry in a loop, or ask
  the user what to do.
- **If any mem0 script fails** (nonzero exit from `memory.sh` or
  `memory-doctor.sh`, or repeated `remember.sh`/`recall.sh` warnings):
  1. Continue the main task immediately — do not block on it.
  2. Spawn a background agent to run `scripts/memory-doctor.sh`.
  3. Have that agent diagnose from the doctor output, apply a fix if one
     is obvious (e.g. compose restart, outbox drain), and drain the
     outbox (`remember.sh --drain`).
  4. Have it report back what was found and fixed — don't silently retry
     forever, and don't surface the failure as blocking to the user until
     the background agent has actually looked at it.
