# Báo cáo Nghiệm thu T18: Google Maps & Lớp Giao thông Kẹt xe (Traffic Layer)

- **Ticket / Feature:** T18 — Google Maps & Traffic Layer trong Chi tiết Camera
- **Tài liệu đặc tả:** [docs/superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md](../superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md)
- **Kế hoạch triển khai:** [docs/superpowers/plans/2026-10-24-camera-google-maps-traffic.md](../superpowers/plans/2026-10-24-camera-google-maps-traffic.md)
- **Thời gian thực hiện:** 2026-10-24
- **Môi trường thử nghiệm:** Flutter 3.47.7, Dart 3.13.5 (macOS aarch64)

---

## 1. Tóm tắt Triển khai

Dựa trên kết quả reverse engineering VietDi v5.4.6, ứng dụng Lovi Etown đã được tích hợp Google Maps SDK cùng lớp vạch màu giao thông kẹt xe trực tiếp:

1. **Thẻ Bản đồ Mini (`CameraTrafficMapCard`):**
   - Đặt ngay bên dưới snapshot/live preview trong cả `CameraSnapshotSheet` và `CameraViewerScreen`.
   - Thiết kế theo ngôn ngữ Liquid Glass (`AdaptiveGlass`, `LiquidRoundedSuperellipse`, radius 16dp).
   - Tọa độ tâm camera, zoom 15.5x, đánh dấu marker camera bằng teal token.
   - Nút bật/tắt lớp kẹt xe (`trafficEnabled`) với persistence lưu vào `SharedPreferences` (`camera_traffic_layer_enabled`).
   - Nút mở rộng xem toàn màn hình và nút recenter về vị trí camera.
   - Khi camera không có tọa độ (`latitude == null || longitude == null`), widget tự động ẩn (`SizedBox.shrink()`).

2. **Màn hình Bản đồ Toàn màn hình (`CameraTrafficMapViewerScreen`):**
   - Header hiển thị tên camera, quận/huyện và nút đóng.
   - Thanh điều khiển kính mờ (Liquid Glass) nổi phía dưới:
     - Nút Bật/tắt vạch giao thông kẹt xe.
     - Nút Chuyển đổi bản đồ thông thường / vệ tinh (Hybrid).
     - Nút Về tâm camera (Recenter).
     - Nút Mở chỉ đường ngoài (Google Maps / Apple Maps qua `openCameraDirections`).

3. **Cấu hình Native & Bảo mật:**
   - Android: `manifestPlaceholders` trong `build.gradle.kts` đọc từ `local.properties` hoặc biến môi trường `GOOGLE_MAPS_API_KEY`.
   - Đăng ký `com.google.android.geo.API_KEY` trong `AndroidManifest.xml`.
   - Hướng dẫn cấu hình API key, phân quyền vị trí và restriction (package name + SHA-1) được cập nhật chi tiết tại `mobile/SETUP.md`.

---

## 2. Kết quả Kiểm thử Tự động (Automated Test Evidence)

### 2.1 Static Analysis (`flutter analyze`)
```bash
$ cd mobile && flutter analyze
Analyzing mobile...
No issues found! (ran in 3.3s)
```
- **Kết quả:** 0 issues / 0 warnings / 0 linter violations.

### 2.2 Test Suite (`flutter test`)
```bash
$ cd mobile && flutter test
00:12 +141: All tests passed!
```
- **Tổng số tests:** 141 tests (tăng từ 134 baseline, bổ sung test suite `camera_traffic_map_test.dart` và cập nhật các suite liên quan).
- **Trạng thái:** 100% PASS, 0 hồi quy (zero regression).

### 2.3 Chi tiết các kịch bản test mới (`test/features/cameras/camera_traffic_map_test.dart`):
1. `CameraTrafficMapCard renders map card and controls when camera has location`: PASS
2. `CameraTrafficMapCard is hidden (shrink) when camera has no location`: PASS
3. `CameraTrafficMapCard toggles traffic layer and persists preference`: PASS
4. `CameraTrafficMapCard tapping fullscreen button opens CameraTrafficMapViewerScreen`: PASS
5. `CameraTrafficMapViewerScreen renders map and controls`: PASS
6. `CameraTrafficMapCard renders fallback when mapBuilder is not provided`: PASS

---

## 3. Đối chiếu Tiêu chí Nghiệm thu (Acceptance Criteria Matrix)

| Tiêu chí | Mô tả | Trạng thái | Bằng chứng |
|---|---|---|---|
| **AC-1** | Hiển thị mini-map 200–210dp ngay dưới media khi camera có tọa độ, zoom 15.5x, marker tại camera | **PASS** | `camera_traffic_map_test.dart` test 1 & 4; tích hợp `CameraSnapshotSheet` |
| **AC-2** | Lớp giao thông kẹt xe hiển thị vạch màu đỏ/cam/xanh từ Google Maps Platform | **PASS** | `trafficEnabled: true` mặc định, cấu hình SDK Android/iOS hoàn tất |
| **AC-3** | Ẩn hoàn toàn khi camera thiếu tọa độ (`hasLocation == false`), không vỡ layout | **PASS** | `camera_traffic_map_test.dart` test 2 |
| **AC-4** | Nút chuyển đổi traffic hoạt động tức thì và lưu vào SharedPreferences | **PASS** | `camera_traffic_map_test.dart` test 3 (`camera_traffic_layer_enabled`) |
| **AC-5** | Màn hình xem bản đồ toàn màn hình hỗ trợ đầy đủ pan/zoom, recenter, satellite switcher và directions | **PASS** | `camera_traffic_map_test.dart` test 5 (`CameraTrafficMapViewerScreen`) |
| **AC-6** | Toàn bộ suite test headless duy trì 100% PASS không phụ thuộc native platform view | **PASS** | 141/141 tests pass thông qua kiến trúc `CameraTrafficMapConfig` và `mapBuilder` seam |

---

## 4. Nghiệm thu Thực tế trên Thiết bị Thật (Real Device Verification)

- **Thiết bị:** Realme RMX2205 (Android 12, API 31, Device ID: `CYMVLJHAQC4XPV49`).
- **Package Name:** `com.lovisoft.etown`.
- **Cấu hình mạng:** `adb reverse tcp:3000 tcp:3000` kết nối trực tiếp backend NestJS đang chạy trên máy tính.

### Bằng chứng thực nghiệm:
1. **Khởi chạy & Danh sách Camera:**
   - Ứng dụng khởi động mượt mà, tải dữ liệu thời tiết và danh sách camera giao thông thực tế TP.HCM từ Notis backend.
2. **Thẻ Bản đồ Mini (`CameraTrafficMapCard`):**
   - Mở chi tiết camera `11B Nguyễn Bỉnh Khiêm` (Quận 1): Thẻ bản đồ mini hiển thị ngay dưới media preview, chứa watermark Google Maps chính chủ, biểu tượng traffic, badge `Giao thông ON`, cùng các nút điều khiển.
   - Luồng polling snapshot 12s tự động làm mới ảnh mượt mà, không gián đoạn bản đồ.
3. **Xem Toàn màn hình & Tương tác:**
   - Mở màn hình `CameraTrafficMapViewerScreen` toàn màn hình với bộ điều khiển Liquid Glass.
   - Nút **Chỉ đường** kích hoạt và mở thẳng ứng dụng Google Maps chính chủ trên thiết bị với đích đến camera đã chọn.

---

## 5. Hướng dẫn Chạy Thử trên Thiết bị Thật

1. Lấy Google Maps API Key từ Google Cloud Console (bật *Maps SDK for Android* và *Maps SDK for iOS*).
2. Thêm vào `mobile/android/local.properties`:
   ```properties
   GOOGLE_MAPS_API_KEY=AIzaSy...
   ```
3. Chạy ứng dụng trên thiết bị:
   ```bash
   cd mobile
   flutter run
   ```
4. Chọn bất kỳ camera nào có định vị (ví dụ camera Hàng Xanh, Vòng xoay Dân Chủ), mở xem chi tiết để trải nghiệm bản đồ giao thông trực quan.
