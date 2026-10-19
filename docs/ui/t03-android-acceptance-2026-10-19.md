# Nghiệm thu T03 — Luồng A1 trên Android (báo cáo từng phần, 2026-10-19)

Báo cáo này ghi bằng chứng nghiệm thu cho ticket #3 (T03) thực hiện trên môi trường agent (VM Linux) tại commit `f097aee` (đã gồm T01/T02). Các phần chưa chạy được ghi rõ lý do và cách hoàn tất; **không** suy PASS thiết bị từ unit/widget tests.

## Môi trường đã dựng

| Thành phần | Giá trị |
| --- | --- |
| Host | Ubuntu 24.04 (VM, 2 CPU, RAM 7,7 GB, **không có `/dev/kvm`**) |
| Flutter / Dart | 3.47.7 stable / 3.13.5 |
| JDK | Temurin OpenJDK 17.0.20.1 |
| Android SDK | platform-tools 37.0.1, platforms android-36 + android-35, build-tools 36.0.0 + 35.0.0, emulator 37.3.4, system images google_apis API 35 (x86_64 và arm64-v8a) — cài thủ công từ gói zip chính thức của Google |
| Gradle | 9.3.1 (theo `gradle-wrapper.properties`), distribution seed thủ công vào wrapper cache |

## Đính chính nguyên nhân chặn Gradle (bản đầu của báo cáo này ghi chưa đúng)

Bản đầu báo cáo kết luận Gradle lỗi do "sandbox/JVM". Điều tra tiếp cho thấy nguyên nhân thật gồm hai lớp thuộc hạ tầng agent, **không liên quan mã nguồn dự án**:

1. Quyền mạng `other_tcp` của Muse ở chế độ Deny chặn kết nối TCP nội bộ: tiến trình kết nối nhận literal banner `muse: Other TCP connections is turned off for this assistant...` thay vì tới được listener, nên client Gradle không bao giờ gửi được lệnh cho tiến trình daemon (`Could not dispatch a message to the daemon`). Chủ repo đã chuyển quyền sang Allow. Riêng kết nối loopback của Java dùng dạng IPv6-mapped (`::ffff:127.0.0.1`) vẫn bị reset kể cả ở chế độ Ask; ép JVM dùng IPv4 (`-Djava.net.preferIPv4Stack=true` qua `JAVA_TOOL_OPTIONS`/`GRADLE_OPTS`/`systemProp`) thì chạy thông (đã kiểm chứng bằng chương trình socket tối thiểu: server nhận `ping`, client nhận `pong`).
2. Proxy egress của sandbox dùng CA riêng (`Hatch Sandbox Egress CA`, có sẵn trong system trust store tại `/usr/local/share/ca-certificates/hatch-egress-ca.crt`) để chặn/giải mã TLS; JDK không dùng system trust store nên handshake TLS tới `dl.google.com` chết ngay lập tức và Gradle báo plugin "not found". Nạp CA này vào `cacerts` của JDK thì tải dependency bình thường (cache Gradle đạt ~3,4 GB trong quá trình build).

`sdkmanager` vẫn không dùng được (HTTP client tích hợp của JDK không tunnel qua proxy được — `NoSuchElementException` ở `HttpURLConnection.doTunneling`), nên SDK được cài bằng gói zip chính thức và AVD được tạo bằng file cấu hình viết tay.

## Kết quả theo tiêu chí nghiệm thu

### AC1 — Integration fixture và debug APK: **APK PASS; fixture trên emulator/thiết bị chưa chạy được**

- **Debug APK build thành công trên chính VM này**: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` (171.714.584 byte), Gradle task `assembleDebug` hoàn tất trong 336 giây ở lần build đầy đủ (sau khi cache dependency đã ấm). APK chứa đủ ABI `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- Fixture `mobile/integration_test/camera_flow_test.dart` bao phủ đúng luồng: tải danh sách → đổi chế độ hiển thị → lọc tìm kiếm → gắn Quan tâm → mở sheet → mở viewer, zoom → đóng viewer/sheet → quay lại đúng ngữ cảnh. Bản sao widget-harness của cùng luồng (`test/features/cameras/camera_flow_integration_test.dart`, cùng tên test và cùng các expect) **PASS** trong bộ test đầy đủ **66/66 PASS**; `flutter analyze` không có issue.
- Tính bền vững của Quan tâm sau restart được bao phủ ở tầng lưu trữ bằng `local_favorites_repository_test.dart` (8 test) và `camera_favorites_test.dart`.
- **Chạy fixture trên emulator: không thể trên VM này**, cả hai kiến trúc đều bị chặn cứng:
  - Image x86_64: emulator thoát ngay với `ERROR | x86_64 emulation currently requires hardware acceleration!` (không có KVM).
  - Image arm64-v8a: `FATAL | Avd's CPU Architecture 'arm64' is not supported by the QEMU2 emulator on x86_64 host. System image must match the host architecture.`
  Do đó ca chạy trên thiết bị/emulator (kèm screenshot) cần máy có KVM hoặc thiết bị thật.

### AC2 — Log/lifecycle: **ở tầng test, chưa có log thiết bị**

- Hành vi dismiss/background dừng request, resume không nhân đôi polling và lỗi mạng có đường phục hồi được bao phủ bằng test có fake clock/transport trong `camera_preview_cubit_test.dart` (gồm các ca bổ sung của T02). Logcat đã che thông tin nhạy cảm trên thiết bị thật **chưa thu thập được** vì chưa chạy được app trên thiết bị/emulator (xem AC1).

### AC3 — Smoke qua backend với camera thực: **chưa chạy**

- Chưa chạy được trên VM này: backend cần PostgreSQL/PostGIS tại `127.0.0.1:5433`, VM không có Docker/PostgreSQL và kho gói hệ điều hành không truy cập được (cùng giới hạn đã ghi ở bằng chứng T01/T02 trong `docs/project-status.md`).

## Việc còn lại để đóng T03

1. Trên máy có KVM/thiết bị thật (Windows/macOS/Linux có tăng tốc): tạo emulator API 35/36 hoặc cắm thiết bị, chạy `flutter test integration_test/camera_flow_test.dart -d <device>`; ghi model thiết bị/OS/SDK và đính kèm screenshot các bước chính. (Build APK không còn là trở ngại: đã chứng minh build được, và máy Windows của chủ repo cũng từng build thành công.)
2. Chạy backend với PostgreSQL/PostGIS, smoke từ app qua một camera thực trong catalog: list/detail/ảnh/304; ghi kết quả từng ca vào báo cáo này.
3. Bổ sung logcat đã che thông tin nhạy cảm cho ca dismiss/background/resume.

Khi các mục trên có bằng chứng, cập nhật trạng thái AC trong báo cáo này và đóng issue #3.
