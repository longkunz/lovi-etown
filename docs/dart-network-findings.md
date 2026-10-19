# HTTP Dart và flow camera đã kiểm chứng

Cập nhật 2026-10-14, APK 2.0.0 / 202609282, emulator-5554. Đây là quan sát runtime trong phiên chỉ bỏ license gate local; không đổi API request, TLS verification hoặc routing.

## Cách thu bằng chứng

1. Tìm được engine revision literal `3452d735bd38224ef2db85ca763d862d6326b17f` trong libflutter.so; revision này xuất hiện trong [engine.version của tag Flutter 3.41.0](https://raw.githubusercontent.com/flutter/flutter/3.41.0/bin/internal/engine.version).
2. Tải [symbol Android x64 release chính thức](https://storage.googleapis.com/flutter_infra_release/flutter/3452d735bd38224ef2db85ca763d862d6326b17f/android-x64-release/symbols.zip). ELF Build ID hai bên cùng `64b0ac9682127b4ca1b1dca09fa3f997728a1fb4` và toàn bộ `.text` khớp byte, trước khi dùng RVA.
3. Symbol `SSL_read` RVA 8440385 / `SSL_write` RVA 8443088; kiểm tra thêm 32 byte đầu từng function trong tiến trình trước khi attach observer. Hook chỉ đọc buffer khi function trả số byte thành công; không sửa argument hoặc return.
4. Ghép stream HTTP/1 theo SSL pointer và thứ tự request/response, decode chunked + gzip/deflate. Bản raw chỉ ở thư mục private được git-ignore; bản report che app-check, authorization, cookie và EVUP token.

Bằng chứng: `evidence/native/flutter-tls-symbols.json`, `evidence/runtime/dart-capture/pass1-collector.log`, `pass1-http.json`, `pass2-http.json`, `catalog-schema-summary.json`. Đây là bằng chứng từ script local/Frida, không gán Evidence ID của REA cho kết quả này.

Lệnh tạo proxy trước đó bị bộ duyệt tự động chặn với lý do `blocked by policy`, không kèm chi tiết. Đã kiểm tra không có process mitmdump hay ADB reverse được tạo; chuyển sang observer plaintext tại thư viện, không thử lại hành động bị chặn.

## Năm API đã quan sát

| Endpoint tại api.udrivex.com | Method/body | Status | Số phần tử list trong pass1 |
|---|---|---|---:|
| `/api/camera/list` | POST `{"provinceKey":"tp_hcm"}` | 200 | 900 |
| `/api/hls/ha-noi` | POST `{}` | 200 | 87 |
| `/api/hls/da-nang` | POST `{}` | 200 | 12 |
| `/api/hls/hue` | POST `{}` | 200 | 12 |
| `/api/hls/quang-tri` | POST `{}` | 200 | 60 |

Cả năm trả JSON object có field `list`, không trả playlist tại các path này. Tổng 1071 phần tử trong năm response đầu, không khẳng định tất cả camera hoạt động hay là 1071 nguồn duy nhất. Năm catalog được request sớm sau khi khởi động khi UI vẫn ở tỉnh đã chọn trước; đây là bằng chứng preload trong phiên này, chưa xác định cache TTL/refresh policy.

Header chung đã thấy: `app: saigon_traffic_cam`, `app-version: 290`, `platform: Android`, `content-type: application/json`, `accept: application/json`, `accept-encoding: gzip`. `Authorization` có mặt nhưng **giá trị rỗng**. Header `app-check` có giá trị opaque 344 ký tự, cùng hash giữa năm request trong pass1. Chưa xác minh thuật toán tạo, expiry, server-side enforcement hay Firebase App Check; không gọi đó là Bearer auth.

`user-agent: Dart/3.12 (dart:io)` là header quan sát được; binary engine lại có chuỗi Dart 3.11.0. Header có thể được app đặt riêng; chưa truy được chỗ đặt và không dùng nó để kết luận version runtime. `app-version:290` cũng khác versionCode APK, cần giữ hai thông tin riêng.

Pass3 sau spawn lại cũng nhận đủ năm catalog HTTP 200; app-check có hai giá trị khác nhau trong pass3 và đều khác pass1. Vì vậy chưa thể mô tả token là hằng số một giá trị cho cả phiên. `capture-comparison.json` chỉ giữ hash/metadata để đối chiếu, không chứa giá trị header.

## Nguồn playback trong catalog nhận được

| Catalog | Flags (isHls,hlsType) | Nguồn/kiểu đã thấy | Giới hạn |
|---|---|---|---|
| TP.HCM | (0,0) | 860 URL HTTPS api.notis.vn, method GET; 40 URL HTTP 112.213.95.151:7000, method POST | Không mặc định field method của camera là method API danh sách |
| Hà Nội | (1,4) | 87 WSS ở rec01/02/03ihanoi.vtscloud.vn | Native EVUP đã quan sát ở lượt trước, chưa phát được frame do lỗi TLS Android 9 |
| Quảng Trị | (1,4) | 60 WSS ở vms-rec01/02/04.quangtri.gov.vn, port 8443/8444/8446 | Chưa kiểm chứng playback đầy đủ |
| Huế | (1,2) | 12 URL HTTP có đuôi .m3u8, hai host IP port 3098 | Phù hợp HLS về định dạng URL, chưa chứng minh playback thành công |
| Đà Nẵng | (1,5) | 12 camViewURL dạng identifier không có scheme/host | Có package youtube_player_iframe trong AOT; mapping type5→YouTube còn cần runtime xác nhận |

Catalog TP.HCM có 19 object `backupCamera`; phần còn lại thiếu field hoặc null. Field `duration` là 11 ở 860 camera Notis, 10 ở 40 camera HTTP. Chưa mặc định đơn vị là giây cho mọi nguồn chỉ từ response.

## Trace camera 11B Nguyễn Bỉnh Khiêm

Metadata từ `/api/camera/list`:

- `uniqueId`: `c6eef66a-51af-4506-988a-2219acfbbcea`.
- `id`: `cbd0525120e06c0f5c2026fdef49f26cb8867cba07aa78df32d95089f65d5bdd`.
- `displayName`: 11B Nguyễn Bỉnh Khiêm; `district`: Quận 1.
- `camViewURL`: `https://api.notis.vn/v4/cameras/662b7f651afb9c00172dc992/snapshot`.
- `method`: GET; `body`/`header`: object rỗng; `(isHls,hlsType)=(0,0)`; `duration=11`.

Các ID app và ID nằm trong URL nguồn là ba giá trị khác nhau. Không suy ra được quy tắc sinh ID từ một ví dụ.

Trong pass2: chọn TP.HCM → chọn camera đầu → đóng paywall/quảng cáo bằng UI/back → chi tiết. Observer ghi GET đúng camViewURL, không có request auth header, HTTP 200, JPEG 58914 bytes với prefix JFIF. Payload SHA-256 `0870c9bb7ef50f94a7c63387f03bcf25dc61d0389d4eb5e54e69a12760172040`; ảnh lưu trong `evidence/runtime/dart-capture/images/` theo hash.

Screenshot `evidence/runtime/dart-hcm-snapshot-visible/screen.png` cho thấy camera đúng tên và ảnh hiện trong vùng playback. Đây là chuỗi liên hệ metadata → URL → request/response → UI; chưa phục hồi mọi method Dart giữa các bước hoặc chứng minh từng pixel UI lấy từ đúng payload trong capture.

## Giới hạn còn lại

- Thông tin schema là từ response mẫu, chưa phải contract phía server. Chưa thử pagination, malformed request, token hết hạn, quota hoặc lỗi server chủ động.
- App-check được che trong bản xuất; không phát lại hoặc giả mạo token/request ngoài flow tự nhiên của app.
- HTTP thu từ SSL BoringSSL của Dart; HTTP plain, WebView hoặc native player có thể đi qua đường khác. Không gọi capture này là toàn bộ network của app.
- Observer có thể thêm overhead; chưa dùng nó làm benchmark FPS/latency. SSL pointer và thứ tự phản hồi dùng để ghép HTTP/1; limitations trong từng file ghi các đoạn không ghép được.
- Chưa giải mã catalog CG01 ở asset; response backend đã cho schema nhưng không chứng minh schema file local giống hệt.
