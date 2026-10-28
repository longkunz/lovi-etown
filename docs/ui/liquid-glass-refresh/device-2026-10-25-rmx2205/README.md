# PR #41 — nghiệm thu Android thật, 2026-10-25

**Đã hoàn tất lượt kiểm tra Android và đo hiệu năng mô tả dưới đây. Người dùng chấp nhận mức hiệu năng hiện tại:** “chấp nhận hiệu năng như vậy”. Số đo được giữ nguyên; hiệu năng không còn là điều kiện chặn theo quyết định này. Quyết định không xác nhận các mục chưa chạy như Maps, LIVE hoặc iOS.

## Thiết bị và bản dựng

- realme RMX2205, Android 12 / API 31; 1080×2400, density 480 dpi (360 logical px).
- Trước: `cc12d9ca352953bfd8fd5c7600b3e64b371e51ea` (base PR).
- Sau: `cbd8ea03e3a3ae9701fa721eb5034a61dece4cba` (head PR #41).
- Hai bản ARM64 profile đều build/install thành công, SHA-256 APK trên thiết bị khớp [metadata](metadata.json). Bản candidate được cài lại khi kết thúc.
- Lệnh: `flutter build apk --profile --target=lib/acceptance_main.dart --dart-define=CAMERA_DEMO_MODE=true --target-platform=android-arm64`.
- [Wrapper đo](acceptance_main.dart.txt) gọi production main và ghi Flutter FrameTiming; không sửa UI hay native config. Fixture gốc giống nhau ở hai commit, có 18 camera, không có tọa độ hay LIVE descriptors.
- Package nghiệm thu `site.capyai.lovi` được cài riêng; không thay thế app `com.lovisoft.etown` và không xóa dữ liệu app đang dùng.

## Các thao tác đã kiểm chứng

| Phạm vi | Kết quả và bằng chứng |
| --- | --- |
| Card / Grid / List, light / dark | Chuyển chế độ, xác nhận trạng thái chọn trong UI tree; có ảnh hai bản dưới đây. |
| Bộ chọn quận | Mở/đóng modal, đọc nhãn và nút Đóng; [semantics](after-district-semantics.xml). Chưa chọn một quận cụ thể trong lượt thiết bị này. |
| Chi tiết camera / toàn màn hình / Back | Mở ảnh fixture, vào toàn màn hình và Back về catalog; hoàn thành cả 20 vòng đo trên mỗi bản, tiến trình không đổi trong từng lượt. Không quan sát crash ở luồng này. |
| Kính và ảnh | Có hiệu ứng kính trên modal quận thật; ảnh fixture rõ ở detail/viewer. Header fullscreen tối. Không suy rộng sang video/native Maps. |
| Quan tâm / lưới nhiều camera | Thêm/xóa camera thứ hai, mở lưới có Nguyễn Huệ - Lê Lợi và Đồng Khởi - Mạc Thị Bưởi; [semantics](after-multi-semantics.xml). Kết thúc còn một camera quan tâm trong app nghiệm thu. |
| Xoay / cỡ chữ | Fullscreen ngang 2400×1080; OEM cho chọn font tối đa 1.6, modal quận vẫn đọc được. Đã trả font về 1.0 và tự xoay. |
| TalkBack | Bật được dịch vụ, TAB di chuyển focus có viền xanh; người dùng báo không nghe tiếng. Chưa xác nhận đọc nhãn bằng âm thanh hoặc điều hướng vuốt. Đã tắt, không tính là walkthrough TalkBack PASS. |

### Ảnh trước / sau cùng fixture

| Màn | Trước sáng | Sau sáng | Trước tối | Sau tối |
| --- | --- | --- | --- | --- |
| Card | [ảnh](before-light-card.png) | [ảnh](after-light-card.png) | [ảnh](before-dark-card.png) | [ảnh](after-dark-card.png) |
| Grid | [ảnh](before-light-grid.png) | [ảnh](after-light-grid.png) | [ảnh](before-dark-grid.png) | [ảnh](after-dark-grid.png) |
| List | [ảnh](before-light-list.png) | [ảnh](after-light-list.png) | [ảnh](before-dark-list.png) | [ảnh](after-dark-list.png) |
| Quận | [ảnh](before-light-district.png) | [ảnh](after-light-district.png) | [ảnh](before-dark-district.png) | [ảnh](after-dark-district.png) |
| Chi tiết | [ảnh](before-light-detail.png) | [ảnh](after-light-detail.png) | [ảnh](before-dark-detail.png) | [ảnh](after-dark-detail.png) |
| Toàn màn hình | [ảnh](before-light-fullscreen.png) | [ảnh](after-light-fullscreen.png) | [ảnh](before-dark-fullscreen.png) | [ảnh](after-dark-fullscreen.png) |
| Hai camera | [ảnh](before-light-multi.png) | [ảnh](after-light-multi.png) | [ảnh](before-dark-multi.png) | [ảnh](after-dark-multi.png) |

Ảnh fullscreen có nền tối ở cả hai theme. [Modal font 1.6](after-font1_6-district.png), [xoay ngang font 1.6](after-landscape-font1_6.png), [TalkBack focus qua TAB](after-talkback-tab-6.png), [trạng thái cuối](after-final-restored.png).

Các file thử nghiệm ngoài bảng không chứng nhận thêm tiêu chí: `before-light-sheet.png` thực tế là detail tối chụp sớm, không phải legacy CameraSnapshotSheet; ảnh `after-landscape-doubletap-zoom.png` giống ảnh trước thao tác, không chứng minh zoom; các ảnh `after-talkback-focus-*` không chứng minh vuốt di chuyển focus.

## Hiệu năng — người dùng đã chấp nhận

Mỗi bản: 5 vòng warm-up, sau đó 20 vòng catalog → detail → fullscreen → Back → Back. Đo ở dark theme, font 1.0, refresh setting tự động; không gồm Maps/LIVE. p95 tính nearest-rank từ FrameTiming, không phải thời gian chờ thao tác ADB.

| Chỉ số | Trước | Sau |
| --- | ---: | ---: |
| Số frame | 2188 | 2119 |
| UI/build p50 (ms) | 2.993 | 3.034 |
| UI/build p95 (ms) | 5.912 | 6.304 |
| Raster p50 (ms) | 9.886 | 11.364 |
| Raster p95 (ms) | 17.035 | 18.536 |
| UI >16.7ms (frame) | 15 | 24 |
| Raster >16.7ms (frame) | 113 | 162 |

| PSS (MiB, KB / 1024) | Trước | Sau |
| --- | ---: | ---: |
| Sau warm-up, vòng 0 | 304.93 | 366.96 |
| Vòng 20 | 480.14 | 501.04 |
| Tăng trong 20 vòng | 175.21 | 134.08 |

Cả hai lượt có raster p95 vượt mục tiêu ban đầu 16.7ms. **Ngày 2026-10-25, người dùng chấp nhận mức hiệu năng đã đo**, không yêu cầu tối ưu thêm để chốt lượt nghiệm thu này. Đây là chấp nhận thực tế, không đổi kết quả thành đạt ngưỡng 16.7ms.

PSS candidate khoảng 499.2 MiB trong các mẫu idle 0/10/30 giây sau đo, chưa giảm trong khoảng lấy mẫu. Cả hai bản đều tăng RAM; một lượt mỗi bản, không đảo thứ tự và cache ban đầu khác nhau, nên chưa đủ kết luận memory leak hoặc nguyên nhân chênh lệch là refresh.

Dữ liệu: [candidate summary](profile-summary.json), [baseline summary](baseline-profile/profile-summary.json), [frame CSV](performance-comparison.csv), [RAM CSV](memory-comparison.csv), [idle](memory-idle-summary.json). Raw FrameTiming và dumpsys meminfo được lưu cùng thư mục. Script chạy lưu ở `scripts/`.

## Phát hiện có sẵn và giới hạn

- **Trạng thái sao Quan tâm lúc khởi động chưa đồng bộ:** camera đã lưu hiện “Bỏ quan tâm” trong mục Quan tâm nhưng cùng camera trong catalog hiện “Quan tâm”. Có ở cả base và head: [baseline cold start](before-cold-restart-favorites.xml), [candidate](after-catalog-semantics.xml). Thêm/xóa một favorite khác làm trạng thái đồng bộ lại: [candidate sau toggle](after-favorites-after-toggle.xml). Chưa ghi nhận là hồi quy riêng của PR này.
- Chưa chạy trên thiết bị: nhập/xóa search, chọn quận cụ thể, bàn phím đầy đủ, legacy CameraSnapshotSheet, pinch/zoom 1–5x, high contrast/opaque/reduced motion và ma trận viewport 320/390/600 × font 1/2. Widget tests lịch sử là bằng chứng riêng, không thay cho thao tác máy thật.
- Native Maps chưa kiểm chứng: không có key hợp lệ và fixture không có tọa độ. LIVE chưa kiểm chứng: host preflight trả 45 camera snapshot-only, không có LIVE. HTTP 200 và tọa độ của catalog production là kiểm tra từ máy tính, không chứng nhận mạng điện thoại.
- Chưa có iOS/VoiceOver; TalkBack mới kiểm tra được focus, chưa xác nhận âm thanh.

## Kết nối và khôi phục

ADB ban đầu nhiều lần treo khi lấy window dump/screenshot dù điện thoại vẫn thao tác bình thường. Lượt thử lại dùng SDK ADB 37.0.1, server riêng 5039 qua Wi-Fi trong khi cáp USB vẫn cắm; dùng uiautomator và screenshot lưu file/pull trực tiếp. Không kết luận lỗi này do ứng dụng.

Đã tắt TalkBack/touch exploration, trả font 1.0, light theme, auto-rotation bật/user rotation 0; giữ timeout 10 phút theo trạng thái người dùng đang dùng. [Giá trị đọc lại](restored-settings.json). Đã trả ADB từ TCP về USB (`restarting in USB mode`), đọc lại TCP port `0`, dừng server thử nghiệm 5039: [log khôi phục](adb-restoration.json). File tạm screenshot/XML của lượt thử đã xóa khỏi Download trên thiết bị.

Lượt nghiệm thu thiết bị không sửa product code hoặc đăng bằng chứng lên PR. Sau đó người dùng yêu cầu “merge đi”: PR #41 đã được chuyển khỏi Draft và merge vào `review/t18-google-maps-prerequisite` lúc 14:48:43 ngày 2026-10-25 (UTC+7), merge commit `fd4a591d9c48b70145040d5b10fc435c2e193c33`. Chưa merge vào main hoặc deploy. [Kết quả merge](merge-result.json). Trước merge chạy lại Flutter 185/185 và backend unit 56/56 PASS; API/DB không chạy lại được do máy không còn Docker/PostGIS ở cổng 5433, giữ bằng chứng PASS trước đó trên cùng head PR. Các mục chưa kiểm chứng vẫn được nêu riêng ở trên.
