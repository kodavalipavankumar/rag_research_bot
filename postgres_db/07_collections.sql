CREATE TABLE IF NOT EXISTS collections (
  collection_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, name)
);

CREATE TABLE IF NOT EXISTS collection_documents (
  tenant_id      uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  collection_id  uuid NOT NULL REFERENCES collections(collection_id) ON DELETE CASCADE,
  doc_id         uuid NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,
  created_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, collection_id, doc_id)
);

CREATE INDEX IF NOT EXISTS idx_collection_documents_doc
  ON collection_documents (tenant_id, doc_id);
