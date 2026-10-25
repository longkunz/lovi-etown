# Camera Map Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Thêm navigation Bản đồ | Camera, mở Bản đồ đầu tiên khi khởi động app, tìm camera theo vùng đang xem và Gần tôi bằng dữ liệu backend.

**Architecture:** API `/v1/map-cameras` truy vấn PostGIS và trả tối đa 200 camera với metadata giới hạn/phạm vi. Flutter có CameraMapRepository/Cubit độc lập, gateway vị trí injectable và shell hai tab dùng lại chi tiết camera. Dùng canvas Vietmap chung cho khám phá/mini/toàn màn hình; giữ state Dart qua chuyển tab nhưng dispose native map khi không hiển thị.

**Navigation:** Dùng `go_router` hiện có (`pubspec.lock`: 17.5.0), `StatefulShellRoute.indexedStack` với hai branch Bản đồ/Camera, `preload: false`; chuyển tab bằng `StatefulNavigationShell.goBranch(index)`. Viewer dùng root navigator. Giữ state của branch không có nghĩa là giữ native map khi tab ẩn.

**Tech Stack:** NestJS 12/Fastify, TypeScript, pg/PostgreSQL 17/PostGIS 3.5; Flutter, flutter_bloc, dio, go_router, `vietmap_flutter_gl: 4.1.1` (xác minh build ở Task 3), geolocator và Liquid Glass hiện có.

**Spec:** [2026-10-24-camera-map-discovery-design.md](../specs/2026-10-24-camera-map-discovery-design.md)

**Status:** Đã chốt nhà cung cấp Vietmap và thứ tự/mặc định navigation; các chi tiết kỹ thuật bên dưới là kế hoạch, chưa triển khai. Đây là kế hoạch một tính năng xuyên backend/mobile, không phải hai dự án độc lập.

**Confirmed requirement:** Người dùng đã chọn Vietmap, xác nhận Bản đồ là tab đầu tiên và màn hình mở mặc định; Camera chuyển sang tab thứ hai.

**Tracking:** [GitHub issue #40](https://github.com/longkunz/lovi-etown/issues/40), chứa snapshot đầy đủ của spec và kế hoạch.

## Nhà cung cấp và điều kiện nghiệm thu runtime

**Vietmap đã được người dùng chốt.** Task 3 bổ sung SDK/config/native setup; Task 5 chuyển cả bản đồ mini/toàn màn hình hiện có, không chỉ tab mới. Task 1–2 và go_router không phụ thuộc provider.

Key Vietmap hợp lệ cần cho smoke map/traffic/hybrid trên thiết bị; thiếu key không chặn viết code hoặc test fake. Key đi qua `--dart-define=VIETMAP_API_KEY`, không được commit. Bản đồ thiếu key hiện thông báo và đường tới Camera; không khóa API danh mục. Tài liệu SDK/native/style/traffic nằm trong spec; không còn giả định Google API key hoạt động.

## Global Constraints

- Hai tab chính **Bản đồ | Camera**: Bản đồ index 0 mặc định tại `/`, Camera index 1 tại `/cameras`; `/map` redirect về `/`; Quan tâm giữ inline.
- Khởi động thông thường luôn mở Bản đồ/Vùng đang xem, không nhớ tab Camera từ phiên trước; deep link tường minh vẫn mở đúng đích. Chỉ khởi tạo danh mục/thumbnail scheduler khi lần đầu chọn Camera.
- Gần tôi bán kính 1/2/5 km, mặc định 2 km; không tự hỏi GPS khi khởi động.
- Kết quả API mặc định/tối đa 200; metadata hasMore; không tải toàn bộ catalog trên điện thoại.
- Debounce map 400 ms; GPS one-shot timeout 10 giây; chống response cũ bằng generation và cancellation.
- Camera dữ liệu/ảnh đi qua backend; map dùng Vietmap SDK với cấu hình riêng, không gắn reader key camera vào request Vietmap.
- Native map dispose khi tab ẩn/background/viewer che; giữ center/zoom/mode bằng state Dart.
- Liquid Glass hiện có, platform view opaque; vùng chạm tối thiểu 48×48 dp; kiểm tra 320 dp/text scale 2.0.
- Giữ nguyên migration 001/002 và hợp đồng list/related/viewer hiện có; bảo toàn các chỉnh sửa có sẵn trong workspace.
- Thêm SDK hiển thị Vietmap theo spec; không thêm navigation SDK/REST wrapper. Kiểm tra native build trước, giữ dependency không liên quan; khi migration hoàn tất loại `google_maps_flutter` và cấu hình key cũ nếu không còn nơi dùng.

## Review Focus

1. Permission dialog làm app inactive: chỉ pause map/network, không hủy luôn thao tác xin quyền đang hợp lệ; chỉ bỏ GPS result nếu người dùng đã đổi query/tab/dispose (Task 3/5).
2. Response chậm sau đổi tab/mode/radius/quận: không ghi đè request mới hoặc phát state sau dispose (Task 3/5).
3. Kết quả bị giới hạn hoặc vùng phủ chưa đủ: không hiển thị thành danh sách đầy đủ; retry vẫn giữ nhãn dữ liệu cũ (Task 2/5).
4. Route viewer che shell, Back/deep link và đổi Quan tâm từ bản đồ: không giữ native map chạy ngầm hoặc mất trạng thái tab (Task 4/5).
5. Tọa độ biên/null, khoảng cách bằng nhau, input số lỗi và đồng bộ catalog giữa truy vấn: API ổn định, không đảo longitude/latitude, snapshot DB nhất quán (Task 1/2).

Rủi ro bổ sung do đổi SDK: key/style lỗi vẫn mở được Camera; đổi street/hybrid không mất marker/traffic hoặc lặp layer; callback style/controller cũ không sửa map mới (Task 3/5).

## File structure và giao diện chung

Các đường dẫn mới là đề xuất, các đường dẫn sửa đã đối chiếu với repository. Không dùng số dòng làm mốc vì workspace đang có thay đổi.

Backend mới trong `backend/src/catalog/`: `map-query-schema.ts`, `map-catalog.types.ts`, `map-catalog.repository.ts`, `map-catalog.service.ts`, `map-catalog.controller.ts`, `dto/map-camera.dto.ts`; đăng ký qua `catalog.module.ts`.

```ts
type MapQuery =
  | { kind: 'viewport'; provinceId: string; district?: string; limit: number;
      bbox: [number, number, number, number] }
  | { kind: 'nearby'; provinceId: string; district?: string; limit: number;
      lat: number; lng: number; radiusMeters: number };
// MapCatalogRepository.query(query: MapQuery): Promise<MapCatalogResult>
// MapCatalogResult = {items: Array<{camera: CameraRecord; distanceMeters: number|null}>,
//                    hasMore: boolean; catalog: CatalogState}
// MapCatalogService.query(query: MapQuery): Promise<MapCatalogDtoResult>
// MapCatalogDtoResult tương tự, nhưng camera là CameraDto.
```

Mobile mới trong `mobile/lib/src/features/cameras/`: domain `camera_map_models.dart`, `camera_map_repository.dart`, `camera_location_gateway.dart`; data `api_camera_map_repository.dart`, `fixture_camera_map_repository.dart`, `geolocator_camera_location_gateway.dart`; presentation `providers/camera_map_cubit.dart`, `camera_map_state.dart`, `screens/camera_navigation_shell.dart`, `camera_map_screen.dart`, `widgets/camera_map_canvas.dart`, `camera_map_view_config.dart`, `camera_map_results.dart`, `vietmap_style_loader.dart`. Cấu hình map riêng: `mobile/lib/src/config/map_config.dart`.

```dart
// CameraMapQuery.viewport({required MapBounds bounds, String? district, int limit = 200})
// CameraMapQuery.nearby({required double lat, required double lng,
//                      int radiusMeters = 2000, String? district, int limit = 200})
// MapBounds(west, south, east, north); CameraMapItem(camera, distanceMeters)
// CameraMapResult(items, hasMore, catalogVersion, fetchedAt, isStale, coverage, syncState)
// CameraMapRepository.search(CameraMapQuery query, {CancelToken? cancelToken})
//   -> FutureEither<CameraMapResult>
// CameraApiClient.getMapCameras(CameraMapQuery query, {CancelToken? cancelToken})
//   -> FutureEither<CameraMapResult>
// CameraLocationGateway.locate() -> Future<CameraLocationResult>
// CameraLocationGateway.openAppSettings()/openLocationSettings() -> Future<bool>
// CameraLocationResult: granted(lat,lng,accuracyMeters), denied, deniedForever,
//                      serviceDisabled, timeout, failure
// MapConnectionConfig.fromEnvironment(): VIETMAP_API_KEY; isConfigured
// CameraMapViewConfig(centerLat, centerLng, zoom, items, selectedCameraId,
//                     baseStyle, trafficEnabled, userLocationEnabled)
// CameraMapCanvas(config, onViewportIdle(MapBounds), onSelectCamera(String))
// CameraMapBuilder: Widget Function(BuildContext, CameraMapViewConfig,
//   ValueChanged<MapBounds> onViewportIdle, ValueChanged<String> onSelectCamera)
// VietmapStyleLoader: loadTraffic({required CancelToken cancelToken}) -> Future<Map<String,dynamic>>;
//   timeout/403/429/invalid JSON -> typed map-layer failure, never CameraApiClient failure.
```

`CameraMapViewConfig` dùng dữ liệu domain, không chứa kiểu controller/LatLng/Marker của Google. Canvas giữ controller Vietmap nội bộ, fake builder không dùng native plugin. `baseStyle` là enum street/hybrid; config/cubit từ chối traffic/hybrid khi capability đã xác định không dùng được và thông báo lý do.

## Task 1: Truy vấn PostGIS và validation

**Files:** Create các file `map-query-schema.ts`, `map-catalog.types.ts`, `map-catalog.repository.ts` ở trên; create `backend/migrations/003_map_geometry_index.sql`; test `backend/test/unit/map-query-schema.test.ts`, `backend/test/integration/map-catalog-repository.test.ts`.

**Interfaces:** Consumes pg pool, Clock, CatalogState/CameraRecord, normalization hiện có. Produces `parseMapQuery(raw: Record<string, unknown>): MapQuery` và `MapCatalogRepository.query(query: MapQuery): Promise<MapCatalogResult>`.

- [ ] Viết test validation: bbox đúng thứ tự, lat/lng đảo, biên lat/lng, missing/unknown/array/trộn mode, `limit='2x'`, limit 0/201/1.5, radius 99/5001/1000.5, NaN/Infinity/số rỗng; assert mã lỗi/giá trị mặc định đúng spec.
- [ ] Viết DB test với ít nhất camera trong vùng, đúng biên vùng, ngoài vùng, null tọa độ, khác tỉnh/quận; nearby có camera cùng khoảng cách để kiểm tra tie-break id. Tính các điểm mẫu bằng `ST_Project` cho bán kính trong/ngoài rõ ràng; dùng tolerance cho khoảng cách float.
- [ ] Chạy `npm run test:unit`, rồi `npm run test:db` trong backend; xác nhận test mới đỏ do thiếu hành vi, không phải lỗi hạ tầng.
- [ ] Implement parser số chặt chẽ và query parameterized theo spec; REPEATABLE READ read-only cho rows + catalog metadata. Trích xuất helper metadata hiện có từ repository nếu cần để cả hai đường query dùng chung Clock/staleness semantics; bổ sung test tương thích list nếu tách helper.
- [ ] Thêm migration GiST expression index `(geom::geometry)`; bbox dùng geometry ST_Intersects/ST_MakeEnvelope, nearby dùng geography ST_DWithin/ST_Distance. Lấy limit+1; sort đúng và cắt về limit.
- [ ] Test migration chạy lặp theo runner hiện có; DB test catalog rỗng và catalog stale, kết quả nhất quán khi sync commit giữa hai read trong cùng transaction. Re-run unit và DB; lưu EXPLAIN trên dữ liệu tổng hợp đủ lớn, không đặt assertion planner bắt buộc dùng index với dữ liệu nhỏ.
- [ ] Review diff và commit chỉ các file task này khi thực thi, giữ chỉnh sửa có sẵn.

## Task 2: HTTP contract cho bản đồ

**Files:** Create `map-catalog.service.ts`, `map-catalog.controller.ts`, `dto/map-camera.dto.ts`; modify `backend/src/catalog/catalog.module.ts`; test `backend/test/integration/map-camera-api.test.ts`, modify `backend/test/integration/openapi.test.ts`; update `docs/api-catalog.md`.

**Interfaces:** Consumes Task 1. Produces GET `/v1/map-cameras` và DTO `{data:[{camera,distanceMeters}],meta:{requestId,dataMode,result,catalog}}` theo spec.

- [ ] Viết API test hai query mode, quận, zero result và 201 matching records với limit 200. Assert returned=200, hasMore=true, thứ tự đúng và `distanceMeters=null` cho bbox.
- [ ] Test invalid query 400, thiếu/sai key 401, reader/admin gọi được; rate limit 429 theo cơ chế hiện có. Assert sourceRef/token không xuất hiện trong JSON; list và `/cameras/:id` vẫn giữ hành vi cũ. Test key rotation theo guard hiện hành.
- [ ] Chạy `npm run test:api` để ghi nhận test đỏ cho endpoint mới.
- [ ] Implement service map CameraRecord qua `toCameraDto`, controller parse/delegate/envelope; đăng ký controller/provider và Swagger query/response/security. Không thêm endpoint trùng `:id`.
- [ ] Chạy backend `npm run typecheck`, rồi lần lượt `npm run test:unit`, `npm run test:api`, `npm run test:db`; tất cả phải PASS. Cập nhật contract docs với ví dụ, giới hạn, khoảng cách đường thẳng và incomplete coverage.
- [ ] Review diff và commit phạm vi task.

## Task 3: Mobile data, SDK Vietmap và quyền vị trí

**Files:** Create các domain/data file ở phần giao diện chung và `mobile/lib/src/config/map_config.dart`; modify `mobile/lib/src/services/camera_api_client.dart`, `mobile/pubspec.yaml`, `pubspec.lock`, `mobile/.env.example`, `mobile/SETUP.md`, `mobile/android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `mobile/ios/Podfile`, `Podfile.lock`, `Runner/Info.plist`, `Runner.xcodeproj/project.pbxproj` khi native target cần đồng bộ. Tests: `mobile/test/features/cameras/camera_map_repository_test.dart`, `camera_location_gateway_test.dart`, `map_config_test.dart`; extend `camera_api_client_test.dart`.

**Interfaces:** Consumes Task 2 HTTP contract. Produces CameraMapRepository/search, CameraLocationGateway và MapConnectionConfig như phần giao diện chung; CameraRepository cũ giữ interface hiện tại. SDK resolve/build được trước khi làm canvas Task 5.

- [ ] Viết client test serialize bbox theo west,south,east,north; nearby tham số đúng; header/origin/cancellation đi theo client hiện có; decode nested camera, khoảng cách, hasMore/catalog metadata. Invalid payload trả failure thay vì crash.
- [ ] Viết fixture test cùng lọc bbox/quận, nearby Haversine dùng bán kính Trái Đất 6371008.8 m, limit+1/sort id/hasMore. Các điểm kiểm thử cách biên bán kính ít nhất 20 m để không giả định Haversine trùng ellipsoid PostGIS; sai số gần biên fixture được ghi rõ.
- [ ] Viết gateway test granted, coarse location, denied, deniedForever, GPS tắt, timeout 10s bằng fake clock/plugin. Permission prompt không được lặp trong cùng một lần bấm; foreground mới không tự xin lại quyền.
- [ ] Viết config tests: key rỗng/trim, key từ build environment hoặc injection; MapConnectionConfig không thay CameraConnectionConfig.isValid; không log style URL có key. Thêm `map_config_test.dart` vào targeted test command bên dưới.
- [ ] Chạy targeted `flutter test test/features/cameras/camera_map_repository_test.dart test/features/cameras/camera_location_gateway_test.dart test/features/cameras/map_config_test.dart test/features/cameras/camera_api_client_test.dart`; xác nhận đỏ cho hành vi mới.
- [ ] Implement models/parser, API adapter/fixture và injectable gateway. Gateway chỉ hỏi quyền từ locate do thao tác người dùng; kiểm tra service/quyền trước fetch, typed result, mở app/location settings. Chỉ dùng getCurrentPosition, có deadline; late completion bỏ qua bằng generation ở consumer.
- [ ] Thêm SDK Vietmap và cấu hình/native targets theo spec; `flutter pub get`, kiểm tra minSdk/JitPack và Pods theo package thực tế, giữ mức target cao hơn sẵn có. Thêm foreground fine/coarse Android, iOS when-in-use usage description; không xin background location. Cấu hình `VIETMAP_API_KEY` theo build environment hiện có, tài liệu ví dụ chỉ chứa placeholder.
- [ ] Chạy `flutter build apk --debug` và `flutter build ios --simulator --no-codesign` trong môi trường có SDK/Xcode. Nếu package 4.1.1 không tương thích, ghi lỗi thật rồi chọn phiên bản đã xác minh build thay vì nâng gói không liên quan. Thiếu hạ tầng ghi giới hạn, không đánh PASS; bước này chưa cần map key thật.
- [ ] Re-run targeted tests rồi `flutter analyze`; review diff và commit phạm vi task.

## Task 4: Navigation hai tab và vòng đời

**Files:** Create `presentation/screens/camera_navigation_shell.dart`; modify `presentation/camera_feature.dart`, `presentation/screens/camera_screen.dart`, `mobile/lib/src/routing/app_router.dart`, `app_routes.dart`, `mobile/assets/translations/vi.json`, `en.json`; test `mobile/test/features/cameras/camera_navigation_test.dart`, existing `camera_screen_test.dart`, `camera_update_required_test.dart`.

**Interfaces:** Consumes injectable camera/favorites repositories hiện có và CameraMapRepository Task 3. Produces shell với Bản đồ tại `/` (index 0), Camera tại `/cameras` (index 1), redirect `/map` → `/`, shared dependencies, callback chọn camera vào luồng detail/viewer hiện có, cùng tín hiệu tab active cho screen/scheduler. Task 5 cung cấp nội dung map thực; Task 4 dùng child builder injectable để test navigation độc lập.

- [ ] Viết widget/router tests: mặc định Bản đồ được chọn ở index 0, Camera ở index 1; mở app không tạo catalog cubit/scheduler hoặc tải thumbnail; deep link `/cameras` chọn Camera, `/map` redirect `/`; đổi tab giữ query/quận/scroll; viewer `/camera/:id` deep link hoạt động; Back từ viewer giữ tab nguồn; không recreate catalog cubit sau lần đầu vào Camera. Giả lập phiên trước kết thúc ở Camera, cold start thông thường vẫn vào Bản đồ.
- [ ] Test bấm lại tab hiện tại không reset state/stack; viewer push trên root navigator che thanh tab và Back trả đúng tab nguồn; viewer mở trực tiếp không có lịch sử thì nút quay lại fallback `/`.
- [ ] Test tab ẩn dừng thumbnail scheduling; các sự kiện app foreground/background vẫn đúng; mở viewer/đóng sheet không nhân đôi polling. Fake map builder ghi nhận dispose/recreate để chứng minh shell không giữ native map ẩn.
- [ ] Chạy `flutter test test/features/cameras/camera_navigation_test.dart` để ghi nhận đỏ.
- [ ] Implement `StatefulShellRoute.indexedStack`, hai `StatefulShellBranch(preload: false)` theo thứ tự Bản đồ/Camera; dùng `navigationShell.currentIndex` và `goBranch(index)` khi chọn tab khác, bấm tab hiện tại là no-op. `AppRoutes.map='/'`, `AppRoutes.camera='/cameras'`, initialLocation dùng `AppRoutes.map`, `/map` redirect `/`. Viewer là route trên root navigator, mở qua push và có fallback `/` nếu không pop được. Rà các tham chiếu route Camera để hành động mở danh mục vẫn tới `/cameras`. Resolve repositories một lần theo shell lifetime, lazy tạo CameraScreen/catalog cubit khi chọn Camera; giữ not-configured/demo/401-update-required gate trên cả hai tab. CameraScreen nhận active lifecycle rõ ràng, không tạo một repository/scheduler mới mỗi build.
- [ ] Truyền tab active kết hợp app lifecycle và root route visibility xuống map/scheduler. IndexedStack chỉ ẩn branch, không tự dispose: chủ động thay native map bằng placeholder khi inactive và giữ state Dart bên ngoài canvas. Test dispose/recreate phải PASS với shell thật, không chỉ khi unmount cả màn hình.
- [ ] Thêm nhãn theo thứ tự Bản đồ/Camera, semantics chọn tab và safe area bằng theme/token hiện có. Không thêm tab Quan tâm riêng.
- [ ] Re-run navigation + screen + update-required tests. Review diff và commit phạm vi task.

## Task 5: Khám phá bản đồ và Gần tôi

**Files:** Create `camera_map_cubit.dart`, `camera_map_state.dart`, `camera_map_screen.dart`, `camera_map_canvas.dart`, `camera_map_view_config.dart`, `camera_map_results.dart`, `vietmap_style_loader.dart` tại các thư mục nêu trên; integrate shell Task 4. Modify `camera_traffic_map_card.dart`, `camera_traffic_map_viewer_screen.dart`, `camera_snapshot_sheet.dart`, `camera_viewer_screen.dart` để dùng chung canvas/builder Vietmap; update translations. Remove dependency/config Google Maps khỏi pubspec/lock, Android Gradle/manifest và native iOS nếu có nơi khởi tạo (AppDelegate hiện không có). Tests: new `camera_map_cubit_test.dart`, `camera_map_screen_test.dart`, `vietmap_style_loader_test.dart`, `camera_map_canvas_test.dart`; extend `camera_traffic_map_test.dart`, `camera_navigation_test.dart`, `camera_snapshot_sheet_test.dart`, `camera_viewer_test.dart` và fake liên quan.

**Interfaces:** Consumes Tasks 3/4. Produces `CameraMapCubit(repository, locationGateway)` với `setViewport(MapBounds)`, `showNearby()`, `setRadius(int meters)`, `setDistrict(String?)`, `retry()`, `setActive(bool)`, `close()`; screen nhận callbacks chọn camera và map builder injectable. State lưu mode, query generation, last-good result kèm query nguồn, center/zoom, request/location status, selected camera.

- [ ] Viết cubit tests fake clock: 400 ms idle debounce chỉ có một request; bbox/mode/radius/quận thay đổi lập tức invalidate generation; request/GPS cũ resolve sau request mới không emit sai; close không emit thêm.
- [ ] Test chuyển Camera hoặc viewer trong khi hỏi GPS; dialog inactive không tự vô hiệu hóa lần xin quyền đang chờ, nhưng đổi tab/mode thật phải bỏ kết quả. Resume kiểm tra lại quyền hiện tại, không mở permission dialog tự động.
- [ ] Viết screen test Bản đồ là màn hình đầu tiên ở Vùng đang xem với default center/zoom, no startup permission, missing config và API key bị từ chối ngay trên Bản đồ; radius 1/2/5 km, loading/empty/error/retry, old-result label, incomplete catalog, cả hai thông báo hasMore; viewport sai biên hiện CTA zoom và không request API.
- [ ] Test marker/dòng danh sách chọn đúng camera, chỉ camera chọn gọi snapshot; Quan tâm thay đổi từ sheet được phản ánh khi về Camera; distance hiển thị theo mét/km với nhãn khoảng cách đường thẳng.
- [ ] Test canvas adapter với fake controller: style-ready mới dựng marker, hai lần style-loaded không lặp layer, đổi street/hybrid giữ marker/selection/traffic, callback controller cũ bị bỏ qua; lỗi key/traffic/hybrid có trạng thái lỗi riêng, base map hoặc tab Camera còn thao tác được. Tải style bằng client riêng, assert không có x-api-key backend và lỗi không log URL chứa key.
- [ ] Update test builder trong mini map/sheet/viewer sang CameraMapViewConfig không chứa kiểu Google; assert cả ba bề mặt bản đồ đều dùng adapter Vietmap. Thiếu key dùng fake trong demo/test, build thật hiện thông báo chứ không gửi placeholder key.
- [ ] Chạy targeted map/cubit/traffic/navigation tests; xác nhận đỏ cho hành vi mới.
- [ ] Implement canvas với VietmapGL; convert domain coordinate/marker ở adapter, SDK LatLng theo lat,lng và API bbox theo west,south,east,north. Gửi viewport sau idle qua callback chung và xử lý style-ready/canvas generation. Refactor mini/toàn màn hình và builder dùng canvas này; không mang GoogleMapController/Marker/LatLng sang API mới.
- [ ] Implement cubit/state, native map canvas chỉ dựng khi active/foreground/không bị route che. Dispose controller và cancel pending requests/timers khi inactive; giữ query/result/center/zoom để dựng lại. Chỉ bật vị trí người dùng khi quyền hợp lệ, kể cả map chi tiết camera.
- [ ] Implement VietmapStyleLoader qua HTTP client riêng: chỉ tải host Vietmap, timeout 10 giây, hủy khi map ẩn, báo typed failure. Đọc key từ MapConnectionConfig, không thêm backend reader key; giữ trạng thái lỗi lớp phụ riêng với catalog. Dùng style đường phố/hybrid và traffic overlay đúng mục Canvas Vietmap trong spec; reapply marker/traffic theo generation sau đổi style, không dùng overlay làm base style.
- [ ] Implement Vùng đang xem và Gần tôi đúng spec; pan ở nearby không thay tâm query. Tái sử dụng district options, traffic preference, glass controls opaque và callback chi tiết camera; không gọi thumbnail theo marker và không tạo timer snapshot của cả bản đồ. Key thiếu/không hợp lệ hiển thị thông báo và nút qua Camera.
- [ ] Rà mọi import/dependency/google API key config sau migration; loại Google Maps SDK khi không còn nơi dùng, giữ luồng chỉ đường external hiện có. Chạy lại `flutter pub get` và pod install phù hợp để lockfile nhất quán.
- [ ] Widget test 320 dp/text scale 2.0, semantics tab/marker/list, touch target 48×48. Native gesture/SDK không thể coi widget test là nghiệm thu thiết bị.
- [ ] Re-run targeted tests và `flutter analyze`; review diff và commit phạm vi task.

## Task 6: Nghiệm thu đầu cuối và vận hành

**Files:** Create `docs/ui/camera-map-discovery-verification.md`; modify `docs/project-status.md`, `docs/README.md`, API docs nếu có thay đổi; test mới `mobile/integration_test/camera_map_discovery_test.dart` khi hạ tầng hỗ trợ.

**Interfaces:** Consumes toàn bộ Task 1–5; produces báo cáo bằng chứng và danh sách giới hạn thực tế.

- [ ] Chuẩn bị PostGIS theo `backend/compose.test.yml` và `backend/README.md`; chạy migration hiện hành. Nếu hạ tầng thiếu thì ghi BLOCKED đúng bộ test, không đánh PASS.
- [ ] Chạy trong backend: `npm run typecheck`, `npm run test:unit`, `npm run test:api`, `npm run test:db` theo thứ tự. Trong mobile: `flutter analyze`, `flutter test` toàn bộ. Ghi số lượng thực từ output, không tái dùng mốc 251 test cũ.
- [ ] Smoke có fixture nhiều hơn một trang danh mục: camera ở trang sau vẫn thấy trên map, chứng minh không lọc danh sách đã tải. Kiểm tra limit 200/hasMore và dữ liệu thiếu tọa độ.
- [ ] Chuẩn bị API key Vietmap qua Console và build config cục bộ; không yêu cầu Google key. Nếu chưa có Vietmap key vẫn chạy automated/fake tests, nhưng ghi rõ chưa kiểm chứng bản đồ thật.
- [ ] Android và iOS: fresh install mở Vietmap ở tab đầu tiên mà không hỏi GPS; từng mở Camera rồi force-stop và mở app thông thường vẫn về Bản đồ; deep link Camera/viewer không bị chuyển sai về mặc định. Kiểm tra grant/deny/permanent deny, GPS off, approximate position, mất mạng, vào/ra tab 10 lần, viewer + Back, background/resume, map pan/pinch, hybrid/traffic Vietmap và Quan tâm trên cả tab mới/mini/toàn màn hình. Thiếu/sai key hoặc lớp phụ bị từ chối phải còn dùng được Camera/đường phố theo trường hợp. Không nghiệm thu một nền tảng bằng kết quả nền tảng còn lại.
- [ ] Đo/profile tab lifecycle: native map dispose khi ẩn, snapshot request chỉ cho camera chọn, không tích lũy controllers/timers sau 10 lần. Ghi thiết bị/build và số đo thực; không đặt con số hiệu năng chưa được đo làm kết luận.
- [ ] Hoàn thiện báo cáo và liên kết trạng thái dự án, phân biệt automated với device evidence. Review diff và commit các file nghiệm thu.

## Thứ tự và điểm bàn giao

Task 1 → 2 → 3 → 4 → 5 → 6. Mỗi task kết thúc ở một thay đổi có thể kiểm thử/review; triển khai inline phù hợp vì các giao diện phụ thuộc nhau. Không bắt đầu product code khi người dùng mới yêu cầu kế hoạch.

## Tự kiểm tra kế hoạch

- Mọi tiêu chí nghiệm thu trong spec có task và phép kiểm tương ứng ở trên.
- Interface/query/result có tên thống nhất giữa backend, client, cubit và UI.
- Permission/lifecycle/response cũ/giới hạn/phạm vi dữ liệu có test owners rõ ràng.
- Chỉ thêm một migration index; không thêm dịch vụ hoặc thay database.
- Vietmap là provider đã chốt; có task cấu hình SDK/key, migration toàn bộ map cũ và kiểm thử lỗi/style. Không còn task chờ chọn provider hoặc phụ thuộc Google API key.
- Chưa chạy tests sản phẩm trong lượt lập kế hoạch vì chỉ thêm tài liệu; các lệnh ở trên là công việc tương lai, không phải kết quả đã có.
