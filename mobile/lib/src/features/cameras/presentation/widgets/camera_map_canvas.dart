import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vietmap_flutter_gl/vietmap_flutter_gl.dart' as vm;
import '../../../../config/map_config.dart';
import '../../domain/camera_map_models.dart';
import 'camera_map_view_config.dart';
import 'vietmap_style_loader.dart';
export 'camera_map_view_config.dart';

/// One native map owner, rebuilt only while the host and app are active.
class CameraMapCanvas extends StatefulWidget {
  const CameraMapCanvas(
      {required this.config,
      this.connectionConfig,
      this.styleLoader,
      this.active = true,
      this.nativeBuilder,
      super.key});
  final CameraMapViewConfig config;
  final MapConnectionConfig? connectionConfig;
  final VietmapStyleLoader? styleLoader;
  final bool active;
  final CameraMapNativeBuilder? nativeBuilder;
  @override
  State<CameraMapCanvas> createState() => _CameraMapCanvasState();
}

class _CameraMapCanvasState extends State<CameraMapCanvas>
    with WidgetsBindingObserver {
  late final VietmapStyleLoader _loader =
      widget.styleLoader ?? VietmapStyleLoader();
  CameraMapCanvasController? _controller;
  late MapCoordinate _center = widget.config.center;
  late double _zoom = widget.config.zoom;
  Map<String, dynamic>? _base;
  String? _style;
  VietmapStyleFailure? _failure;
  VietmapStyleFailure? _auxFailure;
  bool _foreground = true;
  bool _styleReady = false;
  int _generation = 0;
  int _renderGeneration = 0;
  int _markerGeneration = 0;
  int _styleLoadedGeneration = -1;
  bool get _active => widget.active && _foreground;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void didUpdateWidget(CameraMapCanvas old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      if (_active) {
        _reload();
      } else {
        _deactivate();
      }
    } else if (old.config.mapType != widget.config.mapType ||
        old.config.trafficEnabled != widget.config.trafficEnabled ||
        old.connectionConfig != widget.connectionConfig) {
      _reload();
    } else if (_styleReady) {
      _renderMarkers();
    }
    if (old.config.center.latitude != widget.config.center.latitude ||
        old.config.center.longitude != widget.config.center.longitude ||
        old.config.zoom != widget.config.zoom) {
      _center = widget.config.center;
      _zoom = widget.config.zoom;
      _controller?.moveTo(_center.latitude, _center.longitude, zoom: _zoom);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (next == _foreground) return;
    setState(() {
      _foreground = next;
    });
    if (_active) {
      _reload();
    } else {
      _deactivate();
    }
  }

  void _deactivate() {
    _generation++;
    _markerGeneration++;
    _styleReady = false;
    _styleLoadedGeneration = -1;
    _loader.cancel();
    _controller = null;
    _style = null;
  }

  Future<void> _reload() async {
    if (!_active) return;
    final generation = ++_generation;
    _loader.cancel();
    _styleReady = false;
    _styleLoadedGeneration = -1;
    final previous = _controller;
    if (previous != null) {
      try {
        final viewport = await previous.getViewport();
        if (!mounted || generation != _generation) return;
        _center = viewport.center;
        _zoom = viewport.zoom;
      } catch (_) {}
    }

    final key =
        (widget.connectionConfig ?? MapConnectionConfig.fromEnvironment())
            .apiKey;
    try {
      var base = await _loader.load('tm', key);
      if (!mounted || generation != _generation) return;
      _base = base;
      VietmapStyleFailure? auxiliaryFailure;
      if (widget.config.mapType == CameraMapType.hybrid) {
        try {
          base = await _loader.load('hm', key);
        } on VietmapStyleFailure catch (e) {
          auxiliaryFailure = e;
        }
      }
      if (!mounted || generation != _generation) return;
      if (widget.config.trafficEnabled) {
        try {
          final traffic = await _loader.load('tf', key);
          base = VietmapStyleLoader.mergeTraffic(base, traffic);
        } on VietmapStyleFailure catch (e) {
          auxiliaryFailure = e;
        }
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _base = base;
        _auxFailure = auxiliaryFailure;
        _renderGeneration = generation;
        _style = jsonEncode(base);
        _failure = null;
      });
    } on VietmapStyleFailure catch (e) {
      if (mounted && generation == _generation) {
        setState(() {
          _failure = e;
          _renderGeneration = generation;
          if (_base == null) _style = null;
        });
      }
    }
  }

  Future<void> _renderMarkers() async {
    final controller = _controller;
    final generation = _generation;
    final markerGeneration = ++_markerGeneration;
    bool current() =>
        mounted &&
        _active &&
        _styleReady &&
        generation == _generation &&
        markerGeneration == _markerGeneration &&
        identical(controller, _controller);
    if (controller == null || !current()) return;
    try {
      try {
        await controller.setRadius(
            widget.config.radiusCenter, widget.config.radiusMeters);
      } catch (_) {
        if (current()) {
          setState(() => _auxFailure =
              const VietmapStyleFailure(VietmapStyleFailureKind.network));
        }
      }
      if (!current()) return;
      await controller.clearMarkers();
      if (!current()) return;
      for (final marker in widget.config.markers) {
        if (!current()) return;
        await controller.addMarker(CameraMapMarker(
            id: marker.id,
            position: marker.position,
            title: marker.title,
            onTap: () {
              if (mounted &&
                  _active &&
                  generation == _generation &&
                  identical(controller, _controller)) {
                marker.onTap?.call();
              }
            }));
        if (!current()) return;
      }
    } catch (_) {/* A disposed native generation has no work left. */}
  }

  Future<void> _idle(int generation) async {
    final controller = _controller;
    if (controller == null || generation != _generation) return;
    try {
      final viewport = await controller.getViewport();
      if (!mounted ||
          generation != _generation ||
          !identical(controller, _controller)) {
        return;
      }
      _center = viewport.center;
      _zoom = viewport.zoom;
      widget.config.onIdle
          ?.call(viewport.bounds, viewport.zoom, viewport.center);
    } catch (_) {}
  }

  @override
  void dispose() {
    _deactivate();
    WidgetsBinding.instance.removeObserver(this);
    if (widget.styleLoader == null) _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    if (_style == null) {
      return Center(
          child: _failure == null
              ? const CircularProgressIndicator()
              : Text(
                  _failure!.kind == VietmapStyleFailureKind.missingKey
                      ? 'camera.map_key_missing'.tr()
                      : 'camera.map_load_failed'.tr(),
                  textAlign: TextAlign.center));
    }
    final generation = _renderGeneration;
    void created(CameraMapCanvasController controller) {
      if (!mounted || generation != _generation) return;
      _controller = controller;
      widget.config.onMapCreated?.call(_GuardedHandle(
          controller, () => mounted && _active && generation == _generation));
    }

    void ready() {
      if (!mounted ||
          generation != _generation ||
          _styleLoadedGeneration == generation) {
        return;
      }
      _styleLoadedGeneration = generation;
      _styleReady = true;
      _renderMarkers();
      _idle(generation);
    }

    final nativeConfig = CameraMapViewConfig(
        center: _center,
        zoom: _zoom,
        trafficEnabled: widget.config.trafficEnabled,
        markers: widget.config.markers,
        mapType: widget.config.mapType,
        myLocationEnabled: widget.config.myLocationEnabled,
        radiusCenter: widget.config.radiusCenter,
        radiusMeters: widget.config.radiusMeters);
    return Stack(children: [
      Positioned.fill(
          child: KeyedSubtree(
              key: ValueKey('vietmap-$generation'),
              child: (widget.nativeBuilder ?? _buildNative)(context, _style!,
                  nativeConfig, created, ready, () => _idle(generation)))),
      if (_auxFailure != null || _failure != null)
        Positioned(
            left: 8,
            right: 64,
            bottom: 8,
            child: Material(
                color: Colors.white,
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_failure != null
                        ? 'camera.map_reload_failed'.tr()
                        : 'camera.map_layer_failed'.tr()))))
    ]);
  }
}

/// Native boundary injectable in adapter tests, independent of SDK controller types.
typedef CameraMapNativeBuilder = Widget Function(
    BuildContext context,
    String style,
    CameraMapViewConfig config,
    void Function(CameraMapCanvasController) onCreated,
    VoidCallback onStyleLoaded,
    VoidCallback onIdle);

class CameraMapViewport {
  const CameraMapViewport(this.bounds, this.zoom, this.center);
  final MapBounds bounds;
  final double zoom;
  final MapCoordinate center;
}

abstract interface class CameraMapCanvasController implements CameraMapHandle {
  Future<void> setRadius(MapCoordinate? center, double? meters);
  Future<void> clearMarkers();
  Future<void> addMarker(CameraMapMarker marker);
  Future<CameraMapViewport> getViewport();
}

Widget _buildNative(
    BuildContext context,
    String style,
    CameraMapViewConfig config,
    void Function(CameraMapCanvasController) created,
    VoidCallback ready,
    VoidCallback idle) {
  return vm.VietmapGL(
      styleString: style,
      initialCameraPosition: vm.CameraPosition(
          target: vm.LatLng(config.center.latitude, config.center.longitude),
          zoom: config.zoom),
      myLocationEnabled: config.myLocationEnabled,
      trackCameraPosition: true,
      onMapCreated: (controller) => created(_VietmapController(controller)),
      onStyleLoadedCallback: ready,
      onCameraIdle: idle);
}

class _GuardedHandle implements CameraMapHandle {
  _GuardedHandle(this.controller, this.isCurrent);
  final CameraMapHandle controller;
  final bool Function() isCurrent;
  @override
  Future<void> moveTo(double latitude, double longitude, {double? zoom}) async {
    if (isCurrent()) await controller.moveTo(latitude, longitude, zoom: zoom);
  }
}

class _VietmapController implements CameraMapCanvasController {
  _VietmapController(this.controller) {
    controller.onCircleTapped
        .add((circle) => _markers[circle.id]?.onTap?.call());
  }
  final vm.VietmapController controller;
  final Map<String, CameraMapMarker> _markers = {};
  bool _radiusAdded = false;
  @override
  Future<void> setRadius(MapCoordinate? center, double? meters) async {
    final coordinates = <List<double>>[];
    if (center != null && meters != null && meters > 0) {
      final angular = meters / 6371000;
      final latitude = center.latitude * math.pi / 180;
      final longitude = center.longitude * math.pi / 180;
      for (var i = 0; i <= 64; i++) {
        final bearing = i * 2 * math.pi / 64;
        final lat = math.asin(math.sin(latitude) * math.cos(angular) +
            math.cos(latitude) * math.sin(angular) * math.cos(bearing));
        final lng = longitude +
            math.atan2(
                math.sin(bearing) * math.sin(angular) * math.cos(latitude),
                math.cos(angular) - math.sin(latitude) * math.sin(lat));
        coordinates.add([lng * 180 / math.pi, lat * 180 / math.pi]);
      }
    }
    final data = <String, dynamic>{
      'type': 'FeatureCollection',
      'features': coordinates.isEmpty
          ? <Object>[]
          : [
              {
                'type': 'Feature',
                'properties': <String, dynamic>{},
                'geometry': {
                  'type': 'Polygon',
                  'coordinates': [coordinates]
                }
              }
            ]
    };
    if (_radiusAdded) {
      await controller.setGeoJsonSource('camera-nearby-radius', data);
    } else {
      await controller.addGeoJsonSource('camera-nearby-radius', data);
      await controller.addFillLayer(
          'camera-nearby-radius',
          'camera-nearby-radius-fill',
          const vm.FillLayerProperties(
              fillColor: '#12A99B',
              fillOpacity: 0.15,
              fillOutlineColor: '#12A99B'),
          enableInteraction: false);
      _radiusAdded = true;
    }
  }

  @override
  Future<void> clearMarkers() async {
    _markers.clear();
    await controller.clearCircles();
  }

  @override
  Future<void> addMarker(CameraMapMarker marker) async {
    final circle = await controller.addCircle(vm.CircleOptions(
        geometry:
            vm.LatLng(marker.position.latitude, marker.position.longitude),
        circleRadius: 9,
        circleColor: const Color(0xFF12A99B),
        circleStrokeColor: Colors.white,
        circleStrokeWidth: 2));
    _markers[circle.id] = marker;
  }

  @override
  Future<CameraMapViewport> getViewport() async {
    final bounds = await controller.getVisibleRegion();
    final position = controller.cameraPosition!;
    return CameraMapViewport(
        MapBounds(bounds.southwest.longitude, bounds.southwest.latitude,
            bounds.northeast.longitude, bounds.northeast.latitude),
        position.zoom,
        MapCoordinate(position.target.latitude, position.target.longitude));
  }

  @override
  Future<void> moveTo(double latitude, double longitude, {double? zoom}) async {
    await controller.animateCamera(vm.CameraUpdate.newLatLngZoom(
        vm.LatLng(latitude, longitude),
        zoom ?? controller.cameraPosition?.zoom ?? 15));
  }
}
