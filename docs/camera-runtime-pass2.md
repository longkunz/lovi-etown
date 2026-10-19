# Camera — lượt xác minh runtime 2

Ngày 2026-10-14; `emulator-5554`, package/version/artifact runtime giữ như lượt 1. REA được bổ sung bởi ADB/Python/Frida cho các câu hỏi cụ thể.

> **Đính chính ở lượt 3:** rút lại suy luận kẹt splash; vuốt lên hiện menu và vào Camera được. UI restore Quan tâm và nhịp refresh khoảng 12 giây đã được xác minh tiếp. Phần dưới giữ như nhật ký lượt 2; trạng thái hiện tại xem [camera-runtime-pass3.md](camera-runtime-pass3.md).

## Phát hiện

1. **Quan sát runtime storage:** `FlutterSharedPreferences.xml` chứa `flutter.tenantModel/config/url-api-camera = https://api.notis.vn/v4/`, `config/area-camera` gồm 16 khu vực. Evidence: `evidence/camera/storage-added.json`, `storage-restarted.json`; script `scripts/probe-camera-storage.py`. Chỉ thu keys và phần camera, không thu token/cookie.
2. **Quan sát runtime storage:** trước thử, `flutter.CameraCare_ttgt-tphcm` = `[]`. Từ bản đồ Nguyễn Huệ, chọn marker Pasteur - Lê Thánh Tôn, bấm tim: key đổi thành string JSON array có một camera object (`_id=5deb576d1dc17d7c5515ad13`). Evidence trước: `storage-probe-console.txt`; sau: `storage-added.json`.
3. **Quan sát runtime storage:** force-stop rồi launcher mở lại app; cùng record vẫn có trong `storage-restarted.json`. Chứng minh dữ liệu trên disk tồn tại qua restart, chưa chứng minh UI phục hồi hoặc đồng bộ server.
4. **Quan sát runtime, giới hạn:** sau restart app ở màn khởi động lâu. REA `rea-restarted.json`, `rea-favorite-persisted.json` và XML `ui-restart-status.xml` chỉ cho thấy splash/ngôn ngữ. Tên file favorite-persisted là mục tiêu thử, không phải ảnh đã thấy favorite phục hồi. Chưa xác định nguyên nhân; không coi là bug đã chẩn đoán. Không xóa app data vì sẽ mất bằng chứng.
5. **Phép thử HTTP độc lập:** ba GET dựng từ config/record favorite/literal trả 200 với JSON/ảnh. Đây là quan sát runtime dịch vụ ngoài, không phải capture traffic app. Chi tiết trong [api-catalog.md](api-catalog.md), `evidence/camera/api-probes/`.
6. **Quan sát runtime instrumentation:** Frida 17.23.3 attach PID 9852 trước restart; inventory thấy libflutter.so/libapp.so không có exports phù hợp SSL_read/SSL_write, còn libssl.so có. Evidence: `scripts/probe-camera-frida.js`, `evidence/camera/frida-modules.txt`. Chỉ inventory, không hook HTTP, không sửa TLS; không kết luận app không dùng TLS hoặc không thể hook.

7. **Khôi phục thử nghiệm:** do UI còn ở splash, đã dùng Frida gọi SharedPreferences API của app để trả đúng singleton camera vừa thêm về `[]`. Script chỉ sửa khi array có đúng một record với `_id` thử nghiệm; không sửa cấu hình/token. `favorite-cleanup.txt` báo commit true; `storage-cleaned.json` xác nhận `flutter.CameraCare_ttgt-tphcm = []`. Script: `scripts/restore-camera-test-favorite.js`.

## Điều chỉnh spec

- Có nguồn snapshot JPEG ở ít nhất một camera; video vẫn chưa xác minh dù một số record có streamingUrl.
- Có cấu hình tenant cho base API và 16 vùng camera. Record vùng dùng `{name,coordinates:[lng,lat]}`.
- Có local storage Quan tâm theo tenant, chứa object camera, tồn tại sau restart; UI restore và sync chưa biết.
- `nextUpdate=12000` không đủ để đổi vòng đếm UI thành 12 giây. Cần đo/capture riêng.
- Nearby trả 90 camera, khoảng cách tối đa ~1847.70 dù distance query=5000; chưa biết giới hạn server, không cam kết đầy đủ 5km.

## Việc còn lại

Khi app qua splash, đo nhiều vòng refresh với timestamp và kiểm tra UI restore bằng một thử nghiệm riêng có cleanup. Capture traffic app có mục tiêu để nối data API với thao tác, kiểm tra lỗi/cache/lifecycle. Không mở rộng sang tài khoản hay tính năng khác.
