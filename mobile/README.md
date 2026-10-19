# Ứng dụng Di Động Camera Giao Thông TP.HCM (Mobile A1)

Ứng dụng Flutter di động giám sát camera giao thông thời gian thực trên địa bàn Thành phố Hồ Chí Minh, xây dựng với giao diện **Liquid Glass (Kính lỏng)** trong suốt, mượt mà và hiện đại.

---

## Tính năng nổi bật

- **Kiến trúc màn hình đơn (Single Screen):** Trải nghiệm tập trung và liền mạch, không chia nhỏ trang chi tiết hay thanh điều hướng rườm rà.
- **Hiệu ứng Liquid Glass:** Áp dụng `liquid_glass_widgets` cho thanh tìm kiếm, bộ lọc quận/huyện, các thẻ camera và bottom sheet.
- **3 Chế độ hiển thị:**
  - **Thẻ (Card):** Ảnh camera kích thước lớn, dễ quan sát nhanh tình trạng giao thông.
  - **Lưới (Grid):** Hiển thị 2 hoặc 3 cột tùy thuộc độ rộng màn hình thiết bị.
  - **Danh sách (List):** Gọn gàng kèm thumbnail thu nhỏ tối ưu không gian duyệt.
- **Mục "Quan tâm" tích hợp inline:** Lưu danh sách camera yêu thích bền vững trong bộ nhớ cục bộ, hỗ trợ lọc và xem nhanh mà không cần tạo tài khoản.
- **Snapshot Bottom Sheet & Viewer:** Chạm vào bất kỳ camera nào để mở bảng chụp trực tiếp; chạm vào ảnh để xem toàn màn hình với cử chỉ pinch-to-zoom (phóng to/thu nhỏ), chạm đúp 2.5x và tự do xoay ngang/dọc theo hướng cầm máy.
- **Tối ưu hóa dữ liệu & Pin:**
  - Giới hạn tải ảnh thumbnail đồng thời tối đa 4 request.
  - Bộ đệm nhớ trong LRU (8 MiB / 32 frames) tự động tái sử dụng ảnh chụp gần nhất.
  - Hỗ trợ chuẩn ETag (`304 Not Modified`) giảm thiểu truyền tải dữ liệu thừa.
  - Tự động dừng polling khi ứng dụng chuyển vào chế độ chạy ngầm (background).

---

## Hướng dẫn cài đặt & Chạy ứng dụng

### 1. Cài đặt các gói phụ thuộc
```bash
flutter pub get
```

### 2. Chạy ứng dụng ở chế độ Dữ liệu mẫu (Demo / Fixture Mode)
```bash
flutter run --dart-define=CAMERA_DEMO_MODE=true
```

### 3. Chạy ứng dụng kết nối tới Backend thực tế
```bash
flutter run \
  --dart-define=CAMERA_API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=CAMERA_READER_KEY=your_reader_api_key_here \
  --dart-define=CAMERA_DEMO_MODE=false
```

---

## Kiểm thử & Phân tích tĩnh

Chạy toàn bộ kiểm thử đơn vị và tích hợp:
```bash
flutter test
```

Kiểm tra chất lượng mã nguồn:
```bash
flutter analyze
```

Định dạng mã:
```bash
dart format lib test integration_test
```