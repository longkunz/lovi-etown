import { it } from 'node:test';
import assert from 'node:assert/strict';
import { parseMapQuery } from '../../src/catalog/map-query-schema.js';
const base = { provinceId: 'tp_hcm', bbox: '106,10,107,11' };
it('accepts both modes, bounds, trimmed district and defaults', () => {
  assert.equal(parseMapQuery(base).limit, 200);
  assert.deepEqual(
    parseMapQuery({
      ...base,
      bbox: '-180,-90,180,90',
      district: ' Quận 1 ',
      limit: '1',
    }),
    {
      provinceId: 'tp_hcm',
      mode: 'bbox',
      bbox: [-180, -90, 180, 90],
      district: 'Quận 1',
      limit: 1,
    }
  );
  assert.equal(
    parseMapQuery({
      provinceId: 'tp_hcm',
      lat: '10',
      lng: '106',
      radiusMeters: '100',
    }).mode,
    'nearby'
  );
});
it('rejects malformed, repeated, mixed, missing and unsupported input', () => {
  const invalid: Record<string, unknown>[] = [
    {},
    { ...base, foo: 'x' },
    { ...base, bbox: ['1,2,3,4'] },
    { ...base, lat: '1' },
    { ...base, bbox: '107,10,106,11' },
    { ...base, bbox: '10,106,11,107' },
    { ...base, bbox: '-181,0,1,1' },
    { ...base, bbox: '0,-91,1,1' },
    { ...base, bbox: '0,0,0,1' },
    { ...base, bbox: '0,0,1,NaN' },
    { ...base, bbox: '0,,1,1' },
    { ...base, district: ['x'] },
    { ...base, district: 'x'.repeat(81) },
    ...['2x', '0', '201', '1.5', '', 'NaN', 'Infinity'].map((limit) => ({
      ...base,
      limit,
    })),
    ...['99', '5001', '1000.5', '', 'NaN', 'Infinity'].map((radiusMeters) => ({
      provinceId: 'tp_hcm',
      lat: '10',
      lng: '106',
      radiusMeters,
    })),
    { provinceId: 'tp_hcm', lat: '10', lng: '106' },
    { provinceId: 'tp_hcm', lat: '91', lng: '106', radiusMeters: '1000' },
  ];
  for (const raw of invalid)
    assert.throws(
      () => parseMapQuery(raw),
      (e: any) => e.code === 'INVALID_INPUT',
      JSON.stringify(raw)
    );
  assert.throws(
    () => parseMapQuery({ ...base, provinceId: 'ha_noi' }),
    (e: any) => e.code === 'UNSUPPORTED_PROVINCE'
  );
});
