import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_directions.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_traffic_map_card.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Màn hình xem bản đồ Google Maps và lớp giao thông kẹt xe toàn màn hình (T18).
///
/// Cho phép người dùng quan sát diện rộng các tuyến đường xung quanh camera,
/// chuyển đổi loại bản đồ (Bình thường / Vệ tinh), bật/tắt dải màu lưu lượng và
/// dẫn đường trực tiếp sang Google Maps.
class CameraTrafficMapViewerScreen extends StatefulWidget {
  const CameraTrafficMapViewerScreen({
    required this.camera,
    this.mapBuilder,
    super.key,
  });

  final Camera camera;

  /// Custom map builder for widget testing without headless platform view errors.
  final Widget Function(BuildContext context, CameraTrafficMapConfig config)?
      mapBuilder;

  @override
  State<CameraTrafficMapViewerScreen> createState() =>
      _CameraTrafficMapViewerScreenState();
}

class _CameraTrafficMapViewerScreenState
    extends State<CameraTrafficMapViewerScreen> {
  GoogleMapController? _mapController;
  bool _trafficEnabled = true;
  MapType _mapType = MapType.normal;

  @override
  void initState() {
    super.initState();
    _loadTrafficPreference();
  }

  Future<void> _loadTrafficPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(CameraTrafficMapCard.prefTrafficEnabledKey);
      if (saved != null && mounted) {
        setState(() => _trafficEnabled = saved);
      }
    } catch (_) {}
  }

  Future<void> _toggleTraffic() async {
    final next = !_trafficEnabled;
    setState(() => _trafficEnabled = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CameraTrafficMapCard.prefTrafficEnabledKey, next);
    } catch (_) {}
  }

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
    });
  }

  void _recenter() {
    final lat = widget.camera.latitude;
    final lng = widget.camera.longitude;
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      );
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
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

    final cameraPos = LatLng(camera.latitude!, camera.longitude!);
    final markers = <Marker>{
      Marker(
        markerId: MarkerId(camera.id),
        position: cameraPos,
        infoWindow: InfoWindow(
          title: camera.name,
          snippet: camera.address ?? camera.district,
        ),
      ),
    };

    final mapConfig = CameraTrafficMapConfig(
      center: cameraPos,
      zoom: 16,
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
            child: widget.mapBuilder != null
                ? widget.mapBuilder!(context, mapConfig)
                : GoogleMap(
                    key: ValueKey('fullscreen_map_${camera.id}'),
                    initialCameraPosition: CameraPosition(
                      target: cameraPos,
                      zoom: 16,
                    ),
                    trafficEnabled: _trafficEnabled,
                    mapType: _mapType,
                    markers: markers,
                    myLocationEnabled: false,
                    padding: EdgeInsets.only(
                      top: MediaQuery.paddingOf(context).top + kToolbarHeight,
                      bottom: MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: mapConfig.onMapCreated,
                  ),
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
                  icon: _mapType == MapType.normal ? Icons.layers : Icons.map,
                  label: _mapType == MapType.normal
                      ? 'Bản đồ vệ tinh'
                      : 'Bản đồ chuẩn',
                  tooltip: _mapType == MapType.normal
                      ? 'Bản đồ vệ tinh'
                      : 'Bản đồ chuẩn',
                  selected: _mapType != MapType.normal,
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
