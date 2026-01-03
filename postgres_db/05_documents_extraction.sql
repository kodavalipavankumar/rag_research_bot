-- =========================
-- Internal Documents (truth)
-- =========================
CREATE TABLE IF NOT EXISTS documents (
  doc_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,

  title       text,
  tags        text[] NOT NULL DEFAULT '{}',
  metadata    jsonb NOT NULL DEFAULT '{}'::jsonb,

  created_by  uuid REFERENCES principals(principal_id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_documents_updated_at
BEFORE UPDATE ON documents
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS document_versions (
  doc_version_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_id         uuid NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,

  version_num    int NOT NULL,
  status         doc_status NOT NULL DEFAULT 'REGISTERED',
  error_message  text,

  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, doc_id, version_num)
);

CREATE INDEX IF NOT EXISTS idx_doc_versions_status
  ON document_versions (tenant_id, status, created_at DESC);

-- =========================
-- External link tables (need documents now)
-- =========================
CREATE TABLE IF NOT EXISTS document_external_links (
  tenant_id  uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_id     uuid NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,
  record_id  uuid NOT NULL REFERENCES external_records(record_id) ON DELETE CASCADE,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, doc_id, record_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_document_external_primary
  ON document_external_links (tenant_id, doc_id)
  WHERE is_primary = true;

CREATE TABLE IF NOT EXISTS document_identifiers (
  tenant_id   uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_id      uuid NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,
  id_type     text NOT NULL,
  id_value    text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, doc_id, id_type, id_value)
);

CREATE INDEX IF NOT EXISTS idx_document_identifiers_lookup
  ON document_identifiers (tenant_id, id_type, id_value);

CREATE TABLE IF NOT EXISTS document_kv_metadata (
  tenant_id     uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_id        uuid NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,
  mkey          text NOT NULL,

  mvalue_text   text,
  mvalue_num    numeric,
  mvalue_bool   boolean,
  mvalue_json   jsonb,

  source        text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, doc_id, mkey)
);

CREATE INDEX IF NOT EXISTS idx_document_kv_filter_text
  ON document_kv_metadata (tenant_id, mkey, mvalue_text);

CREATE INDEX IF NOT EXISTS idx_document_kv_filter_num
  ON document_kv_metadata (tenant_id, mkey, mvalue_num);

-- =========================
-- Physical artifacts (truth)
-- =========================
CREATE TABLE IF NOT EXISTS document_artifacts (
  artifact_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id        uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_version_id   uuid NOT NULL REFERENCES document_versions(doc_version_id) ON DELETE CASCADE,

  artifact_type    text NOT NULL,  -- RAW_PDF / OCR_PDF / EXTRACTED_TEXT / etc.
  storage_kind     text NOT NULL,  -- LOCAL_DISK (future: GCS/S3)
  local_path       text,
  uri              text,
  mime_type        text,
  file_size_bytes  bigint,
  content_hash     text,

  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_document_artifacts_lookup
  ON document_artifacts (tenant_id, doc_version_id, artifact_type);

-- =========================
-- Extraction outputs
-- =========================
CREATE TABLE IF NOT EXISTS content_parts (
  part_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_version_id uuid NOT NULL REFERENCES document_versions(doc_version_id) ON DELETE CASCADE,

  ptype          content_part_type NOT NULL,
  part_index     int NOT NULL,
  text           text NOT NULL,

  page_num       int,
  bbox           jsonb,
  extra          jsonb NOT NULL DEFAULT '{}'::jsonb,

  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, doc_version_id, ptype, part_index)
);

CREATE INDEX IF NOT EXISTS idx_content_parts_lookup
  ON content_parts (tenant_id, doc_version_id, ptype, part_index);

-- =========================
-- Chunks (retrieval units)
-- includes lexical search column tsv (generated)
-- =========================
CREATE TABLE IF NOT EXISTS chunks (
  chunk_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_version_id uuid NOT NULL REFERENCES document_versions(doc_version_id) ON DELETE CASCADE,
  part_id        uuid REFERENCES content_parts(part_id) ON DELETE SET NULL,

  chunk_index    int NOT NULL,
  text           text NOT NULL,

  -- lexical search index
  tsv            tsvector GENERATED ALWAYS AS (
                    setweight(to_tsvector('english', coalesce(text,'')), 'A')
                 ) STORED,

  token_count    int,
  char_count     int,
  page_start     int,
  page_end       int,

  citation       jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata       jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at     timestamptz NOT NULL DEFAULT now(),

  UNIQUE (tenant_id, doc_version_id, chunk_index)
);

CREATE INDEX IF NOT EXISTS idx_chunks_doc_version
  ON chunks (tenant_id, doc_version_id, chunk_index);

-- GIN index for lexical search
CREATE INDEX IF NOT EXISTS chunks_tsv_gin
  ON chunks USING gin (tsv);
