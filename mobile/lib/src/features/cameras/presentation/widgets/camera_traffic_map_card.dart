import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_traffic_map_viewer_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Configuration passed to [CameraTrafficMapCard.mapBuilder] for testing or custom rendering.
class CameraTrafficMapConfig {
  const CameraTrafficMapConfig({
    required this.center,
    required this.zoom,
    required this.trafficEnabled,
    required this.markers,
    required this.onMapCreated,
  });

  final LatLng center;
  final double zoom;
  final bool trafficEnabled;
  final Set<Marker> markers;
  final void Function(GoogleMapController controller)? onMapCreated;
}

/// Thẻ bản đồ giao thông mini hiển thị định vị camera và vạch kẹt xe Google Maps (T18).
///
/// Bọc trong phong cách Liquid Glass, mặc định bật [trafficEnabled] để tải các vạch
/// màu kẹt xe thời gian thực từ Google Play Services Maps SDK.
class CameraTrafficMapCard extends StatefulWidget {
  const CameraTrafficMapCard({
    required this.camera,
    this.height = 210,
    this.mapBuilder,
    this.onOpenFullscreen,
    super.key,
  });

  final Camera camera;
  final double height;

  /// Custom map builder used in widget tests to bypass native AndroidView/UiKitView.
  final Widget Function(BuildContext context, CameraTrafficMapConfig config)?
      mapBuilder;

  /// Optional callback invoked when the fullscreen button is tapped.
  /// If null, navigates to [CameraTrafficMapViewerScreen].
  final VoidCallback? onOpenFullscreen;

  static const String prefTrafficEnabledKey = 'camera_traffic_layer_enabled';

  @override
  State<CameraTrafficMapCard> createState() => _CameraTrafficMapCardState();
}

class _CameraTrafficMapCardState extends State<CameraTrafficMapCard> {
  GoogleMapController? _mapController;
  bool _trafficEnabled = true;

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
    } catch (_) {
      // SharedPreferences failure is non-fatal; keeps default true
    }
  }

  Future<void> _toggleTraffic() async {
    final next = !_trafficEnabled;
    setState(() => _trafficEnabled = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CameraTrafficMapCard.prefTrafficEnabledKey, next);
    } catch (_) {
      // Non-fatal
    }
  }

  void _recenter() {
    final lat = widget.camera.latitude;
    final lng = widget.camera.longitude;
    if (lat != null && lng != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.5),
      );
    }
  }

  void _handleFullscreen() {
    if (widget.onOpenFullscreen != null) {
      widget.onOpenFullscreen!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CameraTrafficMapViewerScreen(camera: widget.camera),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = widget.camera;
    if (!camera.hasLocation) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
      zoom: 15.5,
      trafficEnabled: _trafficEnabled,
      markers: markers,
      onMapCreated: (controller) => _mapController = controller,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            isDark ? CameraUiTokens.surfaceDark : CameraUiTokens.surfaceLight,
        borderRadius: BorderRadius.circular(CameraUiTokens.radius16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CameraUiTokens.spacing16,
              vertical: CameraUiTokens.spacing8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.traffic,
                      size: 18, color: CameraUiTokens.primaryTeal),
                  const SizedBox(width: CameraUiTokens.spacing8),
                  Expanded(
                      child: Text(
                    'camera.traffic_map_title'.tr(),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  )),
                ]),
                const SizedBox(height: CameraUiTokens.spacing4),
                Text(
                  _trafficEnabled ? 'Giao thông ON' : 'Giao thông OFF',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Map Area
          SizedBox(
            height: widget.height,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(CameraUiTokens.radius16),
              ),
              child: Stack(
                children: [
                  // Google Map View
                  Positioned.fill(
                    child: widget.mapBuilder != null
                        ? widget.mapBuilder!(context, mapConfig)
                        : GoogleMap(
                            key: ValueKey('google_map_${camera.id}'),
                            initialCameraPosition: CameraPosition(
                              target: cameraPos,
                              zoom: 15.5,
                            ),
                            trafficEnabled: _trafficEnabled,
                            markers: markers,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                            onMapCreated: mapConfig.onMapCreated,
                            gestureRecognizers: const <Factory<
                                OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                EagerGestureRecognizer.new,
                              ),
                            },
                          ),
                  ),

                  // Floating Glass Action Controls (Recenter, Toggle, Fullscreen)
                  Positioned(
                    top: CameraUiTokens.spacing8,
                    right: CameraUiTokens.spacing8,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CameraGlassIconButton(
                          key: const ValueKey('traffic_map_recenter_button'),
                          icon: Icons.my_location,
                          label: 'camera.traffic_map_recenter'.tr(),
                          tooltip: 'camera.traffic_map_recenter'.tr(),
                          forceOpaque: true,
                          onPressed: _recenter,
                        ),
                        const SizedBox(height: CameraUiTokens.spacing4),
                        CameraGlassIconButton(
                          key: const ValueKey('traffic_layer_toggle_button'),
                          icon: _trafficEnabled
                              ? Icons.traffic
                              : Icons.traffic_outlined,
                          iconColor: _trafficEnabled
                              ? CameraUiTokens.accentTeal
                              : null,
                          label: 'camera.traffic_map_toggle'.tr(),
                          tooltip: 'camera.traffic_map_toggle'.tr(),
                          selected: _trafficEnabled,
                          forceOpaque: true,
                          onPressed: _toggleTraffic,
                        ),
                        const SizedBox(height: CameraUiTokens.spacing4),
                        CameraGlassIconButton(
                          key: const ValueKey('traffic_map_fullscreen_button'),
                          icon: Icons.fullscreen,
                          label: 'camera.traffic_map_fullscreen'.tr(),
                          tooltip: 'camera.traffic_map_fullscreen'.tr(),
                          forceOpaque: true,
                          onPressed: _handleFullscreen,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
