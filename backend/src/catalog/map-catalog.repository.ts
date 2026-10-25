import pg from 'pg';
import { Clock } from '../http/request-context.js';
import { normalizeText } from './normalize.js';
import { PgCatalogRepository } from './catalog.repository.js';
import { toCatalogState } from './catalog-metadata.js';
import { MapQuery, MapCatalogResult } from './map-catalog.types.js';
export class MapCatalogRepository {
  constructor(
    private readonly pool: pg.Pool,
    private readonly schemaName?: string,
    private readonly clock?: Clock,
    private readonly staleAfterMs = 86400000
  ) {}
  async query(query: MapQuery): Promise<MapCatalogResult> {
    const client = await this.pool.connect();
    try {
      if (this.schemaName)
        await client.query(`SET search_path TO "${this.schemaName}", public`);
      await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
      const state = await client.query(
        'SELECT * FROM catalog_state WHERE id = 1'
      );
      const catalog = toCatalogState(
        state.rows[0],
        this.clock?.now() ?? Date.now(),
        this.staleAfterMs
      );
      const params: unknown[] = [query.provinceId];
      const where = ['province_id = $1', 'geom IS NOT NULL'];
      if (query.district) {
        params.push(normalizeText(query.district));
        where.push(`district_normalized = $${params.length}`);
      }
      let distance = 'NULL::double precision';
      if (query.mode === 'bbox') {
        const n = params.length;
        params.push(...query.bbox);
        where.push(
          `ST_Intersects(geom::geometry, ST_MakeEnvelope($${n + 1},$${n + 2},$${n + 3},$${n + 4},4326))`
        );
      } else {
        const n = params.length;
        params.push(query.lng, query.lat, query.radiusMeters);
        const point = `ST_SetSRID(ST_MakePoint($${n + 1},$${n + 2}),4326)::geography`;
        where.push(`ST_DWithin(geom,${point},$${n + 3})`);
        distance = `ST_Distance(geom,${point})`;
      }
      params.push(query.limit + 1);
      const rows = await client.query(
        `SELECT *, ST_Y(geom::geometry) AS lat, ST_X(geom::geometry) AS lng, ${distance} AS distance_meters FROM cameras WHERE ${where.join(' AND ')} ORDER BY ${query.mode === 'nearby' ? 'distance_meters ASC, ' : ''}id ASC LIMIT $${params.length}`,
        params
      );
      const items = rows.rows.slice(0, query.limit).map((row) => ({
        camera: PgCatalogRepository.mapRowToRecord(row),
        distanceMeters:
          row.distance_meters === null ? null : Number(row.distance_meters),
      }));
      await client.query('COMMIT');
      return {
        items,
        catalog,
        result: {
          limit: query.limit,
          returned: items.length,
          hasMore: rows.rows.length > query.limit,
        },
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
