# RAG Postgres Database

This folder documents the PostgreSQL schema under `postgres_db/` and how to use it safely with RLS.

## Overview
- Multi-tenant schema with explicit `tenant_id` on most tables.
- ACL enforcement via `acl_bindings` and RLS policies.
- Document ingestion pipeline: documents -> versions -> content_parts -> chunks -> embeddings.
- Chat and memory tables for conversational context.

## Schema Layout
- `postgres_db/00_extensions.sql`: Required extensions (pgvector, pgcrypto, citext, pg_trgm).
- `postgres_db/01_types.sql`: Enum types used across tables.
- `postgres_db/02_util.sql`: Utility functions and `app.current_*` helpers.
- `postgres_db/03_core_tenancy.sql`: Tenants, principals, group membership.
- `postgres_db/04_external_metadata.sql`: External source metadata.
- `postgres_db/05_documents_extraction.sql`: Documents, versions, parts, chunks.
- `postgres_db/06_embeddings.sql`: Embedding models and chunk embeddings (dimension fixed at 768).
- `postgres_db/07_collections.sql`: Collections and document membership.
- `postgres_db/08_acl.sql`: ACL bindings.
- `postgres_db/09_chat_memory.sql`: Conversations, messages, memory.
- `postgres_db/10_ops_logs.sql`: Ingestion jobs and RAG logs.
- `postgres_db/11_functions.sql`: Helper functions (conversations, search, document creation).
- `postgres_db/12_rls_security.sql`: RLS policies and ACL enforcement.
- `postgres_db/99_seed_demo.sql`: Demo data with a small end-to-end flow.

## RLS and Session Settings
RLS uses session settings to scope data by tenant and principal. Set these per session or transaction:

```sql
SET app.tenant_id = 'your-tenant-uuid';
SET app.principal_id = 'your-principal-uuid';
```

The following helpers read those settings:
- `app.current_tenant_id()`
- `app.current_principal_id()`

## Common Workflows

Create a document with ACL in one call:

```sql
SELECT create_document_with_acl(
  p_title => 'My Document',
  p_tags => ARRAY['demo'],
  p_metadata => '{}'::jsonb
);
```

Search chunks:

```sql
SELECT * FROM search_chunks_lexical('example query', 10);
SELECT * FROM search_chunks_vector('embed-model-uuid', '[0.1,0.2,...]'::vector, 10);
```

## Demo Data
`postgres_db/99_seed_demo.sql` seeds a tenant, a user principal, a document with ACL, chunks, embeddings, and a conversation. It also shows how to set `app.tenant_id` and `app.principal_id` before calling `create_document_with_acl`.

Note: If you run seeds as a non-superuser with `FORCE ROW LEVEL SECURITY`, you must set the session settings or use a role with `BYPASSRLS`.

## Apply and Seed
From the repo root:

```bash
make apply
make seed
```
