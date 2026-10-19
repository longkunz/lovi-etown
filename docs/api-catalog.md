# API catalog — camera

## Cập nhật lượt 7 — request thực sự của app

**Phần này thay thế trạng thái “chưa capture request app” trong các mục lịch sử phía dưới.** Đã đọc thụ động plaintext ở native Flutter của đúng runtime artifact, đối chiếu method/host/path/header names/response với từng flow. Không đổi TLS hoặc giữ credential values. HAR dẫn xuất đã được REA đọc: `ev_e83f5decb7d2b302bacd89bc87d1f38766b2e49bc5870461f745effc816f0ca8`. Phương pháp, phạm vi, giới hạn và log gốc đã che nằm trong [camera-api-debug-pass7.md](camera-api-debug-pass7.md).

| ID | Base / method / path | Mục đích, caller / input | Auth/header quan sát | Response/cache/lỗi / trạng thái |
|---|---|---|---|---|
| C-08 | `https://api-thongtingiaothong.paas.ttgt.vn` GET `/tenants` | Bootstrap; body không có; native boundary `libflutter.so+0x7fb4df`; Dart caller chưa biết | Nhóm header tenant/device/app; có và không Bearer theo hai phiên; không giữ values | 200 JSON array/gzip/chunked/weak ETag. **Body app** có `config.url-api-camera`, 16 `config.area-camera`. TTL/retry chưa biết |
| C-09 | Cùng host GET `/ttgt-tphcm/configs/homepage` | Shared entry/menu trang chính; không body; cùng native boundary | Header như C-08, khác Authorization theo phiên | 200 object header/menu/addons; gzip/chunked/weak ETag; đã thu body shape; không coi đây là API camera chuyên biệt |
| C-01 | `https://api.notis.vn` GET `/v4/cameras/bybbox` | Vào/pan bản đồ, chọn khu vực; query `lat1,lng1,lat2,lng2`; không body | Header tenant/device/app + Bearer trong mẫu đầy đủ | 200 JSON array; body app mẫu 262/209/8; weak ETag, gzip/chunked. Pagination/TTL chưa biết |
| C-02 | Cùng host GET `/v4/cameras` | Xung quanh; query thực tế `lat=10.778401&lng=106.695975&distance=5000`; không body | Header tenant/device/app + Bearer | 200 JSON/gzip/chunked/weak ETag; UI 90. Body schema trước từ probe; phân trang/cap/độ đầy đủ vẫn mở |
| C-04 | Cùng host GET `/v4/cameras/{_id}/snapshot` | Thumbnail/preview/refresh; không body/query mẫu; native boundary như trên | Chỉ `user-agent,accept-encoding,host`; không Authorization/cookie trong request mẫu | 200; header đầy đủ có chunked, Set-Cookie đã bỏ value; không thấy Content-Type/ETag/Cache-Control ở mẫu. JPEG từ probe; chưa giữ runtime ảnh. Không thấy conditional header; cache contract chưa biết |
| C-05 | Chưa thấy API sync riêng | Add/remove local `CameraCare_ttgt-tphcm` | Window thao tác đã thu native Flutter | Từ trước add đến ~40 giây sau remove chỉ thấy GET ảnh; không chứng minh mọi account/state đều không sync |
| C-07 | `https://api-thongtingiaothong.paas.ttgt.vn` GET `/ttgt-tphcm/routing/geocoding` | Tìm chữ; query `q` che; không body; cùng native boundary | Header tenant/device/app + Bearer | 404 Not Found; JSON content-length 46/weak ETag. Đã xác nhận method bằng traffic plaintext app |
| C-06 | HTTP media như lượt 4 | LIVE Ký Con; Java `p1.p.p`, REA method `ev_90ef8627f015f05c7b82b639c2b333939679d45ab20823ff2a11002eb038e043` | Headers chưa thu | Attempted GET bị cleartext chặn; chưa playlist/segment/codec thành công |

Header gửi không có nghĩa bắt buộc ở server. Probe không credentials vẫn 200 không mâu thuẫn việc app gửi Bearer. DTO body bbox app có optional `videoUrl` dạng string ở một item đầu, chưa giữ URL value hoặc xác minh cách app dùng. Shape array chỉ item đầu, không phải mọi item.

G-01 vẫn là Android Geocoder, host hệ thống chưa thu. Tile HCMGIS mới có cấu hình, chưa capture request. C-03 `/transit/cameras?routeId=` vẫn literal runtime x86_64 offset `0x82be9`, chưa nối với màn Camera. Sync account, saved-address/history, LIVE con, Dart handler và contract pagination/cache/retry đầy đủ còn mở. **Không tuyên bố catalog exhaustive mọi trạng thái.**

## Cập nhật lượt 6 — snapshot và phạm vi nearby

**Probe HTTP độc lập, không phải traffic app**, 2026-10-14 08:33:26 UTC; base `https://api.notis.vn/v4/`, GET không body/Authorization/cookie; caller là `scripts/probe-camera-contract.py`, Dart caller vẫn chưa biết. Bằng chứng `evidence/camera/contract-pass6/`, chi tiết [camera-contract-pass6.md](camera-contract-pass6.md).

| API | Kết quả mới | Cache/lỗi/auth và giới hạn |
|---|---|---|
| C-04 `cameras/5deb576d1dc17d7c5515ad13/snapshot` | 200, 48.800 bytes, JPEG magic; hash trong `snapshot.json` | Không có header content/cache trong tập được giữ qua urllib; chưa xác minh TTL/revalidation. Không gửi credentials vẫn thành công ở mẫu; auth app/headers bắt buộc chưa biết |
| C-02 `cameras?lat=10.775708&lng=106.700359&distance=500` | 10 record, xa nhất tính từ tọa độ ~497,80 m | JSON/weak ETag; chưa thử 304 hoặc lỗi |
| C-02 cùng tâm, `distance=5000` và `10000` | Cùng 89 record/thứ tự ID/body hash; distance tăng dần, xa nhất ~1845,64 m | `limit=5` và `limit=5&page=2` cũng trả cùng body. Không xác minh được cơ chế phân trang; không kết luận mọi tham số phân trang đều vô hiệu |
| C-01 bbox `10.73,106.65 → 10.82,106.75` | 342 record; Haversine có 290 trong 5000 m, 201 ID không có trong nearby | Quy tắc chọn khác nhau giữa endpoint chưa biết. Không cam kết nearby đầy đủ trong 5km |

**Suy luận có giới hạn:** không hardcode 90 từ các mẫu trước. Khoảng cách response gần phép tính Haversine (lệch tối đa ~2,06 m trong mẫu) củng cố đơn vị mét, chưa xác nhận công thức server. Chưa capture snapshot/nearby HTTP app, chưa khôi phục Dart handler. Đây là kết quả probe, không phải hợp đồng backend đã đóng.

## Cập nhật lượt 5 — tìm kiếm và reverse geocoding

| ID | Host/interface, method/path | Tính năng/caller | Tham số/body/auth | Response/cache/lỗi | Bằng chứng/trạng thái |
|---|---|---|---|---|---|
| C-07 | `https://api-thongtingiaothong.paas.ttgt.vn/ttgt-tphcm/`; `routing/geocoding`; method app chưa xác nhận | Nhập địa điểm bằng chữ; Dart caller chưa biết | Query key `q` trong URL log; giá trị đã che; body/headers/auth chưa biết | App lưu `code=404`, response `{"statusCode":404,"message":"Route not found"}` trong hai lần thử; cache/retry chưa biết | Runtime ErrorLog `geocoding-error-log-pass5.json`, không phải wire capture |
| G-01 | Android `Geocoder.getFromLocation` (interface hệ điều hành, không phải endpoint HTTP app đã biết host) | Reverse điểm chọn trên bản đồ; `q3.r.onMethodCall`, case `placemarkFromCoordinates` | latitude, longitude, maxResults=5; SDK <33 sync, ≥33 listener; backend/auth hệ thống chưa biết | Android 9 IOException Service not Available; Android 13 flow UI nhận địa chỉ và xác nhận được. List/address serialization đầy đủ/cache chưa thu | Runtime stack `geocoder-picker-pass5.jsonl`; REA `ev_419c886efb30c1d8a850456d173ba9c8e31ff85e0edbdca555fea6eaf0db0150` |

**Quan hệ với camera:** chọn điểm thành công trên Android 13 dẫn tới grid Xung quanh có 90 camera, khoảng cách km và mở preview được. Chưa capture HTTP nearby/snapshot app đầy đủ để gán method/headers/caller chính xác cho C-02/C-04; GET độc lập lượt 2 vẫn giữ đúng loại bằng chứng probe.

Không dùng base camera api.notis.vn/v4 cho route C-07 chỉ vì cùng app. Hai phép thử dựng trước khi tìm ra host thật đều timeout và được giữ như thử giả thuyết không thành công, không ghi thành API app. `url-api-search-address=null` không tự chứng minh fallback hoặc nguyên nhân lỗi. Chi tiết: [camera-runtime-pass5.md](camera-runtime-pass5.md).

## Cập nhật lượt 4 — nguồn LIVE từ app

| ID | Host / method / path | Mục đích/caller | Params/auth/body | Response/cache/lỗi | Bằng chứng/trạng thái |
|---|---|---|---|---|---|
| C-06 | `http://camera.thongtingiaothong.vn`; attempted GET `/s/{camera_id}/index.m3u8` | LIVE Ký Con; stack Java `p1.p.p`, `p1.p.r`, `p1.p.s`, `p1.z.s`, `L1.r.e` | ID `56de42f611f398ec0c481287`; URL không có query; headers/auth/body cụ thể chưa thu | Không có HTTP response: local Android cleartext policy chặn trước tải; ExoPlayer Source error/Flutter VideoError; cache chưa biết | Hook `java-media-http-pass4.jsonl`, `media-errors-pass4.txt`; REA method `ev_90ef8627f015f05c7b82b639c2b333939679d45ab20823ff2a11002eb038e043` và runtime manifest `ev_88544dd495d4175f4e9b6075e1ddc15b01d2129f564f15f2bb85e4ee47643bd4` |

C-06 là method/URL app thực sự cấu hình để gọi, chưa phải HTTP request thành công trên wire. Đuôi m3u8 gợi ý HLS; nội dung playlist chưa được thu. Không mở rộng kết luận sang hai streamingUrl khác ở response probe.

Lượt 4 còn xác nhận cửa sổ 30 giây app nền không có write tới IP host snapshot trong hooks và resume tải lại. Cấu hình tile tenant `https://bando.tphcm.gov.vn/service/gisp/tile/HCMGIS/{z}/{x}/{y}` chưa được capture request; `url-api-search-address=null` không đủ chứng minh tìm kiếm không có fallback. Chi tiết: [camera-runtime-pass4.md](camera-runtime-pass4.md).

> **Cập nhật lượt 2:** các kết quả mới bên dưới thay thế trạng thái “chỉ đầu mối tĩnh” ở phần lịch sử phía sau. Chưa capture request do app gửi.

## Kết quả xác minh lượt 2

**Bổ sung lượt 3:** Quan tâm đã phục hồi trên UI sau process restart. Socket app PID 13560 gửi đến `109.237.69.7:443` với nhịp ~11.845/12.006 giây khi mở camera; DNS từ máy điều tra cho api.notis.vn trùng IP. Chưa đọc payload, không định danh path/method từng write. UI cũng có chu kỳ ~12 giây trong mẫu; vẫn chưa nối việc sử dụng `status.nextUpdate` bằng code. Xem [camera-runtime-pass3.md](camera-runtime-pass3.md).

**Quan sát runtime storage:** `evidence/camera/storage-added.json` và `storage-restarted.json` chứa cấu hình tenant `config/url-api-camera = https://api.notis.vn/v4/`, `config/area-camera` gồm 16 khu vực. Đây là cấu hình được lưu, chưa tự chứng minh app gọi host trong phiên UI.

**Phép thử HTTP độc lập:** `scripts/probe-camera-api.py` tạo ba GET, không gửi Authorization/cookie, lúc 03:35:11 UTC ngày 2026-10-14. Bằng chứng response và hash ở `evidence/camera/api-probes/`. Không phải traffic capture của app; Dart caller chưa xác định.

| ID | Base URL / method / path | Params / body của probe | Kết quả probe | Quan hệ tính năng / giới hạn |
|---|---|---|---|---|
| C-01 | `https://api.notis.vn/v4/` GET `cameras/bybbox` | `lat1=10.770&lng1=106.695&lat2=10.780&lng2=106.705`; không body | 200, JSON array 18 camera, weak ETag | Suy luận truy vấn camera cho bản đồ; chưa nối caller app |
| C-02 | Cùng base, GET `cameras` | `lat=10.775708&lng=106.700359&distance=5000`; không body | 200, JSON array 90 camera, weak ETag | Mẫu tăng dần distance, max ~1847.70; chưa biết giới hạn/phân trang, không cam kết đủ 5km |
| C-04 | Cùng base, GET `cameras/{_id}/snapshot` | `_id=5deb576d1dc17d7c5515ad13`; không body | 200, 52.554 bytes, JPEG magic `ffd8ffe000104a4649460001` | Relative URL có trong record Quan tâm; đã kiểm chứng một ảnh. Không thu được header content/cache trong probe này |
| C-05 | Chưa xác nhận API đồng bộ | Local key `flutter.CameraCare_ttgt-tphcm` | String JSON array chứa object camera, tồn tại trên disk sau restart | Chứng minh có local storage; không chứng minh chỉ lưu local |

GET và việc không gửi credentials chỉ được xác nhận cho probe. Quy tắc auth đầy đủ, TTL/cache, retry, lỗi và phân trang vẫn chưa biết. Không coi HTTP 200 là quyền dùng API trong sản phẩm mới.

### Response schema quan sát từ probe

Array ngoài cùng chứa object camera, không có envelope trong hai response mẫu:

| Field | Kiểu / ví dụ | Ý nghĩa và giới hạn |
|---|---|---|
| `_id` | string `5deb576d1dc17d7c5515ad13` | Có trong snapshot path; khác mã hiển thị `id` |
| `id` | string `ITS 7.52` | Mã camera hiển thị |
| `name`, `dist` | string | Tên camera, địa bàn |
| `loc.type`, `loc.coordinates` | `Point`, `[106.700359,10.775708]` | Thứ tự `[longitude,latitude]` phù hợp vị trí/cấu hình |
| `angle` | number hoặc null/vắng | Không tự mặc định 0 |
| `ptz` | boolean | Không chứng minh app cho điều khiển PTZ |
| `values` | object, có `ip`, có thể `channel`, `streamingUrl` | Không kết nối trực tiếp IP camera; có field không đồng nghĩa có UI tương ứng |
| `liveviewUrl` | `cameras/{_id}/snapshot` | Relative URL; đã thử với base cấu hình |
| `distance` | number trong nearby, 0 ở tâm | Mét là suy luận từ query/vị trí, chưa có hợp đồng đơn vị |
| `status.responseTime` | number, mẫu 681 | Đơn vị chưa xác minh |
| `status.imageTs` | ISO timestamp, mẫu `2026-10-14T03:32:20.826Z` | Chưa biết timestamp chụp hay thời điểm backend xử lý |
| `status.nextUpdate` | number; cả 90 record mẫu = 12000 | Chưa xác minh đơn vị/ý nghĩa, không đổi timer UI thành 12 giây từ field này |
| `status.numberOfRetry` | number, mẫu 1 | Chưa biết retry phía nào |

Trong 90 camera nearby, 3 record có `values.streamingUrl` khác rỗng; chưa truy cập stream hoặc xác minh phát video trong app. Record Quan tâm local chứa `_id`, `id`, `name`, `dist`, `angle`, `values`, `loc`, `ptz`, `distance`, `liveviewUrl`, không chỉ ID. Việc metadata favorite có cập nhật theo backend hay không chưa biết.

## Lịch sử lượt 1

Ngày: 2026-10-14. Trạng thái: **đầu mối quan sát tĩnh**, chưa có request network quan sát được. Artifact và runtime khác SHA-256; xem [camera-spec.md](camera-spec.md).

Nguồn L: `evidence/camera/native-string-candidates.json`, được trích từ bản sao `libapp.so` có SHA-256 `c7aac93feddc21001c7eb838747b3d0cf9cc764ff6e04edb94249e9d103d5900`. Provenance trích xuất REA: `ev_c9cf7fc7945dd4a8f7496364f61a04f25325687c3540d88aaf8b7cc3aabccb0a`. Các literal bên dưới do script đọc bytes, không phải kết quả xác định caller của REA.

| ID | Host/base URL | Method | Path literal | Tham số/body | Mục đích / quan hệ tính năng | Caller | Bằng chứng / trạng thái |
|---|---|---|---|---|---|---|---|
| C-01 | Chưa biết | Chưa biết | `cameras/bybbox?lat1=` | Chỉ thấy prefix `lat1`; có literal `&lng1=` ở nơi khác, chưa nối được; body chưa biết | Suy luận truy vấn camera theo bounding box, có thể dùng cho bản đồ | Chưa biết | L `0xbc85f`, `0xab6e3`; chỉ literal |
| C-02 | Chưa biết | Chưa biết | `cameras?lat=` | Chỉ thấy prefix `lat`; các tham số khác/body chưa biết | Suy luận truy vấn theo tọa độ, có thể phục vụ Xung quanh | Chưa biết | L `0xc1cbb`; chỉ literal |
| C-03 | Chưa biết | Chưa biết | `/transit/cameras?routeId=` | Chỉ thấy prefix `routeId`; body chưa biết | Suy luận camera theo tuyến transit; chưa xác nhận thuộc màn Camera đang điều tra | Chưa biết | L `0x82a9c`; chỉ literal |
| C-04 | Chưa biết | Chưa biết | URL ảnh/stream chưa lấy được | Chưa biết | UI đã hiển thị ảnh camera thay đổi; chưa bắt request của nguồn ảnh | Chưa biết | Runtime PREVIEW/DETAIL/REFRESH trong camera-spec; endpoint chưa xác minh |
| C-05 | Chưa biết, có thể không có API | Chưa biết | Chưa biết | Chưa biết | Thêm/xóa Quan tâm hoạt động trong UI; chưa biết local hay backend | Chưa biết | Runtime ADD/REMOVE; API chưa xác minh |

**Cho tất cả các mục:** xác thực, response schema, phân trang, TTL/cache, timeout/retry và cấu trúc lỗi **chưa biết**. Không suy ra GET chỉ từ dấu `?`, không suy ra không cần auth vì URL không có token.

Literal cấu hình `url-api-camera` ở `0x135ae0` và `area-camera` ở `0x16a586` là đầu mối để tìm cấu hình runtime, không phải endpoint. Literal `https://api.metrohcm.ttgt.vn/` ở `0xbe180` chưa có xref nối với C-03; không gán làm base URL camera.

Phân loại: C-01/C-02 là ứng viên endpoint nghiệp vụ camera; C-03 là ứng viên transit; C-04 là nguồn media; C-05 chưa xác định có network. Chưa có cơ sở phân loại host camera là dịch vụ nội bộ hay bên thứ ba. Không điều tra telemetry/quảng cáo ngoài phạm vi.

Để đóng catalog: capture có mục tiêu với từng thao tác, đối chiếu timestamp/UI, lưu request/response đã che token/cookie/dữ liệu cá nhân; xác định quyền nguồn dữ liệu cho app mới độc lập với app gốc.
