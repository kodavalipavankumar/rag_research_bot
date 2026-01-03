CREATE TABLE IF NOT EXISTS embedding_models (
  embed_model_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider       text NOT NULL,
  model_name     text NOT NULL,
  dims           int  NOT NULL,
  distance       text NOT NULL DEFAULT 'cosine',
  params         jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, model_name, dims)
);

DO $$ BEGIN
  ALTER TABLE embedding_models
    ADD CONSTRAINT embedding_models_dims_chk CHECK (dims = 768);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Set your embedding dimension here once
-- Default: 768
CREATE TABLE IF NOT EXISTS chunk_embeddings (
  tenant_id      uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  chunk_id       uuid NOT NULL REFERENCES chunks(chunk_id) ON DELETE CASCADE,
  embed_model_id uuid NOT NULL REFERENCES embedding_models(embed_model_id) ON DELETE RESTRICT,
  embed_version  int NOT NULL DEFAULT 1,

  embedding      vector(768) NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),

  PRIMARY KEY (tenant_id, chunk_id, embed_model_id, embed_version)
);

-- HNSW index for cosine similarity
CREATE INDEX IF NOT EXISTS chunk_embeddings_hnsw
  ON chunk_embeddings USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_chunk_embeddings_filter
  ON chunk_embeddings (tenant_id, embed_model_id, created_at DESC);
