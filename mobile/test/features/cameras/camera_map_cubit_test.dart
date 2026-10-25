import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_models.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_map_repository.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_location_gateway.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_map_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_map_state.dart';
import 'package:flutter_starter/src/utils/typedefs.dart';
import 'package:flutter_starter/src/utils/failure.dart';

class PendingMapRepository implements CameraMapRepository {
  final queries = <CameraMapQuery>[];
  final tokens = <CancelToken?>[];
  final requests = <Completer<Either<Failure, CameraMapResult>>>[];
  @override
  FutureEither<CameraMapResult> search(CameraMapQuery query,
      {CancelToken? cancelToken}) {
    queries.add(query);
    tokens.add(cancelToken);
    final c = Completer<Either<Failure, CameraMapResult>>();
    requests.add(c);
    return c.future;
  }

  void succeed(int n, String version) =>
      requests[n].complete(Right(CameraMapResult(
          items: const [], hasMore: false, catalogVersion: version)));
}

class PendingLocation implements CameraLocationGateway {
  int calls = 0;
  Completer<CameraLocationResult> pending = Completer();
  @override
  Future<CameraLocationResult> locate() {
    calls++;
    return pending.future;
  }

  @override
  Future<bool> checkPermission() async => true;
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  const a = MapBounds(106.6, 10.7, 106.8, 10.9),
      b = MapBounds(106.7, 10.8, 106.9, 11);
  testWidgets('idle events debounce 400ms and never ask for GPS on startup',
      (tester) async {
    final repo = PendingMapRepository(), gps = PendingLocation();
    final c = CameraMapCubit(repository: repo, locationGateway: gps);
    addTearDown(c.close);
    c.setViewport(a);
    await tester.pump(const Duration(milliseconds: 200));
    c.setViewport(b);
    await tester.pump(const Duration(milliseconds: 399));
    expect(repo.queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.queries.length, 1);
    expect(repo.queries.single.bounds, same(b));
    expect(gps.calls, 0);
    repo.succeed(0, 'b');
    await tester.pump();
    expect(c.state.result?.catalogVersion, 'b');
  });
  testWidgets('old response cannot publish during debounce for newer viewport',
      (tester) async {
    final repo = PendingMapRepository();
    final c =
        CameraMapCubit(repository: repo, locationGateway: PendingLocation());
    addTearDown(c.close);
    c.setViewport(a);
    await tester.pump(const Duration(milliseconds: 400));
    c.setViewport(b);
    expect(repo.tokens.first!.isCancelled, true);
    repo.succeed(0, 'old');
    await tester.pump();
    expect(c.state.result, isNull);
    await tester.pump(const Duration(milliseconds: 400));
    repo.succeed(1, 'new');
    await tester.pump();
    expect(c.state.result!.catalogVersion, 'new');
  });
  testWidgets('leaving tab invalidates pending GPS without issuing map request',
      (tester) async {
    final repo = PendingMapRepository(), gps = PendingLocation();
    final c = CameraMapCubit(repository: repo, locationGateway: gps);
    addTearDown(c.close);
    c.showNearby();
    expect(gps.calls, 1);
    c.setActive(false);
    gps.pending.complete(const CameraLocationResult(
        status: CameraLocationStatus.granted, lat: 10.8, lng: 106.7));
    await tester.pump();
    expect(repo.queries, isEmpty);
    expect(c.state.locating, false);
  });
  testWidgets(
      'temporary app inactivity preserves a user initiated permission request',
      (tester) async {
    final repo = PendingMapRepository(), gps = PendingLocation();
    final c = CameraMapCubit(repository: repo, locationGateway: gps);
    addTearDown(c.close);
    c.showNearby();
    c.setForeground(false);
    c.setForeground(true);
    gps.pending.complete(const CameraLocationResult(
        status: CameraLocationStatus.granted, lat: 10.8, lng: 106.7));
    await tester.pump();
    expect(repo.queries.single.radiusMeters, 2000);
    expect(repo.queries.single.lat, 10.8);
    repo.succeed(0, 'near');
    await tester.pump();
  });
  testWidgets(
      'nearby pan keeps search center, radius invalidates old responses',
      (tester) async {
    final repo = PendingMapRepository(), gps = PendingLocation();
    final c = CameraMapCubit(repository: repo, locationGateway: gps);
    addTearDown(c.close);
    c.showNearby();
    gps.pending.complete(const CameraLocationResult(
        status: CameraLocationStatus.granted, lat: 10.8, lng: 106.7));
    await tester.pump();
    c.setViewport(a);
    await tester.pump(const Duration(milliseconds: 500));
    expect(repo.queries.length, 1);
    c.setRadius(5000);
    expect(repo.queries.last.radiusMeters, 5000);
    repo.succeed(0, 'old');
    repo.succeed(1, 'new');
    await tester.pump();
    expect(c.state.result!.catalogVersion, 'new');
  });
  testWidgets('failure and retry retain last good result as stale',
      (tester) async {
    final repo = PendingMapRepository();
    final c =
        CameraMapCubit(repository: repo, locationGateway: PendingLocation());
    addTearDown(c.close);
    c.setViewport(a);
    await tester.pump(const Duration(milliseconds: 400));
    repo.succeed(0, 'good');
    await tester.pump();
    c.setDistrict('Quận 1');
    repo.requests[1].complete(const Left(NetworkFailure('offline')));
    await tester.pump();
    expect(c.state.result!.catalogVersion, 'good');
    expect(c.state.resultsAreStale, true);
    c.retry();
    expect(c.state.resultsAreStale, true);
    repo.succeed(2, 'fresh');
    await tester.pump();
    expect(c.state.resultsAreStale, false);
  });
  testWidgets(
      'invalid viewport does not request and close ignores late responses',
      (tester) async {
    final repo = PendingMapRepository();
    final c =
        CameraMapCubit(repository: repo, locationGateway: PendingLocation());
    c.setViewport(const MapBounds(-190, 10, 106, 11));
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.queries, isEmpty);
    expect(c.state.invalidViewport, true);
    c.setViewport(a);
    await tester.pump(const Duration(milliseconds: 400));
    await c.close();
    repo.succeed(0, 'late');
    await tester.pump();
    expect(c.state.result, isNull);
  });
  testWidgets(
      'switching back to viewport invalidates GPS and queries current bounds',
      (tester) async {
    final repo = PendingMapRepository(), gps = PendingLocation();
    final c = CameraMapCubit(repository: repo, locationGateway: gps);
    addTearDown(c.close);
    c.setViewport(a);
    c.showNearby();
    c.showViewport();
    gps.pending.complete(const CameraLocationResult(
        status: CameraLocationStatus.granted, lat: 10.8, lng: 106.7));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.state.mode, CameraMapMode.viewport);
    expect(repo.queries.single.isNearby, false);
  });
}
