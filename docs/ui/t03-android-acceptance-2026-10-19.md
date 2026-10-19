# Nghiệm thu T03 — Luồng A1 trên Android (báo cáo từng phần, 2026-10-19)

Báo cáo này ghi bằng chứng nghiệm thu cho ticket #3 (T03) được thực hiện trên môi trường agent (VM Linux) tại commit `f097aee` (đã gồm T01/T02). Các phần chưa chạy được ghi rõ lý do và cách hoàn tất; **không** suy PASS thiết bị từ unit/widget tests.

## Môi trường đã dựng

| Thành phần | Giá trị |
| --- | --- |
| Host | Ubuntu 24.04 (VM, 2 CPU, RAM 7,7 GB, **không có `/dev/kvm`**) |
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| JDK | Temurin OpenJDK 17.0.20.1 |
| Android SDK | platform-tools 37.0.1, platforms android-36 + android-35, build-tools 36.0.0 + 35.0.0, emulator 37.3.4 (cài thủ công từ gói zip chính thức của Google; `sdkmanager` không dùng được vì HTTP client của JDK không qua được proxy của sandbox) |
| Gradle | 9.3.1 (theo `gradle-wrapper.properties` của dự án), distribution đã tải và seed thủ công vào wrapper cache |

## Kết quả theo tiêu chí nghiệm thu

### AC1 — Integration fixture và debug APK: **một phần**

- Fixture `mobile/integration_test/camera_flow_test.dart` bao phủ đúng luồng: tải danh sách → đổi chế độ hiển thị → lọc tìm kiếm → gắn Quan tâm → mở sheet → mở viewer, zoom → đóng viewer/sheet → quay lại đúng ngữ cảnh. Bản sao widget-harness của cùng luồng (`test/features/cameras/camera_flow_integration_test.dart`, cùng tên test và cùng các expect) **PASS** trong bộ test đầy đủ **66/66 PASS** tại commit này; `flutter analyze` không có issue.
- Tính bền vững của Quan tâm sau restart được bao phủ ở tầng lưu trữ bằng `local_favorites_repository_test.dart` (8 test) và `camera_favorites_test.dart` trong cùng bộ test.
- **Chưa chạy được:** chạy fixture bằng `integration_test` trên thiết bị/emulator và build debug APK (`flutter build apk --debug`) trên VM này. Gradle không thể thực thi bất kỳ task nào: client Gradle không gửi được lệnh tới tiến trình daemon (`Could not dispatch a message to the daemon`), và lỗi tái lập được bằng chương trình Java NIO socket tối thiểu không liên quan tới Gradle (client ghi socket loopback bị `Connection reset by peer`), trong khi socket blocking thuần và Python loopback hoạt động. Đây là giới hạn của môi trường VM hiện tại, không phải lỗi mã nguồn; cùng bản debug APK đã build thành công trước đó trên máy Windows của chủ repo (xem `docs/ui/mobile-a1-verification.md` mục 3).
- VM không có `/dev/kvm` nên emulator chỉ chạy được bằng phần mềm; kể cả khi có APK, kết quả emulator phần mềm trên 2 CPU không đại diện cho thiết bị thật.

### AC2 — Log/lifecycle: **ở tầng test, chưa có log thiết bị**

- Hành vi dismiss/background dừng request, resume không nhân đôi polling và lỗi mạng có đường phục hồi được bao phủ bằng test có fake clock/transport trong `camera_preview_cubit_test.dart` (gồm các ca bổ sung của T02). Logcat đã che thông tin nhạy cảm trên thiết bị thật **chưa thu thập được** vì chưa chạy được app trên thiết bị/emulator (xem AC1).

### AC3 — Smoke qua backend với camera thực: **chưa chạy**

- Chưa chạy được trên VM này: backend cần PostgreSQL/PostGIS tại `127.0.0.1:5433`, VM không có Docker/PostgreSQL và kho gói hệ điều hành không truy cập được (cùng giới hạn đã ghi ở bằng chứng T01/T02 trong `docs/project-status.md`).

## Việc còn lại để đóng T03

Chạy trên máy có Gradle/Android hoạt động (máy Windows đã build được APK trước đây là phù hợp):

1. `flutter build apk --debug` tại commit của PR này trở đi.
2. Tạo emulator Android (API 35/36) hoặc cắm thiết bị thật; chạy `flutter test integration_test/camera_flow_test.dart -d <device>`; ghi model thiết bị/OS/SDK và đính kèm screenshot các bước chính.
3. Chạy backend với PostgreSQL/PostGIS, smoke từ app qua một camera thực trong catalog: list/detail/ảnh/304; ghi kết quả từng ca vào báo cáo này.
4. Bổ sung logcat đã che thông tin nhạy cảm cho ca dismiss/background/resume.

Khi các mục trên có bằng chứng, cập nhật trạng thái AC trong báo cáo này và đóng issue #3.
