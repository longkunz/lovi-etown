import { ApiError } from '../http/api-error.js';
import { validateProvinceId } from './query-schema.js';
import { MapQuery } from './map-catalog.types.js';
import { Bbox } from './catalog.types.js';
const allowed = new Set([
  'provinceId',
  'district',
  'limit',
  'bbox',
  'lat',
  'lng',
  'radiusMeters',
]);
function invalid(): never {
  throw new ApiError(
    'INVALID_INPUT',
    400,
    false,
    'Invalid map query parameters'
  );
}
function number(
  raw: unknown,
  min: number,
  max: number,
  integer = false
): number {
  if (
    typeof raw !== 'string' ||
    !/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(raw.trim())
  )
    invalid();
  if (integer && !/^[0-9]+$/.test(raw)) invalid();
  const value = Number(raw);
  if (
    !Number.isFinite(value) ||
    value < min ||
    value > max ||
    (integer && !Number.isInteger(value))
  )
    invalid();
  return value;
}
export function parseMapQuery(raw: Record<string, unknown>): MapQuery {
  for (const [key, value] of Object.entries(raw))
    if (!allowed.has(key) || typeof value !== 'string') invalid();
  const provinceId = validateProvinceId(raw.provinceId as string);
  const district = (raw.district as string | undefined)?.trim() || undefined;
  if (district && district.length > 80) invalid();
  const limit = raw.limit === undefined ? 200 : number(raw.limit, 1, 200, true);
  const common = { provinceId, district, limit };
  if (raw.bbox !== undefined) {
    if (['lat', 'lng', 'radiusMeters'].some((key) => raw[key] !== undefined))
      invalid();
    const parts = (raw.bbox as string).split(',');
    if (parts.length !== 4) invalid();
    const bbox = parts.map((part, index) =>
      number(part, index % 2 === 0 ? -180 : -90, index % 2 === 0 ? 180 : 90)
    ) as Bbox;
    if (bbox[0] >= bbox[2] || bbox[1] >= bbox[3]) invalid();
    return { ...common, mode: 'bbox', bbox };
  }
  return {
    ...common,
    mode: 'nearby',
    lat: number(raw.lat, -90, 90),
    lng: number(raw.lng, -180, 180),
    radiusMeters: number(raw.radiusMeters, 100, 5000, true),
  };
}
