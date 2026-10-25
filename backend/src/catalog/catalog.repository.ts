import { toCatalogState } from './catalog-metadata.js';
import pg from 'pg';
import {
  Bbox,
  CameraRecord,
  CatalogQuery,
  CatalogState,
  DistrictCount,
  ImportResult,
  ProviderCamera,
} from './catalog.types.js';
import { normalizeText } from './normalize.js';
import { Clock } from '../http/request-context.js';

export const CATALOG_REPOSITORY = 'CATALOG_REPOSITORY';

export interface CatalogRepository {
  commitImport(input: {
    provider: string;
    provinceId: string;
    bbox: Bbox;
    cameras: ProviderCamera[];
    fetchedAt: Date;
    coverage?: 'unknown' | 'partial' | 'verified';
  }): Promise<ImportResult>;

  list(query: CatalogQuery): Promise<{
    items: CameraRecord[];
    total: number;
    catalog: CatalogState;
  }>;

  find(id: string): Promise<CameraRecord | null>;
  findBySource(provider: string, providerCameraId: string): Promise<CameraRecord | null>;
  districts(provinceId: string): Promise<DistrictCount[]>;
  related(
    camera: CameraRecord,
    limit: number
  ): Promise<{ items: CameraRecord[]; reason?: string }>;
  updateAvailability(
    id: string,
    availability: 'online' | 'offline' | 'degraded',
    checkedAt: Date
  ): Promise<void>;
}

function escapeLikeLiteral(str: string): string {
  return str.replace(/[%_\\]/g, '\\$&');
}

export class PgCatalogRepository implements CatalogRepository {
  constructor(
    private readonly pool: pg.Pool,
    private readonly schemaName?: string,
    private readonly clock?: Clock,
    private readonly catalogStaleAfterMs: number = 86400000
  ) {}

  private async getClient(): Promise<pg.PoolClient> {
    const client = await this.pool.connect();
    if (this.schemaName) {
      await client.query(`SET search_path TO "${this.schemaName}", public`);
    }
    return client;
  }

  async commitImport(input: {
    provider: string;
    provinceId: string;
    bbox: Bbox;
    cameras: ProviderCamera[];
    fetchedAt: Date;
    coverage?: 'unknown' | 'partial' | 'verified';
  }): Promise<ImportResult> {
    const client = await this.getClient();
    try {
      await client.query('BEGIN');

      // Fetch or initialize version
      const stateRes = await client.query(
        'SELECT version FROM catalog_state WHERE id = 1 FOR UPDATE'
      );
      let nextVersion = 1n;
      if (stateRes.rows.length > 0) {
        nextVersion = BigInt(stateRes.rows[0].version) + 1n;
      }

      let upsertedCount = 0;
      for (const cam of input.cameras) {
        const nameNorm = normalizeText(cam.name);
        const addressNorm = cam.address ? normalizeText(cam.address) : null;
        const districtNorm = cam.district ? normalizeText(cam.district) : null;
        const capabilities = JSON.stringify({
          snapshot: cam.sourceKind === 'snapshot',
          // T14: live exactly when the provider gave a public HLS URL.
          live: typeof cam.streamUrl === 'string' && cam.streamUrl.length > 0,
        });

        let geomSql = 'NULL';
        const params: any[] = [
          cam.provider,
          cam.providerCameraId,
          cam.name,
          nameNorm,
          cam.provinceId,
          cam.address ?? null,
          addressNorm,
          cam.district ?? null,
          districtNorm,
          capabilities,
          cam.sourceKind,
          cam.sourceRef,
          cam.streamUrl ?? null,
        ];

        if (cam.location && typeof cam.location.lat === 'number' && typeof cam.location.lng === 'number') {
          params.push(cam.location.lng, cam.location.lat);
          geomSql = `ST_SetSRID(ST_MakePoint($${params.length - 1}, $${params.length}), 4326)::geography`;
        }

        const upsertQuery = `
          INSERT INTO cameras (
            provider, provider_camera_id, name, name_normalized, province_id,
            address, address_normalized, district, district_normalized,
            geom, capabilities, source_kind, source_ref, stream_url, updated_at
          ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, ${geomSql}, $10, $11, $12, $13, NOW()
          )
          ON CONFLICT (provider, provider_camera_id) DO UPDATE SET
            name = EXCLUDED.name,
            name_normalized = EXCLUDED.name_normalized,
            address = EXCLUDED.address,
            address_normalized = EXCLUDED.address_normalized,
            district = EXCLUDED.district,
            district_normalized = EXCLUDED.district_normalized,
            geom = EXCLUDED.geom,
            capabilities = EXCLUDED.capabilities,
            source_kind = EXCLUDED.source_kind,
            source_ref = EXCLUDED.source_ref,
            stream_url = EXCLUDED.stream_url,
            updated_at = NOW()
          RETURNING id;
        `;

        await client.query(upsertQuery, params);
        upsertedCount++;
      }

      const coverage = input.coverage || (input.cameras.length > 0 ? 'partial' : 'unknown');

      // Update catalog_state
      await client.query(
        `INSERT INTO catalog_state (id, version, provider, province_id, bbox, fetched_at, coverage, updated_at)
         VALUES (1, $1, $2, $3, $4, $5, $6, NOW())
         ON CONFLICT (id) DO UPDATE SET
           version = EXCLUDED.version,
           provider = EXCLUDED.provider,
           province_id = EXCLUDED.province_id,
           bbox = EXCLUDED.bbox,
           fetched_at = EXCLUDED.fetched_at,
           coverage = EXCLUDED.coverage,
           updated_at = NOW()`,
        [
          nextVersion.toString(),
          input.provider,
          input.provinceId,
          JSON.stringify(input.bbox),
          input.fetchedAt,
          coverage,
        ]
      );

      // Record successful import
      await client.query(
        `INSERT INTO catalog_imports (
           provider, province_id, bbox, outcome, received_count, upserted_count, coverage, started_at, finished_at
         ) VALUES ($1, $2, $3, 'success', $4, $5, $6, $7, NOW())`,
        [
          input.provider,
          input.provinceId,
          JSON.stringify(input.bbox),
          input.cameras.length,
          upsertedCount,
          coverage,
          input.fetchedAt,
        ]
      );

      await client.query('COMMIT');

      return {
        version: nextVersion.toString(),
        upsertedCount,
        receivedCount: input.cameras.length,
        coverage,
      };
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  }

  async list(query: CatalogQuery): Promise<{
    items: CameraRecord[];
    total: number;
    catalog: CatalogState;
  }> {
    const client = await this.getClient();
    try {
      // 1. Fetch catalog state
      const stateRes = await client.query('SELECT * FROM catalog_state WHERE id = 1');
      const catalog = toCatalogState(stateRes.rows[0], this.clock?.now() ?? Date.now(), this.catalogStaleAfterMs);

      // 2. Query cameras
      const whereClauses: string[] = ['province_id = $1'];
      const params: any[] = [query.provinceId];

      if (query.district && query.district.trim()) {
        const normDist = normalizeText(query.district);
        params.push(normDist);
        whereClauses.push(`district_normalized = $${params.length}`);
      }

      if (query.q && query.q.trim()) {
        const normQ = normalizeText(query.q);
        const escaped = escapeLikeLiteral(normQ);
        params.push(`%${escaped}%`);
        const qParamIdx = params.length;
        whereClauses.push(
          `(name_normalized LIKE $${qParamIdx} ESCAPE '\\' OR (address_normalized IS NOT NULL AND address_normalized LIKE $${qParamIdx} ESCAPE '\\'))`
        );
      }

      const whereSql = whereClauses.join(' AND ');

      // Count query
      const countRes = await client.query(
        `SELECT COUNT(*) as total FROM cameras WHERE ${whereSql}`,
        params
      );
      const total = parseInt(countRes.rows[0].total, 10);

      // Data query with stable sort: name_normalized ASC, id ASC
      params.push(query.limit, query.offset);
      const limitIdx = params.length - 1;
      const offsetIdx = params.length;

      const dataQuery = `
        SELECT 
          id, provider, provider_camera_id, name, name_normalized, province_id,
          address, address_normalized, district, district_normalized,
          CASE WHEN geom IS NOT NULL THEN ST_Y(geom::geometry) ELSE NULL END as lat,
          CASE WHEN geom IS NOT NULL THEN ST_X(geom::geometry) ELSE NULL END as lng,
          capabilities, availability, checked_at, updated_at, source_kind, source_ref, stream_url
        FROM cameras
        WHERE ${whereSql}
        ORDER BY name_normalized ASC, id ASC
        LIMIT $${limitIdx} OFFSET $${offsetIdx}
      `;

      const dataRes = await client.query(dataQuery, params);
      const items = dataRes.rows.map((r) => PgCatalogRepository.mapRowToRecord(r));

      return { items, total, catalog };
    } finally {
      client.release();
    }
  }

  async find(id: string): Promise<CameraRecord | null> {
    const client = await this.getClient();
    try {
      const res = await client.query(
        `SELECT 
           id, provider, provider_camera_id, name, name_normalized, province_id,
           address, address_normalized, district, district_normalized,
           CASE WHEN geom IS NOT NULL THEN ST_Y(geom::geometry) ELSE NULL END as lat,
           CASE WHEN geom IS NOT NULL THEN ST_X(geom::geometry) ELSE NULL END as lng,
           capabilities, availability, checked_at, updated_at, source_kind, source_ref, stream_url
         FROM cameras WHERE id = $1`,
        [id]
      );
      if (res.rows.length === 0) return null;
      return PgCatalogRepository.mapRowToRecord(res.rows[0]);
    } finally {
      client.release();
    }
  }

  async findBySource(provider: string, providerCameraId: string): Promise<CameraRecord | null> {
    const client = await this.getClient();
    try {
      const res = await client.query(
        `SELECT 
           id, provider, provider_camera_id, name, name_normalized, province_id,
           address, address_normalized, district, district_normalized,
           CASE WHEN geom IS NOT NULL THEN ST_Y(geom::geometry) ELSE NULL END as lat,
           CASE WHEN geom IS NOT NULL THEN ST_X(geom::geometry) ELSE NULL END as lng,
           capabilities, availability, checked_at, updated_at, source_kind, source_ref, stream_url
         FROM cameras WHERE provider = $1 AND provider_camera_id = $2`,
        [provider, providerCameraId]
      );
      if (res.rows.length === 0) return null;
      return PgCatalogRepository.mapRowToRecord(res.rows[0]);
    } finally {
      client.release();
    }
  }

  async districts(provinceId: string): Promise<DistrictCount[]> {
    const client = await this.getClient();
    try {
      const res = await client.query(
        `SELECT district, 
                COUNT(*) as count,
                COUNT(*) FILTER (WHERE availability = 'online') as online_count
         FROM cameras
         WHERE province_id = $1 AND district IS NOT NULL AND TRIM(district) <> ''
         GROUP BY district
         ORDER BY district ASC`,
        [provinceId]
      );
      return res.rows.map((r) => ({
        district: r.district,
        cameraCount: parseInt(r.count, 10),
        onlineCount: parseInt(r.online_count, 10),
      }));
    } finally {
      client.release();
    }
  }

  async related(
    camera: CameraRecord,
    limit: number = 6
  ): Promise<{ items: CameraRecord[]; reason?: string }> {
    if (!camera.district || !camera.districtNormalized) {
      return { items: [], reason: 'DISTRICT_UNKNOWN' };
    }

    const client = await this.getClient();
    try {
      const res = await client.query(
        `SELECT 
           id, provider, provider_camera_id, name, name_normalized, province_id,
           address, address_normalized, district, district_normalized,
           CASE WHEN geom IS NOT NULL THEN ST_Y(geom::geometry) ELSE NULL END as lat,
           CASE WHEN geom IS NOT NULL THEN ST_X(geom::geometry) ELSE NULL END as lng,
           capabilities, availability, checked_at, updated_at, source_kind, source_ref, stream_url
         FROM cameras
         WHERE province_id = $1 AND district_normalized = $2 AND id <> $3
         ORDER BY name_normalized ASC, id ASC
         LIMIT $4`,
        [camera.provinceId, camera.districtNormalized, camera.id, limit]
      );
      return { items: res.rows.map((r) => PgCatalogRepository.mapRowToRecord(r)) };
    } finally {
      client.release();
    }
  }

  async updateAvailability(
    id: string,
    availability: 'online' | 'offline' | 'degraded',
    checkedAt: Date
  ): Promise<void> {
    const client = await this.getClient();
    try {
      await client.query(
        `UPDATE cameras SET availability = $1, checked_at = $2 WHERE id = $3`,
        [availability, checkedAt, id]
      );
    } finally {
      client.release();
    }
  }

  static mapRowToRecord(row: any): CameraRecord {
    return {
      id: row.id,
      provider: row.provider,
      providerCameraId: row.provider_camera_id,
      name: row.name,
      nameNormalized: row.name_normalized,
      provinceId: row.province_id,
      address: row.address,
      addressNormalized: row.address_normalized,
      district: row.district,
      districtNormalized: row.district_normalized,
      location:
        row.lat !== null && row.lng !== null
          ? { lat: parseFloat(row.lat), lng: parseFloat(row.lng) }
          : null,
      capabilities:
        typeof row.capabilities === 'string'
          ? JSON.parse(row.capabilities)
          : row.capabilities,
      availability: row.availability,
      checkedAt: row.checked_at ? new Date(row.checked_at) : null,
      updatedAt: new Date(row.updated_at),
      sourceKind: row.source_kind,
      sourceRef: row.source_ref,
      streamUrl: row.stream_url ?? null,
    };
  }
}
