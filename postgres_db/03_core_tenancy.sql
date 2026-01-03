CREATE TABLE IF NOT EXISTS tenants (
  tenant_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_name text NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS principals (
  principal_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  ptype        principal_type NOT NULL,
  email        citext,
  display_name text,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, ptype, email)
);

CREATE TABLE IF NOT EXISTS principal_membership (
  tenant_id uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  group_id  uuid NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  member_id uuid NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, group_id, member_id)
);

CREATE INDEX IF NOT EXISTS idx_principals_tenant_ptype
  ON principals (tenant_id, ptype);

DO $$ BEGIN
  ALTER TABLE principals
    ADD CONSTRAINT principals_email_by_type_chk
    CHECK (
      (ptype IN ('user','service') AND email IS NOT NULL)
      OR (ptype = 'group' AND email IS NULL)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_principals_tenant_ptype_email
  ON principals (tenant_id, ptype, email)
  WHERE email IS NOT NULL;
