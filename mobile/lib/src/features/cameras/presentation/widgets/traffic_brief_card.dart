import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// "Tình trạng tại điểm" — traffic brief v1 (T17). A one-glance card inside
/// the camera sheet summarizing what the backend already knows about the
/// camera's district: how many cameras the area has, how many of the
/// related ones can stream live, and the nearest related cameras (tap to
/// jump). Renders nothing while loading, on failure, or when the camera
/// has no district — it never blocks the sheet.
class TrafficBriefCard extends StatefulWidget {
  const TrafficBriefCard({
    required this.camera,
    required this.repository,
    required this.onSelectCamera,
    super.key,
  });

  final Camera camera;
  final CameraRepository repository;
  final ValueChanged<Camera> onSelectCamera;

  @override
  State<TrafficBriefCard> createState() => _TrafficBriefCardState();
}

class _TrafficBriefCardState extends State<TrafficBriefCard> {
  List<Camera> _related = const [];
  int? _districtTotal;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final camera = widget.camera;
    final relatedResult = await widget.repository.related(camera.id, limit: 6);
    final districtsResult = await widget.repository.districts();
    if (!mounted) return;
    relatedResult.fold((_) {}, (items) => _related = items);
    districtsResult.fold((_) {}, (options) {
      for (final option in options) {
        if (option.name == camera.district) _districtTotal = option.count;
      }
    });
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    if (!_loaded || camera.district == null) {
      return const SizedBox.shrink();
    }
    if (_related.isEmpty && _districtTotal == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final liveCount =
        _related.where((c) => c.canLive).length + (camera.canLive ? 1 : 0);
    final shownRelated = _related.take(3).toList();

    return Container(
      key: const ValueKey('traffic_brief_card'),
      margin: const EdgeInsets.fromLTRB(
        CameraUiTokens.spacing16,
        0,
        CameraUiTokens.spacing16,
        CameraUiTokens.spacing16,
      ),
      padding: const EdgeInsets.all(CameraUiTokens.spacing12),
      decoration: BoxDecoration(
        color: CameraUiTokens.primaryTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
        border: Border.all(
          color: CameraUiTokens.primaryTeal.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.traffic_outlined,
                size: 18,
                color: CameraUiTokens.primaryTeal,
              ),
              const SizedBox(width: CameraUiTokens.spacing8),
              Text(
                'Tình trạng tại điểm',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: CameraUiTokens.spacing8),
          Text(
            [
              camera.district!,
              if (_districtTotal != null) '$_districtTotal camera trong khu vực',
              if (liveCount > 0) '$liveCount camera có trực tiếp',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (shownRelated.isNotEmpty) ...[
            const SizedBox(height: CameraUiTokens.spacing8),
            Text(
              'Camera lân cận',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final related in shownRelated)
              InkWell(
                key: ValueKey('brief_related_${related.id}'),
                onTap: () => widget.onSelectCamera(related),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: CameraUiTokens.spacing4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_outlined,
                        size: 16,
                        color: CameraUiTokens.primaryTeal,
                      ),
                      const SizedBox(width: CameraUiTokens.spacing8),
                      Expanded(
                        child: Text(
                          related.name,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (related.canLive)
                        const Icon(
                          Icons.live_tv_outlined,
                          size: 16,
                          color: CameraUiTokens.errorRed,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
