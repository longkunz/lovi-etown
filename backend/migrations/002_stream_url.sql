-- T14: store the public HLS playlist URL for cameras whose provider
-- exposes one (Notis `videoUrl`). NULL = snapshot-only camera.
ALTER TABLE cameras ADD COLUMN IF NOT EXISTS stream_url VARCHAR(512);
