DO $$ BEGIN
  CREATE TYPE principal_type AS ENUM ('user','group','service');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE doc_status AS ENUM ('REGISTERED','EXTRACTED','CHUNKED','EMBEDDED','INDEXED','FAILED','DELETED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE content_part_type AS ENUM ('text','table','ocr','caption','code','metadata');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE acl_object_type AS ENUM ('document','doc_version','collection','conversation','memory_item');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE acl_permission AS ENUM ('read','write','admin');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE job_status AS ENUM ('PENDING','RUNNING','SUCCEEDED','FAILED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE chat_role AS ENUM ('user','assistant','system','tool');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE memory_type AS ENUM ('summary','fact','preference','task','decision','entity_profile');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;