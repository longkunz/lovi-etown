CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

CREATE TABLE IF NOT EXISTS schema_migrations (
  id SERIAL PRIMARY KEY,
  version VARCHAR(64) UNIQUE NOT NULL,
  checksum VARCHAR(64) NOT NULL,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS catalog_state (
  id INT PRIMARY KEY DEFAULT 1,
  version BIGINT NOT NULL DEFAULT 0,
  provider VARCHAR(32) NOT NULL,
  province_id VARCHAR(32) NOT NULL,
  bbox JSONB,
  fetched_at TIMESTAMPTZ,
  coverage VARCHAR(32) NOT NULL DEFAULT 'unknown',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT single_catalog_state CHECK (id = 1)
);

CREATE TABLE IF NOT EXISTS catalog_imports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(32) NOT NULL,
  province_id VARCHAR(32) NOT NULL,
  bbox JSONB,
  outcome VARCHAR(32) NOT NULL,
  received_count INT NOT NULL DEFAULT 0,
  upserted_count INT NOT NULL DEFAULT 0,
  coverage VARCHAR(32) NOT NULL DEFAULT 'unknown',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  error_message TEXT
);

CREATE TABLE IF NOT EXISTS cameras (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(32) NOT NULL,
  provider_camera_id VARCHAR(128) NOT NULL,
  name VARCHAR(255) NOT NULL,
  name_normalized VARCHAR(255) NOT NULL,
  province_id VARCHAR(32) NOT NULL,
  address VARCHAR(255),
  address_normalized VARCHAR(255),
  district VARCHAR(100),
  district_normalized VARCHAR(100),
  geom geography(Point, 4326),
  capabilities JSONB NOT NULL DEFAULT '{"snapshot":true,"live":false}',
  availability VARCHAR(32) NOT NULL DEFAULT 'unknown',
  checked_at TIMESTAMPTZ,
  source_kind VARCHAR(32) NOT NULL DEFAULT 'snapshot',
  source_ref VARCHAR(255) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_provider_camera UNIQUE (provider, provider_camera_id)
);

CREATE INDEX IF NOT EXISTS idx_cameras_geom ON cameras USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_cameras_province_district ON cameras (province_id, district_normalized);
CREATE INDEX IF NOT EXISTS idx_cameras_name_normalized ON cameras (name_normalized);
CREATE INDEX IF NOT EXISTS idx_cameras_address_normalized ON cameras (address_normalized);
