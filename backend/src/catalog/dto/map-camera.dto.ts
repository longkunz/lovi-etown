import { CameraDto } from './camera.dto.js';
export interface MapCameraDto {
  camera: CameraDto;
  distanceMeters: number | null;
}

/** Public camera schema mirrors toCameraDto; internal provider/source fields are excluded. */
export const mapCameraSchema = {
  type: 'object' as const,
  required: ['camera', 'distanceMeters'],
  properties: {
    camera: {
      type: 'object' as const,
      required: [
        'id',
        'name',
        'provinceId',
        'address',
        'district',
        'location',
        'capabilities',
        'streamUrl',
        'availability',
        'checkedAt',
        'thumbnailEndpoint',
        'snapshotEndpoint',
        'playbackEndpoint',
      ],
      properties: {
        id: { type: 'string' as const, format: 'uuid' },
        name: { type: 'string' as const },
        provinceId: { type: 'string' as const },
        address: { type: 'string' as const, nullable: true },
        district: { type: 'string' as const, nullable: true },
        location: {
          type: 'object' as const,
          nullable: true,
          properties: {
            lat: { type: 'number' as const },
            lng: { type: 'number' as const },
          },
        },
        capabilities: {
          type: 'object' as const,
          properties: {
            snapshot: { type: 'boolean' as const },
            live: { type: 'boolean' as const },
          },
        },
        streamUrl: { type: 'string' as const, nullable: true },
        availability: { type: 'string' as const },
        checkedAt: {
          type: 'string' as const,
          format: 'date-time',
          nullable: true,
        },
        thumbnailEndpoint: { type: 'string' as const, nullable: true },
        snapshotEndpoint: { type: 'string' as const, nullable: true },
        playbackEndpoint: { type: 'string' as const },
      },
    },
    distanceMeters: {
      type: 'number' as const,
      nullable: true,
      description: 'Straight-line geographic distance in meters; null for bbox',
    },
  },
};
