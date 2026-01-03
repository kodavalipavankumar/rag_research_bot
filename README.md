# RAG Database (PostgreSQL)

This repository contains a PostgreSQL schema for a research-focused RAG bot. It is multi-tenant, ACL-aware, and optimized for document ingestion, chunking, and vector search with pgvector.

## What this DB supports
- Document ingestion with versions, content parts, and chunks.
- Hybrid retrieval (lexical + vector).
- Embeddings tied to a single configured dimension (currently 768).
- Conversations, chat messages, and memory items.
- Ingestion jobs and query logs for observability.
- Row Level Security (RLS) with per-tenant isolation and document ACLs.

## High-level flow
1) `documents` + `document_versions`
2) `content_parts` -> `chunks`
3) `chunk_embeddings` for vector search
4) `rag_queries` + `rag_retrievals` for logging

## RLS usage (required)
RLS policies use session settings to scope data:

```sql
SET app.tenant_id = 'your-tenant-uuid';
SET app.principal_id = 'your-principal-uuid';
```

The helper functions live in the `app` schema and are referenced by RLS policies and search functions.

## Quick start
```bash
make apply
make seed
```

Optional sanity checks (in psql):
```sql
SET app.tenant_id = '<tenant-uuid>';
SET app.principal_id = '<principal-uuid>';
SELECT * FROM search_chunks_lexical('demo', 5);
```

## Docs
See `doc/README.md` for a detailed breakdown of the schema files and usage patterns.

## Note: 
Make sure to add the .env file with required credentials before creating the docker containers
```bash
- POSTGRES_USER=${POSTGRES_USER}
- POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
- POSTGRES_DB=${POSTGRES_DB}
```
