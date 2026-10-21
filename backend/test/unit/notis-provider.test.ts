import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { MockAgent, setGlobalDispatcher } from 'undici';
import { NotisProvider } from '../../src/providers/notis.provider.js';
import { ApiError } from '../../src/http/api-error.js';

describe('Notis Camera Provider (Unit)', () => {
  const origin = 'https://api.notis.vn';

  it('queries bybbox with correct query parameters and maps cameras properly', async () => {
    const mockAgent = new MockAgent();
    mockAgent.disableNetConnect();
    const mockPool = mockAgent.get(origin);

    // bbox = [106.69, 10.76, 106.71, 10.78] -> west=106.69, south=10.76, east=106.71, north=10.78
    // expected query: lat1=10.78, lng1=106.69, lat2=10.76, lng2=106.71
    mockPool
      .intercept({
        path: '/v4/cameras/bybbox?lat1=10.78&lng1=106.69&lat2=10.76&lng2=106.71',
        method: 'GET',
      })
      .reply(
        200,
        [
          {
            _id: '507f1f77bcf86cd799439011',
            name: 'Camera Lê Lợi - Pasteur',
            lat: 10.7738,
            lng: 106.7011,
            address: 'Pasteur, Bến Nghé, Quận 1',
            dist: '01',
            values: { ip: '192.168.1.100' }, // must be discarded!
            liveviewUrl: 'http://malicious-origin.com/stream.m3u8', // must be discarded!
          },
        ],
        { headers: { 'content-type': 'application/json' } }
      );

    const provider = new NotisProvider({ dispatcher: mockAgent });
    const cameras = await provider.fetchCatalog([106.69, 10.76, 106.71, 10.78]);

    assert.equal(cameras.length, 1);
    const cam = cameras[0];
    assert.equal(cam.provider, 'notis');
    assert.equal(cam.providerCameraId, '507f1f77bcf86cd799439011');
    assert.equal(cam.name, 'Camera Lê Lợi - Pasteur');
    assert.equal(cam.location?.lat, 10.7738);
    assert.equal(cam.location?.lng, 106.7011);
    assert.equal(cam.address, 'Pasteur, Bến Nghé, Quận 1');
    assert.equal(cam.sourceKind, 'snapshot');
    assert.equal(cam.sourceRef, '507f1f77bcf86cd799439011');
    // Ensure values.ip and liveviewUrl were not used
    assert.equal((cam as any).values, undefined);
    assert.notEqual(cam.sourceRef, 'http://malicious-origin.com/stream.m3u8');
  });

  it('maps GeoJSON loc.coordinates ([lng, lat]) from the live Notis payload shape', async () => {
    const mockAgent = new MockAgent();
    mockAgent.disableNetConnect();
    const mockPool = mockAgent.get(origin);

    mockPool
      .intercept({ path: (p) => p.startsWith('/v4/cameras/bybbox'), method: 'GET' })
      .reply(
        200,
        [
          {
            // Shape verified against api.notis.vn on 2026-10-20: no lat/lng
            // fields, coordinates live in loc.coordinates as [lng, lat].
            _id: '58af8eb2bd82540010390c30',
            id: 'TTH 35.6',
            name: 'Nam Kỳ Khởi Nghĩa -Nguyễn Thị Minh Khai 1',
            dist: 'Quận 3',
            angle: 210,
            loc: { type: 'Point', coordinates: [106.69508278369902, 10.779754243901596] },
            ptz: false,
            liveviewUrl: 'cameras/58af8eb2bd82540010390c30', // must be discarded
            videoUrl: 'http://125.234.114.126:11984/api/stream.m3u8?src=cam1',
            values: { ip: '180.1.1.39' }, // must be discarded
          },
          {
            _id: '58af8eb2bd82540010390c31',
            name: 'Camera Broken Coordinates',
            loc: { type: 'Point', coordinates: [106.695, 107.79] }, // lat out of range
            videoUrl: 'rtsp://internal.example/stream', // not http(s) HLS — must degrade to null
          },
        ],
        { headers: { 'content-type': 'application/json' } }
      );

    const provider = new NotisProvider({ dispatcher: mockAgent });
    const cameras = await provider.fetchCatalog([106.69, 10.76, 106.71, 10.78]);

    assert.equal(cameras.length, 2);
    assert.equal(cameras[0].location?.lng, 106.69508278369902);
    assert.equal(cameras[0].location?.lat, 10.779754243901596);
    assert.equal(cameras[0].address, null);
    assert.equal(cameras[0].sourceRef, '58af8eb2bd82540010390c30');
    // Out-of-range GeoJSON coordinates degrade to a null location, not a failure
    assert.equal(cameras[1].location, null);
    // D3: `dist` is mapped through as the display district label;
    // a missing `dist` degrades to null.
    assert.equal(cameras[0].district, 'Quận 3');
    assert.equal(cameras[1].district, null);
    // T14: a plausible public HLS videoUrl is kept as streamUrl; a
    // non-HTTP(S)/non-playlist value degrades to null (snapshot-only).
    assert.equal(cameras[0].streamUrl, 'http://125.234.114.126:11984/api/stream.m3u8?src=cam1');
    assert.equal(cameras[1].streamUrl, null);
  });

  it('rejects cameras with invalid 24-hex ID or missing required name', async () => {
    const mockAgent = new MockAgent();
    mockAgent.disableNetConnect();
    const mockPool = mockAgent.get(origin);

    mockPool
      .intercept({
        path: (path) => path.startsWith('/v4/cameras/bybbox'),
        method: 'GET',
      })
      .reply(
        200,
        [
          {
            _id: 'not_a_valid_24_hex_id',
            name: 'Camera Invalid',
          },
        ],
        { headers: { 'content-type': 'application/json' } }
      );

    const provider = new NotisProvider({ dispatcher: mockAgent });
    await assert.rejects(
      async () => provider.fetchCatalog([106.69, 10.76, 106.71, 10.78]),
      (err: ApiError) => {
        assert.equal(err.code, 'INVALID_UPSTREAM_RESPONSE');
        return true;
      }
    );
  });

  it('maps upstream errors (401/403, 429, 500) to sanitized ApiError', async () => {
    const mockAgent = new MockAgent();
    mockAgent.disableNetConnect();
    const mockPool = mockAgent.get(origin);

    // 401
    mockPool
      .intercept({ path: (p) => p.startsWith('/v4/cameras/bybbox'), method: 'GET' })
      .reply(401, { message: 'Unauthorized secret token' });

    const provider = new NotisProvider({ dispatcher: mockAgent });
    await assert.rejects(
      async () => provider.fetchCatalog([106.69, 10.76, 106.71, 10.78]),
      (err: ApiError) => {
        assert.equal(err.code, 'UPSTREAM_AUTH');
        assert.doesNotMatch(err.message, /secret token/);
        return true;
      }
    );
  });

  it('handles empty camera array gracefully without failure', async () => {
    const mockAgent = new MockAgent();
    mockAgent.disableNetConnect();
    const mockPool = mockAgent.get(origin);

    mockPool
      .intercept({ path: (p) => p.startsWith('/v4/cameras/bybbox'), method: 'GET' })
      .reply(200, [], { headers: { 'content-type': 'application/json' } });

    const provider = new NotisProvider({ dispatcher: mockAgent });
    const cameras = await provider.fetchCatalog([106.69, 10.76, 106.71, 10.78]);
    assert.deepEqual(cameras, []);
  });
});
