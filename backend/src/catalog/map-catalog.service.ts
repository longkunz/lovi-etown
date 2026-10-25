import { Injectable } from '@nestjs/common';
import { MapCatalogRepository } from './map-catalog.repository.js';
import { MapQuery } from './map-catalog.types.js';
import { toCameraDto } from './dto/camera.dto.js';
@Injectable()
export class MapCatalogService {
  constructor(private readonly repository: MapCatalogRepository) {}
  async query(query: MapQuery) {
    const result = await this.repository.query(query);
    return {
      ...result,
      items: result.items.map((item) => ({
        camera: toCameraDto(item.camera),
        distanceMeters: item.distanceMeters,
      })),
    };
  }
}
