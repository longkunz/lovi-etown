import { describe, it } from 'node:test';
import assert from 'node:assert';
import { HCMC_CITY_BBOX } from '../../src/catalog/catalog.types.js';
import { coverageForBbox } from '../../src/sync/sync.service.js';
import { validateBbox } from '../../src/sync/sync.controller.js';

describe('City-wide coverage (T13)', () => {
  it('city bbox is valid and has the approved D5 extent', () => {
    const bbox = validateBbox([...HCMC_CITY_BBOX]);
    assert.deepEqual(bbox, [106.45, 10.6, 107.05, 11.05]);
  });

  it('city bbox fully contains the old central observation window', () => {
    const [w, s, e, n] = HCMC_CITY_BBOX;
    const [ow, os, oe, on] = [106.69, 10.76, 106.71, 10.78];
    assert.ok(w <= ow && s <= os && e >= oe && n >= on);
  });

  it('coverageForBbox: the city window itself is verified', () => {
    assert.equal(coverageForBbox(HCMC_CITY_BBOX), 'verified');
  });

  it('coverageForBbox: a larger window is verified', () => {
    assert.equal(coverageForBbox([106.0, 10.0, 108.0, 11.5]), 'verified');
  });

  it('coverageForBbox: the old central window is only partial', () => {
    assert.equal(coverageForBbox([106.69, 10.76, 106.71, 10.78]), 'partial');
  });

  it('coverageForBbox: a window missing one edge is partial', () => {
    assert.equal(coverageForBbox([106.45, 10.6, 107.05, 11.0]), 'partial');
    assert.equal(coverageForBbox([106.5, 10.6, 107.05, 11.05]), 'partial');
  });
});
