# Camera — lượt 5: đóng flow Xung quanh

Ngày 2026-10-14. Phạm vi đã hoàn thành trong lượt này: chọn vị trí thủ công → xác nhận → danh sách camera Xung quanh → mở preview. Đã đối chiếu hai lỗi độc lập của tìm kiếm/chọn vị trí. HTTP snapshot app đầy đủ vẫn chưa thu được; không đánh dấu hợp đồng backend hoàn tất.

## 1. Artifact và môi trường

- Môi trường cũ: `emulator-5554`, Android 9, x86_64, 1600×900, app runtime 5.2.1/502001 như các lượt trước.
- Môi trường đối chiếu: `emulator-5580`, Google Android 13, x86_64, 900×1600. Trước thử chưa có `com.fts.notis`.
- REA pull toàn bộ set APK từ emulator-5554: `rea-pull-runtime-pass5.json`, Evidence `ev_9b466c141f6d1b748dc639a75b6d0918cc00ebefe1b1c94f0de1845a84f674b8`; files trong `runtime-apk-set-pass5/com.fts.notis/` gồm base, hdpi, vi, x86_64.
- Cài đúng set đó lên emulator-5580. Base SHA-256 vẫn `1cef9bf94c18d37a9d83eb7de97bff8e32644b9f2d56ea86107c625d615a0f54`. Metadata REA: `rea-google-package-pass5.json` (`ev_54c60ee272aac0200e54983eb2f9225bb5323b23c608a6e1b47d34f045bd2a9f`) và `rea-google-device-pass5.json` (`ev_f5017133f6b292a5f92f935d24871bf3ee8518d2fe7d0974e912492be22c74c0`).
- Chỉ chuyển APK, không chuyển shared preferences/token/cookie/tài khoản từ emulator cũ. App mới tự khởi tạo cấu hình/dữ liệu trong lần chạy. Đã từ chối notification và giữ quyền FINE/COARSE denied trong flow thành công.

## 2. Tìm địa điểm bằng chữ: endpoint trả 404

**Quan sát runtime storage/log của app cũ:** key `flutter.ErrorLog` chứa hai record cho đường dẫn:

`https://api-thongtingiaothong.paas.ttgt.vn/ttgt-tphcm/routing/geocoding`

`code=404`, response lưu trong app: `{"statusCode":404,"message":"Route not found"}`. Record mới có timestamp `2026-10-14 13:33:44.118879`, đối chiếu lần nhập `Go Dua`; record trước ở `11:05:26.159377` khớp lượt 3. Evidence được chiết chọn lọc ở `geocoding-error-log-pass5.json`; query values, param và metadata không được giữ. Script `probe-camera-geocoding-errors.py`.

**Giới hạn:** đây là log tự lưu của app, chưa phải HTTP wire capture; không suy ra method/headers/auth, hoặc route luôn hỏng với mọi tenant/thời điểm. Kết luận cho mẫu: trang kết quả rỗng đi cùng lỗi route 404, không chứng minh địa điểm không tồn tại.

**Đầu mối tĩnh/runtime memory:** literal ARM64 `routing/geocoding?q=` tại offset `0x153261`; `geocoding-memory-pass5.jsonl` thấy URL cùng host/path trong 128MiB đầu vùng rw của process, đã bỏ query. Memory candidate tự nó không chứng minh request; kết luận lỗi dựa vào record ErrorLog có response/status.

Hai GET dựng thử tới host **api.notis.vn/v4/** là thử sai giả thuyết base URL cho geocoding và đều timeout 15 giây; không dùng chúng làm bằng chứng endpoint app. Evidence giữ tại `geocoding-probes-pass5/`; không lặp lại các probe đó.

## 3. Chọn điểm bản đồ: lỗi Geocoder trên Android 9

**Quan sát runtime bằng Frida:** thao tác chọn/pan điểm trên emulator-5554 gọi `android.location.Geocoder.getFromLocation(...,5)`. Stack có `q3.r.onMethodCall`; call ném:

`java.io.IOException: Service not Available`

Evidence: `geocoder-picker-pass5.jsonl`, `rea-pass5-picker-longpress.json`; script `observe-camera-geocoder.js` không đổi kết quả hoặc cung cấp địa chỉ giả. `Geocoder.isPresent()` trả true nhưng request vẫn lỗi, nên isPresent không đủ để chứng minh backend phục vụ được.

**Giới hạn:** batch thử gồm tap, pan/long-press, không gán chính xác call cho một gesture khi không có mốc từng thao tác. Probe Geocoder đầu tiên chỉ có isPresent, không thấy call trong cửa sổ đó; không dùng nó để kết luận app không sử dụng Geocoder.

## 4. REA/JADX xác nhận tầng xử lý

REA trên đúng runtime APK:

- Class `q3.r`: `rea-pass5-geocoder-class.json`, Evidence `ev_5149abd9bed62698967ffd8172d9f4837375202ee88d2a72ff8886c101a9b031`.
- Method `q3.r.onMethodCall`, overload 0: `rea-pass5-geocoder-method.json`, Evidence `ev_419c886efb30c1d8a850456d173ba9c8e31ff85e0edbdca555fea6eaf0db0150`; source status complete. Bản đọc có dòng tại `geocoder-onMethodCall-pass5.txt`.

**Quan sát tĩnh:** case `placemarkFromCoordinates` lấy `latitude`/`longitude` (dòng 9–11), tạo Geocoder theo locale (15), SDK <33 dùng `getFromLocation(lat,lng,5)` và chuyển IOException sang `onError` (16–20), SDK ≥33 dùng overload có listener (24). `locationFromAddress` và `placemarkFromAddress` là hai case khác; không đồng nhất chúng với route tìm kiếm chữ của app khi chưa có caller.

**Suy luận có đối chiếu:** UI chọn điểm cần kết quả reverse geocoding để có địa chỉ/nút xác nhận. Lỗi Geocoder ở Android 9 phù hợp với nút mờ; môi trường Android 13 dưới đây trả được địa chỉ và flow tiếp tục. Chưa phục hồi Dart handler/điều kiện enable button trực tiếp nên không khẳng định predicate nội bộ chính xác.

Coverage repo cho APK/source text là `not_tracked`; đã đọc trực tiếp exact method và các dòng trên bằng REA/source fallback. Không coi graph repo có coverage Dart/Java đã dịch ngược. Hook sync trên Android 13 không thấy event là phù hợp khác overload, không chứng minh không geocode. Probe async về sau không thu được callback thành công do trạng thái UI/cửa sổ thử không tương đương; bằng chứng thành công bên dưới là UI/flow.

## 5. Flow Xung quanh thành công trên Android 13

**Quan sát runtime UI trên emulator-5580:**

1. Trang chính → Camera → Xung quanh → Tìm vị trí → Chọn vị trí trên bản đồ.
2. Từ chối prompt quyền vị trí của app; chọn/pan điểm thủ công trên bản đồ.
3. Thẻ địa chỉ xuất hiện cho địa điểm công cộng trên đường Phan Đăng Lưu, nút Đồng ý chuyển xanh/hoạt động. REA `rea-pass5-google-geocoded.json`, Evidence `ev_615e07ff4981ecd868c429d0b7753fa1165b361a63b72a39957fbd801c6c8998`.
4. Bấm Đồng ý: quay về Xung quanh, trường vị trí mang địa chỉ đã chọn; tiêu đề Camera trong bán kính 5km; nhãn **Kết quả tìm kiếm 90 camera**. Layout portrait là grid hai cột. REA `rea-pass5-nearby-success.json`, Evidence `ev_bb423f8e0d8fabaa2e2315ca37e327c056858f878764702d0e489661c1da79fc`; XML `ui-pass5-nearby-success.xml`.
5. Các mục đầu: Phan Đăng Lưu - Hoàng Hoa Thám (**0.07 km**), Phan Đăng Lưu - Nơ Trang Long (**0.33 km**), Nơ Trang Long - Nguyễn Huy Lượng (**0.41 km**), Phan Đăng Lưu - Nguyễn Văn Đậu (**0.51 km**). Mẫu đầu tăng theo khoảng cách; chưa kết luận toàn bộ 90 mục luôn sort như vậy hoặc trả đủ mọi camera 5km.
6. Bấm thẻ Phan Đăng Lưu - Hoàng Hoa Thám: preview hiện đúng tên, ảnh giao thông, tim, X và counter. REA `rea-pass5-nearby-open.json`, Evidence `ev_db651d49917052345ed699b07d1482ee889996036e26a72ee6a72f10b5b6c4ae`; XML `ui-pass5-nearby-open.xml`. Thumbnail có thể tải sau text; frame đầu của grid còn vùng ảnh trắng, frame mở sau đã thấy thumbnails khác.

`google-permissions-pass5.txt` xác nhận FINE/COARSE đều -1 sau flow thành công: chọn thủ công không cần grant GPS trong mẫu này. Không dùng vị trí thật của người dùng; điểm được chọn trên bản đồ thành phố. Tái hiện bằng ADB/UI hoặc helper `camera-ui-click.py` (prefix phải khớp duy nhất; không coi click nhầm trạng thái là flow thành công).

## 6. HTTP snapshot và giới hạn công cụ

Thử native REA: `native-provider-status-pass5.json` ghi Ghidra chưa cấu hình, Hopper không hỗ trợ Windows, IDA chưa cấu hình. Không cài thêm engine hoặc đổi cấu hình toàn cục.

Thử tìm serialized request camera trong 256MiB đầu vùng rw của process Android 13: `http-memory-google-pass5.jsonl` không có candidate. Lần này UI thực ra đang vào prompt quyền ở phép thử phụ, không phải một lần truy vấn nearby được xác nhận; không dùng nó làm kết luận về traffic/HTTP protocol/cache. Query/memory probes không thay thế HTTP capture. Snapshot method/path/headers của app đầy đủ vẫn mở; các endpoint đã GET thử độc lập ở lượt 2 giữ đúng loại bằng chứng đó.

## 7. Trạng thái cuối và nghiệm thu

- Đã từ chối dialog quyền phát sinh trong phép thử phụ; `google-permissions-final-pass5.txt` xác nhận FINE/COARSE vẫn -1. Không bật dịch vụ GPS hoặc thêm mock location.
- Không thêm camera Quan tâm, không thay tenant/backend config hoặc giả địa chỉ Geocoder. App test mới vẫn được cài trên emulator-5580 để tái hiện sau; đã force-stop để dừng network. Không gỡ/xóa dữ liệu app gốc emulator-5554.
- Flow Xung quanh đã đạt kiểm tra: chọn vị trí → xác nhận → danh sách có tên/khoảng cách → mở được camera. Lỗi nhập chữ 404 và lỗi reverse geocoding ở Android 9 được giữ thành nhánh lỗi riêng.
- Còn mở: snapshot HTTP app đầy đủ, pagination/cap 90, cache/auth/sync và LIVE phát thành công. Không đánh dấu các mục này đã hoàn tất.
