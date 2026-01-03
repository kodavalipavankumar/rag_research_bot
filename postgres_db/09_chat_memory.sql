CREATE TABLE IF NOT EXISTS conversations (
  conversation_id    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id          uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  owner_principal_id uuid NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  title              text,
  metadata           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_conversations_updated_at
BEFORE UPDATE ON conversations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_conversations_owner
  ON conversations (tenant_id, owner_principal_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
  message_id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  conversation_id     uuid NOT NULL REFERENCES conversations(conversation_id) ON DELETE CASCADE,
  author_principal_id uuid REFERENCES principals(principal_id) ON DELETE SET NULL,
  role                chat_role NOT NULL,
  content             text NOT NULL,
  tool_payload        jsonb,
  citations           jsonb NOT NULL DEFAULT '[]'::jsonb,
  metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conv_time
  ON chat_messages (tenant_id, conversation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS memory_items (
  memory_id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id              uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  conversation_id        uuid REFERENCES conversations(conversation_id) ON DELETE CASCADE,
  created_by_principal_id uuid REFERENCES principals(principal_id) ON DELETE SET NULL,

  mtype                  memory_type NOT NULL,
  title                  text,
  content                text NOT NULL,
  tags                   text[] NOT NULL DEFAULT '{}',
  importance             real NOT NULL DEFAULT 0.5,
  valid_from             timestamptz,
  valid_to               timestamptz,
  metadata               jsonb NOT NULL DEFAULT '{}'::jsonb,

  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_memory_items_updated_at
BEFORE UPDATE ON memory_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_memory_items_conv
  ON memory_items (tenant_id, conversation_id, updated_at DESC);

-- embeddings for memory (dimension 768)
CREATE TABLE IF NOT EXISTS memory_embeddings (
  tenant_id      uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  memory_id      uuid NOT NULL REFERENCES memory_items(memory_id) ON DELETE CASCADE,
  embed_model_id uuid NOT NULL REFERENCES embedding_models(embed_model_id) ON DELETE RESTRICT,
  embed_version  int NOT NULL DEFAULT 1,
  embedding      vector(768) NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, memory_id, embed_model_id, embed_version)
);

CREATE INDEX IF NOT EXISTS memory_embeddings_hnsw
  ON memory_embeddings USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);