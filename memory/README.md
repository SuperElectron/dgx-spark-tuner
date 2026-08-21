# memory

Box-side memory stack: self-hosted mem0 backed by pgvector, embedding via a
local vLLM server. Independent of `sparkrun_*` benchmark containers (project
name `sparkmem`) so `sparkrun ... --fresh` never touches it.

## Quickstart

```bash
cd memory
cp .env.example .env   # edit POSTGRES_PASSWORD at minimum
docker compose --env-file .env up -d
./configure-memory.sh
```

## Architecture

```
                 +-------------------+
  research loop  |  mem0 (:8888)     |
  (remember/     |  FastAPI server   |
   recall) ----> |  infer=false      |
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
