# Liquid Glass Refresh — review và kiểm chứng

Ngày review: 2026-10-24. Phạm vi: [plan](../superpowers/plans/2026-10-24-liquid-glass-refresh.md) và [spec](../superpowers/specs/2026-10-24-liquid-glass-refresh-design.md).

**Kết luận:** Có triển khai Dart cho theme/policy, controls, catalog, sheet, viewers, favorites, lưới nhiều camera và controls map. Kiểm thử tự động PASS sau sửa review. **Chưa hoàn tất toàn bộ kế hoạch nghiệm thu**: còn screenshot app trước/sau, shader/native Maps, TalkBack/VoiceOver và profile p95/RAM. PR để Draft.

## Phạm vi PR và tiền đề

- Baseline ban đầu: `a87f44c` trên `main`.
- Nhánh tiền đề: `review/t18-google-maps-prerequisite`, chứa tích hợp Dart/dependency T18 đã có trong workspace và sửa SQL `stream_url` bị khai báo hai lần trong INSERT (`89907ba`). Sửa SQL cần thiết để suite API/DB chạy qua.
- PR Refresh: `review/liquid-glass-refresh`, base là nhánh tiền đề. Diff PR chỉ chứa refresh và các sửa sau review; không đưa cấu hình Android/iOS, đổi package native, widget sync, backend compose hoặc map discovery vào PR này.
- T18 vẫn cần hoàn thiện/nghiệm thu riêng, nhất là cấu hình key và lifecycle map. Nhánh tiền đề là phần nguồn để review nối tiếp; không phải xác nhận T18 sẵn sàng merge/release. Khi T18 thay đổi phải rebase và chạy kiểm thử lại.
- Dùng worktree riêng để kiểm thử nội dung PR. Workspace gốc giữ các thay đổi chưa commit khác.

## Các phát hiện review đã sửa

| Phát hiện | Sửa và bằng chứng |
|---|---|
| Segment Card/Grid/List chỉ có target 44×36, mất tên khi chỉ hiện icon, bỏ qua `enabled`, animation luôn chạy | Target mỗi segment ≥48×48; tooltip/semantics localized, disabled không phát callback; reduced-motion đặt duration về 0. Regression ở `camera_glass_controls_test.dart`. |
| AppBar catalog có kính nhưng nội dung không cuộn bên dưới | `extendBodyBehindAppBar` và khoảng bù safe-area/toolbar trong sliver; giữ scroll controller và các callback. |
| Bộ chọn quận chưa quản lý focus và bàn phím | Trigger có FocusNode được dispose; modal tính keyboard inset, Back trả focus cho trigger và giữ query. Regression ở `camera_filters_test.dart`. |
| Header media có chữ trắng nhưng opaque fallback theo light theme thành trắng | Cho phép override brightness của surface; các header media dùng dark settings và dark opaque fallback. Regression ở `camera_glass_controls_test.dart`. |
| Test bản đồ khai báo `MediaQuery.size=320` nhưng viewport thực vẫn rộng | Đặt physicalSize/devicePixelRatio thật. Tái hiện overflow trước sửa; header bản đồ chuyển thành bố cục xuống hàng, controls giữ opaque và safe-area. |
| Favorite card cao cố định 96 tràn với tên dài ở text scale 2 | Tái hiện overflow 31px trước sửa; chiều cao tăng theo text scaler, target nút lưới ≥48. Regression ở `camera_filters_test.dart`. |
| Test đổi theme tap nút nằm sau modal với `warnIfMissed:false` nên không thật sự đổi theme | Gọi StateSetter trực tiếp, chờ theme transition hữu hạn; assert brightness/highContrast thật đã đổi và snapshot request không tăng. |

## Kết quả tự động

Môi trường: macOS 15.6.1 (24G90), arm64; Flutter **3.47.7**, Dart **3.13.5**; Node **24.16.0**. `liquid_glass_widgets` giữ **1.13.0**. PostgreSQL/PostGIS test container tại `127.0.0.1:5433` đã chạy sẵn, không đổi compose trong PR.

| Thư mục | Lệnh | Kết quả |
|---|---|---|
| `mobile/` | `flutter pub get` | PASS |
| `mobile/` | `flutter pub run easy_localization:generate -S assets/translations -O lib/src/core/i18n -o locale_keys.g.dart` | PASS; output không được app sử dụng, không thêm vào PR |
| `mobile/` | `flutter analyze` | 0 issues |
| `mobile/` | `flutter test --reporter expanded` | 174/174 PASS |
| `backend/` | `npm run test:unit` | 56/56 PASS |
| `backend/` | `npm run test:api` | 18/18 PASS |
| `backend/` | `npm run test:db` | 12/12 PASS |

Backend chạy **lần lượt** với `PATH` ưu tiên Node 24. Một lần thử ban đầu qua npm đã dùng Node 23.3.0 và lỗi `undici/createZstdDecompress`; chạy lại đúng runtime trên cho kết quả trong bảng. Không cần thay dependency backend.

[Evidence đầu ra rút gọn](liquid-glass-refresh/automated-review-evidence.txt) ghi phiên bản và dòng kết quả thực. Test widget map dùng `mapBuilder`, không tạo native GoogleMap. Ma trận filters dùng viewport **320/390/600** và text scaler **1/2**, tên quận dài; có case bàn phím 300px và Back. Các case này không chứng nhận toàn bộ màn hình app hay screen reader thật.

## AC1–AC8

| Tiêu chí | Trạng thái | Bằng chứng / giới hạn |
|---|---|---|
| AC1 — đồng bộ theme và ảnh trước/sau | PARTIAL | Code dùng chung theme/policy/controls; 12 PNG là mockup HTML. Chưa có bộ screenshot app trước/sau cùng fixture cho đủ các màn. |
| AC2 — kính thấy được trên thiết bị | NOT RUN | Có settings theo role/brightness và một surface cho mỗi control; widget test không chứng nhận shader GPU. |
| AC3 — media rõ | PASS (cấu trúc) | Bỏ glass bao toàn card/sheet/map; media là sibling của header/controls. Chưa nghiệm thu hình ảnh native/video thật. |
| AC4 — tương tác | PASS (tự động) | Search/clear, district, modes, favorites, sheet → image overlay → đóng, kiểm thử flow/viewer/live hiện có đều PASS. |
| AC5 — trợ năng/layout | PARTIAL | Regression target, semantics, matrix filters và focus PASS. Chưa walkthrough TalkBack/VoiceOver và chưa có ma trận thiết bị cho toàn bộ màn hình. |
| AC6 — live/map | PARTIAL | Callback/config và opaque controls được kiểm tra bằng fake map; live regression PASS. Chưa pan/zoom/toggle/recenter/fullscreen trên native Maps. |
| AC7 — tài nguyên | PARTIAL | Đổi theme/highContrast không thêm snapshot request hoặc mất frame. Profile 20 vòng, p95 UI/raster ≤16.7ms và RAM sau warm-up: NOT RUN. |
| AC8 — kiểm thử/bằng chứng | PASS (tự động) | Analyze + 174 Flutter + 86 backend tests trên worktree PR. Không dùng test tự động để kết luận các AC thiết bị đã đạt. |

## Mockup và việc còn lại

12 PNG ở [thư mục mockup](liquid-glass-refresh/README.md) được tạo bằng `scripts/ui/generate-refresh-mockups.mjs` (Chrome headless/HTML), không phải Flutter screenshots hoặc bằng chứng trước/sau. Không dùng các file `ios-sim-*` chưa có metadata phiên chạy trong PR.

Trước khi đổi PR sang Ready: review giao diện thật light/dark và opaque; chụp trước/sau đủ màn; kiểm tra native Maps/live, xoay và Back; walkthrough TalkBack/VoiceOver; chạy build profile 20 lần mở/đóng và ghi p95 UI/raster cùng RAM. Chưa có bằng chứng hoàn tất các bước này trong lượt review.
