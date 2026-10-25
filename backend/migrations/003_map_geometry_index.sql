CREATE INDEX IF NOT EXISTS cameras_geom_geometry_gist ON cameras USING GIST ((geom::geometry));
