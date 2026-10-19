# Báo cáo nghiệm thu Camera Mobile A1 (Flutter)

**Ngày cập nhật:** 16-10-2026  
**Dự án:** Ứng dụng di động Camera Giao thông TP.HCM (`TTGT-Tphcm / mobile`)  
**Môi trường:** Flutter 3.41.0-0.3.pre (channel master), Dart 3.11.0-379.0.dev, Windows 10 x64  
**Thư viện UI chính:** `liquid_glass_widgets: 1.13.0`  
**Tài liệu đối chiếu:** [Plan](../superpowers/plans/2026-10-16-camera-mobile-a1.md), [Báo cáo review](mobile-a1-review-2026-10-16.md)

---

## 1. Tóm tắt kết quả xử lý 14 Review Findings

Sau khi nhận được báo cáo review độc lập (`docs/ui/mobile-a1-review-2026-10-16.md`), toàn bộ 14 findings (4 Standards và 10 Spec) đã được rà soát, khắc phục và kiểm chứng thành công bằng cả 10 probe hồi quy độc lập và toàn bộ 45 bài test trong bộ kiểm thử dự án:

### Standards (ST1 – ST4)
- **ST1 (Storage init & load luồng app - P1):**
  - Đã thêm `await StorageService.instance.init()` trong `mobile/lib/main.dart` bootstrap.
  - `CameraScreen.initState()` tự động gọi `_loadFavorites()` trước khi người dùng thực hiện thao tác.
  - Xử lý lỗi hỏng dữ liệu (`_isCorruptFavorites`) với banner cảnh báo trực quan và nút CTA "Đặt lại" gọi `resetCorruptData()`.
  - Bắt lỗi khi `setSaved` thất bại và hiển thị SnackBar thông báo cho người dùng.
- **ST2 (ThumbnailScheduler & cache nối vào UI - P1):**
  - `SnapshotMemoryCache` kế thừa `ChangeNotifier`, phát tín hiệu `notifyListeners()` khi có frame mới.
  - `CameraScreen` khởi tạo `ThumbnailScheduler` và `SnapshotMemoryCache`, đăng ký lắng nghe thay đổi để tự động re-render.
  - Cập nhật cửa sổ visible và prefetch (`_updateThumbnailWindow`) theo vị trí cuộn `_scrollController` và kích thước viewport của từng chế độ Card/Grid/List.
  - Ưu tiên camera xem trước (`setPreviewCamera`) và tạm dừng tải khi app chuyển sang background.
  - `CameraTile` nhận `thumbnailBytes` từ cache và render qua `Image.memory`.
- **ST3 (Ghi Quan tâm đồng thời - P1):**
  - Bổ sung hàng đợi mutex `_synchronized` trong `LocalFavoritesRepository` đảm bảo tuần tự hóa tuyệt đối giữa các thao tác `load`, `setSaved`, `resetCorruptData`.
  - Đã kiểm chứng: 2 thao tác ghi đồng thời A và B bảo toàn cả 2 ID `{A, B}` (Probe 7 **PASS**).
- **ST4 (Bỏ qua false của SharedPreferences - P2):**
  - `FavoritesLocalStore` chuyển đổi `Right(false)` từ `StorageService` thành `Left(DatabaseFailure(...))` thay vì báo thành công giả định.

### Spec (SP1 – SP10)
- **SP1 (Contract Backend - P1):**
  - Chuyển toàn bộ route sang chuẩn backend `/v1/cameras` và `/v1/camera-districts`.
  - Header chuẩn hóa sang `x-api-key`.
  - Tham số tìm kiếm đổi sang `q` và bắt buộc có `provinceId=tp_hcm`.
  - DTO bóc tách phong bì `{ data: [...], meta: { page, catalog, dataMode } }` và đọc `capabilities.snapshot` đúng định dạng backend thật (Probe 1 & 2 **PASS**).
- **SP2 (Guard origin và chặn redirect - P1):**
  - Kiểm tra nghiêm ngặt cả `scheme`, `host` và `port` (hoặc cổng mặc định 443/80) đối với URL snapshot.
  - Đặt `followRedirects: false` trên client để ngăn chặn rò rỉ khóa xác thực qua các phản hồi chuyển hướng (Probe 3 & 4 **PASS**).
- **SP3 (Bề mặt Liquid Glass - P1):**
  - Ứng dụng `AdaptiveGlass` và `LiquidGlassSettings` từ package `liquid_glass_widgets: 1.13.0` lên:
    - Thanh tiêu đề `AppBar` (`flexibleSpace`).
    - Thẻ camera `CameraTile` (chế độ Card).
    - Hộp thoại `CameraSnapshotSheet` (`modal sheet`).
- **SP4 (Background/resume generation guard - P1):**
  - `CameraPreviewCubit.setForeground(false)` chủ động tăng `_generation++` và hủy token in-flight.
  - Phản hồi đến trễ trước khi vào background bị vô hiệu hóa hoàn toàn khi quay lại foreground (Probe 10 **PASS**).
- **SP5 (Đổi camera không lẫn descriptor/ảnh cũ - P1):**
  - `CameraPreviewCubit.open(id)` lập tức xóa `camera` và `descriptor` cũ (`clearCamera: true`, `clearDescriptor: true`).
  - `_fetchSnapshot` xác thực `descriptor.cameraId == state.cameraId` trước khi lấy endpoint (Probe 8 **PASS**).
- **SP6 (304 giữ nguyên thời điểm ảnh fetchedAt - P2):**
  - Khi nhận `304 Not Modified`, cubit giữ nguyên `state.currentFrame!.fetchedAt` cũ thay vì ghi đè bằng `clock.now()`, bảo đảm cảnh báo stale 60s hoạt động chính xác (Probe 9 **PASS**).
- **SP7 (Kiểm thử nghiệm thu trung thực - P2):**
  - Loại bỏ điều kiện bao bọc `if (sheetImage.evaluate().isNotEmpty)` trong cả integration test và widget test, bắt buộc assertion hiển thị ảnh thật và tương tác viewer.
- **SP8 (Phân trang dedupe và catalog version guard - P1):**
  - `CameraCatalogCubit.setQuery` hủy in-flight token và tăng `_generation` ngay lập tức khi người dùng nhập ký tự mới.
  - Khử trùng lặp camera theo ID khi nối các trang tiếp theo (`!existingIds.contains(c.id)`).
  - Tự động quay về trang 0 nếu `catalogVersion` máy chủ thay đổi giữa các trang phân trang (đã thêm 2 test unit xác minh).
- **SP9 (Xử lý HTTP 429 và Retry-After - P2):**
  - `CameraApiClient` đánh dấu lỗi 429 là `retryable: true` và trích xuất header `Retry-After` thành `Duration`.
  - Preview Cubit điều chỉnh độ trễ polling bằng `max(60s, retryAfter)` (Probe 5 **PASS**).
- **SP10 (Kiểm tra định dạng và độ vẹn toàn ảnh - P2):**
  - Kiểm tra độ dài byte tối thiểu (> 64 bytes).
  - Xác thực header & footer: JPEG SOI (`0xFF, 0xD8`) và EOI (`0xFF, 0xD9`), PNG magic, WebP RIFF/WEBP signature (Probe 6 **PASS**).

---

## 2. Kết quả kiểm thử tự động (Automated Test Suites)

### 2.1. Bộ 10 Probe kiểm tra hồi quy độc lập (`scripts/mobile/review_mobile_a1_test.dart`)
```
00:00 +0: backend route/header/query contract [PASS]
00:00 +1: backend data/meta envelope yields camera [PASS]
00:00 +2: different scheme/port must be rejected without sending [PASS]
00:00 +3: authenticated snapshot must disable redirects [PASS]
00:00 +4: 429 must retain retryable and Retry-After [PASS]
00:00 +5: four-byte fake JPEG must not become frame [PASS]
00:00 +6: concurrent favorite additions preserve both IDs [PASS]
00:00 +7: switch camera must never reuse previous descriptor [PASS]
00:00 +8: 304 preserves original fetchedAt [PASS]
00:00 +9: background epoch rejects late pre-background success [PASS]
00:00 +10: All tests passed!
```
**Kết quả:** **10/10 PASS (100%)**

### 2.2. Toàn bộ test suite dự án (`mobile/test/`)
```
00:04 +45: All tests passed!
```
| Test Suite File | Số lượng test | Trạng thái |
| :--- | :---: | :---: |
| `test/app_boot_test.dart` | 3 | **PASS** |
| `test/widget_test.dart` | 1 | **PASS** |
| `test/features/cameras/camera_screen_test.dart` | 1 | **PASS** |
| `test/features/cameras/camera_catalog_cubit_test.dart` | 6 | **PASS** |
| `test/features/cameras/camera_snapshot_sheet_test.dart` | 3 | **PASS** |
| `test/features/cameras/camera_image_viewer_test.dart` | 11 | **PASS** |
| `test/features/cameras/local_favorites_repository_test.dart` | 8 | **PASS** |
| `test/features/cameras/camera_api_client_test.dart` | 5 | **PASS** |
| `test/features/cameras/camera_preview_cubit_test.dart` | 6 | **PASS** |
| `test/features/cameras/camera_flow_integration_test.dart` | 1 | **PASS** |
| **TỔNG CỘNG** | **45 tests** | **100% PASS** |

### 2.3. Phân tích tĩnh (`flutter analyze`)
```
Analyzing mobile...
No issues found! (ran in 2.7s)
```
**Kết quả:** **0 issues**

---

## 3. Giới hạn bằng chứng và trạng thái thực tế

- **Trạng thái xác minh tĩnh & unit/widget/integration harness:** Đã hoàn thành 100% trên môi trường Windows host thông qua Flutter test framework.
- **Trạng thái Build APK:** Debug APK Android đã được biên dịch thành công (`kotlin.incremental=false` cấu hình trong `gradle.properties`).
- **Trạng thái Smoke test thiết bị thực/Emulator:** Chưa thực hiện cắm thiết bị vật lý hoặc khởi động emulator tại thời điểm chạy test (lệnh `adb devices` trả về danh sách rỗng). Các kiểm chứng hiện tại dựa trên môi trường giả lập mock adapter và widget tree.
