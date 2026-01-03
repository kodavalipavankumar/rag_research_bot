-- Create conversation + grant owner admin
CREATE OR REPLACE FUNCTION create_conversation(
  p_tenant_id uuid,
  p_owner_principal_id uuid,
  p_title text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE v_conversation_id uuid;
BEGIN
  INSERT INTO conversations (tenant_id, owner_principal_id, title, metadata)
  VALUES (p_tenant_id, p_owner_principal_id, p_title, COALESCE(p_metadata,'{}'::jsonb))
  RETURNING conversation_id INTO v_conversation_id;

  INSERT INTO acl_bindings (tenant_id, object_type, object_id, principal_id, permission)
  VALUES
    (p_tenant_id, 'conversation', v_conversation_id, p_owner_principal_id, 'read'),
    (p_tenant_id, 'conversation', v_conversation_id, p_owner_principal_id, 'write'),
    (p_tenant_id, 'conversation', v_conversation_id, p_owner_principal_id, 'admin')
  ON CONFLICT DO NOTHING;

  RETURN v_conversation_id;
END $$;

-- Create document + grant creator read/write/admin
CREATE OR REPLACE FUNCTION create_document_with_acl(
  p_title text DEFAULT NULL,
  p_tags text[] DEFAULT '{}',
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_tenant_id uuid := app.current_tenant_id();
  v_principal_id uuid := app.current_principal_id();
  v_doc_id uuid;
BEGIN
  IF v_tenant_id IS NULL OR v_principal_id IS NULL THEN
    RAISE EXCEPTION 'app.tenant_id and app.principal_id must be set for this session';
  END IF;

  INSERT INTO documents (tenant_id, title, tags, metadata, created_by)
  VALUES (v_tenant_id, p_title, COALESCE(p_tags, '{}'), COALESCE(p_metadata, '{}'::jsonb), v_principal_id)
  RETURNING doc_id INTO v_doc_id;

  INSERT INTO acl_bindings (tenant_id, object_type, object_id, principal_id, permission)
  VALUES
    (v_tenant_id, 'document', v_doc_id, v_principal_id, 'read'),
    (v_tenant_id, 'document', v_doc_id, v_principal_id, 'write'),
    (v_tenant_id, 'document', v_doc_id, v_principal_id, 'admin')
  ON CONFLICT DO NOTHING;

  RETURN v_doc_id;
END $$;

-- Append chat message
CREATE OR REPLACE FUNCTION append_chat_message(
  p_tenant_id uuid,
  p_conversation_id uuid,
  p_author_principal_id uuid,
  p_role chat_role,
  p_content text,
  p_tool_payload jsonb DEFAULT NULL,
  p_citations jsonb DEFAULT '[]'::jsonb,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE v_message_id uuid;
BEGIN
  INSERT INTO chat_messages (
    tenant_id, conversation_id, author_principal_id, role, content,
    tool_payload, citations, metadata
  )
  VALUES (
    p_tenant_id, p_conversation_id, p_author_principal_id, p_role, p_content,
    p_tool_payload, COALESCE(p_citations,'[]'::jsonb), COALESCE(p_metadata,'{}'::jsonb)
  )
  RETURNING message_id INTO v_message_id;

  UPDATE conversations
  SET updated_at = now()
  WHERE tenant_id = p_tenant_id AND conversation_id = p_conversation_id;

  RETURN v_message_id;
END $$;

-- Short term memory
CREATE OR REPLACE FUNCTION get_recent_messages(
  p_tenant_id uuid,
  p_conversation_id uuid,
  p_limit int DEFAULT 20
) RETURNS TABLE (
  message_id uuid,
  role chat_role,
  content text,
  citations jsonb,
  metadata jsonb,
  created_at timestamptz
)
LANGUAGE sql AS $$
  SELECT m.message_id, m.role, m.content, m.citations, m.metadata, m.created_at
  FROM chat_messages m
  WHERE m.tenant_id = p_tenant_id
    AND m.conversation_id = p_conversation_id
  ORDER BY m.created_at DESC
  LIMIT GREATEST(p_limit, 0);
$$;

-- Lexical search over chunks (tsvector)
DROP FUNCTION IF EXISTS search_chunks_lexical(uuid, text, int);
CREATE OR REPLACE FUNCTION search_chunks_lexical(
  p_query text,
  p_k int DEFAULT 20
) RETURNS TABLE (
  chunk_id uuid,
  doc_version_id uuid,
  rank real,
  snippet text
)
LANGUAGE sql
STABLE AS $$
  SELECT
    c.chunk_id,
    c.doc_version_id,
    ts_rank_cd(c.tsv, websearch_to_tsquery('english', p_query)) AS rank,
    left(c.text, 300) AS snippet
  FROM chunks c
  WHERE c.tenant_id = app.current_tenant_id()
    AND c.tsv @@ websearch_to_tsquery('english', p_query)
  ORDER BY rank DESC
  LIMIT GREATEST(p_k, 0);
$$;

-- Vector search over chunks (no ACL enforcement here; keep it pure retrieval)
-- NOTE: pass vector literal as '[0.1,0.2,...]'
DROP FUNCTION IF EXISTS search_chunks_vector(uuid, uuid, vector, int);
CREATE OR REPLACE FUNCTION search_chunks_vector(
  p_embed_model_id uuid,
  p_query_embedding vector(768),
  p_k int DEFAULT 20
) RETURNS TABLE (
  chunk_id uuid,
  doc_version_id uuid,
  distance double precision,
  snippet text
)
LANGUAGE sql
STABLE AS $$
  SELECT
    ce.chunk_id,
    c.doc_version_id,
    (ce.embedding <=> p_query_embedding) AS distance,
    left(c.text, 300) AS snippet
  FROM chunk_embeddings ce
  JOIN chunks c
    ON c.chunk_id = ce.chunk_id
   AND c.tenant_id = ce.tenant_id
  WHERE ce.tenant_id = app.current_tenant_id()
    AND ce.embed_model_id = p_embed_model_id
  ORDER BY ce.embedding <=> p_query_embedding
  LIMIT GREATEST(p_k, 0);
$$;
