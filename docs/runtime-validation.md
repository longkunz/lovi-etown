# Kiểm chứng runtime

Ngày: 2026-10-14. Thiết bị: emulator-5554, Android 9 / SDK 28; APK trùng hash bộ local. Một ADB serial mạng cũng được liệt kê nhưng chưa dùng để tránh nhầm thiết bị. Session Frida: 17.23.3.

## Baseline và phạm vi hook

Baseline không hook: launch → LicenseActivity → Google Play chưa đăng nhập → app đóng. Bằng chứng: launch-window.xml, license-screen/screen.png, launch-logcat-local.txt.

Theo yêu cầu người dùng, chạy:

```powershell
frida -D emulator-5554 -f com.genius.cameragiaothong -l scripts/frida/observe-without-license.js -q -t 20 --eternalize
```

Log xác nhận `hook_ready` và `license_check_skipped`; app tới chọn tỉnh. Hook chỉ bỏ entry checkLicense trong tiến trình, không patch APK hay entitlement VIP. `--eternalize` giữ script trong tiến trình sau khi CLI thoát; hook mất khi tiến trình kết thúc. Không coi phiên này là hành vi launch không can thiệp.

## Ca đã chạy

| Ca | Bước / kết quả | Bằng chứng trong evidence/runtime/ |
|---|---|---|
| R-001 | Chọn TP.HCM, xem disclosure vị trí, chọn Để sau → home vẫn có dữ liệu | hooked-launch-window.xml, location-disclosure, hcm-home |
| R-002 | Mở camera đầu TP.HCM → có route chi tiết và snapshot UI | hcm-detail; ảnh đầu transition, không dùng để khẳng định full playback |
| R-003 | Chạm tim trên chi tiết, quay lại tab Yêu thích → có camera 11B Nguyễn Bỉnh Khiêm | favorites, after-map-back |
| R-004 | Mở bản đồ → route riêng với traffic/2D/zoom/vị trí và xem camera gần nhất | map |
| R-005 | Cài đặt có VIP, feedback, review, policy, version, cross-promotion | settings |
| R-006 | Mở dropdown khu vực và bộ lọc TP.HCM → quận, Mặc định/Gần tôi/Yêu thích | hcm-districts, hcm-filters |
| R-007 | Đổi lần lượt sang Hà Nội, Đà Nẵng, Huế, Quảng Trị → mỗi tỉnh có danh sách camera | hanoi-home, danang-home, hue-home, quangtri-home |
| R-008 | Trong flow mở camera Hà Nội xuất hiện paywall và quảng cáo; đóng bằng nút UI/back để tiếp tục | hanoi-detail-confirmed/screen.png là paywall; after-ad-back là chi tiết |
| R-009 | Chi tiết Hà Nội gọi EVUP native tới rec01ihanoi.vtscloud.vn rồi handshake lỗi protocol version; UI hiện không tải được hình, Báo lỗi/Thử lại | playback-logcat-local.txt, after-ad-back |
| R-010 | Tại Quảng Trị tìm `zzz_no_camera_9381` → không tìm thấy camera phù hợp | search-empty; đã xóa query sau ca thử |
| R-011 | Observer thụ động trong app ghi POST /track/ host api.mixpanel.com | network-observations.txt; không thu auth/body |
| R-012 | Hook SSL_read/SSL_write native engine đúng Build ID/text/prefix; năm POST Udrivex có response 200 và JSON list | dart-capture/pass1-http.json, pass3-http.json; không đổi routing/TLS verification |
| R-013 | TP.HCM → camera 11B → đóng paywall/ad → GET Notis snapshot, JPEG 200 và ảnh trên chi tiết | dart-capture/pass2-http.json, dart-hcm-snapshot-visible/screen.png |
| R-014 | Spawn lại để capture: favorite 11B vẫn tồn tại; app-check có giá trị khác ở lần khởi động mới và nhiều giá trị trong pass3 | dart-hcm-list, dart-capture/capture-comparison.json; chưa xác định storage key hoặc token lifecycle |
| R-015 | AVD Android 13: nguồn Hà Nội WSS mở, handshake, HEVC decode và video hiện trên UI | api33-playback-summary.json, api33-hanoi-playing/screen.png |
| R-016 | Đọc payload tạo App-Check và đối chiếu hash ciphertext với header API 200 | dart-capture/app-check-summary.json; docs/app-check-analysis.md |
| R-017 | Đà Nẵng: Bệnh viện Đà Nẵng mở YouTube embedded player, có hình, nút Pause và nhãn Live | players33-danang-detail; players33-summary.json |
| R-018 | Huế: Cầu Lòn Bùi Thị Xuân1 hiện hình thay đổi giữa hai capture, log tạo media_kit cùng thời điểm | players33-hue-detail, players33-hue-playing2; chưa capture HTTP playlist |
| R-019 | Quảng Trị: thử Ba Lòng và Ba Đồn; WSS handshake thành công nhưng chưa có decoded frame trong khoảng quan sát | recovery-summary.json; recovery-and-backup.md |
| R-020 | Ngắt mạng AVD khi Hà Nội đang phát: hiện lỗi; khôi phục mạng ~29 giây vẫn lỗi; bấm Thử lại thì HEVC phát tiếp | recovery-offline, recovery-online-waited, recovery-confirmed; recovery-summary.json |
| R-021 | Camera Phan Đăng Lưu–Phan Xích Long có backup descriptor, nguồn chính Notis JPEG 200; chưa kích hoạt failover | backup-final-visible, dart-capture/backup-detail-http.json; recovery-and-backup.md |
| R-022 | Gây lỗi DNS riêng Notis trong process: 92 lần lỗi, UI error, chưa thấy DNS tới backup host; probe tự gỡ sau 200 giây | dart-capture/fallback-fault-summary.json; catalog-cache-favorites.md |
| R-023 | Đọc hai mảng key trong object pool, giải mã CG01 xác thực GCM; asset/cache 726 ID khớp API sau lọc 174 ID | native/catalog-local-state-summary.json; key/plaintext private |
| R-024 | Thêm/bỏ tim Phan Đăng Lưu; XML SharedPreferences thay đổi theo id, rồi khôi phục array trước thử | native/catalog-local-state-summary.json; prefs XML private |
| R-025 | API DNS lỗi: cache Notis bị thay bằng asset; không cache dùng asset; cache tạo từ asset được đọc và UI có danh sách | catalog-fallback-summary.json; catalog-fallback-runtime.md; file fixture khôi phục đúng hash |

R-009 xác minh đường gọi tới WSS và một nhánh lỗi. Lỗi `TLSV1_ALERT_PROTOCOL_VERSION` đến từ Conscrypt trên emulator Android 9; chưa chứng minh root cause toàn hệ thống hoặc trạng thái nguồn trên Android mới. Native code có cả AVC/HEVC decoder branch, nhưng phiên lỗi chưa decode được frame.

## Giới hạn capture

- UIAutomator semantics Flutter đôi lúc giữ nội dung home trong khi screenshot đã là paywall/quảng cáo. Screenshot và XML không phải snapshot nguyên tử; các capture mâu thuẫn được ghi rõ và không dùng XML cũ làm bằng chứng màn mới.
- Hook SSL_write ở libssl.so quan sát được một số SDK/Java request, **không bao phủ TLS Dart trong libflutter** (không có SSL_write export). DNS không chứng minh path/method; thiếu capture không chứng minh không có request.
- Giới hạn hook libssl ở trên đã được bổ sung bằng native observer theo symbol official đúng engine ở R-012; đã thu HTTP Dart. Capture này vẫn không bao phủ toàn bộ HTTP plain/WebView/native player hoặc chứng minh mọi request của app đã được thu.
- Script observer còn giữ trong tiến trình sau CLI thoát; message gửi sau detach không nằm trong log CLI. Logcat playback được thu riêng sau đó.
- Giá paywall trong ảnh là `- đ`; chưa xác nhận offering/giá thật và chưa mua/khôi phục giao dịch.
- Có thêm một favorite trong dữ liệu thử nghiệm. Không clear data hoặc thay đổi account, APK, quyền VIP.

## Chưa chạy / cần làm tiếp

- Server enforcement/expiry và cache TTL. Nhánh disk/asset đã thử với lỗi DNS API; CG01 đã giải mã xác thực; App-check generation đã đối chiếu runtime; buffer cache token 60 giây mới xác định tĩnh.
- Playback thành công từng loại snapshot/HLS/EVUP, reconnect/background, codec thực tế.
- Mất mạng rồi phục hồi; quyền Android thực sự deny/grant; vị trí gần tôi và marker đầy đủ.
- Favorites migration/ID đổi/camera bị gỡ; pagination và danh sách hoàn toàn rỗng do backend. Storage key và id đã đối chiếu qua XML, xem catalog-cache-favorites.md.
- Android hiện đại đã thử API 33 và một camera Hà Nội phát được; tiếp tục HLS/type5 và reconnect. Xem android13-playback.md.

Để chụp một state tiếp theo: `python scripts/capture-state.py emulator-5554 ten-state`. Đối chiếu cả nodes.json và ảnh trước khi thao tác tiếp vì quảng cáo có thể đổi màn bất đồng bộ.
