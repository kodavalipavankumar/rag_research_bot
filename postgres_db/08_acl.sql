CREATE TABLE IF NOT EXISTS acl_bindings (
  tenant_id    uuid NOT NULL REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  object_type  acl_object_type NOT NULL,
  object_id    uuid NOT NULL,
  principal_id uuid NOT NULL REFERENCES principals(principal_id) ON DELETE CASCADE,
  permission   acl_permission NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, object_type, object_id, principal_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_acl_lookup
  ON acl_bindings (tenant_id, object_type, object_id, permission);

CREATE INDEX IF NOT EXISTS idx_acl_principal
  ON acl_bindings (tenant_id, principal_id);

CREATE INDEX IF NOT EXISTS idx_acl_object
  ON acl_bindings (tenant_id, object_type, object_id);
