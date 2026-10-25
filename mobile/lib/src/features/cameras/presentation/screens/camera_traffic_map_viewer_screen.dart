import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_canvas.dart';
export 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_map_view_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_directions.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_traffic_map_card.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

class CameraTrafficMapViewerScreen extends StatefulWidget {
  const CameraTrafficMapViewerScreen({
    required this.camera,
    this.mapBuilder,
    this.active = true,
    super.key,
  });

  final Camera camera;
  final bool active;

  /// Custom map builder for widget testing without headless platform view errors.
  final Widget Function(BuildContext context, CameraTrafficMapConfig config)?
      mapBuilder;

  @override
  State<CameraTrafficMapViewerScreen> createState() =>
      _CameraTrafficMapViewerScreenState();
}

class _CameraTrafficMapViewerScreenState
    extends State<CameraTrafficMapViewerScreen> {
  CameraMapHandle? _mapController;
  bool _trafficEnabled = true;
  bool _preferenceEdited = false;
  CameraMapType _mapType = CameraMapType.street;

  @override
  void initState() {
    super.initState();
    _loadTrafficPreference();
  }

  Future<void> _loadTrafficPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(CameraTrafficMapCard.prefTrafficEnabledKey);
      if (saved != null && mounted && !_preferenceEdited) {
        setState(() => _trafficEnabled = saved);
      }
    } catch (_) {}
  }

  Future<void> _toggleTraffic() async {
    _preferenceEdited = true;
    final next = !_trafficEnabled;
    setState(() => _trafficEnabled = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CameraTrafficMapCard.prefTrafficEnabledKey, next);
    } catch (_) {}
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == CameraMapType.street
          ? CameraMapType.hybrid
          : CameraMapType.street;
    });
  }

  void _recenter() {
    final lat = widget.camera.latitude;
    final lng = widget.camera.longitude;
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.moveTo(
        lat,
        lng,
        zoom: 16,
      );
    }
  }

  @override
  void dispose() {
    _mapController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    final theme = Theme.of(context);

    if (!camera.hasLocation) {
      return Scaffold(
        appBar: AppBar(title: Text(camera.name)),
        body: Center(
          child: Text('camera.traffic_map_no_location'.tr()),
        ),
      );
    }

    final cameraPos = MapCoordinate(camera.latitude!, camera.longitude!);
    final markers = <CameraMapMarker>{
      CameraMapMarker(id: camera.id, position: cameraPos, title: camera.name)
    };

    final mapConfig = CameraTrafficMapConfig(
      center: cameraPos,
      zoom: 16,
      mapType: _mapType,
      trafficEnabled: _trafficEnabled,
      markers: markers,
      onMapCreated: (controller) => _mapController = controller,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: CameraGlassSurface(
          role: CameraGlassRole.header,
          forceOpaque: true,
          borderRadius: BorderRadius.zero,
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  camera.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (camera.district != null || camera.address != null)
                  Text(
                    camera.address ?? camera.district ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: CameraUiTokens.primaryTealLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            actions: [
              IconButton(
                key: const ValueKey('fullscreen_directions_button'),
                icon: const Icon(Icons.directions),
                tooltip: 'Chỉ đường',
                onPressed: () => openCameraDirections(camera),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map Canvas
          Positioned.fill(
            child: !widget.active || !TickerMode.valuesOf(context).enabled
                ? const SizedBox.shrink()
                : widget.mapBuilder != null
                    ? widget.mapBuilder!(context, mapConfig)
                    : CameraMapCanvas(config: mapConfig),
          ),

          // Floating Controls (Recenter, Toggle Traffic, Toggle Layers, Directions)
          Positioned(
            bottom: CameraUiTokens.spacing24 +
                MediaQuery.viewPaddingOf(context).bottom,
            right: CameraUiTokens.spacing16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CameraGlassIconButton(
                  key: const ValueKey('fullscreen_traffic_recenter_button'),
                  icon: Icons.my_location,
                  label: 'camera.traffic_map_recenter'.tr(),
                  tooltip: 'camera.traffic_map_recenter'.tr(),
                  forceOpaque: true,
                  onPressed: _recenter,
                ),
                const SizedBox(height: CameraUiTokens.spacing8),
                CameraGlassIconButton(
                  key: const ValueKey('fullscreen_traffic_toggle_button'),
                  icon:
                      _trafficEnabled ? Icons.traffic : Icons.traffic_outlined,
                  iconColor: _trafficEnabled ? CameraUiTokens.accentTeal : null,
                  label: 'camera.traffic_map_toggle'.tr(),
                  tooltip: 'camera.traffic_map_toggle'.tr(),
                  selected: _trafficEnabled,
                  forceOpaque: true,
                  onPressed: _toggleTraffic,
                ),
                const SizedBox(height: CameraUiTokens.spacing8),
                CameraGlassIconButton(
                  key: const ValueKey('fullscreen_map_type_button'),
                  icon: _mapType == CameraMapType.street
                      ? Icons.layers
                      : Icons.map,
                  label: _mapType == CameraMapType.street
                      ? 'Bản đồ vệ tinh'
                      : 'Bản đồ chuẩn',
                  tooltip: _mapType == CameraMapType.street
                      ? 'Bản đồ vệ tinh'
                      : 'Bản đồ chuẩn',
                  selected: _mapType != CameraMapType.street,
                  forceOpaque: true,
                  onPressed: _toggleMapType,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
