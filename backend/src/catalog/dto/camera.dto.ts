import { CameraRecord } from '../catalog.types.js';

export interface CameraDto {
  id: string;
  name: string;
  provinceId: string;
  address: string | null;
  district: string | null;
  location: { lat: number; lng: number } | null;
  capabilities: {
    snapshot: boolean;
    live: boolean;
  };
  availability: string;
  checkedAt: string | null;
  thumbnailEndpoint: string | null;
  snapshotEndpoint: string | null;
  playbackEndpoint: string;
}

export interface PlaybackDto {
  cameraId: string;
  kind: 'snapshot';
  snapshotEndpoint: string;
  refreshIntervalMs: number;
  capturedAt: null;
}

export function toCameraDto(record: CameraRecord): CameraDto {
  const isSnapshotCapable = Boolean(record.capabilities?.snapshot);
  const snapshotEndpoint = isSnapshotCapable ? `/v1/cameras/${record.id}/snapshot` : null;

  return {
    id: record.id,
    name: record.name,
    provinceId: record.provinceId,
    address: record.address,
    district: record.district,
    location: record.location,
    capabilities: {
      snapshot: isSnapshotCapable,
      live: Boolean(record.capabilities?.live),
    },
    availability: record.availability,
    checkedAt: record.checkedAt ? record.checkedAt.toISOString() : null,
    thumbnailEndpoint: snapshotEndpoint,
    snapshotEndpoint,
    playbackEndpoint: `/v1/cameras/${record.id}/playback`,
  };
}
