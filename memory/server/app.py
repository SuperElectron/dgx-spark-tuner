"""Thin FastAPI wrapper around mem0ai's Memory class, pointed at pgvector +
the box's vLLM embeddings server. Replaces mem0/mem0-api-server (stale image,
no `infer` support, hardcoded OpenAI embedder, requires a graph store).
No auth: this only ever binds to 127.0.0.1 on the box.
"""
import os

from fastapi import FastAPI, HTTPException
from mem0 import Memory
from pydantic import BaseModel

EMBED_BASE_URL = os.environ.get("EMBED_BASE_URL", "http://embeddings:8001/v1")
EMBED_MODEL = os.environ["EMBED_MODEL"]
EMBEDDING_DIMS = int(os.environ["EMBEDDING_DIMS"])

# infer=false on every real call, so the LLM is never actually invoked;
# it still needs a config (mem0 requires one) and shares the local base_url
# so a stray infer=true never reaches an external service.
_openai_local = {
    "api_key": "sparkmem-local",
    "openai_base_url": EMBED_BASE_URL,
}

CONFIG = {
    "vector_store": {
        "provider": "pgvector",
        "config": {
            "host": os.environ["POSTGRES_HOST"],
            "port": int(os.environ.get("POSTGRES_PORT", 5432)),
            "user": os.environ["POSTGRES_USER"],
            "password": os.environ["POSTGRES_PASSWORD"],
            "dbname": os.environ["POSTGRES_DB"],
            "collection_name": os.environ.get("POSTGRES_COLLECTION_NAME", "memories"),
            "embedding_model_dims": EMBEDDING_DIMS,
        },
    },
    "embedder": {
        "provider": "openai",
        "config": {"model": EMBED_MODEL, "embedding_dims": EMBEDDING_DIMS, **_openai_local},
    },
    "llm": {
        "provider": "openai",
        "config": {"model": EMBED_MODEL, **_openai_local},
    },
}

memory = Memory.from_config(CONFIG)
app = FastAPI(title="sparkmem")


class Message(BaseModel):
    role: str
    content: str


class MemoryCreate(BaseModel):
    messages: list[Message]
    user_id: str
    metadata: dict | None = None
    infer: bool = False


class SearchRequest(BaseModel):
    query: str
    user_id: str
    limit: int = 10
    filters: dict | None = None


class ListRequest(BaseModel):
    user_id: str
    filters: dict | None = None
    limit: int = 100


def _entity_filters(user_id: str, extra: dict | None) -> dict:
    """Merge the user_id scope with caller-supplied metadata filters. mem0's
    local pgvector store matches filter keys directly against the stored
    payload (entity ids and metadata fields alike), so no "metadata" nesting."""
    return {"user_id": user_id, **(extra or {})}


def _find_by_sha256(user_id: str, sha256: str) -> dict | None:
    existing = memory.get_all(filters=_entity_filters(user_id, {"sha256": sha256}), top_k=1)
    results = existing.get("results", [])
    return results[0] if results else None


@app.post("/memories")
def add_memory(req: MemoryCreate):
    try:
        sha256 = (req.metadata or {}).get("sha256")
        if sha256:
            dupe = _find_by_sha256(req.user_id, sha256)
            if dupe:
                return {"results": [{"id": dupe["id"]}], "deduped": True}

        return memory.add(
            [m.model_dump() for m in req.messages],
            user_id=req.user_id,
            metadata=req.metadata,
            infer=req.infer,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.post("/search")
def search_memory(req: SearchRequest):
    try:
        return memory.search(
            req.query, filters=_entity_filters(req.user_id, req.filters), top_k=req.limit
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.post("/memories/list")
def list_memories(req: ListRequest):
    try:
        raw = memory.get_all(filters=_entity_filters(req.user_id, req.filters), top_k=req.limit)
        results = [
            {
                "id": r["id"],
                "memory": r.get("memory"),
                "created_at": r.get("created_at"),
                "metadata": r.get("metadata"),
            }
            for r in raw.get("results", [])
        ]
        return {"results": results}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e)) from e


@app.delete("/memories/{memory_id}")
def delete_memory(memory_id: str):
    try:
        return memory.delete(memory_id=memory_id)
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@app.get("/health")
def health():
    try:
        memory.vector_store.list(limit=1)
        return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=503, detail=str(e)) from e
