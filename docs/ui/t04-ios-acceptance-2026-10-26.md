# Nghiệm thu T04 — Luồng A1 trên iOS

Báo cáo này ghi bằng chứng runtime riêng cho issue #4 trên simulator iOS. Kết quả không được suy từ Android hoặc widget test.

## Kết quả — 2026-10-26

### Môi trường

| Thành phần | Giá trị |
| --- | --- |
| Host | macOS, Xcode 26.1.1 (17B100) |
| Flutter / Dart | Flutter 3.47.7 stable / Dart 3.13.5 |
| iPhone | iPhone 17 Pro, iOS 26.1, simulator mới `Lovi T04 Fresh iPhone` |
| iPad | iPad Pro 11-inch (M5), iOS 26.1, simulator mới `Lovi T04 Fresh iPad` |
| Mã được nghiệm thu | `dc0d9d1`, base `4b844f6` |
| Backend thật | NestJS cục bộ trên `127.0.0.1:3000`, PostgreSQL 17/PostGIS tại `127.0.0.1:5433` |

### AC1 — Build, fixture iPhone và hành vi sau restart: **PASS**

- `flutter build ios --simulator --debug` → **PASS**, tạo `build/ios/iphonesimulator/Runner.app` (Xcode build 69,7 giây).
- `flutter test integration_test/camera_flow_test.dart -d <iphone-udid>` → **2/2 PASS** trong 1 phút. Fixture đi qua district, Card/Grid/List, search, favorite, detail/viewer, fullscreen/zoom, Back giữ nguyên context; ca lifecycle xác nhận recovery/background/resume và không còn request sau dismiss.
- Lần chạy đầu trên iOS phát hiện test chạm nút fullscreen khi animation push còn đang chạy: route còn lệch 57,9 pt và nút ở ngoài viewport. Đây là lỗi đồng bộ fixture, không phải layout sản phẩm. Commit `dc0d9d1` chờ transition theo helper đã dùng trong widget test; sau sửa, log thực tế là:

  ```text
  T04_LAYOUT view=Size(402.0, 874.0) media=Rect.fromLTRB(0.0, 118.0, 402.0, 344.1) button=Rect.fromLTRB(350.0, 122.0, 398.0, 170.0)
  T03_LIFECYCLE recovery=2 background=2 resume=4
  T03_DISMISS calls=4 stable=true
  ```

- Dùng app demo trên simulator, thêm `Nguyễn Huệ - Lê Lợi` vào Quan tâm, terminate tiến trình bằng `simctl`, mở lại và vào Camera: mục Quan tâm vẫn có camera, cả mục inline và catalog đều hiển thị `Bỏ quan tâm`.
- Fullscreen pinch zoom 2× và xoay `landscape-right` đều được quan sát trực tiếp. Ảnh framebuffer khi xoay được CoreSimulator lưu theo pixel portrait, vì vậy file bằng chứng landscape trông xoay 90°; không hậu kỳ ảnh.

### AC2 — Backend thật và viewport iPad: **PASS**

- Backend health trả `live`, `dataMode=notis`. Lệnh smoke dùng `http://127.0.0.1:3000` và reader key qua biến shell, không ghi key hoặc URL upstream vào log/tài liệu.
- `flutter test integration_test/camera_backend_smoke_test.dart -d <iphone-udid> --dart-define=T03_BACKEND_URL=http://127.0.0.1:3000 ...` → **2/2 PASS**: list → detail → playback descriptor → snapshot `200` có ETag → `304`, và UI render ảnh camera thật `Hàm Nghi - Phó Đức Chính`.
- Không có lỗi ATS/local-network hoặc lỗi nguồn trong lượt smoke; ảnh thật render được trong app, nên cấu hình/mạng/backend/source đều hoạt động ở ca đã chạy.
- `flutter test integration_test/camera_flow_test.dart -d <ipad-udid> --plain-name 'camera full user flow integration test'` → **1/1 PASS**. Viewport đo được `834×1210`; media `Rect(0,88,834,557.1)` và nút fullscreen `Rect(782,92,830,140)`, đều nằm trọn trong viewport. Ảnh iPad xác nhận catalog không overflow/cắt nội dung.

### Kiểm tra hồi quy

- `flutter analyze` → **No issues found**.
- `flutter test` → **243 PASS, 1 skipped**.
- Android fixture dùng chung sau thay đổi timing: `flutter test integration_test/camera_flow_test.dart -d emulator-5556` → **2/2 PASS** trong 1 phút; viewport `360×640`, nút fullscreen nằm trong khung.
- Backend không đổi mã nguồn. Cùng base đã được kiểm tra cho T03: unit **59/59**, API **21/21**, DB **16/16**.

### Lệnh tái hiện chính

Chạy trong `mobile/`; giá trị reader key được lấy vào biến shell cục bộ và không lưu trong history/report:

```sh
flutter build ios --simulator --debug
flutter test integration_test/camera_flow_test.dart -d FB6FB705-7A93-4EBC-B625-474B7318623B
flutter test integration_test/camera_backend_smoke_test.dart -d FB6FB705-7A93-4EBC-B625-474B7318623B \
  --dart-define=T03_BACKEND_URL=http://127.0.0.1:3000 \
  --dart-define=T03_READER_KEY="$reader_key" \
  --dart-define='T03_CAMERA_QUERY=Hàm Nghi - Phó Đức Chính'
flutter test integration_test/camera_flow_test.dart -d 45EA85CB-07A2-41CC-939B-5E51EBC36BFE \
  --plain-name 'camera full user flow integration test'
flutter analyze
flutter test
flutter test integration_test/camera_flow_test.dart -d emulator-5556
```

Restart persistence dùng `xcrun simctl terminate <iphone-udid> com.lovisoft.etown`, sau đó `xcrun simctl launch <iphone-udid> com.lovisoft.etown`. Xoay dùng `agent-device orientation landscape-right` trên đúng UDID iPhone ở trên.

## Bằng chứng ảnh

Ảnh gốc, kích thước và diễn giải nằm trong [`t04-ios-acceptance-2026-10-26/`](t04-ios-acceptance-2026-10-26/README.md). Không ảnh nào chứa API key hoặc URL upstream.
