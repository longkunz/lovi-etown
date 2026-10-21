import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_starter/src/features/cameras/data/models/camera_dto.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/favorites_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_directions.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

Camera camWith({double? lat, double? lng}) => Camera(
      id: 'cam-01',
      name: 'Mai Chí Thọ - Lương Định Của',
      provinceId: 'tp_hcm',
      district: 'TP. Thủ Đức',
      snapshotCapable: true,
      playbackEndpoint: '/v1/cameras/cam-01/playback',
      snapshotEndpoint: '/v1/cameras/cam-01/snapshot',
      latitude: lat,
      longitude: lng,
    );

void main() {
  group('directions URIs', () {
    test('google maps uri carries the destination coordinates', () {
      final uri = googleMapsDirectionsUri(10.7801, 106.725);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '10.7801,106.725');
    });

    test('geo uri carries the coordinates', () {
      final uri = geoDirectionsUri(10.7801, 106.725);
      expect(uri.scheme, 'geo');
      expect(uri.toString(), contains('10.7801,106.725'));
    });
  });

  group('openCameraDirections', () {
    test('no location -> returns false and never launches', () async {
      var calls = 0;
      final ok = await openCameraDirections(
        camWith(),
        launcher: (uri) async {
          calls++;
          return true;
        },
      );
      expect(ok, isFalse);
      expect(calls, 0);
    });

    test('google maps success -> single launch', () async {
      final launched = <Uri>[];
      final ok = await openCameraDirections(
        camWith(lat: 10.7801, lng: 106.725),
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
      );
      expect(ok, isTrue);
      expect(launched, hasLength(1));
      expect(launched.single.host, 'www.google.com');
    });

    test('google maps refused -> falls back to geo uri', () async {
      final launched = <Uri>[];
      final ok = await openCameraDirections(
        camWith(lat: 10.7801, lng: 106.725),
        launcher: (uri) async {
          launched.add(uri);
          return uri.scheme == 'geo';
        },
      );
      expect(ok, isTrue);
      expect(launched, hasLength(2));
      expect(launched.last.scheme, 'geo');
    });

    test('google maps throws -> falls back to geo uri', () async {
      final launched = <Uri>[];
      final ok = await openCameraDirections(
        camWith(lat: 10.7801, lng: 106.725),
        launcher: (uri) async {
          launched.add(uri);
          if (uri.scheme == 'https') throw Exception('no handler');
          return true;
        },
      );
      expect(ok, isTrue);
      expect(launched.last.scheme, 'geo');
    });
  });

  group('CameraDto location parsing', () {
    test('parses location {lat,lng} into the domain camera', () {
      final dto = CameraDto.fromJson({
        'id': 'cam-01',
        'name': 'X',
        'provinceId': 'tp_hcm',
        'location': {'lat': 10.7801, 'lng': 106.725},
        'capabilities': {'snapshot': true, 'live': false},
      });
      final camera = dto.toDomain();
      expect(camera.latitude, 10.7801);
      expect(camera.longitude, 106.725);
      expect(camera.hasLocation, isTrue);
    });

    test('missing/null location -> null coordinates', () {
      final dto = CameraDto.fromJson({
        'id': 'cam-02',
        'name': 'Y',
        'provinceId': 'tp_hcm',
        'location': null,
        'capabilities': {'snapshot': true, 'live': false},
      });
      final camera = dto.toDomain();
      expect(camera.latitude, isNull);
      expect(camera.longitude, isNull);
      expect(camera.hasLocation, isFalse);
    });
  });

  group('snapshot sheet directions button', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await EasyLocalization.ensureInitialized();
    });

    testWidgets('button shows when the camera has a location', (tester) async {
      final preview = CameraPreviewCubit(
        repository: _Repo(camWith(lat: 10.7801, lng: 106.725)),
      );
      addTearDown(preview.close);
      await tester.pumpWidget(_app(preview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('directions_button')), findsOneWidget);
      expect(find.text('Chỉ đường'), findsOneWidget);
    });

    testWidgets('button hidden when the camera has no location', (tester) async {
      final preview = CameraPreviewCubit(repository: _Repo(camWith()));
      addTearDown(preview.close);
      await tester.pumpWidget(_app(preview));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('directions_button')), findsNothing);
    });
  });
}

class _Repo implements CameraRepository {
  _Repo(this.camera);
  final Camera camera;

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      Right(CatalogPage(
        items: [camera],
        limit: limit,
        offset: offset,
        total: 1,
        catalogVersion: 'v1',
        dataMode: 'fixture',
      ));

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async =>
      const Right([]);

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      Right(camera);

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async =>
      Right(PlaybackDescriptor(
        cameraId: camera.id,
        kind: 'snapshot_poll',
        snapshotEndpoint: camera.snapshotEndpoint!,
        refreshIntervalMs: 60000,
      ));

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
          {String? etag, CancelToken? cancelToken}) async =>
      Right(SnapshotReceived(SnapshotFrame(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        etag: 'e1',
      )));
}

class _Favs implements FavoritesRepository {
  @override
  Stream<List<FavoriteCamera>> watch() async* {
    yield const [];
  }

  @override
  FutureEither<void> load() async => const Right(null);

  @override
  FutureEither<void> setSaved(Camera camera, bool saved) async => const Right(null);

  @override
  FutureEither<void> resetCorruptData() async => const Right(null);
}

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => {
        'shared': {'retry': 'Thử lại', 'close': 'Đóng'},
      };
}

Widget _app(CameraPreviewCubit preview) {
  final favs = _Favs();
  return EasyLocalization(
    supportedLocales: const [Locale('vi')],
    path: 'assets/translations',
    assetLoader: const _Loader(),
    fallbackLocale: const Locale('vi'),
    startLocale: const Locale('vi'),
    saveLocale: false,
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Scaffold(
          body: Builder(
            builder: (inner) => ElevatedButton(
              onPressed: () => showCameraSnapshotSheet(
                inner,
                cameraId: 'cam-01',
                preview: preview,
                favorites: favs,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}
