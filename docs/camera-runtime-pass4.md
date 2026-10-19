# Camera — lượt xác minh runtime 4

Ngày 2026-10-14. Cùng artifact runtime `runtime-base.apk` SHA-256 `1cef9bf94c18d37a9d83eb7de97bff8e32644b9f2d56ea86107c625d615a0f54`. Thiết bị `emulator-5554`, Android 9, x86_64, 1600×900. Phạm vi: lifecycle snapshot, LIVE và nhánh quyền/provider vị trí. Evidence nằm trong `evidence/camera/`; REA IDs đầy đủ trong evidence-index.md.

## 1. Camera khi app vào nền

**Quan sát runtime socket**, PID 13560:

| Giai đoạn | Thời lượng | Write tới 109.237.69.7:443 trong các hooks |
|---|---:|---:|
| Khung snapshot Pasteur đang mở | 18 giây | 2 |
| Bấm Home, app ở nền | 30 giây | 0 |
| Launcher mở lại app | 18 giây | 4, gồm các write 249/64/159 bytes sát nhau và một write 159 bytes tiếp theo |

Write đầu sau mốc `resumed-start` khoảng **0,052 giây**. Các write 159 bytes trước/sau nền vẫn phù hợp nhịp khoảng 12 giây. Đây là metadata socket, không định danh request HTTP. Kết luận được giới hạn: **không quan sát tải tới host camera qua các hooks này trong 30 giây nền; tiếp tục gửi khi resume**. Không suy ra mọi tác vụ nền/mọi host đều dừng.

Evidence: `lifecycle-pass4.json` chứa mốc trước/sau thao tác, `socket-lifecycle-pass4.jsonl`, `lifecycle-summary-pass4.json`. Tái hiện: mở snapshot → chạy `observe-camera-sockets.js` và `probe-camera-lifecycle.py`; tổng hợp bằng `summarize-camera-lifecycle.py`. Đã detach hooks sau timeout, không để lại agent thường trú.

## 2. LIVE có UI và nguồn riêng

**Quan sát runtime UI:** camera **Võ Văn Kiệt - Ký Con** có nút **LIVE** trong hàng tên của preview (`rea-pass4-kycon-preview.json`). Camera Pasteur ở mẫu không có nút LIVE tương ứng. Bấm LIVE ở Ký Con: vùng ảnh chuyển sang spinner và chữ **Đang tải**, không thấy video phát trong frame đầu và frame sau (`rea-pass4-live.json`, `rea-pass4-live-later.json`).

**Quan sát API probe từ lượt 2:** record Ký Con `_id=56de42f611f398ec0c481287` có `values.streamingUrl` là `http://camera.thongtingiaothong.vn/s/56de42f611f398ec0c481287/index.m3u8`. Đây là đường dẫn playlist HLS theo tên `.m3u8`; chưa tải nội dung playlist nên định dạng thực/codec/segments chưa được xác minh.

**Quan sát runtime bằng Frida:** hook chọn lọc host media, không thu query values hoặc headers bí mật:

- `java.net.URL.openConnection` được gọi với đúng URL trên.
- `com.android.okhttp.internal.huc.HttpURLConnectionImpl.setRequestMethod` nhận **GET**.
- Stack gồm `p1.p.p → p1.p.r → p1.p.s → p1.m.s → p1.z.s → p1.j.a → L1.r.e → L1.k.run` theo danh sách stack trả về (callee ở đầu; xem raw để đối chiếu hướng).

Evidence: `java-media-pass4.jsonl`, `java-media-http-pass4.jsonl`; script `observe-camera-media-java.js`. Bản `java-media-method-pass4.jsonl` dùng hook lớp base không ghi được setRequestMethod; bản `java-media-http-pass4.jsonl` hook implementation mới xác nhận GET. Không dùng việc hook vắng event làm kết luận method không được gọi.

## 3. Nguyên nhân LIVE không phát trong mẫu

**Quan sát runtime log:** `media-errors-pass4.txt` có ExoPlayer Source error và nguyên nhân:

`java.io.IOException: Cleartext HTTP traffic to camera.thongtingiaothong.vn not permitted`

Flutter ghi `PlatformException(VideoError, Video player had error ... Source error ...)`. Vì vậy đã xác nhận **attempt GET playlist bị chặn bởi cleartext policy**, chưa phải request thành công tới server, chưa có HTTP status/response. Không mô tả stream đã phát hoặc server media bị hỏng.

**Quan sát tĩnh trên đúng runtime APK qua REA/JADX:**

- `rea-runtime-package-pass4.json`, Evidence `ev_88544dd495d4175f4e9b6075e1ddc15b01d2129f564f15f2bb85e4ee47643bd4`: decoded manifest lưu tại `runtime-AndroidManifest-pass4.xml`, dòng 99: `android:usesCleartextTraffic="false"`.
- `rea-pass4-media-class.json`, Evidence `ev_c69c69e8a5b0a2604a177c8008043b65cf5642b2047987b05ebf3dae94b076b5`: inventory `p1.p` có method `p(URL,int,byte[],long,long,boolean,boolean,Map):HttpURLConnection`, overload 0.
- `rea-pass4-media-method.json`, Evidence `ev_90ef8627f015f05c7b82b639c2b333939679d45ab20823ff2a11002eb038e043`: method gọi `url.openConnection()`, gán connect/read timeout từ fields, ghép request properties, hỗ trợ Range và Accept-Encoding, map method int `1→GET`, `2→POST`, `3→HEAD`, rồi `connect()`. Các header và timeout cụ thể của lần chạy chưa được thu; không điền từ pseudocode chung.

**Suy luận có đối chiếu:** URL HTTP từ dữ liệu, manifest false và lỗi policy runtime cùng giải thích nhánh tải LIVE thất bại. Đã không thay TLS/cleartext policy để ép phát video. Spec app mới cần nguồn HTTPS được phép dùng, trạng thái loading/error có timeout và lối quay về snapshot.

Giới hạn caller: đã nối được UI LIVE với URL/method và caller Java thông qua thao tác/hook/log; Dart handler và Flutter channel cụ thể chưa xác định. Tên obfuscated chỉ áp dụng cho artifact này. `check_index_coverage` của APK và JSON method trả freshness `not_tracked`; dùng REA đọc trực tiếp exact artifact/method, không coi graph repo có coverage Java/Dart. Decompiled display types/offsets có giới hạn của JADX; không gán class tên rõ ràng chỉ từ suy đoán library.

## 4. Cấu hình bản đồ và quyền vị trí

**Quan sát runtime storage:** `map-config-pass4.json` trích chọn lọc từ tenant/config:

- `tileBaseMap = https://bando.tphcm.gov.vn/service/gisp/tile/HCMGIS/{z}/{x}/{y}`.
- `map.minZoom=8`, `map.maxZoom=17`, có center/pan boundary/maxBounds. Đây là cấu hình chung tenant, chưa xác minh màn Camera áp dụng mọi giá trị.
- `url-api-search-address=null`, `url-api-busmap=null`, `url-api-busmap-2=null`. Không đủ để kết luận tìm kiếm không có provider hoặc null gây lỗi; có thể có fallback.

Script `probe-camera-map-config.py` chỉ lưu field liên quan và che key nhạy cảm. Đây là giá trị runtime storage, không phải request tile/search đã capture.

**Quan sát runtime quyền:**

1. Trước thử, `checkSelfPermission` trả -1 cho cả FINE/COARSE (`permissions-pass4.txt`).
2. Xung quanh → Tìm vị trí → Chọn vị trí trên bản đồ → app prompt Đồng ý → Android dialog CHO PHÉP (`rea-pass4-location-prompt.json`, `rea-pass4-android-permission.json`).
3. Sau bấm CHO PHÉP, cả hai permission trả 0 (`permissions-allowed-pass4.txt`). Android tiếp tục hiện dialog yêu cầu bật vị trí/độ chính xác (`rea-pass4-location-allowed.json`). Điều này cho thấy quyền app và cấu hình dịch vụ vị trí là hai trạng thái riêng.
4. Chọn Không, cảm ơn ở dialog dịch vụ; không bật hoặc thay cấu hình vị trí toàn thiết bị. Bấm điểm bản đồ vẫn có chấm tím, nút Đồng ý mờ; chưa xác nhận chọn vị trí thành công (`rea-pass4-location-provider-off.json`). `settings get secure location_mode` trả null; không suy ra con số mode cụ thể từ đó.
5. Thu hồi đúng FINE/COARSE đã cấp thử qua `pm revoke`, launcher mở lại, `checkSelfPermission` xác nhận cả hai về -1 (`permissions-restored-verified-pass4.txt`). Danh sách Quan tâm vẫn `[]` (`storage-cleaned-pass4.json`). Trạng thái grant đã trả về ban đầu; không khẳng định các permission flags/lịch sử prompt bit-for-bit giống trước thử.

Chưa thử bật dịch vụ vị trí, GPS/mock location, geocoding trả địa chỉ, nút xác nhận hoạt động và danh sách camera Xung quanh có dữ liệu. Không coi việc cấp quyền đơn lẻ là đủ cho flow thành công.

## 5. Yêu cầu tái dựng được bổ sung

- Snapshot: dừng lịch tải khi app ở nền, resume tải lại và tiếp tục nhịp cấu hình; nghiệm thu bằng network stub có timestamp.
- Media: phân biệt snapshot và nguồn LIVE theo metadata; có loading/error/timeout, đóng được và quay về snapshot. Nguồn HTTPS và quyền sử dụng phải được xác minh riêng.
- Vị trí: tách trạng thái permission denied, permission granted nhưng provider chưa sẵn sàng, vị trí đang lấy, chọn thủ công và xác nhận điểm. Cần giải thích nút xác nhận disabled và cho phép người dùng tiếp tục bằng vị trí thủ công khi phù hợp.

Phần mở: Dart caller/snapshot HTTP app đầy đủ, LIVE phát thành công/codec/seek/fullscreen, nguồn geocoding và flow Xung quanh hoàn chỉnh, auth/cache/pagination/sync. Không đánh dấu các phần này hoàn tất.

Lưu ý công cụ: hai lần dump XML khi cuộn sheet Khu vực báo `null root node`; `ui-pass4-area-scroll.xml` và `ui-pass4-area-scroll2.xml` là file cũ được pull lại, không dùng chứng minh trạng thái sau cuộn. Điều hướng sau đó dựa trên screenshot REA hiện thời. Các file kiểm tra permission ban đầu bị ghi thiếu trong lần launcher chưa có PID đã được chạy lại; bản xác minh cuối có hai dòng result -1.
