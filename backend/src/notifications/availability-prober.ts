import { CatalogRepository } from '../catalog/catalog.repository.js';
import { CameraRecord } from '../catalog/catalog.types.js';
import { CameraProvider } from '../providers/camera-provider.js';
import {
  Availability,
  AvailabilityChange,
  detectAvailabilityChange,
  notificationText,
} from './availability.js';

/**
 * Availability prober (T16): probes every snapshot-capable catalog camera
 * through the provider, persists the new availability, and notifies the
 * camera's FCM topic on offline/recovered transitions.
 *
 * The sender is optional: without a Firebase service account the prober
 * still maintains availability state and counts the changes it *would*
 * have notified — the trial backend runs fine in that mode.
 */
export interface ProberSender {
  sendToTopic(
    topic: string,
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<void>;
}

export interface ProberSummary {
  checked: number;
  online: number;
  offline: number;
  changes: number;
  notified: number;
}

export interface ProberOptions {
  repository: Pick<CatalogRepository, 'list' | 'updateAvailability'>;
  provider: Pick<CameraProvider, 'fetchSnapshot'>;
  sender?: ProberSender | null;
  concurrency?: number;
  timeoutMs?: number;
  now?: () => Date;
}

export class AvailabilityProber {
  private readonly repo: ProberOptions['repository'];
  private readonly provider: ProberOptions['provider'];
  private readonly sender: ProberSender | null;
  private readonly concurrency: number;
  private readonly timeoutMs: number;
  private readonly now: () => Date;

  constructor(options: ProberOptions) {
    this.repo = options.repository;
    this.provider = options.provider;
    this.sender = options.sender ?? null;
    this.concurrency = options.concurrency ?? 4;
    this.timeoutMs = options.timeoutMs ?? 8000;
    this.now = options.now ?? (() => new Date());
  }

  async runOnce(provinceId = 'tp_hcm'): Promise<ProberSummary> {
    const { items } = await this.repo.list({
      provinceId,
      limit: 1000,
      offset: 0,
    });
    const cameras = items.filter((c) => c.capabilities?.snapshot);
    const summary: ProberSummary = {
      checked: 0,
      online: 0,
      offline: 0,
      changes: 0,
      notified: 0,
    };

    let index = 0;
    const worker = async () => {
      while (index < cameras.length) {
        const camera = cameras[index++];
        await this.probeOne(camera, summary);
      }
    };
    await Promise.all(
      Array.from({ length: Math.min(this.concurrency, cameras.length) }, worker)
    );
    return summary;
  }

  private async probeOne(
    camera: CameraRecord,
    summary: ProberSummary
  ): Promise<void> {
    let current: Availability = 'offline';
    try {
      await this.provider.fetchSnapshot(
        camera.sourceRef,
        AbortSignal.timeout(this.timeoutMs)
      );
      current = 'online';
    } catch {
      current = 'offline';
    }

    summary.checked++;
    if (current === 'online') summary.online++;
    else summary.offline++;

    const change: AvailabilityChange | null = detectAvailabilityChange(
      { id: camera.id, name: camera.name, availability: camera.availability },
      current
    );

    if (current !== camera.availability) {
      await this.repo.updateAvailability(camera.id, current, this.now());
    }

    if (change) {
      summary.changes++;
      if (this.sender) {
        const { title, body } = notificationText(change);
        try {
          await this.sender.sendToTopic(change.topic, title, body, {
            cameraId: change.cameraId,
            kind: change.kind,
          });
          summary.notified++;
        } catch {
          // A failed notification must not fail the probe run.
        }
      }
    }
  }
}
