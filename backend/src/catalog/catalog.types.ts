export type Bbox = [number, number, number, number]; // [west, south, east, north]

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
}

export interface ImportResult {
  version: string;
  upsertedCount: number;
  receivedCount: number;
  coverage: string;
}
