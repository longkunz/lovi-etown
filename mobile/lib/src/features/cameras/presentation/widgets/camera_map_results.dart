import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/shared/widgets/ui/app/feedback/app_empty_state.dart';
import 'package:flutter_starter/src/shared/widgets/ui/app/feedback/app_error_widget.dart';
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
            semanticsLabel: 'map_discovery.loading'.tr()),
      if (state.invalidViewport)
        Text('map_discovery.invalid_viewport'.tr()),
      if (state.updateRequired)
        Text('map_discovery.update_required'.tr()),
      if (state.failure != null && !state.updateRequired)
        AppErrorWidget(
          title: 'map_discovery.load_failed'.tr(),
          onRetry: onRetry,
          retryLabel: 'map_discovery.retry'.tr(),
        ),
      if (state.resultsAreStale)
        Text('map_discovery.stale_results'.tr()),
      if (result != null &&
          (result.coverage != 'verified' ||
              (result.syncState != null &&
                  result.syncState != 'synced' &&
                  result.syncState != 'ready' &&
                  result.syncState != 'idle')))
        Text('map_discovery.incomplete_catalog'.tr()),
      if (result?.hasMore ?? false)
        Text(!(state.resultQuery?.isNearby ??
                (state.mode == CameraMapMode.nearby))
            ? 'map_discovery.viewport_limit'.tr()
            : 'map_discovery.nearby_limit'.tr()),
      if (result != null &&
          result.items.isEmpty &&
          !state.loading &&
          state.failure == null)
        AppEmptyState(
          icon: Icons.search_off_outlined,
          title: 'map_discovery.empty'.tr(),
        ),
      if (result != null)
        ...result.items.map((item) => ListTile(
            minVerticalPadding: 12,
            title: Text(item.camera.name),
            subtitle: Text([
              if (item.camera.district != null) item.camera.district!,
              if (item.distanceMeters != null)
                '${item.distanceMeters! < 1000 ? "${item.distanceMeters!.round()} m" : "${(item.distanceMeters! / 1000).toStringAsFixed(1)} km"} · ${'map_discovery.straight_distance'.tr()}'
            ].join(' · ')),
            onTap: () => onSelectCamera(item.camera))),
    ]);
  }
}
