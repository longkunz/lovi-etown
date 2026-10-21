import { request, Dispatcher } from 'undici';
import { CameraProvider, SnapshotBytes } from './camera-provider.js';
import { Bbox, ProviderCamera } from '../catalog/catalog.types.js';
import { ApiError } from '../http/api-error.js';
import { detectImageMime } from '../snapshot/mime.js';

export interface NotisProviderOptions {
  dispatcher?: Dispatcher;
  origin?: string;
  authToken?: string;
  timeoutMs?: number;
}

const HEX_24_REGEX = /^[0-9a-fA-F]{24}$/;
const MAX_JSON_BYTES = 8388608; // 8 MiB limit

export class NotisProvider extends CameraProvider {
  private readonly dispatcher?: Dispatcher;
  private readonly origin: string;
  private readonly authToken?: string;
  private readonly timeoutMs: number;

  constructor(options?: NotisProviderOptions) {
    super();
    this.dispatcher = options?.dispatcher;
    this.origin = options?.origin || 'https://api.notis.vn';
    this.authToken = options?.authToken;
    this.timeoutMs = options?.timeoutMs || 5000;
  }

  async fetchCatalog(bbox: Bbox, signal?: AbortSignal): Promise<ProviderCamera[]> {
    const [west, south, east, north] = bbox;
    // Map bbox: lat1=north, lng1=west, lat2=south, lng2=east
    const path = `/v4/cameras/bybbox?lat1=${north}&lng1=${west}&lat2=${south}&lng2=${east}`;
    const url = `${this.origin}${path}`;

    const headers: Record<string, string> = {
      accept: 'application/json',
    };
    if (this.authToken && this.authToken.trim()) {
      headers.authorization = `Bearer ${this.authToken.trim()}`;
    }

    try {
      const response = await request(url, {
        method: 'GET',
        headers,
        dispatcher: this.dispatcher,
        signal,
        headersTimeout: this.timeoutMs,
        bodyTimeout: this.timeoutMs,
      });

      if (response.statusCode === 401 || response.statusCode === 403) {
        throw new ApiError('UPSTREAM_AUTH', 502, false, 'Upstream authentication failed');
      }
      if (response.statusCode === 429) {
        throw new ApiError('UPSTREAM_RATE_LIMIT', 502, true, 'Upstream rate limit exceeded');
      }
      if (response.statusCode >= 500) {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, true, `Upstream server error (${response.statusCode})`);
      }
      if (response.statusCode !== 200) {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, `Unexpected upstream status (${response.statusCode})`);
      }

      // Read response body with byte limit
      const chunks: Buffer[] = [];
      let totalBytes = 0;
      for await (const chunk of response.body) {
        totalBytes += chunk.length;
        if (totalBytes > MAX_JSON_BYTES) {
          throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Upstream response exceeded limit');
        }
        chunks.push(chunk as Buffer);
      }

      const bodyText = Buffer.concat(chunks).toString('utf8');
      let parsed: unknown;
      try {
        parsed = JSON.parse(bodyText);
      } catch {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Malformed upstream response');
      }

      if (!Array.isArray(parsed)) {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Upstream response is not an array');
      }

      const results: ProviderCamera[] = [];
      for (const item of parsed) {
        if (!item || typeof item !== 'object') {
          throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Invalid item in upstream response');
        }

        const id = item._id;
        if (typeof id !== 'string' || !HEX_24_REGEX.test(id)) {
          throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Invalid 24-hex camera ID from upstream');
        }

        const name = item.name;
        if (typeof name !== 'string' || !name.trim()) {
          throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Missing camera name from upstream');
        }

        let location: { lat: number; lng: number } | null = null;
        if (typeof item.lat === 'number' && typeof item.lng === 'number' && isFinite(item.lat) && isFinite(item.lng)) {
          location = { lat: item.lat, lng: item.lng };
        } else if (
          item.loc &&
          typeof item.loc === 'object' &&
          Array.isArray(item.loc.coordinates) &&
          item.loc.coordinates.length === 2
        ) {
          // The live Notis API returns GeoJSON: loc.coordinates = [lng, lat]
          // (verified against api.notis.vn on 2026-10-20; no lat/lng fields).
          const [geoLng, geoLat] = item.loc.coordinates;
          if (
            typeof geoLng === 'number' &&
            typeof geoLat === 'number' &&
            isFinite(geoLng) &&
            isFinite(geoLat) &&
            geoLng >= -180 &&
            geoLng <= 180 &&
            geoLat >= -90 &&
            geoLat <= 90
          ) {
            location = { lat: geoLat, lng: geoLng };
          }
        }

        const address = typeof item.address === 'string' && item.address.trim() ? item.address.trim() : null;

        // T14: keep the provider's public HLS playlist when it is a
        // plausible http(s) .m3u8 URL. Anything else (missing, not a URL,
        // not a playlist) degrades to null and the camera stays
        // snapshot-only. Internal addresses under `values` are never read.
        let streamUrl: string | null = null;
        if (typeof item.videoUrl === 'string' && item.videoUrl.trim()) {
          try {
            const parsed = new URL(item.videoUrl.trim());
            if (
              (parsed.protocol === 'http:' || parsed.protocol === 'https:') &&
              parsed.pathname.includes('.m3u8')
            ) {
              streamUrl = parsed.toString();
            }
          } catch {
            // Not a URL — snapshot-only.
          }
        }

        results.push({
          provider: 'notis',
          providerCameraId: id,
          name: name.trim(),
          provinceId: 'tp_hcm',
          address,
          // D3 (spec 2026-10-20, approved): Notis `dist` is kept as a
          // display label only — it follows pre-merger district names and
          // must not be treated as an official administrative key.
          district: typeof item.dist === 'string' && item.dist.trim() ? item.dist.trim() : null,
          location,
          sourceKind: 'snapshot',
          sourceRef: id, // derived strictly from 24-hex ID
          streamUrl,
        });
      }

      return results;
    } catch (err: any) {
      if (err instanceof ApiError) throw err;
      if (err.name === 'AbortError' || err.code === 'ABORT_ERR') {
        throw new ApiError('GATEWAY_TIMEOUT', 504, true, 'Upstream request timed out or was aborted');
      }
      throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, true, `Upstream request failed: ${err.message}`);
    }
  }

  async fetchSnapshot(sourceRef: string, signal?: AbortSignal): Promise<SnapshotBytes> {
    if (!HEX_24_REGEX.test(sourceRef)) {
      throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Invalid camera source reference');
    }

    const url = `${this.origin}/v4/cameras/${sourceRef}/snapshot`;
    const headers: Record<string, string> = {
      accept: 'image/jpeg, image/png, image/webp, image/*;q=0.8, */*;q=0.5',
    };
    if (this.authToken && this.authToken.trim()) {
      headers.authorization = `Bearer ${this.authToken.trim()}`;
    }

    try {
      const response = await request(url, {
        method: 'GET',
        headers,
        dispatcher: this.dispatcher,
        signal,
        headersTimeout: this.timeoutMs,
        bodyTimeout: this.timeoutMs,
      });

      if (response.statusCode === 401 || response.statusCode === 403) {
        throw new ApiError('UPSTREAM_AUTH', 502, false, 'Upstream authentication failed');
      }
      if (response.statusCode === 404) {
        throw new ApiError('UPSTREAM_CAMERA_NOT_FOUND', 502, false, 'Upstream camera snapshot not found');
      }
      if (response.statusCode === 429) {
        throw new ApiError('UPSTREAM_RATE_LIMIT', 502, true, 'Upstream rate limit exceeded');
      }
      if (response.statusCode >= 500) {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, true, `Upstream server error (${response.statusCode})`);
      }
      if (response.statusCode !== 200) {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, `Unexpected upstream status (${response.statusCode})`);
      }

      const MAX_SNAPSHOT_BYTES = 2097152; // 2 MiB
      const chunks: Buffer[] = [];
      let totalBytes = 0;

      for await (const chunk of response.body) {
        totalBytes += chunk.length;
        if (totalBytes > MAX_SNAPSHOT_BYTES) {
          throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Upstream snapshot exceeded maximum allowed size');
        }
        chunks.push(chunk as Buffer);
      }

      const fullBuffer = Buffer.concat(chunks);
      const mime = detectImageMime(fullBuffer);
      if (!mime) {
        throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, false, 'Upstream returned invalid or non-image payload');
      }

      return {
        bytes: fullBuffer,
        mime,
      };
    } catch (err: any) {
      if (err instanceof ApiError) throw err;
      if (err.name === 'AbortError' || err.code === 'ABORT_ERR') {
        throw new ApiError('GATEWAY_TIMEOUT', 504, true, 'Upstream snapshot request timed out or was aborted');
      }
      throw new ApiError('INVALID_UPSTREAM_RESPONSE', 502, true, `Upstream snapshot request failed: ${err.message}`);
    }
  }
}

