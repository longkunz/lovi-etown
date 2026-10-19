import { Bbox, ProviderCamera } from '../catalog/catalog.types.js';

export const CAMERA_PROVIDER = 'CAMERA_PROVIDER';

export interface SnapshotBytes {
  bytes: Buffer;
  mime: string;
}

export abstract class CameraProvider {
  abstract fetchCatalog(bbox: Bbox, signal?: AbortSignal): Promise<ProviderCamera[]>;
  abstract fetchSnapshot(sourceRef: string, signal?: AbortSignal): Promise<SnapshotBytes>;
}
