import { Controller, Get, Param, Headers, Req, Res } from '@nestjs/common';
import { SnapshotService } from './snapshot.service.js';
import { ApiError } from '../http/api-error.js';

const UUID_REGEX = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

@Controller('v1/cameras')
export class SnapshotController {
  constructor(private readonly snapshotService: SnapshotService) {}

  @Get(':id/snapshot')
  async getSnapshot(
    @Param('id') id: string,
    @Headers('if-none-match') ifNoneMatch: string | undefined,
    @Req() req: any,
    @Res() reply: any,
  ): Promise<void> {
    if (!UUID_REGEX.test(id)) {
      throw new ApiError('INVALID_PARAMETER', 400, false, 'Invalid camera ID format (must be UUID)');
    }

    const abortController = new AbortController();
    if (req.raw) {
      req.raw.on('close', () => {
        if (!req.raw.complete) {
          abortController.abort();
        }
      });
    }

    const result = await this.snapshotService.getSnapshot(id, ifNoneMatch, abortController.signal);

    reply
      .header('cache-control', 'private, no-cache')
      .header('etag', result.etag)
      .header('x-image-fetched-at', result.fetchedAt.toISOString())
      .header('x-data-mode', result.dataMode);

    if (result.notModified) {
      reply.status(304).send();
      return;
    }

    reply
      .header('content-type', result.mime)
      .status(200)
      .send(result.bytes);
  }
}
