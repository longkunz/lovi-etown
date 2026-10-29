import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'localized_widget_test_helper.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/features/cameras/data/repositories/fixture_camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_repository.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/traffic_brief_card.dart';
import 'package:flutter_starter/src/utils/failure.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';

Camera cam(
  String id,
  String name, {
  String? district,
  bool live = false,
  String availability = 'unknown',
  double? latitude,
  double? longitude,
}) =>
    Camera(
      id: id,
      name: name,
      provinceId: 'tp_hcm',
      district: district,
      playbackEndpoint: '/v1/cameras/$id/playback',
      snapshotEndpoint: '/v1/cameras/$id/snapshot',
      liveCapable: live,
      streamUrl: live ? 'http://media.example/$id.m3u8' : null,
      availability: availability,
      latitude: latitude,
      longitude: longitude,
    );

class _Bundle extends AssetBundle {
  _Bundle(this.json);
  final String json;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.view(Uint8List.fromList(utf8.encode(json)).buffer);
  @override
  Future<String> loadString(String key, {bool cache = true}) async => json;
}

class _Repo implements CameraRepository {
  _Repo(
      {required this.relatedItems,
      required this.districtOptions,
      this.failDistrictData = false});
  final List<Camera> relatedItems;
  final List<DistrictOption> districtOptions;
  final bool failDistrictData;

  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      failDistrictData
          ? const Left(ServerFailure('related unavailable'))
          : Right(relatedItems.take(limit).toList());

  @override
  FutureEither<List<DistrictOption>> districts(
          {CancelToken? cancelToken}) async =>
      failDistrictData
          ? const Left(ServerFailure('districts unavailable'))
          : Right(districtOptions);

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      const Right(CatalogPage(
          items: [],
          limit: 50,
          offset: 0,
          total: 0,
          catalogVersion: 'v1',
          dataMode: 'fixture'));

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      const Left(ServerFailure('n/a'));

  @override
  FutureEither<PlaybackDescriptor> playback(String id,
          {CancelToken? cancelToken}) async =>
      const Left(ServerFailure('n/a'));

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
          {String? etag, CancelToken? cancelToken}) async =>
      const Left(ServerFailure('n/a'));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  group('FixtureCameraRepository.related', () {
    final fixtureJson = jsonEncode({
      'catalogVersion': 'fixture-v1',
      'dataMode': 'fixture',
      'items': [
        {
          'id': 'a',
          'name': 'A',
          'district': 'Quận 3',
          'playbackEndpoint': '/p/a',
          'availability': 'online'
        },
        {
          'id': 'b',
          'name': 'B',
          'district': 'Quận 3',
          'playbackEndpoint': '/p/b',
          'availability': 'online'
        },
        {
          'id': 'c',
          'name': 'C',
          'district': 'Quận 1',
          'playbackEndpoint': '/p/c',
          'availability': 'offline'
        },
        {'id': 'd', 'name': 'D', 'playbackEndpoint': '/p/d'},
      ],
    });

    test('returns same-district cameras excluding itself', () async {
      final repo = FixtureCameraRepository(bundle: _Bundle(fixtureJson));
      final result = await repo.related('a');
      final ids = result.fold(
          (_) => <String>[], (items) => items.map((c) => c.id).toList());
      expect(ids, ['b']);
    });

    test('camera without a district has no related cameras', () async {
      final repo = FixtureCameraRepository(bundle: _Bundle(fixtureJson));
      final result = await repo.related('d');
      expect(result.fold((_) => -1, (items) => items.length), 0);
    });

    test('districts provides onlineCount per district', () async {
      final repo = FixtureCameraRepository(bundle: _Bundle(fixtureJson));
      final result = await repo.districts();
      final options = result.fold((_) => <DistrictOption>[], (items) => items);
      final q3 = options.firstWhere((o) => o.name == 'Quận 3');
      expect(q3.count, 2);
      expect(q3.onlineCount, 2);
    });

    test('districts reports zero online cameras for an all-offline district',
        () async {
      final repo = FixtureCameraRepository(bundle: _Bundle(fixtureJson));
      final result = await repo.districts();
      final options = result.fold((_) => <DistrictOption>[], (items) => items);
      final q1 = options.firstWhere((o) => o.name == 'Quận 1');
      expect(q1.count, 1);
      expect(q1.onlineCount, 0);
    });

    test('districts counts only online cameras in mixed availability fixtures',
        () async {
      final repo = FixtureCameraRepository(
          bundle: _Bundle(jsonEncode({
        'items': [
          for (final status in ['online', 'offline', 'degraded', 'unknown'])
            {
              'id': status,
              'name': status,
              'district': 'Quận 1',
              'availability': status
            },
        ],
      })));
      final result = await repo.districts();
      final option =
          result.fold((f) => throw StateError('$f'), (items) => items.single);
      expect(option.count, 4);
      expect(option.onlineCount, 1);
    });
  });

  testWidgets('traffic details switch between English and Vietnamese',
      (tester) async {
    final repo = _Repo(relatedItems: const [], districtOptions: const []);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('vi')],
      startLocale: const Locale('en'),
      fallbackLocale: const Locale('vi'),
      saveLocale: false,
      path: 'assets/translations',
      child: Builder(
          builder: (context) => MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: Scaffold(
                    body: Column(children: [
                  TextButton(
                      onPressed: () => context.setLocale(const Locale('vi')),
                      child: const Text('switch')),
                  TrafficBriefCard(
                      camera: cam('c1', 'Cam', availability: 'online'),
                      repository: repo,
                      onSelectCamera: (_) {}),
                ])),
              )),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Location status'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();
    expect(find.text('Tình trạng tại điểm'), findsOneWidget);
    expect(find.text('Đang hoạt động'), findsOneWidget);
  });

  group('TrafficBriefCard', () {
    testWidgets('shows district totals, live count and related cameras',
        (tester) async {
      final repo = _Repo(
        relatedItems: [
          cam('r1', 'Lân cận 1', district: 'Quận 3', live: true),
          cam('r2', 'Lân cận 2', district: 'Quận 3'),
        ],
        districtOptions: const [DistrictOption(name: 'Quận 3', count: 61)],
      );
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('self', 'Camera chính', district: 'Quận 3'),
            repository: repo,
            onSelectCamera: (_) {},
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_card')), findsOneWidget);
      expect(find.text('Tình trạng tại điểm'), findsOneWidget);
      expect(find.byKey(const ValueKey('traffic_brief_district_info')),
          findsOneWidget);
      expect(
        find.text('Quận 3 · 61 camera trong khu vực · 1 camera có trực tiếp'),
        findsOneWidget,
      );
      expect(find.text('Lân cận 1'), findsOneWidget);
      expect(find.text('Lân cận 2'), findsOneWidget);
    });

    testWidgets('shows online availability badge when camera is online',
        (tester) async {
      final repo = _Repo(
        relatedItems: const [],
        districtOptions: const [DistrictOption(name: 'Quận 1', count: 10)],
      );
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera:
                cam('c1', 'Cam 1', district: 'Quận 1', availability: 'online'),
            repository: repo,
            onSelectCamera: (_) {},
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_status_online')),
          findsOneWidget);
      expect(find.text('Đang hoạt động'), findsOneWidget);
    });

    testWidgets('shows offline availability badge when camera is offline',
        (tester) async {
      final repo = _Repo(
        relatedItems: const [],
        districtOptions: const [DistrictOption(name: 'Quận 1', count: 10)],
      );
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera:
                cam('c2', 'Cam 2', district: 'Quận 1', availability: 'offline'),
            repository: repo,
            onSelectCamera: (_) {},
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_status_offline')),
          findsOneWidget);
      expect(find.text('Mất tín hiệu'), findsOneWidget);
    });

    testWidgets('shows snapshot freshness: fresh vs stale', (tester) async {
      final baseTime = DateTime(2026, 10, 25, 12, 0, 0);
      final repo = _Repo(
        relatedItems: const [],
        districtOptions: const [DistrictOption(name: 'Quận 1', count: 10)],
      );

      // Fresh snapshot (15s ago)
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('c1', 'Cam 1', district: 'Quận 1'),
            repository: repo,
            onSelectCamera: (_) {},
            snapshotFetchedAt: baseTime,
            clockNow: () => DateTime(2026, 10, 25, 12, 0, 15),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_freshness_fresh')),
          findsOneWidget);
      expect(find.text('Ảnh mới: Cập nhật 15s trước'), findsOneWidget);

      // Stale snapshot (90s ago)
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('c1', 'Cam 1', district: 'Quận 1'),
            repository: repo,
            onSelectCamera: (_) {},
            snapshotFetchedAt: baseTime,
            isStale: true,
            clockNow: () => DateTime(2026, 10, 25, 12, 1, 30),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_freshness_stale')),
          findsOneWidget);
      expect(find.text('Ảnh cũ (90s trước)'), findsOneWidget);
    });

    testWidgets('shows district online ratio when onlineCount is available',
        (tester) async {
      final repo = _Repo(
        relatedItems: const [],
        districtOptions: const [
          DistrictOption(name: 'Quận 3', count: 61, onlineCount: 45)
        ],
      );
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('self', 'Camera chính', district: 'Quận 3'),
            repository: repo,
            onSelectCamera: (_) {},
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Quận 3 · 45/61 camera hoạt động'), findsOneWidget);
    });

    testWidgets(
        'does not render a directions button even when location present',
        (tester) async {
      final repo = _Repo(
        relatedItems: const [],
        districtOptions: const [DistrictOption(name: 'Quận 1', count: 10)],
      );
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('c1', 'Cam 1',
                district: 'Quận 1', latitude: 10.77, longitude: 106.70),
            repository: repo,
            onSelectCamera: (_) {},
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // Directions lives in the viewer/sheet action row, not in this card.
      expect(
          find.byKey(const ValueKey('brief_directions_button')), findsNothing);
    });

    testWidgets('tapping a related camera selects it', (tester) async {
      Camera? selected;
      final repo = _Repo(
        relatedItems: [cam('r1', 'Lân cận 1', district: 'Quận 3')],
        districtOptions: const [],
      );
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('self', 'Camera chính', district: 'Quận 3'),
            repository: repo,
            onSelectCamera: (c) => selected = c,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('brief_related_r1')));
      expect(selected?.id, 'r1');
    });

    testWidgets('shows camera status and freshness without a district',
        (tester) async {
      final repo = _Repo(
        relatedItems: const [],
        districtOptions: const [],
      );
      final fetchedAt = DateTime(2026, 10, 25, 12);
      await tester.pumpWidget(localizedApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('self', 'Camera chính',
                availability: 'online', latitude: 10.77, longitude: 106.7),
            repository: repo,
            onSelectCamera: (_) {},
            snapshotFetchedAt: fetchedAt,
            clockNow: () => fetchedAt.add(const Duration(seconds: 15)),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_card')), findsOneWidget);
      expect(find.text('Đang hoạt động'), findsOneWidget);
      expect(find.text('Ảnh mới: Cập nhật 15s trước'), findsOneWidget);
      expect(find.byKey(const ValueKey('traffic_brief_district_info')),
          findsNothing);
      expect(
          find.byKey(const ValueKey('brief_directions_button')), findsNothing);
    });

    testWidgets('keeps camera information when district requests fail',
        (tester) async {
      final repo = _Repo(
          relatedItems: const [],
          districtOptions: const [],
          failDistrictData: true);
      final fetchedAt = DateTime(2026, 10, 25, 12);
      await tester.pumpWidget(localizedApp(
          home: Scaffold(
              body: TrafficBriefCard(
        camera: cam('self', 'Camera chính',
            district: 'Quận 1',
            availability: 'offline',
            latitude: 10.77,
            longitude: 106.7),
        repository: repo,
        onSelectCamera: (_) {},
        snapshotFetchedAt: fetchedAt,
        isStale: true,
        clockNow: () => fetchedAt.add(const Duration(seconds: 90)),
      ))));
      await tester.pump();
      expect(find.text('Mất tín hiệu'), findsOneWidget);
      expect(find.text('Ảnh cũ (90s trước)'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('brief_directions_button')), findsNothing);
      expect(find.textContaining('camera hoạt động'), findsNothing);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('fits narrow layout at 200 percent text scale ($width)',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = _Repo(relatedItems: const [], districtOptions: const [
          DistrictOption(name: 'Quận 1', count: 4, onlineCount: 1)
        ]);
        final fetchedAt = DateTime(2026, 10, 25, 12);
        await tester.pumpWidget(localizedApp(
            home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: SingleChildScrollView(
                  child: TrafficBriefCard(
            camera: cam('self', 'Camera chính',
                district: 'Quận 1',
                availability: 'online',
                latitude: 10.77,
                longitude: 106.7),
            repository: repo,
            onSelectCamera: (_) {},
            snapshotFetchedAt: fetchedAt,
            clockNow: () => fetchedAt.add(const Duration(seconds: 90)),
          ))),
        )));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Tình trạng tại điểm'), findsOneWidget);
        expect(find.text('Đang hoạt động'), findsOneWidget);
      });
    }
  });
}
