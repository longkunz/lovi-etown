# Hiện trạng dự án Lovi Etown

Cập nhật: **2026-10-25**. Trang này ghi hiện trạng repository và bằng chứng kiểm thử gần nhất; spec/plan lưu chi tiết thiết kế và lịch sử thực thi.

## Repository và cấu hình làm việc

- Repository chung: [longkunz/lovi-etown](https://github.com/longkunz/lovi-etown), nhánh `main`, workspace `D:\lovi-etown`.
- `backend/`, `mobile/`, `docs/` và `scripts/` là các thư mục của cùng repository. Tạo commit từ repo chính; các hướng dẫn khởi tạo Git riêng trong plan cũ là lịch sử.
- Hai commit đã đưa mã nguồn và cấu hình lên GitHub: `f94338b` (mã nguồn hiện tại) và `8592757` (Matt Pocock Skills).
- Lịch sử Git trước khi hợp nhất được lưu cục bộ tại `.git/local-repositories/backend.git` và `.git/local-repositories/mobile.git`; các bản sao lưu này không nằm trên GitHub.
- Cấu hình Matt Pocock Skills: [issue tracker](agents/issue-tracker.md), [triage labels](agents/triage-labels.md), [domain docs](agents/domain.md).

## Phạm vi và bằng chứng

Backend A1 có [báo cáo nghiệm thu](../backend/docs/verification.md). Mobile A1 có [báo cáo xử lý review và nghiệm thu](ui/mobile-a1-verification.md) cho luồng danh sách/tìm kiếm → snapshot bottom sheet → viewer → Quan tâm inline. Dùng các báo cáo để tra nội dung đã kiểm chứng; các đề xuất rộng hơn trong [rebuild-spec](rebuild-spec.md) là phạm vi sản phẩm/roadmap, không phải danh sách tính năng đã hoàn thành.

Ngày 2026-10-19 đã chạy lại trên mã nguồn đưa lên GitHub:

| Phần | Lệnh, chạy trong thư mục tương ứng | Kết quả |
|---|---|---|
| Backend unit | `npm run test:unit` | 22/22 PASS |
| Backend API | `npm run test:api` | 15/15 PASS |
| Backend database | `npm run test:db` | 12/12 PASS |
| Mobile unit/widget | `flutter test` | 45/45 PASS |

Backend API/database tests cần PostgreSQL/PostGIS; lần chạy trong sandbox ban đầu bị chặn kết nối `127.0.0.1:5433`, sau đó chạy lại với quyền truy cập local và đều PASS. Flutter tests cũng chạy với quyền truy cập SDK/cache ngoài workspace.

Đây là bằng chứng kiểm thử tự động, không phải xác nhận mới về bản APK/IPA phát hành, nghiệm thu iOS trên thiết bị, shader trên mọi thiết bị hoặc triển khai production. Các tính năng sau A1 phải đối chiếu các mục cập nhật bên dưới; bản đồ/Vietmap/nearby hiện có triển khai #40 trên nhánh tính năng, chưa nghiệm thu map native với key thật.

### T01/T02 (issue #1, #2) — 2026-10-19

- T03 (issue #3, đang thực hiện qua pull request trên branch `t03-android-acceptance`): bằng chứng từng phần và các việc còn lại để nghiệm thu luồng A1 trên Android nằm ở [báo cáo T03](ui/t03-android-acceptance-2026-10-19.md). Tóm tắt: **debug APK đã build thành công trên môi trường agent** (sau khi gỡ hai lớp chặn hạ tầng: quyền `other_tcp` của Muse chặn TCP nội bộ của Gradle và CA riêng của proxy egress chưa có trong trust store của JDK); luồng fixture có bản sao widget-harness PASS trong bộ 66/66 test. Còn thiếu: chạy fixture trên emulator/thiết bị (VM không có KVM — image x86_64 đòi tăng tốc phần cứng, image arm64 bị emulator từ chối khác kiến trúc host) và smoke backend (không có PostgreSQL/PostGIS).
- T01: `CameraApiClient.getSnapshot` nay decode thật payload (ngoài kiểm tra magic bytes ở header) trước khi tạo `SnapshotFrame`; payload JPEG/PNG/WebP có header hợp lệ nhưng không giải mã được bị từ chối với lỗi 422, nên không thể thay last-good frame trong preview/viewer hay đi vào snapshot cache dùng chung. Có regression test ở tầng client và test đầu-cuối client → repository → preview/cache (kể cả thumbnail scheduler).
- T02: `CameraPreviewCubit` được tách thành các stage detail → descriptor → snapshot; backoff tự động và retry thủ công làm lại đúng stage còn thiếu thay vì gọi snapshot khi chưa có endpoint, descriptor lỗi vẫn thử snapshot qua endpoint của camera và được khôi phục ở chu kỳ poll kế tiếp, lỗi refresh đánh dấu ảnh hiện tại là cũ (`isStale`) ngay cả trước ngưỡng 60 giây, và bộ đếm backoff đặt lại khi mỗi stage thành công.
- Kiểm thử đã chạy lại trên môi trường agent (Flutter 3.47.7 / Dart 3.13.5): targeted tests cho T01/T02 đỏ trước khi sửa (8 test fail) và xanh sau khi sửa; `flutter test` toàn bộ **66/66 PASS**; `flutter analyze` không có issue. Backend không thay đổi mã nguồn; `npm run test:unit` **22/22 PASS**. `test:api`/`test:db` chưa chạy được trên môi trường agent vì không có Docker/PostgreSQL và kho gói hệ điều hành không truy cập được; cần chạy lại ở môi trường có PostgreSQL/PostGIS tại `127.0.0.1:5433` để hoàn tất bằng chứng backend.

### T18 — Google Maps & Traffic Layer (2026-10-24)

- **Báo cáo nghiệm thu:** [`docs/ui/t18-google-maps-traffic-verification.md`](ui/t18-google-maps-traffic-verification.md).
- **Đặc tả & Kế hoạch:** [`docs/superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md`](superpowers/specs/2026-10-24-camera-google-maps-traffic-design.md) & [`docs/superpowers/plans/2026-10-24-camera-google-maps-traffic.md`](superpowers/plans/2026-10-24-camera-google-maps-traffic.md).
- **Tóm tắt:** Tích hợp Google Maps SDK cùng lớp vạch màu kẹt xe (`trafficEnabled: true`) vào `CameraSnapshotSheet` và `CameraViewerScreen`, kèm màn hình xem bản đồ toàn màn hình `CameraTrafficMapViewerScreen` (hỗ trợ chuyển đổi vệ tinh/hybrid, recenter, directions).
- **Kiểm thử tự động:** `flutter test` toàn bộ **141/141 PASS**; `flutter analyze` 0 issues; Backend unit (56/56 PASS), API (15/15 PASS), DB (12/12 PASS).

### Liquid Glass Refresh (review 2026-10-24)

- [Báo cáo review](ui/liquid-glass-refresh-verification.md), [spec](superpowers/specs/2026-10-24-liquid-glass-refresh-design.md), [plan](superpowers/plans/2026-10-24-liquid-glass-refresh.md).
- Có triển khai theme/policy và controls dùng chung cho catalog, sheet/viewers, favorites/lưới và bản đồ. Review đã sửa target/semantics/reduced-motion, keyboard focus, opaque header media, feed dưới AppBar và overflow map/favorites ở chữ lớn.
- Kiểm thử worktree PR: `flutter analyze` 0 issues; **174/174 Flutter tests PASS**; backend chạy lần lượt **56 unit + 18 API + 12 DB PASS** với Node 24.16.0 và PostGIS local. Sửa SQL tiền đề nằm ở nhánh T18, ngoài diff Refresh.
- **Chưa hoàn tất nghiệm thu**: 12 PNG là mockup HTML, thiếu screenshot app trước/sau, shader/native Maps/live trên thiết bị, TalkBack/VoiceOver và profile p95/RAM. PR Draft trên nhánh T18 tiền đề; không phải xác nhận sẵn sàng phát hành.

### #40 — Bản đồ mặc định / Vietmap / Gần tôi (2026-10-25)

- Triển khai trên nhánh `feat/40-vietmap-discovery` từ `c0a01b9`; chưa ghi nhận merge vào `main`. Navigation Bản đồ | Camera, mặc định Bản đồ tại `/`, Camera lazy tại `/cameras`; backend `/v1/map-cameras` dùng PostGIS. Canvas Vietmap dùng chung cả khám phá lẫn chi tiết camera, đã gỡ Google Maps SDK.
- [Báo cáo #40](ui/camera-map-discovery-verification.md), [spec](superpowers/specs/2026-10-24-camera-map-discovery-design.md), [plan](superpowers/plans/2026-10-24-camera-map-discovery.md).
- Backend kiểm tra thực: typecheck PASS, **59 unit + 21 API + 15 DB PASS** trên Node24.16/PG17.11/PostGIS3.6.4. Android debug và iOS Simulator build PASS. Flutter analyze không có issue; **231 Flutter tests PASS, 1 conditional skip**. Kết quả và evidence nằm trong báo cáo đi kèm.
- Android emulator demo smoke xác nhận cold start Bản đồ, chuyển tab/detail/Back, force-stop rồi mở về Bản đồ, không tự xin GPS. **Chưa có key Vietmap hợp lệ**, không đánh PASS tiles/hybrid/traffic hoặc nghiệm thu runtime iOS từ fake/build.

## Cách đọc và cập nhật tài liệu

- Dùng [README gốc](../README.md) và [README backend](../backend/README.md) cho thao tác cài đặt/chạy hiện hành. Script thực tế nằm trong [backend/package.json](../backend/package.json); dependency Flutter nằm trong [pubspec.yaml](../mobile/pubspec.yaml) và [pubspec.lock](../mobile/pubspec.lock).
- Các spec/plan ngày 14–16/10 mô tả cả thời điểm chưa triển khai. Những câu như “chờ review”, “chưa có Git” và checkbox chưa đánh dấu trong bản kế hoạch gốc là ghi chép lịch sử; đối chiếu báo cáo nghiệm thu và bằng chứng mới trước khi nhận việc.
- Báo cáo review ban đầu lưu các lỗi đã được phát hiện. Đọc cùng báo cáo nghiệm thu kế tiếp để biết phần đã xử lý; không xóa phát hiện cũ hoặc tự đánh dấu các hạng mục chưa được xác minh là hoàn tất.
- Chỉ cập nhật kết quả kiểm thử sau khi thực sự chạy lại, kèm ngày và phạm vi. Số lượng test trong bảng là mốc kiểm chứng, không phải giới hạn cố định cho các lần phát triển tiếp theo.
- Khi dùng quy trình nhiều phiên của Matt Pocock Skills, xuất công việc mới thành spec/tickets trên GitHub Issues với tiêu chí nghiệm thu và quan hệ phụ thuộc. `CONTEXT.md` và ADR được tạo khi chốt thuật ngữ hoặc quyết định phù hợp theo [quy tắc domain](agents/domain.md).
