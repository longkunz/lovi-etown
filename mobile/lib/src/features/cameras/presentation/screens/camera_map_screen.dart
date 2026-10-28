import '../../../../utils/failure.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../config/map_config.dart';
import '../../domain/camera_models.dart';
import '../../domain/camera_map_models.dart';
import '../../domain/camera_map_repository.dart';
import '../../domain/camera_location_gateway.dart';
import '../../domain/camera_repository.dart';
import '../providers/camera_map_cubit.dart';
import '../providers/camera_map_state.dart';
import '../widgets/camera_map_canvas.dart';
import '../widgets/camera_map_results.dart';

class CameraMapScreen extends StatefulWidget {
  const CameraMapScreen(
      {required this.repository,
      required this.locationGateway,
      required this.cameraRepository,
      required this.onSelectCamera,
      required this.onOpenCameras,
      this.mapBuilder,
      this.connectionConfig,
      this.active = true,
      this.isDemoMode = false,
      super.key});
  final CameraMapRepository repository;
  final CameraLocationGateway locationGateway;
  final CameraRepository cameraRepository;
  final ValueChanged<Camera> onSelectCamera;
  final VoidCallback onOpenCameras;
  final CameraMapViewBuilder? mapBuilder;
  final MapConnectionConfig? connectionConfig;
  final bool active, isDemoMode;
  @override
  State<CameraMapScreen> createState() => _CameraMapScreenState();
}

class _CameraMapScreenState extends State<CameraMapScreen>
    with WidgetsBindingObserver {
  late final CameraMapCubit _cubit;
  late final MapConnectionConfig _connection;
  CameraMapHandle? _handle;
  bool _foreground = true, _traffic = true, _demoScheduled = false;
  int _preferenceGeneration = 0;
  CameraMapType _mapType = CameraMapType.street;
  List<DistrictOption> _districts = [];
  Failure? _districtFailure;
  @override
  void initState() {
    super.initState();
    _connection =
        widget.connectionConfig ?? MapConnectionConfig.fromEnvironment();
    _cubit = CameraMapCubit(
        repository: widget.repository, locationGateway: widget.locationGateway);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _cubit.setForeground(_foreground);
    _cubit.setActive(widget.active);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadOptions());
    unawaited(_loadTrafficPreference());
  }

  Future<void> _loadOptions() async {
    final districts = await widget.cameraRepository.districts();
    if (!mounted) return;
    districts.fold((failure) {
      if (failure is ApiFailure && failure.statusCode == 401) {
        setState(() => _districtFailure = failure);
      }
    },
        (values) => setState(() {
              _districts = values;
              _districtFailure = null;
            }));
  }

  Future<void> _loadTrafficPreference() async {
    final generation = ++_preferenceGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || generation != _preferenceGeneration) return;
      setState(() =>
          _traffic = prefs.getBool('camera_traffic_layer_enabled') ?? true);
    } catch (_) {}
  }

  Future<void> _toggleTraffic() async {
    final generation = ++_preferenceGeneration;
    final next = !_traffic;
    setState(() => _traffic = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || generation != _preferenceGeneration) return;
      await prefs.setBool('camera_traffic_layer_enabled', next);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(CameraMapScreen old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) {
      _cubit.setActive(widget.active);
      if (!widget.active) {
        _handle = null;
        _preferenceGeneration++;
      } else {
        unawaited(_loadTrafficPreference());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final next = state == AppLifecycleState.resumed;
    if (next == _foreground) return;
    setState(() => _foreground = next);
    _cubit.setForeground(next);
    if (!next) {
      _handle = null;
      _preferenceGeneration++;
    } else {
      unawaited(_loadTrafficPreference());
    }
  }

  @override
  void dispose() {
    _preferenceGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _cubit.close();
    super.dispose();
  }

  Widget _locationStatus(CameraMapState state) {
    final status = state.locationStatus;
    if (state.locating) {
      return Text('map_discovery.locating'.tr());
    }
    return switch (status) {
      CameraLocationStatus.denied => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _cubit.showNearby,
          child: Text(
              'map_discovery.location_denied'.tr())),
      CameraLocationStatus.deniedForever => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _cubit.openAppSettings,
          child: Text('map_discovery.app_settings'.tr())),
      CameraLocationStatus.serviceDisabled => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _cubit.openLocationSettings,
          child: Text('map_discovery.location_settings'.tr())),
      CameraLocationStatus.timeout => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _cubit.showNearby,
          child: Text('map_discovery.location_timeout'.tr())),
      CameraLocationStatus.failure => TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _cubit.showNearby,
          child: Text(
              'map_discovery.location_failed'.tr())),
      _ => const SizedBox.shrink()
    };
  }

  Widget _map(CameraMapState state) {
    if (!widget.active || !_foreground) {
      return const SizedBox(height: 1);
    }
    if (!_connection.isConfigured &&
        !widget.isDemoMode &&
        widget.mapBuilder == null) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text('map_discovery.missing_key'.tr()),
            TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: widget.onOpenCameras,
                child: Text('map_discovery.open_cameras'.tr()))
          ]));
    }
    final config = CameraMapViewConfig(
        center: MapCoordinate(state.latitude, state.longitude),
        zoom: state.zoom,
        trafficEnabled: _traffic,
        mapType: _mapType,
        myLocationEnabled: state.locationPermission,
        radiusCenter:
            state.mode == CameraMapMode.nearby && state.nearbyLat != null
                ? MapCoordinate(state.nearbyLat!, state.nearbyLng!)
                : null,
        radiusMeters: state.mode == CameraMapMode.nearby
            ? state.radiusMeters.toDouble()
            : null,
        markers: (state.result?.items ?? [])
            .where((item) => item.camera.hasLocation)
            .map((item) => CameraMapMarker(
                id: item.camera.id,
                position: MapCoordinate(
                    item.camera.latitude!, item.camera.longitude!),
                title: item.camera.name,
                onTap: () => widget.onSelectCamera(item.camera))),
        onMapCreated: (handle) => _handle = handle,
        onIdle: (bounds, zoom, center) => _cubit.setViewport(bounds,
            latitude: center.latitude,
            longitude: center.longitude,
            zoom: zoom));
    if (widget.mapBuilder != null) {
      return widget.mapBuilder!(context, config);
    }
    if (widget.isDemoMode) {
      if (!_demoScheduled) {
        _demoScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            config.onIdle?.call(
                const MapBounds(106.5, 10.6, 106.9, 11), 13, config.center);
          }
        });
      }
      return ColoredBox(
          color: const Color(0xffdceae5),
          child: Center(
              child:
                  Text('map_discovery.demo_map'.tr())));
    }
    return CameraMapCanvas(config: config, connectionConfig: _connection);
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<CameraMapCubit,
          CameraMapState>(
      bloc: _cubit,
      listenWhen: (old, next) =>
          old.nearbyLat != next.nearbyLat || old.nearbyLng != next.nearbyLng,
      listener: (context, state) {
        if (state.nearbyLat != null) {
          _handle?.moveTo(state.nearbyLat!, state.nearbyLng!, zoom: state.zoom);
        }
      },
      builder: (context, state) => Scaffold(
          body: SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('map_discovery.title'.tr(),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              ChoiceChip(
                                  labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  label: Text(
                                      'map_discovery.viewport'.tr()),
                                  selected:
                                      state.mode == CameraMapMode.viewport,
                                  onSelected: (_) => _cubit.showViewport()),
                              ChoiceChip(
                                  labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  label: Text('map_discovery.nearby'.tr()),
                                  selected: state.mode == CameraMapMode.nearby,
                                  onSelected: (_) => _cubit.showNearby())
                            ]),
                            if (state.mode == CameraMapMode.nearby)
                              Wrap(spacing: 8, children: [
                                for (final radius in [1000, 2000, 5000])
                                  ChoiceChip(
                                      labelStyle: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface),
                                      label: Text('${radius ~/ 1000} km'),
                                      selected: state.radiusMeters == radius,
                                      onSelected: (_) =>
                                          _cubit.setRadius(radius)),
                                TextButton(
                                    style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48)),
                                    onPressed: state.locating
                                        ? null
                                        : _cubit.showNearby,
                                    child: Text('map_discovery.refresh_location'.tr()))
                              ]),
                            if (_districts.isNotEmpty)
                              DropdownButtonFormField<String>(
                                  initialValue: state.district,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText:
                                          'map_discovery.district'.tr()),
                                  items: [
                                    DropdownMenuItem(
                                        value: null,
                                        child: Text('map_discovery.all_districts'.tr())),
                                    ..._districts.map((d) => DropdownMenuItem(
                                        value: d.name,
                                        child: Text(d.name,
                                            overflow: TextOverflow.ellipsis)))
                                  ],
                                  onChanged: _cubit.setDistrict),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              FilterChip(
                                  labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  label: Text('map_discovery.traffic'.tr()),
                                  selected: _traffic,
                                  onSelected: (_) => _toggleTraffic()),
                              ChoiceChip(
                                  labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  label: Text('map_discovery.street'.tr()),
                                  selected: _mapType == CameraMapType.street,
                                  onSelected: (_) => setState(
                                      () => _mapType = CameraMapType.street)),
                              ChoiceChip(
                                  labelStyle: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface),
                                  label: Text('map_discovery.hybrid'.tr()),
                                  selected: _mapType == CameraMapType.hybrid,
                                  onSelected: (_) => setState(
                                      () => _mapType = CameraMapType.hybrid))
                            ]),
                            _locationStatus(state),
                            SizedBox(
                                height: !_connection.isConfigured &&
                                        !widget.isDemoMode &&
                                        widget.mapBuilder == null
                                    ? null
                                    : 280,
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: _map(state))),
                            if (_connection.isConfigured ||
                                widget.isDemoMode ||
                                widget.mapBuilder != null)
                              TextButton(
                                  style: TextButton.styleFrom(
                                      minimumSize: const Size(48, 48)),
                                  onPressed: widget.onOpenCameras,
                                  child: Text(
                                      'map_discovery.open_cameras'.tr())),
                            const SizedBox(height: 12),
                            CameraMapResults(
                                state: _districtFailure == null
                                    ? state
                                    : state.copyWith(failure: _districtFailure),
                                onSelectCamera: widget.onSelectCamera,
                                onRetry: _cubit.retry),
                          ]))))));
}
