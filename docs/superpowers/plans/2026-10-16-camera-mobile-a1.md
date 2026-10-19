# Camera Mobile A1 Implementation Plan

> **Hiện trạng 2026-10-19:** Mobile A1 đã có mã nguồn và [báo cáo nghiệm thu](../../ui/mobile-a1-verification.md); 45 unit/widget tests đã chạy lại PASS. Xem [hiện trạng dự án](../../project-status.md) cho phạm vi và giới hạn. Checkbox trong kế hoạch gốc chưa được đối soát từng bước, không phải danh sách việc còn thiếu đã xác nhận; không suy từ test PASS rằng mọi bước nghiệm thu thiết bị trong plan đã hoàn tất.

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` để triển khai tuần tự trong phiên này (đề xuất), hoặc `superpowers:subagent-driven-development` nếu người dùng chọn chia task cho agent. Theo dõi bằng checkbox; không tự bắt đầu implementation chỉ vì plan đã được tạo.

**Goal:** Hoàn thành Flutter Android/iOS cho luồng Camera → snapshot bottom sheet → viewer xoay ngang/zoom → Quan tâm inline, bắt đầu với fixture rồi nối backend hiện có.

**Architecture:** Giữ feature-first của FlutterInit, BLoC/Cubit, go_router và shared Dio. Feature `cameras` sở hữu domain/data/presentation và Quan tâm của chính nó; không tạo feature Quan tâm riêng chỉ để chia thư mục. Sheet/viewer dùng chung một preview controller; thumbnail có scheduler/cache hữu hạn, độc lập với phân trang catalog.

**Tech Stack:** Flutter ≥3.41.0 cho `liquid_glass_widgets` 1.13.0, Dart theo Flutter SDK tương thích, flutter_bloc, Dio, fpdart, SharedPreferences, easy_localization. Không thêm Freezed, routing/state/image-viewer library mới.

**Spec:** [Mobile A1](../specs/2026-10-15-camera-mobile-a1-design.md), [brief](../../ui/stitch-brief.md), [prototype tương tác](../../ui/stitch/camera-interaction-prototype.md), [artboard](../../ui/stitch/camera-prototype-artboards.md). Feedback sheet tối giản trong spec có ưu tiên cao hơn mockup/page lịch sử.

## Global Constraints

- Một màn Camera; Quan tâm là section/filter inline. Không route detail/favorites hoặc bottom tab thừa.
- Dropdown lấy district thực từ backend, không hardcode phường từ ảnh mẫu. Card/Grid/List; Grid 2 cột, mật độ gọn 3 cột khi đủ chỗ. Infinite scroll, không nút “Tải thêm” trong happy path.
- Sheet chỉ có handle/X/tên/metadata nullable/saved star/ảnh. Không nút Làm mới, không nút Toàn màn hình, không text giờ nhận/cập nhật/unknown timestamp. Timestamp in sẵn trong JPEG nguồn giữ nguyên.
- Chạm ảnh mở viewer overlay, hỗ trợ dọc/ngang, pinch/pan; fit toàn ảnh, zoom 1–5×, double-tap fit/2.5× theo prototype. Back/X đóng viewer trước sheet; giữ query/filter/mode/scroll/Quan tâm.
- Liquid Glass cho chrome/controls/sheet; ảnh và nội dung list rõ nét. Dùng tokens starter và wrapper App*; wrapper glass riêng chỉ khi App* chưa đáp ứng. Không bọc glass control trong glass surface khác.
- JSON/binary qua backend riêng, không gọi Notis trực tiếp; không dùng sourceRef/upstream ID làm khóa. `provinceId=tp_hcm`, backend UUID, `limit=50`, offset ≤10000.
- Query trim; rỗng bỏ param, 1 ký tự không request và hướng dẫn nhập ≥2 ký tự, tối đa 120; debounce 350 ms. Đổi query/district tăng generation/reset trang; response cũ không được ghi đè state.
- Thumbnail: visible + tối đa một hàng prefetch, tối đa 4 request đồng thời; không polling toàn list. Ảnh ≤2 MiB; cache RAM hữu hạn, không album/disk cache.
- Preview: chỉ camera đang mở sheet/viewer poll; interval ≥3 giây, descriptor hợp lệ hoặc fallback 12 giây; timeout 15 giây; backoff 12/24/48/60 giây. 429 chờ ít nhất 60 giây và Retry-After; 401/403/404/422 không auto-retry.
- Background/dismiss hủy timer/request không cần và loại response cũ; resume chỉ một refresh chain. Detent, zoom, viewer và xoay không tạo timer mới.
- Favorites schema version + `id,name,address?,district?,addedAt`, serialize writes, rollback nếu ghi lỗi; hỏng local data không crash hoặc âm thầm xóa. Metadata revalidate tối đa 4 đồng thời, chỉ 404 đánh dấu không còn trong catalog.
- Reader key không vào UI/URL/log, không forward sang origin tùy ý. Demo bật explicit và ghi “Dữ liệu mẫu”; lỗi backend không tự chuyển demo. Không thay API backend, auth production, map/LIVE/GPS/tài khoản trong lát này.
- Android phải có bằng chứng chạy; iOS chưa đạt nếu chưa build/chạy trên macOS. Không coi widget test/HTML screenshot là nghiệm thu shader.

## Review Focus

1. Đổi query/mode/district khi trang cũ còn chạy: không trộn catalog, không mất ID mốc cuộn — test Task 2, 5.
2. Camera A trả ảnh sau khi đã mở B, background trong lúc request: không render A hoặc phát sinh timer ma — test Task 3, 6.
3. JPEG lỗi/quá cỡ và 304 khi không giữ bytes: không crash, không hiển thị blank image như thành công — test Task 5, 6.
4. Favorites ghi đồng thời/lỗi/hỏng JSON hoặc metadata 404: không mất state đã lưu, cho chủ động phục hồi — test Task 4.
5. Font lớn/màn hẹp/Android tablet/iPad multitasking: sheet không overflow, zoom không dismiss modal, viewer fit theo viewport — widget Task 3 và device Task 7.

## Cơ sở source và điều kiện thực thi

**Quan sát source/config ngày 16/10:** `app_router.dart` bắt đầu onboarding; `SessionListenerWrapper` chuyển unauthenticated về onboarding; `StateWrapper` tạo SessionBloc. `AppConfig` dùng URL fallback ngoài backend; `DioService.get()` chưa có binary/options/cancel; `runTask()` có connectivity check/toast. Localization chỉ `en`. `pubspec.yaml` chưa có glass; runner Android/iOS và lockfile chưa có trong inventory hiện tại. Shell không resolve flutter/dart/adb, chưa chứng minh SDK chưa cài. Vì vậy không giả định `flutter run` có thể chạy ngay.

Graph `TTGT-Tphcm` generation 2026-10-14T03:17:26Z chỉ 9 nodes, search các symbol starter không có kết quả; coverage các file source đọc trả `not_tracked`, không phải bằng chứng source vắng. Đã đọc trực tiếp main/app/router/config/services/wrappers/middleware/utils/theme/widget_test và backend CameraDto/query-schema; graph không có symbol để trace/snippet. Đây là plan, chưa chạy analyze/build/tests Flutter.

Package vừa đối chiếu ngày 16/10: pub.dev API/readme 1.13.0 yêu cầu Flutter ≥3.41.0. Chốt dependency `liquid_glass_widgets: 1.13.0` và commit lockfile khi thực thi; không tự nâng SDK/downgrade package chỉ để bỏ lỗi resolve. Tham khảo [package](https://pub.dev/packages/liquid_glass_widgets), [InteractiveViewer](https://api.flutter.dev/flutter/widgets/InteractiveViewer-class.html), [orientation](https://api.flutter.dev/flutter/services/SystemChrome/setPreferredOrientations.html).

Native runner: theo `mobile/SETUP.md`, nếu còn thiếu, generate platform scaffolding Android/iOS tại bước môi trường, bảo toàn Dart/assets hiện có và review diff; không chỉnh native config tùy tiện hoặc thêm quyền GPS. Android chỉ cần Internet. Không chạy regenerate toàn starter. Hiện `mobile/` và `backend/` cùng repository `D:/lovi-etown`; tạo checkpoint/commit từ repo chính theo công việc mới, giữ nguyên lịch sử kế hoạch cũ.

## Cấu trúc file và contract dùng chung

Đường dẫn dưới đây tương đối workspace root. File mới có ghi **Create** trong task; không giả định đã tồn tại. Trong các task, `C = mobile/lib/src/features/cameras`, `T = mobile/test/features/cameras`; đây là tiền tố đường dẫn chính xác để tránh lặp.

| Nhóm | File | Trách nhiệm |
|---|---|---|
| Bootstrap | `mobile/lib/main.dart`, `mobile/lib/src/app.dart`, `mobile/lib/src/config/app_config.dart`, routing và wrappers hiện có | Boot không cần auth, cấu hình/DI, localization, glass initialization |
| Theme | `mobile/lib/src/theme/camera_glass_theme.dart`, `camera_ui_tokens.dart` | Tokens/light/dark/giảm hiệu ứng, không hardcode trong feature |
| Domain | `C/domain/camera_models.dart`, `camera_repository.dart`, `favorites_repository.dart` | Types + abstract repository; presentation không import datasource |
| Data | `C/data/models/camera_dto.dart`, `repositories/{fixture_camera_repository,api_camera_repository,local_favorites_repository}.dart`, `datasources/favorites_local_store.dart` | Mapping/fixture/favorites bền |
| Transport | `mobile/lib/src/services/camera_api_client.dart` | JSON/stream binary/validation/cancel, dùng `AppConfig.dio` |
| Presentation | `C/presentation/{camera_feature.dart,screens/camera_screen.dart}`, `providers/*`, `widgets/*` | Scope DI, catalog/favorites/preview state, tiles/filter/sheet/viewer |
| Snapshot | `C/data/snapshot/{thumbnail_scheduler,snapshot_memory_cache}.dart` | Visibility/prefetch/priority/cache; không timer list |

Contract Dart đề xuất, phải dùng thống nhất giữa fixture/API/UI:

```dart
enum CameraViewMode { card, grid, list }
enum GridDensity { comfortable, compact }
// Immutable Camera: id/name/provinceId, address?/district?, snapshotCapable,
// thumbnailEndpoint?/snapshotEndpoint?, playbackEndpoint.
// CatalogPage: items, limit, offset, total, catalogVersion, fetchedAt?,
// isStale, coverage, syncState, dataMode. DistrictOption: name/count.
// PlaybackDescriptor: cameraId/kind/snapshotEndpoint/refreshIntervalMs/capturedAt?.
// SnapshotFrame: Uint8List bytes, String? etag, DateTime? fetchedAt, String dataMode.
// SnapshotReply sealed: SnapshotReceived(frame), SnapshotUnchanged().
abstract interface class CameraRepository {
  FutureEither<CatalogPage> list({String? query, String? district,
    int limit = 50, int offset = 0, CancelToken? cancelToken});
  FutureEither<List<DistrictOption>> districts({CancelToken? cancelToken});
  FutureEither<Camera> detail(String id, {CancelToken? cancelToken});
  FutureEither<PlaybackDescriptor> playback(String id, {CancelToken? cancelToken});
  FutureEither<SnapshotReply> snapshot(String endpoint,
    {String? etag, CancelToken? cancelToken});
}
abstract interface class FavoritesRepository {
  Stream<List<FavoriteCamera>> watch(); // emits current snapshot to each subscriber
  FutureEither<void> load();
  FutureEither<void> setSaved(Camera camera, bool saved);
  FutureEither<void> resetCorruptData(); // explicit user action only
}
```

Types domain ở `camera_models.dart`, `FavoriteCamera` gồm metadata schema đã nêu; `FutureEither`/`RequestState` tái dùng `utils/typedefs.dart` và `utils/async_state.dart`. CancelToken là lựa chọn coupling có chủ đích với Dio đã có, không dựng thêm abstraction cancellation cho A1. Fixture ID phải là UUID hợp lệ; JPEG local từ docs chỉ là bytes minh họa, không dùng source asset ID làm ID backend.

## Task 1: Boot vào Camera và xác nhận nền Liquid Glass

**Files:** Modify `mobile/pubspec.yaml`, `mobile/lib/main.dart`, `mobile/lib/src/{app.dart,config/app_config.dart,routing/app_router.dart,routing/app_routes.dart}`, `mobile/lib/src/shared/wrappers/{state_wrapper,session_listener_wrapper,localization_wrapper}.dart`, `mobile/test/widget_test.dart`. Create theme files ở bảng trên, `mobile/assets/translations/vi.json`, `mobile/test/app_boot_test.dart`, `mobile/.env.example`. Nếu thiếu runner: generated `mobile/android/**`, `mobile/ios/**`, ghi provenance; không sửa native bằng tay cho UI.

**Interfaces:** `CameraConnectionConfig.fromEnvironment()` tại config với `baseUrl`, `readerKey`, `demoMode`; mặc định demo false, thiếu config render lỗi kết nối rõ thay URL fallback. `CameraUiTokens` giữ touch target 48, cache/spacing không rải số trong widget. `CameraFeature` là route entry sẽ hoàn thiện ở Task 2; ở task này dùng placeholder đơn giản có glass + ảnh local để kiểm tra renderer.

Cấu hình build dùng `--dart-define=CAMERA_API_BASE_URL=...`, `CAMERA_READER_KEY`, `CAMERA_DEMO_MODE=true|false`; demo mặc định false. `CameraConnectionConfig` có constructor nhận `String baseUrl`, `String readerKey`, `bool demoMode=false` để tests inject, factory chỉ đọc defines. Không gửi key trong command/capture chia sẻ; README chỉ ghi placeholder. Placeholder Task1 dùng một JPEG local đã có provenance, Task2 chuyển sang fixture asset path chính thức.

- [ ] Locate SDK thật (`Get-Command`, FVM/settings đã có), chạy `flutter --version`, `flutter doctor -v`, `flutter devices`; ghi output. Nếu xác nhận thiếu hoặc <3.41 thì xử lý SDK trước, không giả định cài mới. Generate runner còn thiếu theo SETUP, kiểm tra Dart/assets giữ nguyên.
- [ ] Viết `boots_camera_without_session_redirect`, `missing_config_shows_connection_state`, `demo_requires_explicit_flag` trong app_boot_test. Pump đúng providers/localization; test startup không cần SessionBloc/auth. Chạy `flutter test test/app_boot_test.dart` từ `mobile`, xác nhận fail đúng behavior cũ.
- [ ] Chọn route named `camera` path `/`, app boot Camera; giữ file auth lịch sử nhưng tháo auth/session redirect khỏi A1 runtime. Remove splash sau boot success hoặc boot error, không chờ auth event. Init StorageService và xử lý failure rõ.
- [ ] Add glass 1.13.0, initialize/wrap đúng API phiên bản đã khóa; giữ Cupertino + Material token bridge. Áp dụng theme màu teal theo mockup qua tokens; hỗ trợ Vietnamese locale mặc định, dịch labels/error copy feature. `.env` thật không commit; bỏ asset `.env` bắt buộc nếu dùng build config, không để asset missing phá build.
- [ ] Chạy `flutter pub get`, `flutter analyze`, `flutter test test/app_boot_test.dart test/widget_test.dart`; PASS, mở fixture glass trên Android xác nhận shader không crash. Baseline lỗi starter ghi riêng, sửa tối thiểu liên quan boot, không tắt lint.

**Checkpoint:** boot Camera không đăng nhập và có glass thực. Gate renderer/SDK phải qua trước khi mở rộng UI; checkpoint gợi ý `feat(mobile): boot camera with liquid glass shell`.

## Task 2: Camera fixture — dropdown, modes, Quan tâm inline

**Files:** Create `C/domain/{camera_models,camera_repository,favorites_repository}.dart`, `C/data/repositories/fixture_camera_repository.dart`, `C/presentation/camera_feature.dart`, `C/presentation/screens/camera_screen.dart`, `C/presentation/providers/{camera_catalog_cubit,camera_catalog_state}.dart`, `C/presentation/widgets/{camera_filters,camera_tile,camera_feed}.dart`, `mobile/assets/fixtures/cameras.json`, `mobile/assets/fixtures/snapshots/*.jpg`, `T/camera_catalog_cubit_test.dart`, `T/camera_screen_test.dart`. Modify route placeholder and pubspec fixture assets.

**Interfaces:** `CameraCatalogCubit(CameraRepository repository)`; `start()`, `setQuery(String)`, `setDistrict(String?)`, `setViewMode(CameraViewMode)`, `setGridDensity(GridDensity)`, `loadNextPage()`, `retry()`. Immutable sealed state giữ `RequestState<CatalogPage>`/items, generation, nextOffset, viewMode/gridDensity/query/district, pagination request state riêng. UI gọi state methods, không backend trực tiếp. `CameraFeature` compose repository + Cubits qua constructor/provider.

- [ ] Tests: `stale_query_response_is_discarded`, `mode_change_keeps_filters_and_camera_anchor`, `dropdown_uses_repository_labels`, `one_character_query_skips_request`, `ready_screen_shows_thumbnail_and_inline_favorites`. Assertion query trim/350 ms, compact density không cắt tên ở width 320 và textScale 2.0. Run `flutter test test/features/cameras/camera_catalog_cubit_test.dart test/features/cameras/camera_screen_test.dart`, xác nhận red trước implementation.
- [ ] Tạo fixture ≥3 trang có UUID, nullable metadata, district rỗng, loading/error điều khiển được trong fake repository test; ảnh được embed/copy local, labels đúng fixture. UI dùng slivers/lazy builders với stable key backend ID; giữ camera mốc + vị trí trong viewport khi đổi mode, không chỉ giữ raw pixel offset.
- [ ] Implement Cubit/filters/tiles/inline section và mode; favorite ban đầu dùng in-memory implementation cùng contract Task 4. Mỗi filter/query mới reset generation/page, debounce cancel đúng; ảnh fixture không dùng network.
- [ ] Run targeted tests đến PASS; review Android light/dark, chữ Việt/font lớn, Grid 2/3 cột khi đủ chỗ, List/Card. Hiện nhãn “Dữ liệu mẫu”; không lấy count giả trong mockup.

**Checkpoint:** Camera fixture thao tác được, không route/tab thừa; `feat(mobile): add camera feed and display modes`.

## Task 3: Sheet tối giản và viewer xoay/zoom

**Files:** Create `C/presentation/providers/{camera_preview_cubit,camera_preview_state}.dart`, `C/presentation/widgets/{camera_snapshot_sheet,camera_image_viewer}.dart`, `mobile/lib/src/shared/helpers/viewer_orientation_policy.dart`, `T/camera_snapshot_sheet_test.dart`, `T/camera_image_viewer_test.dart`. Modify screen/tile và theme tokens nếu cần.

**Interfaces:** `CameraPreviewCubit(CameraRepository repository)` có `open(String id)`, `setForeground(bool)`, `retry()`, `dismiss()`; clock injection/scheduling thêm Task 6. `showCameraSnapshotSheet(BuildContext context, {required String cameraId, required CameraPreviewCubit preview, required FavoritesRepository favorites}) -> Future<void>`; `showCameraImageViewer(BuildContext context, {required CameraPreviewCubit preview}) -> Future<void>`. Provider/controller có owner rõ; viewer không tạo hoặc dispose preview.

- [ ] Tests: `sheet_has_no_refresh_fullscreen_buttons_or_time_text`, `tap_image_opens_viewer_with_same_preview`, `back_closes_viewer_before_sheet`, `zoom_does_not_dismiss_sheet`, `large_font_small_viewport_no_overflow`. Run `flutter test test/features/cameras/camera_snapshot_sheet_test.dart test/features/cameras/camera_image_viewer_test.dart`, xác nhận red.
- [ ] Implement GlassModalSheet theo API 1.13.0 đã đọc: content height, max khoảng 90%, scroll khi cần, ảnh BoxFit.contain. Header X/tên/star; focus modal + trả focus card, scrim/Back/swipe, nền không scroll lọt. Một sheet active, chọn B thay preview A không xếp chồng.
- [ ] Viewer overlay cùng Navigator/modal stack, không go_router detail route; nền tối, Close và tên, InteractiveViewer + TransformationController min1/max5; double-tap fit/2.5, pan có clamp, fit lại theo viewport khi xoay nhưng không đổi camera/state/polling. Không dùng GestureDetector pan phủ pinch hoặc swipe-down viewer khi zoom.
- [ ] A1 không khóa portrait toàn app: orientation policy mặc định OS (`[]`), viewer cho OS xoay; quản lý/restoration tập trung nếu sau này có lock. Không suy orientation hiện tại từ một lần MediaQuery để restore. Android API36 màn ≥600dp/iPad multitasking phải responsive theo OS, không ép orientation không hỗ trợ.
- [ ] Run tests đến PASS; thử Android bằng tay chạm/pinch/pan/rotate/Back hai lần, khi loading/error chỉ có retry đúng trạng thái. Screenshot light/dark dọc/ngang; không text thời gian thường trực, không sửa timestamp nằm trong JPEG.

**Checkpoint:** luồng fixture hoàn chỉnh để review Liquid Glass trước API; `feat(mobile): add snapshot sheet and zoom viewer`.

## Task 4: Lưu bền Quan tâm và đồng bộ inline

**Files:** Create `C/data/datasources/favorites_local_store.dart`, `C/data/repositories/local_favorites_repository.dart`, `C/presentation/providers/{camera_favorites_cubit,camera_favorites_state}.dart`, `C/presentation/widgets/camera_favorites_section.dart`, `T/local_favorites_repository_test.dart`, `T/camera_favorites_test.dart`. Modify CameraFeature/sheet/feed composition.

**Interfaces:** `FavoritesLocalStore({required StorageService storage})` có `FutureEither<String?> read()`, `FutureEither<void> write(String json)`, `FutureEither<void> remove()`; key `camera_favorites_v1`. `LocalFavoritesRepository` implements contract chung; `CameraFavoritesCubit` subscribe một repository cho section/star/filter, có `revalidate(CameraRepository)` và `resetCorruptData()`.

- [ ] Tests `serialized_toggles_survive_restart`, `failed_write_rolls_back_all_surfaces`, `corrupt_storage_requires_explicit_reset`, `metadata_404_retains_removable_favorite`, `metadata_network_error_keeps_last_known_name`, `revalidation_max_four`. Assert unknown schema version là lỗi phục hồi, không auto overwrite; hai toggle nhanh giữ thứ tự. Run `flutter test test/features/cameras/local_favorites_repository_test.dart test/features/cameras/camera_favorites_test.dart`, xác nhận red.
- [ ] Implement versioned JSON/serialize queue, published stream snapshot; init repository một lần ngoài build. Persist metadata/addedAt, không image bytes. UI rollback và copy lỗi tiếng Việt. Empty có CTA quay về tìm camera cùng screen; filter local hoạt động trên saved IDs, không chỉ lọc phần catalog đã tải.
- [ ] Revalidate saved ID khi mở section/filter với concurrency4; 404 đánh dấu không còn catalog nhưng cho bỏ star; lỗi khác giữ metadata. Bỏ star trong sheet cập nhật grid/section ngay, sheet không đóng.
- [ ] Run targeted tests PASS; restart Android kiểm tra Quan tâm còn, test storage failure/corrupt bằng fake, không phá dữ liệu người dùng thật.

**Checkpoint:** Quan tâm bền, không auth; `feat(mobile): persist inline camera favorites`.

## Task 5: Backend client, phân trang thật và thumbnail hữu hạn

**Files:** Create `mobile/lib/src/services/camera_api_client.dart`, `C/data/models/camera_dto.dart`, `C/data/repositories/api_camera_repository.dart`, `C/data/snapshot/{thumbnail_scheduler,snapshot_memory_cache}.dart`, `T/{camera_api_client,camera_pagination,thumbnail_scheduler}_test.dart`. Modify config, `mobile/lib/src/utils/failure.dart`, logging interceptor, CameraFeature/catalog/feed/tile, `.env.example`.

**Interfaces:** `CameraApiClient({required Dio dio, required CameraConnectionConfig config})` methods `getCatalog({String? query,String? district,int limit=50,int offset=0,CancelToken? cancelToken})`, `getDistricts({CancelToken? cancelToken})`, `getCamera(String id,{CancelToken? cancelToken})`, `getPlayback(String id,{CancelToken? cancelToken})`, `getSnapshot(String endpoint,{String? etag,CancelToken? cancelToken})`; return FutureEither domain types như repository. `ApiCameraRepository` delegates/mapping, không giấu raw Dio errors trong widget.

`SnapshotMemoryCache({int maxBytes=8*1024*1024,int maxEntries=32})` LRU chứa frame keyed ID+endpoint; `ThumbnailScheduler` nhận `updateWindow({required Set<String> visible, required Set<String> prefetch})`, `setForeground(bool)`, `setPreviewCamera(String?)`, `dispose()`. Expose frame/request state per ID; visible prioritized, prefetch một hàng; preview lấy ưu tiên và không fetch list trùng active camera. Tối đa4 thumbnail request, frame preview pinned ngoài budget thumbnail; decoded thumbnails dùng kích thước tile×DPR capped640, không decode tất cả fullres.

- [ ] Tests API: exact params/UUID/nullability/relative endpoint, reader header đúng origin, reject absolute/cross-origin/redirect trước khi gửi key, malformed JSON/error mapping, 200 image/304, non-image/decode invalid/stream vượt2MiB bị cancel, thiếu config không request. Extend `Failure` trong cùng file sealed library với `ApiFailure(statusCode,code,retryable,retryAfter?,requestId?)` và `CancelledFailure`; message an toàn tiếng Việt, không raw exception/key vào logs.
- [ ] Tests paging: A chậm/B nhanh, concurrent loadNext một request, duplicate IDs nhưng offset tăng theo raw count, total/trang rỗng dừng, offset cap10000, version change restart trang0 không trộn items, lỗi trang sau giữ items+retry. Tests thumbnails:4 concurrent, offscreen/background cancel, mode change giữ ID ảnh, LRU bytes/entry cap, active preview không bị list request cạnh tranh. Run `flutter test test/features/cameras/camera_api_client_test.dart test/features/cameras/camera_pagination_test.dart test/features/cameras/thumbnail_scheduler_test.dart` và xác nhận red.
- [ ] Implement client trên shared `AppConfig.dio`, request-level timeout15s/safe status200/304; stream bounded accumulation ≤2MiB + validate ảnh trước cache. No redirects carrying key; endpoint phải relative path thuộc backend origin. Không dùng Image.network/cached_network_image fetch URL descriptor riêng bypass guard hoặc disk-cache ảnh.
- [ ] Không tái sử dụng `DioService.get()` nguyên trạng cho binary/cancel; CameraApiClient là service tại thư mục services theo starter. Dùng `runTask` với API failures đã sanitize, không connectivity preflight/toast cho mỗi snapshot; giữ status/retry headers trước mapping, cancelled không báo lỗi người dùng. Không log DioException/raw response chứa credentials; test fake reader marker không xuất hiện trong logs.
- [ ] Wire backend mode explicit, fixture chỉ demo; JSON endpoint như spec, related chưa gọi vì quick sheet không có related. Infinite-scroll trigger khi extentAfter<600 logical px; footer loading/retry/end, prefill nếu trang đầu chưa đủ viewport. Nếu catalog partial/stale hiện badge phù hợp, count “Đã tải N camera”. District rỗng ẩn dropdown; danh mục cập nhật clear ảnh/cache không còn hợp lệ.
- [ ] Run targeted tests PASS + `flutter analyze`; tích hợp backend fixture qua Android host đúng cấu hình (`10.0.2.2` cho emulator khi cần), không dùng URL fallback starter. Lỗi thật không đổi sang demo.

**Checkpoint:** Camera nối backend và thumbnail/infinite scroll hữu hạn; `feat(mobile): connect camera catalog and bounded snapshots`.

## Task 6: Preview polling, ETag và lifecycle

**Files:** Modify preview Cubit/state, CameraFeature, sheet/viewer và scheduler. Create `C/domain/preview_clock.dart`, `T/camera_preview_cubit_test.dart`.

**Interfaces:** `PreviewClock` có `DateTime now()` và `Timer schedule(Duration delay, void Function() callback)` để fake clock trong test. `CameraPreviewCubit` constructor nhận repository + clock + thumbnail cache; methods Task 3 giữ nguyên. `PreviewState` immutable chứa cameraId/camera/descriptor/frame/request state/isStale/foreground; timer/cancel token/generation là private, không trong widget build.

- [ ] Tests bằng fake clock/Completer: `one_request_in_flight`, `late_A_never_replaces_B`, `304_keeps_frame_and_fetchedAt`, `304_without_bytes_recovers_unconditionally_once`, `refresh_error_keeps_frame`, `invalid_image_does_not_replace_good_frame`, `dismiss_background_cancel_and_ignore_completion`, `resume_has_single_chain`, `viewer_rotation_detents_do_not_duplicate_polling`, `retry_policy_respects_status_and_retry_after`. Assert 3s floor/12s fallback/15s timeout/backoff12,24,48,60;429 max(60s,Retry-After);401/403/404/422 stop. Run `flutter test test/features/cameras/camera_preview_cubit_test.dart`, xác nhận red.
- [ ] Implement open detail→playback→snapshot; seed last valid frame cùng ID nếu có nhưng không gán bytes A sang B. ETag chỉ gửi nếu giữ bytes;304 không bytes thực hiện một fetch không ETag, vẫn304 thì báo lỗi protocol, không loop. Refresh next sau request hoàn tất, không periodic timer chồng nhau.
- [ ] Gắn WidgetsBindingObserver foreground đúng scope, detach khi dispose; dismiss stop/cancel+generation. Fullscreen không own controller; close viewer không stop sheet đang xem. Khi app background dừng thumbnail và preview; resume sheet mở refresh ngay một lần.
- [ ] Giữ last good frame khi refresh/decode lỗi; stale>60s là trạng thái ảnh cũ, không thêm text timestamp; unsupported/404/auth có copy/CTA đúng, không tuyên bố camera offline hoặc LIVE. Request cancel không vào retry backoff.
- [ ] Run tests PASS; verify trên Android với transport fixture có request log redacted: đóng/background không request mới, viewer/rotation không thêm chain, mở B không lóe A.

**Checkpoint:** preview lifecycle/ETag xác minh được; `feat(mobile): enforce snapshot refresh lifecycle`.

## Task 7: Nghiệm thu thiết bị và hướng dẫn chạy

**Files:** Create `mobile/integration_test/camera_flow_test.dart`, `mobile/test/support/camera_fakes.dart`, `docs/ui/mobile-a1-verification.md`; Modify pubspec (`integration_test` SDK), `mobile/README.md`, `mobile/DESIGN.md`. Evidence mới: `evidence/mobile-a1/2026-10-16/` hoặc ngày chạy thực tế, không sửa evidence gốc.

**Interfaces:** app boot inject repositories/config qua constructor test, integration demo không gọi source thật. Test end-to-end trên Android, còn iOS chạy cùng flow khi có macOS.

- [ ] Integration fixture: list/dropdown/search→Grid/Card/List→save star→sheet→viewer zoom→rotate→Back→same filter/anchor, restart favorites; infinite/error/empty/partial catalog. Không viết golden pixel test bắt chước HTML; kiểm tra hành vi và screenshot review riêng.
- [ ] Chạy từ `mobile`: `dart format --output=none --set-exit-if-changed lib test integration_test`, `flutter analyze`, `flutter test`, `flutter test integration_test/camera_flow_test.dart -d <android-device-id>`, `flutter build apk --debug`. Ghi command/output/device/SDK/package lock; PASS mới đánh dấu tương ứng. Không chạy vòng test lặp nếu chưa có thay đổi/failure.
- [ ] Device review 320/390px, font scale2, dark/light, TalkBack focus/labels, modal focus trap, reduced motion/contrast, fast scroll/rotate/background; glass khúc xạ nhìn được mà chữ rõ, không shader exception. Profile scroll và preview active: ghi frame timing/memory/device; budget mục tiêu frame ≤16.7ms ở60Hz, không RAM tăng liên tục qua20 lần open/close, giảm quality nếu đo cho thấy cần.
- [ ] Smoke một camera UUID thật đang có trong catalog backend đã cấu hình: catalog→descriptor→ảnh200/304→dismiss; giữ reader key private, không tự sync/import toàn TP.HCM. Fixture/real log tách rõ; API có mặt không đồng nghĩa auth production đã giải quyết.
- [ ] Trên macOS: `flutter build ios --simulator`, chạy cùng flow iPhone dọc/ngang và iPad viewport nếu có. Thiếu macOS thì ghi **chưa xác minh iOS**, không chặn kết luận Android đạt và không tuyên bố A1 hai nền tảng đã hoàn tất.
- [ ] Cập nhật verification với screenshot, request lifecycle, lỗi chưa khép và checklist spec1–12. Review diff không source APK/secret/native thay đổi ngoài scaffolding cần thiết; checkpoint `test(mobile): verify camera A1 flow` nếu repo hợp lệ.

## Thứ tự và điểm review

Task1 → Task2 → Task3 → **review UI Flutter/renderer thực** → Task4 → Task5 → Task6 → Task7. UI fixture dùng đúng contract ngay từ đầu; không dựng UI HTML khác rồi rewrite thành Flutter. Chỉ hoàn tất task khi targeted checks của task có bằng chứng.

Đề xuất thực thi **trực tiếp, tuần tự trong phiên này** bằng `executing-plans`: các task dùng chung Cubit/repository/widget interfaces, thuận tiện giữ ngữ cảnh và review UI trước API. Nếu người dùng chọn nhiều agent, phải có ownership file cụ thể và không cho cùng sửa bootstrap/feature composition; lượt lập plan này không dispatch agent.

## Self-review của plan

- Phạm vi spec: navigation/modes/dropdown/thumbnails/infinite Task2,3,5; favorites Task4; API/config/security Task1,5; preview lifecycle/ETag Task6; device/iOS/accessibility Task7. Các Review Focus đều có test owner.
- Contract fixture/API dùng cùng types và methods; preview controller không do viewer sở hữu; `async_state.dart` là file thật của RequestState, không tạo nhầm `core/request_state.dart`. `ApiFailure` mở rộng đúng file sealed `Failure`.
- Không thiếu feedback mới: bỏ2nút/texttime, ảnh tap viewer, landscape/pinch/pan; không thêm page Quan tâm/chi tiết. Native/platform tạo mới là prerequisite đã ghi, không suy SDK/native runner có sẵn.
- Giới hạn còn lại là verification runtime và review của người dùng; tài liệu này không chứng nhận mobile build, iOS hoặc shader đã pass. Không có product code/dependency nào được sửa trong lượt tạo plan.
