/**
 * Availability transition detection for per-camera notifications (T16).
 * Pure logic: the prober feeds the previous availability (from the
 * catalog) and the freshly probed one; only meaningful transitions
 * produce a notification event:
 *   online|degraded -> offline   => "offline" event
 *   offline -> online            => "recovered" event
 * A first probe from `unknown` never notifies (no baseline yet).
 */
export type Availability = 'unknown' | 'online' | 'offline' | 'degraded';

export interface AvailabilityChange {
  /** Catalog UUID of the camera. */
  cameraId: string;
  cameraName: string;
  kind: 'offline' | 'recovered';
  /** FCM topic the mobile app subscribes to for this camera. */
  topic: string;
}

/** FCM topic for a camera: `cam_<catalog uuid>` (hyphens are topic-safe). */
export function topicForCamera(cameraId: string): string {
  return `cam_${cameraId}`;
}

export interface CameraAvailabilitySnapshot {
  id: string;
  name: string;
  availability: Availability;
}

export function detectAvailabilityChange(
  previous: CameraAvailabilitySnapshot,
  current: Availability
): AvailabilityChange | null {
  if (previous.availability === current) return null;
  if (
    current === 'offline' &&
    (previous.availability === 'online' || previous.availability === 'degraded')
  ) {
    return {
      cameraId: previous.id,
      cameraName: previous.name,
      kind: 'offline',
      topic: topicForCamera(previous.id),
    };
  }
  if (current === 'online' && previous.availability === 'offline') {
    return {
      cameraId: previous.id,
      cameraName: previous.name,
      kind: 'recovered',
      topic: topicForCamera(previous.id),
    };
  }
  return null;
}

export function notificationText(change: AvailabilityChange): {
  title: string;
  body: string;
} {
  return change.kind === 'offline'
    ? { title: 'Camera ngoại tuyến', body: change.cameraName }
    : { title: 'Camera đã trở lại', body: change.cameraName };
}
