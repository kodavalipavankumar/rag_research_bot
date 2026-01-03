CREATE TABLE IF NOT EXISTS external_sources (
  source_system text PRIMARY KEY,
  description   text,
  base_url      text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS external_records (
  record_id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id         uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  source_system     text NOT NULL REFERENCES external_sources(source_system) ON DELETE RESTRICT,
  external_id       text NOT NULL,
  external_version  text,
  title             text,
  abstract          text,
  authors_json      jsonb,
  published_at      timestamptz,
  updated_at        timestamptz,
  primary_url       text,
  pdf_url           text,
  license           text,
  extra             jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, source_system, external_id, external_version)
);

CREATE INDEX IF NOT EXISTS idx_external_records_lookup
  ON external_records (tenant_id, source_system, external_id);