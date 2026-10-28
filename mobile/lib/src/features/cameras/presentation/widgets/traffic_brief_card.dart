import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_directions.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// "Tình trạng tại điểm" — traffic brief v1 (T17).
///
/// Thẻ tổng hợp tình trạng camera tại điểm xem chi tiết:
/// - Trạng thái hoạt động (online / offline / degraded / unknown)
/// - Độ tươi của ảnh (số giây từ ảnh mới nhất, ảnh tươi / cũ)
/// - Tỉ lệ camera cùng quận đang online / tổng số camera quận
/// - Nút "Chỉ đường" (T10 handoff) khi camera có tọa độ
/// - Danh sách camera lân cận cùng quận (chạm để chuyển)
class TrafficBriefCard extends StatefulWidget {
  const TrafficBriefCard({
    required this.camera,
    required this.repository,
    required this.onSelectCamera,
    this.snapshotFetchedAt,
    this.isStale = false,
    this.onDirectionsTap,
    this.clockNow,
    super.key,
  });

  final Camera camera;
  final CameraRepository repository;
  final ValueChanged<Camera> onSelectCamera;
  final DateTime? snapshotFetchedAt;
  final bool isStale;
  final VoidCallback? onDirectionsTap;
  final DateTime Function()? clockNow;

  @override
  State<TrafficBriefCard> createState() => _TrafficBriefCardState();
}

class _TrafficBriefCardState extends State<TrafficBriefCard> {
  List<Camera> _related = const [];
  int? _districtTotal;
  int? _districtOnlineCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TrafficBriefCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera.id != widget.camera.id ||
        oldWidget.camera.district != widget.camera.district) {
      _load();
    }
  }

  Future<void> _load() async {
    final camera = widget.camera;
    final relatedResult = await widget.repository.related(camera.id, limit: 6);
    final districtsResult = await widget.repository.districts();
    if (!mounted) return;

    relatedResult.fold((_) {}, (items) => _related = items);
    districtsResult.fold((_) {}, (options) {
      for (final option in options) {
        if (option.name == camera.district) {
          _districtTotal = option.count;
          _districtOnlineCount = option.onlineCount;
        }
      }
    });

    setState(() {});
  }

  Widget _buildStatusBadge(String availability) {
    final Color color;
    final String label;
    final IconData icon;

    switch (availability) {
      case 'online':
        color = CameraUiTokens.successGreen;
        label = 'camera.status_online'.tr();
        icon = Icons.check_circle_outline;
        break;
      case 'offline':
        color = CameraUiTokens.errorRed;
        label = 'camera.status_offline'.tr();
        icon = Icons.error_outline;
        break;
      case 'degraded':
        color = CameraUiTokens.warningOrange;
        label = 'camera.status_degraded'.tr();
        icon = Icons.warning_amber_outlined;
        break;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        label = 'camera.status_unknown'.tr();
        icon = Icons.help_outline;
    }

    return Container(
      key: ValueKey('traffic_brief_status_$availability'),
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing8,
        vertical: CameraUiTokens.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CameraUiTokens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: CameraUiTokens.spacing4),
          Flexible(
              child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          )),
        ],
      ),
    );
  }

  Widget _buildFreshnessRow(BuildContext context) {
    if (widget.snapshotFetchedAt == null) return const SizedBox.shrink();

    final now = widget.clockNow?.call() ?? DateTime.now();
    final seconds =
        now.difference(widget.snapshotFetchedAt!).inSeconds.clamp(0, 999999);
    final isStale = widget.isStale || seconds >= 60;

    final String text;
    final IconData icon;
    final Color color;

    if (isStale) {
      icon = Icons.history_rounded;
      color = CameraUiTokens.errorRed;
      text = 'camera.fresh_stale'.tr(args: ['$seconds']);
    } else {
      icon = Icons.check_circle_outlined;
      color = CameraUiTokens.primaryTeal;
      text = seconds < 5
          ? 'camera.fresh_just_now'.tr()
          : 'camera.fresh_seconds'.tr(args: ['$seconds']);
    }

    return Padding(
      padding: const EdgeInsets.only(top: CameraUiTokens.spacing8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: CameraUiTokens.spacing4),
          Expanded(
              child: Text(
            text,
            key: ValueKey(isStale
                ? 'traffic_brief_freshness_stale'
                : 'traffic_brief_freshness_fresh'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final theme = Theme.of(context);
    final liveCount =
        _related.where((c) => c.canLive).length + (camera.canLive ? 1 : 0);
    final shownRelated = _related.take(3).toList();

    final String districtDetail;
    if (_districtTotal != null && _districtOnlineCount != null) {
      districtDetail = 'camera.district_online'
          .tr(args: ['$_districtOnlineCount', '$_districtTotal']);
    } else if (_districtTotal != null) {
      districtDetail = 'camera.district_count'.tr(args: ['$_districtTotal']);
    } else {
      districtDetail = '';
    }
    final districtInfo = [
      if (camera.district?.trim().isNotEmpty ?? false) camera.district!,
      if (districtDetail.isNotEmpty) districtDetail,
      if (liveCount > 0) 'camera.live_count'.tr(args: ['$liveCount']),
    ].join(' · ');

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
          Wrap(
            spacing: CameraUiTokens.spacing8,
            runSpacing: CameraUiTokens.spacing8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(
                  Icons.traffic_outlined,
                  size: 18,
                  color: CameraUiTokens.primaryTeal,
                ),
                const SizedBox(width: CameraUiTokens.spacing8),
                Flexible(
                    child: Text(
                  'camera.point_status'.tr(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                )),
              ]),
              _buildStatusBadge(camera.availability),
            ],
          ),
          if (districtInfo.isNotEmpty) ...[
            const SizedBox(height: CameraUiTokens.spacing8),
            Text(
              districtInfo,
              key: const ValueKey('traffic_brief_district_info'),
              style: theme.textTheme.bodySmall,
            ),
          ],
          _buildFreshnessRow(context),
          if (camera.hasLocation) ...[
            const SizedBox(height: CameraUiTokens.spacing8),
            OutlinedButton.icon(
              key: const ValueKey('brief_directions_button'),
              onPressed:
                  widget.onDirectionsTap ?? () => openCameraDirections(camera),
              icon: const Icon(Icons.directions, size: 16),
              label: Text('camera.directions'.tr()),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                    horizontal: CameraUiTokens.spacing12,
                    vertical: CameraUiTokens.spacing4),
              ),
            ),
          ],
          if (shownRelated.isNotEmpty) ...[
            const SizedBox(height: CameraUiTokens.spacing8),
            Text(
              'camera.nearby_cameras'.tr(),
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
