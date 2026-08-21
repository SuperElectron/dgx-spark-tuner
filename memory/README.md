# memory

Box-side memory stack: self-hosted mem0 backed by pgvector, embedding via a
local vLLM server. Independent of `sparkrun_*` benchmark containers (project
name `sparkmem`) so `sparkrun ... --fresh` never touches it.

## Quickstart

```bash
cd memory
cp .env.example .env   # edit POSTGRES_PASSWORD at minimum
docker compose --env-file .env up -d --build
./configure-memory.sh
```

## Architecture

```
                 +-------------------+
  research loop  |  mem0 (:8888)     |
  (remember/     |  our FastAPI      |
   recall) ----> |  wrapper, infer=  |
                 |  false always     |
                 +----+---------+----+
                      |         |
             OpenAI-  |         | pgvector
             compat   |         | (memories table)
                      v         v
             +----------------+   +-----------------+
             | embeddings     |   | postgres (:5432, |
             | vLLM (:8001)   |   |  internal only)  |
             | Qwen3-Embed    |   +-----------------+
             +----------------+
```

The `mem0` service is `memory/server/` - a ~80-line FastAPI wrapper around
the `mem0ai` library, built locally rather than pulled. The published
`mem0/mem0-api-server` image is a stale build that lacks `infer` support,
hardcodes the OpenAI embedder, and requires an external graph store; our
wrapper configures `mem0ai` directly (pgvector vector store, OpenAI-protocol
embedder pointed at the box's vLLM server, no graph store) so no API keys or
extra services are needed.

## API contract

`memory/server/app.py` is the single authority for this contract - all four
endpoints are unauthenticated (loopback-bound only). Entity filters
(`user_id`, and any custom metadata key such as `sha256`) are merged into a
single filters dict internally; the local pgvector store matches filter keys
directly against the stored payload, so metadata keys are NOT nested under a
`"metadata"` sub-object.

### `POST /memories` - add
```json
{"messages": [{"role": "user", "content": "..."}], "user_id": "...", "metadata": {}, "infer": false}
```
Returns `{"results": [{"id": "...", ...}]}` on a normal add. If
`metadata.sha256` is present and a memory with that `sha256` already exists
for `user_id`, no new memory is written - the existing id is returned as
`{"results": [{"id": "<existing-id>"}], "deduped": true}`. This makes
client-side crash-replay of an add harmless.

### `POST /search` - semantic search
```json
{"query": "...", "user_id": "...", "limit": 10, "filters": {"entity": "...", "sha256": "..."}}
```
`filters` is optional and merged with `user_id` before being passed to
`mem0ai`'s `Memory.search(filters=..., top_k=limit)`.

### `POST /memories/list` - exact listing (no vector search)
```json
{"user_id": "...", "filters": {"sha256": "..."}, "limit": 100}
```
Wraps `mem0ai`'s `Memory.get_all()`. Returns
`{"results": [{"id": "...", "memory": "...", "created_at": "...", "metadata": {}}]}`.
Use this (not `/search`) for exact-match lookups such as dedupe checks.

### `DELETE /memories/{id}`
Deletes one memory by id.

### `GET /health`
Touches the vector store; 200 when the DB connection is live, 503 otherwise.

## Recovery model

mem0/postgres is a derived index, not the source of truth: research journal
and RESULTS files are canonical. If the `memory/data/` volume is lost or the
stack is torn down, the box loses fast recall but nothing is unrecoverable -
memories can be backfilled from the journal files by replaying `[VERDICT]` /
`[ENV]` / `[CRASH]` / `[LESSON]` lines back through the `remember` path.
Treat memory outages as best-effort degradation, never a blocker.

## Ports

| Service    | Port (host, 127.0.0.1 only) | Purpose                     |
|------------|------------------------------|------------------------------|
| mem0       | `${MEM0_PORT}` (8888)        | REST API: add/search memories |
| embeddings | `${EMBED_PORT}` (8001)       | OpenAI-compatible embeddings |
| postgres   | none (internal network)      | pgvector storage             |
