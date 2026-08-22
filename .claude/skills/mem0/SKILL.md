---
name: mem0
description: Use when you need to remember a finding, recall prior context before starting a hypothesis, manage the mem0 memory service (start/stop/status), or diagnose and self-heal memory failures. Triggers include "remember this", "recall", "what do we know about", "memory service is down", and after any experiment verdict.
---

# mem0

Self-hosted agentic memory for the DGX Spark research harness. Our own
FastAPI wrapper (`memory/server/app.py`, built in the parallel stack PR)
around the `mem0ai` library serves REST on port 8888; vLLM embeddings run
on port 8001. Both run on the box under docker compose project `sparkmem`
(`memory/docker-compose.yml`). Both ports bind to `127.0.0.1` on the box,
so every script talks to them over `ssh <host>` — never directly. The box
hostname is never hardcoded; it's read from `.claude/box.json` (gitignored)
via `scripts/_common.sh`.

Scripts source `_common.sh` by its own directory-relative path — they
never `cd` into the skill's `scripts/` directory, so relative path
arguments you pass (e.g. an experiment directory for `memory-backfill.sh`)
resolve against your own shell's cwd, exactly as you'd expect.

## API contract

`memory/server/app.py` is the single authority; scripts here are written
against it exactly:

- `POST /memories` — add. `{messages, user_id, metadata, infer: false}`.
  Returns `{"results": [{"id": ...}]}`. If `metadata.sha256` matches an
  existing memory for `user_id`, no new memory is written and the
  response is `{"results": [{"id": "<existing-id>"}], "deduped": true}` —
  scripts treat this the same as a normal add (2xx is success either way).
- `POST /search` — semantic search. `{query, user_id, limit, filters?}`.
  `filters` keys (e.g. `entity`, `sha256`) are top-level, not nested under
  `metadata` — the server merges them for you.
- `POST /memories/list` — exact listing, no vector search, wraps
  `get_all()`. `{user_id, filters?, limit?}` -> `{"results": [...]}`. Used
  for dedupe checks, never `/search` (dedupe must be exact, not
  similarity-ranked).
- `DELETE /memories/{id}` — delete by id.
- `GET /health` — 200 when the vector store connection is live, 503
  otherwise.

## Marker scheme

Every memory is a single line of text, prefixed with one marker:

- `[VERDICT]` — an experiment outcome (keep/revert), from RESULTS.md
- `[ENV]` — an environment fact (image version, driver, clock policy, ...)
- `[CRASH]` — a run that crashed, and why
- `[LESSON]` — a general takeaway not tied to one benchmark row
- `[COST]` — harness-token spend for a round phase (tokens-per-point
  accounting); the memory is a best-effort index entry only — phase totals
  must ALSO be recorded in the journal, which stays canonical

Entity metadata (stored in `metadata.entity`, passed as `filters.entity`
on recall — never client-side filtered) scopes a memory:

- `experiment:<name>` — e.g. `experiment:qwen35-08b-tg128-c1`
- `box:<alias>` — e.g. `box:spark-6f0e`
- `flag:<vllm-flag>` — e.g. `flag:--async-scheduling`

Every write also carries `metadata.sha256` (the sha256 of the memory
text). This is the exact-match dedupe key for both `remember.sh` and
`memory-backfill.sh`, and it also makes crash-replay of an add harmless:
retrying the same write after a crash lands on the same sha256, so the
server dedupes it server-side (`deduped: true`) instead of creating a
duplicate — no client-side bookkeeping required.

## Scripts

All scripts live in `scripts/`. Run them from anywhere, with any relative
paths resolved against your own cwd — they don't change directory.

### `memory.sh start|stop|status|logs [service]`

Controls the stack via `ssh <host> docker compose -p sparkmem ...`.
`start` brings the stack up and polls `:8888/health` and `:8001/v1/models`
until both answer 2xx (or times out). `status` prints per-container state
plus per-service health. `logs [service]` tails the last 200 lines.
Requires a configured box (`.claude/box.json`); exits nonzero without one.

### `remember.sh "<text>" [entity]`

Outbox-first write, safe to call even with no box configured. Appends
`{ts, text, entity, sha256}` to `.cache/memory-outbox.jsonl` at the repo
root under a portable `mkdir`-spinlock (no `flock` dependency — works on
macOS), then tries to POST it (`user_id=dgx-spark-tuner`, `infer=false`,
`metadata: {entity, sha256}`). On success it removes that line and drains
any other pending lines. On failure — service down, box unreachable, or
`.claude/box.json` missing entirely — it leaves the line queued, warns on
stderr, and **exits 0**; a down memory service is never a hard error.
`remember.sh --drain` retries everything currently queued without adding
anything new (this is what `memory-doctor.sh` calls to flush the
backlog). The lock guards every read-modify-write on the outbox file, so
concurrent `remember.sh` calls and a concurrent `--drain` never lose or
duplicate a queued line.

Durability against a killed process: the lock is released by a trap on
`EXIT`/`INT`/`TERM`, and `acquire_lock` steals a lock dir older than 60s
(the case a trap can't cover — nothing catches `SIGKILL`). A drain moves
the outbox to a `.inflight` file first and deletes each line from it only
after a confirmed 2xx, so a kill mid-drain leaves every undelivered line
on disk (never held only in a shell variable); a leftover `.inflight` is
folded back into the outbox at the start of the next `remember.sh` run,
write or drain.

Concurrent drains all peek the same `.inflight` head until one of them
successfully removes it, so several concurrent `--drain`s can each POST
the same line before it's removed (observed ~4.6x redundant traffic under
5 concurrent drainers). Harmless — the server dedupes on `metadata.sha256`
and just answers `deduped: true` — and not worth optimizing for a
low-frequency guardrail script.

`memory-doctor.sh`'s outbox-drained check looks at both
`.cache/memory-outbox.jsonl` and its `.inflight` file — a drain that
stalled mid-flight parks its backlog in `.inflight`, and checking only the
outbox would let the doctor false-green with memories still stuck.

Example: `remember.sh "[VERDICT] bench_4f9da10931e0: ngram spec decode (n=4) — KEEP: +3.9 tg over band" experiment:qwen35-08b-tg128-c1`

### `recall.sh "<query>" [entity] [k=10]`

POSTs to `/search` with `filters: {entity: ...}` when an entity is given
— filtering happens server-side, never client-side. Prints bullets in the
server's own relevance order (never re-sorted locally), capped at ~1200
total characters. Empty output and exit 0 on no hits, a down service, or
a missing box config — callers should never branch on recall failing.

### `memory-doctor.sh`

Self-heal chain, one step at a time, each printed as
`PASS`/`FIXED`/`FAIL`/`SKIP`: box reachable (ssh) -> containers up
(`docker compose ps`, `up -d` if not) -> mem0 `:8888/health` (restart if
not) -> embeddings `:8001/v1/models` (restart if not) -> add/search/delete
roundtrip -> outbox drained (`remember.sh --drain`). If the box itself is
unreachable, every remaining ssh-dependent check is printed `SKIP` rather
than attempted (they'd all time out identically) — only the outbox-drain
step still runs, since that degrades gracefully on its own. Idempotent —
safe to run repeatedly. Exits nonzero only if something is still broken
at the end.

### `memory-backfill.sh [-n] <experiment-dir>`

Rebuilds mem0's index for one experiment from its canonical
`RESULTS.md` table — every row with a non-empty verdict becomes a
one-liner, tagged `[CRASH]` when the verdict column starts with "crash"
and `[VERDICT]` otherwise. Each
entry is tagged `entity=experiment:<dirname>` and deduped via
`POST /memories/list` with `filters: {sha256: ...}` — an exact-match
check, not a similarity search, so it never posts a false-positive
duplicate. If the dedupe check itself fails (non-2xx), the row is skipped
and warned about, never added — this script would rather leave a gap
than risk a duplicate. `-n` prints what would be posted instead of
posting it, with no network calls at all. Use this any time mem0's data
looks wrong — it's a derived index, not a source of truth; `journal.md`
is not parsed (RESULTS.md is the single canonical source for backfill).

## GUARDRAIL: memory ops must never block main work

RESULTS.md/journal.md files are canonical; mem0 is a rebuildable index
(`memory-backfill.sh` reconstructs it from RESULTS.md at any time). Given
that, memory operations must never gate or delay the actual research
work:

- `remember.sh` and `recall.sh` always exit 0 on service failure or a
  missing box config. Never treat their stderr warnings as reasons to
  stop, retry in a loop, or ask the user what to do.
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
