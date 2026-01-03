DO $$
DECLARE
  v_tenant uuid;
  v_user uuid;
  v_doc uuid;
  v_ver uuid;
  v_part uuid;
  v_chunk1 uuid;
  v_chunk2 uuid;
  v_model uuid;
  v_conv uuid;
  v_doc2 uuid;
BEGIN
  -- tenant
  INSERT INTO tenants (tenant_name)
  VALUES ('demo_tenant')
  ON CONFLICT (tenant_name) DO UPDATE
    SET tenant_name = EXCLUDED.tenant_name
  RETURNING tenant_id INTO v_tenant;

  -- principal
  INSERT INTO principals (tenant_id, ptype, email, display_name)
  VALUES (v_tenant, 'user', 'demo@demo.com', 'Demo User')
  ON CONFLICT DO NOTHING;

  SELECT principal_id INTO v_user
  FROM principals
  WHERE tenant_id = v_tenant AND email = 'demo@demo.com';

  -- external source
  INSERT INTO external_sources (source_system, description, base_url)
  VALUES ('arxiv', 'arXiv', 'https://arxiv.org')
  ON CONFLICT DO NOTHING;

  -- document
  INSERT INTO documents (tenant_id, title, created_by)
  VALUES (v_tenant, 'Demo Document', v_user)
  RETURNING doc_id INTO v_doc;

  -- grant access to document
  INSERT INTO acl_bindings (tenant_id, object_type, object_id, principal_id, permission)
  VALUES
    (v_tenant, 'document', v_doc, v_user, 'read'),
    (v_tenant, 'document', v_doc, v_user, 'write')
  ON CONFLICT DO NOTHING;

  -- document version
  INSERT INTO document_versions (tenant_id, doc_id, version_num, status)
  VALUES (v_tenant, v_doc, 1, 'CHUNKED')
  RETURNING doc_version_id INTO v_ver;

  -- content part
  INSERT INTO content_parts (tenant_id, doc_version_id, ptype, part_index, text, page_num)
  VALUES (
    v_tenant,
    v_ver,
    'text',
    0,
    'This is a demo paragraph used to validate chunking and embeddings.',
    1
  )
  RETURNING part_id INTO v_part;

  -- chunks
  INSERT INTO chunks (
    tenant_id, doc_version_id, part_id, chunk_index, text,
    token_count, char_count, page_start, page_end
  )
  VALUES (
    v_tenant,
    v_ver,
    v_part,
    0,
    'Demo chunk one about embeddings and retrieval.',
    8,
    44,
    1,
    1
  )
  RETURNING chunk_id INTO v_chunk1;

  INSERT INTO chunks (
    tenant_id, doc_version_id, part_id, chunk_index, text,
    token_count, char_count, page_start, page_end
  )
  VALUES (
    v_tenant,
    v_ver,
    v_part,
    1,
    'Demo chunk two about lexical + vector hybrid search.',
    10,
    55,
    1,
    1
  )
  RETURNING chunk_id INTO v_chunk2;

  -- embedding model
  INSERT INTO embedding_models (provider, model_name, dims, distance)
  VALUES ('demo', 'demo-embed-768', 768, 'cosine')
  ON CONFLICT (provider, model_name, dims) DO UPDATE
    SET distance = EXCLUDED.distance
  RETURNING embed_model_id INTO v_model;

  -- embeddings
  INSERT INTO chunk_embeddings (tenant_id, chunk_id, embed_model_id, embed_version, embedding)
  VALUES
    (
      v_tenant,
      v_chunk1,
      v_model,
      1,
      (ARRAY(SELECT 0.001::real FROM generate_series(1, 768)))::vector
    ),
    (
      v_tenant,
      v_chunk2,
      v_model,
      1,
      (ARRAY(SELECT 0.002::real FROM generate_series(1, 768)))::vector
    )
  ON CONFLICT DO NOTHING;

  -- conversation
  INSERT INTO conversations (tenant_id, owner_principal_id, title)
  VALUES (v_tenant, v_user, 'Demo Conversation')
  RETURNING conversation_id INTO v_conv;

  INSERT INTO chat_messages (tenant_id, conversation_id, author_principal_id, role, content)
  VALUES
    (v_tenant, v_conv, v_user, 'user', 'What is this document about?'),
    (v_tenant, v_conv, v_user, 'assistant', 'It is a demo document for validating the RAG DB schema.');

  -- Example: helper function for RLS-safe document creation
  PERFORM set_config('app.tenant_id', v_tenant::text, true);
  PERFORM set_config('app.principal_id', v_user::text, true);
  v_doc2 := create_document_with_acl('Demo Document (ACL helper)', ARRAY['demo'], '{}'::jsonb);
  INSERT INTO document_versions (tenant_id, doc_id, version_num, status)
  VALUES (v_tenant, v_doc2, 1, 'REGISTERED');
END $$;
