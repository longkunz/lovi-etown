import { Bbox, CameraRecord, CatalogState } from './catalog.types.js';
type Common = { provinceId: string; district?: string; limit: number };
export type MapQuery = Common &
  (
    | { mode: 'bbox'; bbox: Bbox }
    | { mode: 'nearby'; lat: number; lng: number; radiusMeters: number }
  );
export interface MapCatalogResult {
  items: { camera: CameraRecord; distanceMeters: number | null }[];
  catalog: CatalogState;
  result: { limit: number; returned: number; hasMore: boolean };
}
