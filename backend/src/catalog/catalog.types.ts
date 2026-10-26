export type Bbox = [number, number, number, number]; // [west, south, east, north]

/**
 * City-wide Ho Chi Minh City sync window (D5, spec 2026-10-20 — T13).
 * Sized from the full Notis crawl of 2026-10-20 (656 cameras, all inside
 * this box with margin). The previous default was a small central
 * observation window ([106.69, 10.76, 106.71, 10.78]).
 */
export const HCMC_CITY_BBOX: Bbox = [106.45, 10.6, 107.05, 11.05];

export interface ProviderCamera {
  provider: string;
  providerCameraId: string;
  name: string;
  provinceId: string;
  address?: string | null;
  district?: string | null;
  location?: { lat: number; lng: number } | null;
  sourceKind: 'snapshot' | 'hls' | 'evup' | 'youtube' | 'unknown';
  sourceRef: string;
  /** Public HLS playlist URL when the provider exposes one (T14). */
  streamUrl?: string | null;
}

export interface CameraRecord {
  id: string;
  provider: string;
  providerCameraId: string;
  name: string;
  nameNormalized: string;
  provinceId: string;
  address: string | null;
  addressNormalized: string | null;
  district: string | null;
  districtNormalized: string | null;
  location: { lat: number; lng: number } | null;
  capabilities: {
    snapshot: boolean;
    live: boolean;
  };
  availability: 'unknown' | 'online' | 'offline' | 'degraded';
  checkedAt: Date | null;
  updatedAt: Date;
  sourceKind: string;
  sourceRef: string;
  /** Public HLS playlist URL, or null when the camera has no live stream. */
  streamUrl: string | null;
}

export interface CatalogQuery {
  provinceId: string;
  q?: string;
  district?: string;
  limit: number;
  offset: number;
}

export interface CatalogState {
  version: string;
  fetchedAt: string | null;
  isStale: boolean;
  coverage: 'unknown' | 'partial' | 'verified';
  syncState: 'never_synced' | 'synced';
}

export interface DistrictCount {
  district: string;
  cameraCount: number;
  onlineCount?: number;
}

export interface ImportResult {
  version: string;
  upsertedCount: number;
  receivedCount: number;
  coverage: string;
}
