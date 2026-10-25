import { it } from 'node:test';
import assert from 'node:assert/strict';
import { createTestSchemaContext } from '../helpers/test-database.js';
import { FakeClock } from '../helpers/clock.js';
import { PgCatalogRepository } from '../../src/catalog/catalog.repository.js';
import { MapCatalogRepository } from '../../src/catalog/map-catalog.repository.js';
import { runMigrations } from '../../src/database/migrate.js';
it('PostGIS excludes null/outside/province/district, includes boundaries, orders ties, limits, and shares catalog semantics', async () => {
  const ctx = await createTestSchemaContext();
  try {
    const clock = new FakeClock(1700000000000);
    const list = new PgCatalogRepository(ctx.pool, ctx.schema, clock);
    const map = new MapCatalogRepository(ctx.pool, ctx.schema, clock);
    const bbox = {
      mode: 'bbox' as const,
      provinceId: 'tp_hcm',
      bbox: [106, 10, 107, 11] as [number, number, number, number],
      limit: 200,
    };
    assert.deepEqual(
      (await map.query(bbox)).catalog,
      (await list.list({ provinceId: 'tp_hcm', limit: 10, offset: 0 })).catalog
    );
    await list.commitImport({
      provider: 'notis',
      provinceId: 'tp_hcm',
      bbox: bbox.bbox,
      fetchedAt: clock.nowDate(),
      cameras: [
        ...[
          { id: 'inside', lat: 10.5, lng: 106.5 },
          { id: 'edge', lat: 10, lng: 106 },
          { id: 'outside', lat: 12, lng: 108 },
        ].map((p) => ({
          provider: 'notis',
          providerCameraId: p.id,
          name: p.id,
          provinceId: 'tp_hcm',
          district: 'Quận 1',
          location: { lat: p.lat, lng: p.lng },
          sourceKind: 'snapshot' as const,
          sourceRef: 'private',
        })),
        {
          provider: 'notis',
          providerCameraId: 'null',
          name: 'null',
          provinceId: 'tp_hcm',
          district: 'Quận 1',
          location: null,
          sourceKind: 'snapshot',
          sourceRef: 'private',
        },
        {
          provider: 'notis',
          providerCameraId: 'province',
          name: 'province',
          provinceId: 'other',
          district: 'Quận 1',
          location: { lat: 10.5, lng: 106.5 },
          sourceKind: 'snapshot',
          sourceRef: 'private',
        },
        {
          provider: 'notis',
          providerCameraId: 'district',
          name: 'district',
          provinceId: 'tp_hcm',
          district: 'Quận 3',
          location: { lat: 10.5, lng: 106.5 },
          sourceKind: 'snapshot',
          sourceRef: 'private',
        },
      ],
    });
    const filtered = await map.query({ ...bbox, district: 'quan 1' });
    assert.equal(filtered.items.length, 2);
    assert.ok(filtered.items.every((item) => item.distanceMeters === null));
    assert.deepEqual(
      filtered.items.map((x) => x.camera.id),
      filtered.items.map((x) => x.camera.id).sort()
    );
    assert.deepEqual((await map.query({ ...bbox, limit: 1 })).result, {
      limit: 1,
      returned: 1,
      hasMore: true,
    });
    // ST_Project provides known geodesic distances without degree approximations.
    const client = await ctx.pool.connect();
    try {
      await client.query(`SET search_path TO "${ctx.schema}", public`);
      await client.query(
        `UPDATE cameras SET geom=ST_Project(ST_SetSRID(ST_MakePoint(106.5,10.5),4326)::geography, CASE WHEN provider_camera_id='outside' THEN 1001 ELSE 999 END, 0) WHERE provider_camera_id IN ('inside','edge','outside')`
      );
    } finally {
      client.release();
    }
    const near = await map.query({
      mode: 'nearby',
      provinceId: 'tp_hcm',
      lat: 10.5,
      lng: 106.5,
      radiusMeters: 1000,
      district: 'quan 1',
      limit: 200,
    });
    assert.equal(near.items.length, 2);
    for (const item of near.items)
      assert.ok(Math.abs(item.distanceMeters! - 999) < 0.01);
    assert.deepEqual(
      near.items.map((x) => x.camera.id),
      near.items.map((x) => x.camera.id).sort()
    );
    clock.advance(86400001);
    assert.equal((await map.query(bbox)).catalog.isStale, true);
    assert.deepEqual(
      (await map.query(bbox)).catalog,
      (await list.list({ provinceId: 'tp_hcm', limit: 10, offset: 0 })).catalog
    );
    assert.deepEqual(
      await runMigrations({ pool: ctx.pool, schema: ctx.schema }),
      []
    );
  } finally {
    await ctx.cleanup();
  }
});
it('keeps rows and metadata in one snapshot when a sync commits between reads', async () => {
  const ctx = await createTestSchemaContext();
  try {
    const writer = new PgCatalogRepository(ctx.pool, ctx.schema);
    const input = {
      provider: 'notis',
      provinceId: 'tp_hcm',
      bbox: [106, 10, 107, 11] as [number, number, number, number],
      fetchedAt: new Date(),
      cameras: [
        {
          provider: 'notis',
          providerCameraId: 'stable',
          name: 'old',
          provinceId: 'tp_hcm',
          location: { lat: 10.5, lng: 106.5 },
          sourceKind: 'snapshot' as const,
          sourceRef: 'private',
        },
      ],
    };
    await writer.commitImport(input);
    const real = await ctx.pool.connect();
    const original = real.query.bind(real);
    let triggered = false;
    const wrapped = {
      query: async (...args: any[]) => {
        const result = await (original as any)(...args);
        if (
          typeof args[0] === 'string' &&
          args[0].startsWith('SELECT * FROM catalog_state') &&
          !triggered
        ) {
          triggered = true;
          await writer.commitImport({
            ...input,
            cameras: [{ ...input.cameras[0], name: 'new' }],
          });
        }
        return result;
      },
      release: () => real.release(),
    };
    const fakePool = { connect: async () => wrapped } as any;
    const result = await new MapCatalogRepository(fakePool, ctx.schema).query({
      mode: 'bbox',
      provinceId: 'tp_hcm',
      bbox: input.bbox,
      limit: 200,
    });
    assert.equal(triggered, true);
    assert.equal(result.catalog.version, '1');
    assert.equal(result.items[0].camera.name, 'old');
    assert.equal((await writer.findBySource('notis', 'stable'))?.name, 'new');
  } finally {
    await ctx.cleanup();
  }
});
it('records spatial EXPLAIN plans on a synthetic catalog of 20000 cameras', async () => {
  const ctx = await createTestSchemaContext();
  try {
    const client = await ctx.pool.connect();
    try {
      await client.query(`SET search_path TO "${ctx.schema}", public`);
      await client.query(
        `INSERT INTO cameras(provider,provider_camera_id,name,name_normalized,province_id,geom,source_kind,source_ref) SELECT 'explain',g::text,'camera','camera','tp_hcm',ST_SetSRID(ST_MakePoint(106+(g%200)*0.005,10+(g/200)*0.005),4326)::geography,'snapshot','private' FROM generate_series(1,20000) g`
      );
      await client.query('ANALYZE cameras');
      for (const predicate of [
        'ST_Intersects(geom::geometry,ST_MakeEnvelope(106.49,10.24,106.51,10.26,4326))',
        'ST_DWithin(geom,ST_SetSRID(ST_MakePoint(106.5,10.25),4326)::geography,1000)',
      ]) {
        const plan = await client.query(
          `EXPLAIN (ANALYZE, BUFFERS) SELECT id FROM cameras WHERE province_id='tp_hcm' AND ${predicate} ORDER BY id LIMIT 201`
        );
        console.log(
          'Map catalog EXPLAIN:',
          predicate,
          '\n' + plan.rows.map((row) => row['QUERY PLAN']).join('\n')
        );
      }
    } finally {
      client.release();
    }
  } finally {
    await ctx.cleanup();
  }
});
