# Đặc tả Kỹ thuật — Tích hợp Google Maps & Lớp Giao thông Kẹt xe (Traffic Layer) vào Chi tiết Camera (T18)

Trạng thái: **ĐỀ XUẤT (Chờ duyệt)** — Biên soạn ngày 2026-10-24 dựa trên phát hiện reverse-engineering ứng dụng VietDi v5.4.6 (`com.freevn.trafficfines`) và nhu cầu người dùng Lovi Etown.

---

## 1. Bối cảnh & Bằng chứng Kỹ thuật

1. **Phát hiện từ dịch ngược VietDi v5.4.6:**
   - Ứng dụng VietDi hiển thị dải màu lưu lượng giao thông (xanh lá = thông thoáng, cam = đông chậm, đỏ/đỏ sẫm = ùn tắc) hoàn toàn đồng nhất với Google Maps.
   - Cơ chế kỹ thuật: Sử dụng gói `google_maps_flutter` và kích hoạt thuộc tính bản địa `trafficEnabled: true` trên `GoogleMap` widget.
   - Nguồn dữ liệu: **100% Google Maps Platform**, thiết bị kết nối trực tiếp đến máy chủ Google qua Google Maps SDK for Android / iOS; backend app không cần xử lý hay lưu trữ dữ liệu vạch màu giao thông.
   - Chi phí & Pháp lý: Google Maps Platform áp dụng chính sách **Miễn phí không giới hạn (Unlimited Free Mobile Map Loads)** cho Dynamic Maps trên Android & iOS SDK; tính năng Traffic Layer đi kèm hoàn toàn miễn phí. Cần sử dụng API Key chính chủ đăng ký trên Google Cloud Project cá nhân/tổ chức (có khóa theo Android Package Name + SHA-1 certificate fingerprint), không sử dụng lại API Key của bên thứ ba.
2. **Hiện trạng Lovi Etown (`mobile/`):**
   - Đã có dữ liệu vị trí: Model [Camera](file:///Users/admin/Sources/lovi-etown/mobile/lib/src/features/cameras/domain/camera_models.dart#L20-L21) có sẵn `latitude`, `longitude` và getter `hasLocation`.
   - Đã có nút "Chỉ đường" (ticket T10): Mở Google Maps app ngoài bằng deep link qua `url_launcher`.
   - Đã có thẻ "Traffic Brief" (ticket T17): Liệt kê các camera lân cận trong cùng khu vực/quận.
   - **Khoảng trống UX hiện tại:** Người dùng xem ảnh camera tĩnh/live nhưng không thấy được trực quan bức tranh giao thông xung quanh ngã tư/tuyến đường đó (ví dụ: camera chỉ soi một góc ngã tư, không thấy được nhánh rẽ bên kia có đang kẹt cứng hay không).

---

## 2. Nguyên tắc Thiết kế

1. **Bổ trợ không xâm lấn:** Khung bản đồ giao thông đóng vai trò thông tin ngữ cảnh mở rộng, không làm xáo trộn luồng xem ảnh snapshot 12s hoặc live player HLS hiện có.
2. **Thiết kế chuẩn Liquid Glass:** Tuân thủ triệt để hệ thống token `CameraUiTokens`, bo góc `LiquidRoundedSuperellipse` và `AdaptiveGlass` ăn khớp với giao diện tổng thể của Lovi Etown.
3. **An toàn kiểm thử (Zero Regression):** Tích hợp `google_maps_flutter` không được làm hỏng hoặc gián đoạn 134 test cases hiện có trên `flutter test`. Sử dụng abstraction/factory để mockable trên môi trường headless runner.
4. **Bảo toàn tài nguyên & Vòng đời:** Chỉ tải và hiển thị bản đồ khi mở chi tiết camera; tự động giải phóng bộ nhớ khi đóng bottom sheet hoặc khi app chuyển sang chế độ nền (background).

---

## 3. Các Quyết định Thiết kế Đề xuất

### D18.1 — Thẻ bản đồ giao thông mini trong `CameraSnapshotSheet`
- **Vị trí:** Đặt ngay dưới khu vực Media (ảnh snapshot / live player) và trên nút "Chỉ đường" (T10).
- **Điều kiện hiển thị:** Chỉ render khi `camera.hasLocation == true`. Khi camera chưa có tọa độ, hiển thị thẻ thông báo nhẹ hoặc ẩn mượt mà, không gây vỡ layout.
- **Kích thước & Trực quan:**
  - Chiều cao: 200 dp.
  - Tâm bản đồ (Center): `LatLng(camera.latitude!, camera.longitude!)`.
  - Mức thu phóng (Zoom level): `15.5` – đủ quan sát các nhánh đường và giao lộ trong bán kính ~500m quanh camera.
  - Marker: Một custom marker ghim đúng tọa độ camera, màu ngọc bích `CameraUiTokens.primaryTeal`.

### D18.2 — Lớp giao thông kẹt xe thời gian thực (`trafficEnabled`)
- Mặc định: `trafficEnabled = true` khi bản đồ khởi tạo.
- Bổ sung nút toggle dạng icon kính mờ nhỏ gọn ở góc bản đồ để người dùng có thể tắt/bật lớp màu kẹt xe tùy ý (tiện khi cần nhìn rõ tên đường hoặc vệ tinh).
- Lưu trạng thái bật/tắt vào `SharedPreferences` (`camera_traffic_layer_enabled`) để ghi nhớ cho các lần mở tiếp theo.

### D18.3 — Xem bản đồ toàn màn hình (`CameraTrafficMapViewerScreen`)
- Trên góc thẻ bản đồ mini có nút "Mở rộng" (Fullscreen button).
- Khi chạm, điều hướng hoặc mở modal toàn màn hình:
  - Bản đồ Google Maps toàn màn hình có đầy đủ lớp màu giao thông.
  - Nút "Về vị trí camera" (Recenter to camera).
  - Nút "Vị trí của tôi" (My location) nếu người dùng đã cấp quyền GPS.
  - Header kính mờ hiển thị tên camera, quận và nút đóng (X).

### D18.4 — Quản lý Khóa API Google Maps
- **Android:** Khai báo `<meta-data android:name="com.google.android.geo.API_KEY" android:value="${GOOGLE_MAPS_API_KEY}"/>` trong `AndroidManifest.xml`.
- **iOS:** Cung cấp khóa qua `GMSServices.provideAPIKey(...)` trong `AppDelegate.swift`.
- **Biến môi trường:** Đọc từ file `.env` qua `flutter_dotenv` hoặc fallback mock key trong môi trường test/dev nội bộ.

---

## 4. Tiêu chí Nghiệm thu (Acceptance Criteria)

- [ ] **AC-1 (Hiển thị đúng tọa độ):** Mở camera có tọa độ (ví dụ: ngã tư Hàng Xanh `10.8018, 106.7114`), bản đồ mini hiển thị đúng vị trí tâm và có marker ghim vị trí camera.
- [ ] **AC-2 (Vạch màu kẹt xe):** Lớp giao thông hiển thị rõ các dải màu xanh/vàng/đỏ trên các trục đường chính quanh camera.
- [ ] **AC-3 (Camera không tọa độ):** Mở camera có `latitude = null` hoặc `longitude = null`, app không crash, không xuất hiện màn hình đỏ; thẻ bản đồ ẩn nhẹ nhàng.
- [ ] **AC-4 (Toggle Traffic):** Bấm nút bật/tắt trên bản đồ, các dải màu giao thông ẩn/hiện tức thì và lưu trạng thái thành công.
- [ ] **AC-5 (Xem toàn màn hình):** Bấm nút phóng to, mở ra màn hình bản đồ toàn màn hình mượt mà, zoom/pan tương tác tốt.
- [ ] **AC-6 (Kiểm thử tự động):** `flutter test` trong `mobile/` đạt 100% PASS (bao gồm các test cases mới và 134 test cũ).
