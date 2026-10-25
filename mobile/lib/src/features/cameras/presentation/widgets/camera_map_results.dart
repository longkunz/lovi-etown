import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../domain/camera_models.dart';
import '../providers/camera_map_state.dart';

class CameraMapResults extends StatelessWidget {
  const CameraMapResults(
      {required this.state,
      required this.onSelectCamera,
      required this.onRetry,
      super.key});
  final CameraMapState state;
  final ValueChanged<Camera> onSelectCamera;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final result = state.result;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (state.loading)
        LinearProgressIndicator(
            semanticsLabel: mapText('loading', 'Đang tải camera')),
      if (state.invalidViewport)
        Text(mapText(
            'invalid_viewport', 'Phóng to bản đồ để chọn vùng hợp lệ.')),
      if (state.updateRequired)
        Text(mapText('update_required',
            'Mã truy cập camera đã hết hiệu lực. Vui lòng cập nhật cấu hình truy cập.')),
      if (state.failure != null && !state.updateRequired) ...[
        Text(mapText('load_failed', 'Không thể tải camera trong vùng này.')),
        TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onRetry,
            child: Text(mapText('retry', 'Thử lại')))
      ],
      if (state.resultsAreStale)
        Text(mapText('stale_results',
            'Kết quả cũ — chưa cập nhật cho tìm kiếm hiện tại.')),
      if (result != null &&
          (result.coverage == 'partial' ||
              (result.coverage != null &&
                  !['full', 'complete'].contains(result.coverage)) ||
              (result.syncState != null &&
                  result.syncState != 'synced' &&
                  result.syncState != 'ready' &&
                  result.syncState != 'idle')))
        Text(mapText(
            'incomplete_catalog', 'Danh mục camera có thể chưa đầy đủ.')),
      if (result?.hasMore ?? false)
        Text(state.mode == CameraMapMode.viewport
            ? mapText('viewport_limit', 'Phóng to để xem đủ camera')
            : mapText('nearby_limit',
                'Đang hiển thị các camera gần nhất, hãy giảm bán kính để xem đủ')),
      if (result != null &&
          result.items.isEmpty &&
          !state.loading &&
          state.failure == null)
        Text(mapText('empty', 'Chưa tìm thấy camera trong vùng đã chọn.')),
      if (result != null)
        ...result.items.map((item) => ListTile(
            minVerticalPadding: 12,
            title: Text(item.camera.name),
            subtitle: Text([
              if (item.camera.district != null) item.camera.district!,
              if (item.distanceMeters != null)
                '${item.distanceMeters! < 1000 ? "${item.distanceMeters!.round()} m" : "${(item.distanceMeters! / 1000).toStringAsFixed(1)} km"} · ${mapText('straight_distance', 'khoảng cách đường thẳng')}'
            ].join(' · ')),
            onTap: () => onSelectCamera(item.camera))),
    ]);
  }
}

String mapText(String key, String fallback) {
  final translated = 'map_discovery.$key'.tr();
  return translated == 'map_discovery.$key' ? fallback : translated;
}
