import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { CameraProvider, SnapshotBytes } from './camera-provider.js';
import { Bbox, ProviderCamera } from '../catalog/catalog.types.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export class FixtureProvider implements CameraProvider {
  private readonly fixturesDir: string;
  private readonly cameras: ProviderCamera[];
  private readonly snapshotBuffer: Buffer;
  constructor(fixturesDir?: string) {
    const dir1 = path.resolve(__dirname, '..', '..', 'fixtures');
    const dir2 = path.resolve(process.cwd(), 'fixtures');

    const dir3 = path.resolve(__dirname, '..', '..', '..', 'fixtures');
    this.fixturesDir =
      fixturesDir ||
      (fs.existsSync(path.join(dir1, 'catalog.json'))
        ? dir1
        : fs.existsSync(path.join(dir2, 'catalog.json'))
        ? dir2
        : dir3);
    const catalogPath = path.join(this.fixturesDir, 'catalog.json');
    const snapshotPath = path.join(this.fixturesDir, 'snapshot.png');


    if (!fs.existsSync(catalogPath)) {
      throw new Error(`Fixture catalog not found at: ${catalogPath}`);
    }
    if (!fs.existsSync(snapshotPath)) {
      throw new Error(`Fixture snapshot not found at: ${snapshotPath}`);
    }

    this.cameras = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
    this.snapshotBuffer = fs.readFileSync(snapshotPath);
  }

  async fetchCatalog(bbox: Bbox, signal?: AbortSignal): Promise<ProviderCamera[]> {
    if (signal?.aborted) {
      throw new Error('Aborted');
    }
    return [...this.cameras];
  }

  async fetchSnapshot(sourceRef: string, signal?: AbortSignal): Promise<SnapshotBytes> {
    if (signal?.aborted) {
      throw new Error('Aborted');
    }
    return {
      bytes: this.snapshotBuffer,
      mime: 'image/png',
    };
  }
}
