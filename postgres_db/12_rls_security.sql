-- =========================
-- RLS + security helpers
-- =========================
-- Requires: SET app.tenant_id and SET app.principal_id per session/transaction.
CREATE SCHEMA IF NOT EXISTS app;

CREATE OR REPLACE FUNCTION app.has_doc_permission(
  p_tenant_id uuid,
  p_doc_id uuid,
  p_perm acl_permission
) RETURNS boolean
LANGUAGE sql
STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM acl_bindings ab
    WHERE ab.tenant_id = p_tenant_id
      AND ab.object_type = 'document'
      AND ab.object_id = p_doc_id
      AND ab.principal_id = app.current_principal_id()
      AND (
        (p_perm = 'read' AND ab.permission IN ('read','write','admin'))
        OR (p_perm = 'write' AND ab.permission IN ('write','admin'))
        OR (p_perm = 'admin' AND ab.permission = 'admin')
      )
  );
$$;

-- -------------------------
-- Enable + force RLS
-- -------------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename IN (
        'tenants','principals','principal_membership',
        'external_records',
        'documents','document_versions','document_external_links',
        'document_identifiers','document_kv_metadata',
        'document_artifacts','content_parts','chunks',
        'chunk_embeddings',
        'collections','collection_documents',
        'acl_bindings',
        'conversations','chat_messages','memory_items','memory_embeddings',
        'ingestion_runs','ingestion_jobs',
        'rag_queries','rag_retrievals','rag_feedback'
      )
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', r.tablename);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY;', r.tablename);
  END LOOP;
END $$;

-- -------------------------
-- Tenant-only policies
-- -------------------------
DROP POLICY IF EXISTS rls_tenants_select ON tenants;
DROP POLICY IF EXISTS rls_tenants_insert ON tenants;
DROP POLICY IF EXISTS rls_tenants_update ON tenants;
DROP POLICY IF EXISTS rls_tenants_delete ON tenants;
CREATE POLICY rls_tenants_select ON tenants
  FOR SELECT USING (tenant_id = app.current_tenant_id());
CREATE POLICY rls_tenants_insert ON tenants
  FOR INSERT WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY rls_tenants_update ON tenants
  FOR UPDATE USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());
CREATE POLICY rls_tenants_delete ON tenants
  FOR DELETE USING (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_principals ON principals;
CREATE POLICY rls_principals ON principals
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_principal_membership ON principal_membership;
CREATE POLICY rls_principal_membership ON principal_membership
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_external_records ON external_records;
CREATE POLICY rls_external_records ON external_records
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_collections ON collections;
CREATE POLICY rls_collections ON collections
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_collection_documents ON collection_documents;
CREATE POLICY rls_collection_documents ON collection_documents
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_acl_bindings ON acl_bindings;
CREATE POLICY rls_acl_bindings ON acl_bindings
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_conversations ON conversations;
CREATE POLICY rls_conversations ON conversations
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_chat_messages ON chat_messages;
CREATE POLICY rls_chat_messages ON chat_messages
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_memory_items ON memory_items;
CREATE POLICY rls_memory_items ON memory_items
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_memory_embeddings ON memory_embeddings;
CREATE POLICY rls_memory_embeddings ON memory_embeddings
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_ingestion_runs ON ingestion_runs;
CREATE POLICY rls_ingestion_runs ON ingestion_runs
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_ingestion_jobs ON ingestion_jobs;
CREATE POLICY rls_ingestion_jobs ON ingestion_jobs
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_rag_queries ON rag_queries;
CREATE POLICY rls_rag_queries ON rag_queries
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_rag_retrievals ON rag_retrievals;
CREATE POLICY rls_rag_retrievals ON rag_retrievals
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

DROP POLICY IF EXISTS rls_rag_feedback ON rag_feedback;
CREATE POLICY rls_rag_feedback ON rag_feedback
  USING (tenant_id = app.current_tenant_id())
  WITH CHECK (tenant_id = app.current_tenant_id());

-- -------------------------
-- Documents + ACL policies
-- -------------------------
DROP POLICY IF EXISTS rls_documents_select ON documents;
DROP POLICY IF EXISTS rls_documents_insert ON documents;
DROP POLICY IF EXISTS rls_documents_update ON documents;
DROP POLICY IF EXISTS rls_documents_delete ON documents;
CREATE POLICY rls_documents_select ON documents
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND app.has_doc_permission(tenant_id, doc_id, 'read')
  );
CREATE POLICY rls_documents_insert ON documents
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND (created_by IS NULL OR created_by = app.current_principal_id())
  );
CREATE POLICY rls_documents_update ON documents
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND app.has_doc_permission(tenant_id, doc_id, 'write')
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND app.has_doc_permission(tenant_id, doc_id, 'write')
  );
CREATE POLICY rls_documents_delete ON documents
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND app.has_doc_permission(tenant_id, doc_id, 'admin')
  );

DROP POLICY IF EXISTS rls_document_versions_select ON document_versions;
DROP POLICY IF EXISTS rls_document_versions_insert ON document_versions;
DROP POLICY IF EXISTS rls_document_versions_update ON document_versions;
DROP POLICY IF EXISTS rls_document_versions_delete ON document_versions;
CREATE POLICY rls_document_versions_select ON document_versions
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_versions.doc_id
        AND d.tenant_id = document_versions.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_document_versions_insert ON document_versions
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_versions.doc_id
        AND d.tenant_id = document_versions.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_versions_update ON document_versions
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_versions.doc_id
        AND d.tenant_id = document_versions.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_versions.doc_id
        AND d.tenant_id = document_versions.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_versions_delete ON document_versions
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_versions.doc_id
        AND d.tenant_id = document_versions.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_document_external_links_select ON document_external_links;
DROP POLICY IF EXISTS rls_document_external_links_insert ON document_external_links;
DROP POLICY IF EXISTS rls_document_external_links_update ON document_external_links;
DROP POLICY IF EXISTS rls_document_external_links_delete ON document_external_links;
CREATE POLICY rls_document_external_links_select ON document_external_links
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_external_links.doc_id
        AND d.tenant_id = document_external_links.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_document_external_links_insert ON document_external_links
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_external_links.doc_id
        AND d.tenant_id = document_external_links.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_external_links_update ON document_external_links
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_external_links.doc_id
        AND d.tenant_id = document_external_links.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_external_links.doc_id
        AND d.tenant_id = document_external_links.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_external_links_delete ON document_external_links
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_external_links.doc_id
        AND d.tenant_id = document_external_links.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_document_identifiers_select ON document_identifiers;
DROP POLICY IF EXISTS rls_document_identifiers_insert ON document_identifiers;
DROP POLICY IF EXISTS rls_document_identifiers_update ON document_identifiers;
DROP POLICY IF EXISTS rls_document_identifiers_delete ON document_identifiers;
CREATE POLICY rls_document_identifiers_select ON document_identifiers
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_identifiers.doc_id
        AND d.tenant_id = document_identifiers.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_document_identifiers_insert ON document_identifiers
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_identifiers.doc_id
        AND d.tenant_id = document_identifiers.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_identifiers_update ON document_identifiers
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_identifiers.doc_id
        AND d.tenant_id = document_identifiers.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_identifiers.doc_id
        AND d.tenant_id = document_identifiers.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_identifiers_delete ON document_identifiers
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_identifiers.doc_id
        AND d.tenant_id = document_identifiers.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_document_kv_metadata_select ON document_kv_metadata;
DROP POLICY IF EXISTS rls_document_kv_metadata_insert ON document_kv_metadata;
DROP POLICY IF EXISTS rls_document_kv_metadata_update ON document_kv_metadata;
DROP POLICY IF EXISTS rls_document_kv_metadata_delete ON document_kv_metadata;
CREATE POLICY rls_document_kv_metadata_select ON document_kv_metadata
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_kv_metadata.doc_id
        AND d.tenant_id = document_kv_metadata.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_document_kv_metadata_insert ON document_kv_metadata
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_kv_metadata.doc_id
        AND d.tenant_id = document_kv_metadata.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_kv_metadata_update ON document_kv_metadata
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_kv_metadata.doc_id
        AND d.tenant_id = document_kv_metadata.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_kv_metadata.doc_id
        AND d.tenant_id = document_kv_metadata.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_kv_metadata_delete ON document_kv_metadata
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM documents d
      WHERE d.doc_id = document_kv_metadata.doc_id
        AND d.tenant_id = document_kv_metadata.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_document_artifacts_select ON document_artifacts;
DROP POLICY IF EXISTS rls_document_artifacts_insert ON document_artifacts;
DROP POLICY IF EXISTS rls_document_artifacts_update ON document_artifacts;
DROP POLICY IF EXISTS rls_document_artifacts_delete ON document_artifacts;
CREATE POLICY rls_document_artifacts_select ON document_artifacts
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = document_artifacts.doc_version_id
        AND dv.tenant_id = document_artifacts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_document_artifacts_insert ON document_artifacts
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = document_artifacts.doc_version_id
        AND dv.tenant_id = document_artifacts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_artifacts_update ON document_artifacts
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = document_artifacts.doc_version_id
        AND dv.tenant_id = document_artifacts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = document_artifacts.doc_version_id
        AND dv.tenant_id = document_artifacts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_document_artifacts_delete ON document_artifacts
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = document_artifacts.doc_version_id
        AND dv.tenant_id = document_artifacts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_content_parts_select ON content_parts;
DROP POLICY IF EXISTS rls_content_parts_insert ON content_parts;
DROP POLICY IF EXISTS rls_content_parts_update ON content_parts;
DROP POLICY IF EXISTS rls_content_parts_delete ON content_parts;
CREATE POLICY rls_content_parts_select ON content_parts
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = content_parts.doc_version_id
        AND dv.tenant_id = content_parts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_content_parts_insert ON content_parts
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = content_parts.doc_version_id
        AND dv.tenant_id = content_parts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_content_parts_update ON content_parts
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = content_parts.doc_version_id
        AND dv.tenant_id = content_parts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = content_parts.doc_version_id
        AND dv.tenant_id = content_parts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_content_parts_delete ON content_parts
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = content_parts.doc_version_id
        AND dv.tenant_id = content_parts.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_chunks_select ON chunks;
DROP POLICY IF EXISTS rls_chunks_insert ON chunks;
DROP POLICY IF EXISTS rls_chunks_update ON chunks;
DROP POLICY IF EXISTS rls_chunks_delete ON chunks;
CREATE POLICY rls_chunks_select ON chunks
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = chunks.doc_version_id
        AND dv.tenant_id = chunks.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_chunks_insert ON chunks
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = chunks.doc_version_id
        AND dv.tenant_id = chunks.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_chunks_update ON chunks
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = chunks.doc_version_id
        AND dv.tenant_id = chunks.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = chunks.doc_version_id
        AND dv.tenant_id = chunks.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_chunks_delete ON chunks
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM document_versions dv
      JOIN documents d ON d.doc_id = dv.doc_id AND d.tenant_id = dv.tenant_id
      WHERE dv.doc_version_id = chunks.doc_version_id
        AND dv.tenant_id = chunks.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );

DROP POLICY IF EXISTS rls_chunk_embeddings_select ON chunk_embeddings;
DROP POLICY IF EXISTS rls_chunk_embeddings_insert ON chunk_embeddings;
DROP POLICY IF EXISTS rls_chunk_embeddings_update ON chunk_embeddings;
DROP POLICY IF EXISTS rls_chunk_embeddings_delete ON chunk_embeddings;
CREATE POLICY rls_chunk_embeddings_select ON chunk_embeddings
  FOR SELECT USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM chunks c
      JOIN document_versions dv
        ON dv.doc_version_id = c.doc_version_id
       AND dv.tenant_id = c.tenant_id
      JOIN documents d
        ON d.doc_id = dv.doc_id
       AND d.tenant_id = dv.tenant_id
      WHERE c.chunk_id = chunk_embeddings.chunk_id
        AND c.tenant_id = chunk_embeddings.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'read')
    )
  );
CREATE POLICY rls_chunk_embeddings_insert ON chunk_embeddings
  FOR INSERT WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM chunks c
      JOIN document_versions dv
        ON dv.doc_version_id = c.doc_version_id
       AND dv.tenant_id = c.tenant_id
      JOIN documents d
        ON d.doc_id = dv.doc_id
       AND d.tenant_id = dv.tenant_id
      WHERE c.chunk_id = chunk_embeddings.chunk_id
        AND c.tenant_id = chunk_embeddings.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_chunk_embeddings_update ON chunk_embeddings
  FOR UPDATE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM chunks c
      JOIN document_versions dv
        ON dv.doc_version_id = c.doc_version_id
       AND dv.tenant_id = c.tenant_id
      JOIN documents d
        ON d.doc_id = dv.doc_id
       AND d.tenant_id = dv.tenant_id
      WHERE c.chunk_id = chunk_embeddings.chunk_id
        AND c.tenant_id = chunk_embeddings.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  )
  WITH CHECK (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM chunks c
      JOIN document_versions dv
        ON dv.doc_version_id = c.doc_version_id
       AND dv.tenant_id = c.tenant_id
      JOIN documents d
        ON d.doc_id = dv.doc_id
       AND d.tenant_id = dv.tenant_id
      WHERE c.chunk_id = chunk_embeddings.chunk_id
        AND c.tenant_id = chunk_embeddings.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'write')
    )
  );
CREATE POLICY rls_chunk_embeddings_delete ON chunk_embeddings
  FOR DELETE USING (
    tenant_id = app.current_tenant_id()
    AND EXISTS (
      SELECT 1
      FROM chunks c
      JOIN document_versions dv
        ON dv.doc_version_id = c.doc_version_id
       AND dv.tenant_id = c.tenant_id
      JOIN documents d
        ON d.doc_id = dv.doc_id
       AND d.tenant_id = dv.tenant_id
      WHERE c.chunk_id = chunk_embeddings.chunk_id
        AND c.tenant_id = chunk_embeddings.tenant_id
        AND app.has_doc_permission(d.tenant_id, d.doc_id, 'admin')
    )
  );
