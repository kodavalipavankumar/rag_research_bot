CREATE TABLE IF NOT EXISTS ingestion_runs (
  run_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  source_system text NOT NULL REFERENCES external_sources(source_system) ON DELETE RESTRICT,

  stage         text NOT NULL,
  status        job_status NOT NULL DEFAULT 'PENDING',

  config        jsonb NOT NULL DEFAULT '{}'::jsonb,
  stats         jsonb NOT NULL DEFAULT '{}'::jsonb,

  started_at    timestamptz,
  finished_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ingestion_runs_lookup
  ON ingestion_runs (tenant_id, source_system, created_at DESC);

CREATE TABLE IF NOT EXISTS ingestion_jobs (
  job_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  doc_version_id uuid NOT NULL REFERENCES document_versions(doc_version_id) ON DELETE CASCADE,
  run_id        uuid REFERENCES ingestion_runs(run_id) ON DELETE SET NULL,

  stage         text NOT NULL,
  status        job_status NOT NULL DEFAULT 'PENDING',
  attempts      int NOT NULL DEFAULT 0,

  locked_by     text,
  locked_at     timestamptz,
  error_message text,

  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_ingestion_jobs_updated_at
BEFORE UPDATE ON ingestion_jobs
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_pick
  ON ingestion_jobs (tenant_id, status, stage, updated_at);

CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_run
  ON ingestion_jobs (tenant_id, run_id);

CREATE INDEX IF NOT EXISTS idx_ingestion_jobs_doc_version
  ON ingestion_jobs (tenant_id, doc_version_id);

-- RAG logs
CREATE TABLE IF NOT EXISTS rag_queries (
  query_id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  principal_id    uuid REFERENCES principals(principal_id) ON DELETE SET NULL,
  conversation_id uuid REFERENCES conversations(conversation_id) ON DELETE SET NULL,

  query_text      text NOT NULL,
  rewritten_query text,
  mode            text NOT NULL DEFAULT 'rag',
  latency_ms      int,
  model_name      text,
  extra           jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rag_queries_tenant_time
  ON rag_queries (tenant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS rag_retrievals (
  query_id     uuid NOT NULL REFERENCES rag_queries(query_id) ON DELETE CASCADE,
  tenant_id    uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  stage        text NOT NULL,
  rank         int  NOT NULL,
  source_type  text NOT NULL,  -- chunk|memory
  source_id    uuid NOT NULL,
  score        double precision,
  PRIMARY KEY (query_id, tenant_id, stage, rank)
);

CREATE TABLE IF NOT EXISTS rag_feedback (
  feedback_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  query_id     uuid REFERENCES rag_queries(query_id) ON DELETE SET NULL,
  principal_id uuid REFERENCES principals(principal_id) ON DELETE SET NULL,
  rating       int NOT NULL,
  reason       text,
  extra        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);
