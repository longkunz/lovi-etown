import { ApiError } from '../http/api-error.js';
import { CatalogQuery } from './catalog.types.js';

const UUID_REGEX = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const ALLOWED_LIST_PARAMS = new Set(['provinceId', 'q', 'district', 'limit', 'offset']);

export function validateUuid(id: string, paramName: string = 'id'): string {
  if (!id || typeof id !== 'string' || !UUID_REGEX.test(id)) {
    throw new ApiError('INVALID_INPUT', 400, false, `Invalid ${paramName} parameter, must be a valid UUID`);
  }
  return id;
}

export function validateProvinceId(provinceId?: string): string {
  if (!provinceId || typeof provinceId !== 'string') {
    throw new ApiError('INVALID_INPUT', 400, false, 'provinceId query parameter is required');
  }
  const trimmed = provinceId.trim();
  if (trimmed !== 'tp_hcm') {
    throw new ApiError('UNSUPPORTED_PROVINCE', 400, false, `Province '${trimmed}' is unsupported, only 'tp_hcm' is allowed`);
  }
  return trimmed;
}

export function parseCatalogQuery(rawQuery: Record<string, any>): CatalogQuery {
  // Reject unknown query parameters
  for (const key of Object.keys(rawQuery)) {
    if (!ALLOWED_LIST_PARAMS.has(key)) {
      throw new ApiError('INVALID_INPUT', 400, false, `Unexpected query parameter '${key}'`);
    }
  }

  const provinceId = validateProvinceId(rawQuery.provinceId);

  let q: string | undefined = undefined;
  if (rawQuery.q !== undefined && rawQuery.q !== null) {
    const trimmed = String(rawQuery.q).trim();
    if (trimmed.length === 1) {
      throw new ApiError('INVALID_INPUT', 400, false, 'Search query must be at least 2 characters');
    }
    if (trimmed.length > 120) {
      throw new ApiError('INVALID_INPUT', 400, false, 'Search query must not exceed 120 characters');
    }
    if (trimmed.length >= 2) {
      q = trimmed;
    }
  }

  let district: string | undefined = undefined;
  if (rawQuery.district !== undefined && rawQuery.district !== null) {
    const trimmed = String(rawQuery.district).trim();
    if (trimmed.length > 80) {
      throw new ApiError('INVALID_INPUT', 400, false, 'district filter must not exceed 80 characters');
    }
    if (trimmed.length >= 1) {
      district = trimmed;
    }
  }

  let limit = 50;
  if (rawQuery.limit !== undefined && rawQuery.limit !== null) {
    const parsed = parseInt(String(rawQuery.limit), 10);
    if (isNaN(parsed) || parsed < 1 || parsed > 100) {
      throw new ApiError('INVALID_INPUT', 400, false, 'limit must be an integer between 1 and 100');
    }
    limit = parsed;
  }

  let offset = 0;
  if (rawQuery.offset !== undefined && rawQuery.offset !== null) {
    const parsed = parseInt(String(rawQuery.offset), 10);
    if (isNaN(parsed) || parsed < 0 || parsed > 10000) {
      throw new ApiError('INVALID_INPUT', 400, false, 'offset must be an integer between 0 and 10000');
    }
    offset = parsed;
  }

  return {
    provinceId,
    q,
    district,
    limit,
    offset,
  };
}

export function parseRelatedLimit(limitParam?: any): number {
  if (limitParam === undefined || limitParam === null) {
    return 6;
  }
  const parsed = parseInt(String(limitParam), 10);
  if (isNaN(parsed) || parsed < 1 || parsed > 20) {
    throw new ApiError('INVALID_INPUT', 400, false, 'limit must be an integer between 1 and 20');
  }
  return parsed;
}
