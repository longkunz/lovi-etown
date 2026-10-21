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

Camera cam(String id, String name, {String? district, bool live = false}) =>
    Camera(
      id: id,
      name: name,
      provinceId: 'tp_hcm',
      district: district,
      playbackEndpoint: '/v1/cameras/$id/playback',
      snapshotEndpoint: '/v1/cameras/$id/snapshot',
      liveCapable: live,
      streamUrl: live ? 'http://media.example/$id.m3u8' : null,
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
  _Repo({required this.relatedItems, required this.districtOptions});
  final List<Camera> relatedItems;
  final List<DistrictOption> districtOptions;

  @override
  FutureEither<List<Camera>> related(String id,
          {int limit = 6, CancelToken? cancelToken}) async =>
      Right(relatedItems.take(limit).toList());

  @override
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken}) async =>
      Right(districtOptions);

  @override
  FutureEither<CatalogPage> list({
    String? query,
    String? district,
    int limit = 50,
    int offset = 0,
    CancelToken? cancelToken,
  }) async =>
      const Right(CatalogPage(
          items: [], limit: 50, offset: 0, total: 0, catalogVersion: 'v1', dataMode: 'fixture'));

  @override
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken}) async =>
      const Left(ServerFailure('n/a'));

  @override
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken}) async =>
      const Left(ServerFailure('n/a'));

  @override
  FutureEither<SnapshotReply> snapshot(String endpoint,
          {String? etag, CancelToken? cancelToken}) async =>
      const Left(ServerFailure('n/a'));
}
void main() {
  group('FixtureCameraRepository.related', () {
    final fixtureJson = jsonEncode({
      'catalogVersion': 'fixture-v1',
      'dataMode': 'fixture',
      'items': [
        {'id': 'a', 'name': 'A', 'district': 'Quận 3', 'playbackEndpoint': '/p/a'},
        {'id': 'b', 'name': 'B', 'district': 'Quận 3', 'playbackEndpoint': '/p/b'},
        {'id': 'c', 'name': 'C', 'district': 'Quận 1', 'playbackEndpoint': '/p/c'},
        {'id': 'd', 'name': 'D', 'playbackEndpoint': '/p/d'},
      ],
    });

    test('returns same-district cameras excluding itself', () async {
      final repo = FixtureCameraRepository(bundle: _Bundle(fixtureJson));
      final result = await repo.related('a');
      final ids = result.fold((_) => <String>[], (items) => items.map((c) => c.id).toList());
      expect(ids, ['b']);
    });

    test('camera without a district has no related cameras', () async {
      final repo = FixtureCameraRepository(bundle: _Bundle(fixtureJson));
      final result = await repo.related('d');
      expect(result.fold((_) => -1, (items) => items.length), 0);
    });
  });

  group('TrafficBriefCard', () {
    testWidgets('shows district totals, live count and related cameras', (tester) async {
      final repo = _Repo(
        relatedItems: [
          cam('r1', 'Lân cận 1', district: 'Quận 3', live: true),
          cam('r2', 'Lân cận 2', district: 'Quận 3'),
        ],
        districtOptions: const [DistrictOption(name: 'Quận 3', count: 61)],
      );
      await tester.pumpWidget(MaterialApp(
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
      expect(
        find.text('Quận 3 · 61 camera trong khu vực · 1 camera có trực tiếp'),
        findsOneWidget,
      );
      expect(find.text('Lân cận 1'), findsOneWidget);
      expect(find.text('Lân cận 2'), findsOneWidget);
    });

    testWidgets('tapping a related camera selects it', (tester) async {
      Camera? selected;
      final repo = _Repo(
        relatedItems: [cam('r1', 'Lân cận 1', district: 'Quận 3')],
        districtOptions: const [],
      );
      await tester.pumpWidget(MaterialApp(
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

    testWidgets('hidden when the camera has no district', (tester) async {
      final repo = _Repo(
        relatedItems: [cam('r1', 'Lân cận 1')],
        districtOptions: const [],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TrafficBriefCard(
            camera: cam('self', 'Camera chính'),
            repository: repo,
            onSelectCamera: (_) {},
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('traffic_brief_card')), findsNothing);
    });
  });
}
