# Debug API camera — lượt 7

Ngày 2026-10-14. Đây là lượt đã lấy **HTTP plaintext do app thực sự tạo** qua hook thụ động native, bổ sung cho các probe độc lập trước. Không đổi certificate validation, proxy, server, APK hoặc giá trị trả về. Không giữ token/cookie/device ID, query tìm địa điểm, raw response body.

## 1. Artifact và phương pháp

Runtime `com.fts.notis` 5.2.1 (502001), base SHA-256 `1cef9bf94c18d37a9d83eb7de97bff8e32644b9f2d56ea86107c625d615a0f54`. Cùng APK set đã kéo bằng REA lượt 5, không đồng nhất với base.apk workspace khác hash.

`lib/x86_64/libflutter.so` trong runtime split: SHA-256 `eb1159947b57f7119a24fc6aa39ce5cee39b86ea5549d6a4848950eb8ab687f8`; bản trích riêng `evidence/camera/native/runtime-libflutter-x86_64.so`. Đọc ELF relocation để định vị native `SecureSocket_Init` VA offset `0x97f050`, `SecureSocket_Connect` `0x9801e0`, `SecureSocket_RegisterKeyLogPort` `0x984970`. Không sử dụng keylog port hoặc thu khóa phiên TLS.

**Quan sát runtime/native:** disassembly Frida từ vùng SecureSocket dẫn tới candidate callees; offset `0x7fb4df` nhận HTTP request plaintext, offset `0x7fa9eb` trả HTTP response plaintext. Chưa gán tên symbol SSL/BIO chính xác. Hook offsets này bằng `observe-camera-http-pass7.js`, giữ request line đã che query, tên header, scheme Bearer nếu có, header response được phép giữ và timestamp. `trace-camera-tls-stack.js` dùng FUZZY backtrace chỉ là đầu mối, không coi mọi frame là call chain chính xác.

**Runtime response body:** `run-camera-http-observer.py --body-shapes` xử lý trong RAM framing HTTP/chunked/gzip của các GET cấu hình/danh sách, ghi hash/shape và hai field cấu hình camera công khai, bỏ raw body. Shape của array chỉ phản ánh item đầu, không phải union schema hoặc chứng minh mọi item giống nhau.

REA native provider vẫn chưa cấu hình; không cài engine. Lệnh CLI `binary-session` không tồn tại, đã kiểm tra bằng MCP `binary_session`; không mở native session. REA CLI Android/JADX và ADB tiếp tục dùng được. Search DEX `okhttp` được lưu nhưng không xác lập Dart caller.

HAR `camera-app-pass7.har` được **dựng từ log hook đã che dữ liệu**, không phải packet/proxy capture. REA `inspect_web_network_capture` đọc thành công, Evidence ID **`ev_e83f5decb7d2b302bacd89bc87d1f38766b2e49bc5870461f745effc816f0ca8`**, file `rea-pass7-network-corrected.json`. Lần đầu HAR không qua schema do query placeholder chưa URL encode; đã sửa generator và giữ lỗi lịch sử `rea-pass7-network.json`. REA xác nhận nội dung capture dẫn xuất, không độc lập chứng minh hành vi runtime hoặc payload bị bỏ.

## 2. Catalog đã đối chiếu runtime

Header nhóm **H** quan sát: `user-agent`, `x-device_id`, `connection`, `app-packagename`, `accept-encoding`, `device-id`, `x-tenant`, `content-type`, `tenant`, `uid`, `accept`, `language`, `host`, `app-version`; một số phiên thêm `authorization: Bearer …`. Giá trị credentials và device/uid đã bỏ. Gửi header không chứng minh header đó bắt buộc ở server.

| API | Tính năng / caller | Request thực tế | Response / cache / lỗi |
|---|---|---|---|
| GET `https://api-thongtingiaothong.paas.ttgt.vn/tenants` | Bootstrap tenant, cấp cấu hình camera; native hook boundary, Dart handler chưa biết | Không body; nhóm H; Android 13 phiên đầu không Authorization, Android 9 phiên sau có Bearer | 200 JSON array, gzip/chunked, weak ETag. Body app có `config.url-api-camera=https://api.notis.vn/v4/`, `config.area-camera` array 16 `{name,coordinates}`. TTL/retry chưa biết |
| GET cùng host `/ttgt-tphcm/configs/homepage` | Cấu hình menu entry Camera và trang chính; shared bootstrap | Không body; H; Authorization thay đổi theo phiên như trên | 200 JSON object; header/menu/addons, gzip/chunked, weak ETag. Body shape chưa giữ toàn bộ menu action values, không dùng shape để khẳng định tên route Camera |
| GET `https://api.notis.vn/v4/cameras/bybbox` | Vào bản đồ, pan và chọn khu vực | `lat1`, `lng1`, `lat2`, `lng2` số thực; không body; H + Bearer trong mẫu đầy đủ | 200 JSON array; body app các mẫu 262/209/8 item; gzip/chunked, weak ETag. Item đầu có `_id`, `id`, `name`, `loc`, `values`, `dist`, `ptz`, `liveviewUrl`, optional `angle`; một mẫu có `videoUrl`. Chưa có phân trang/TTL contract |
| GET cùng host `/v4/cameras` | Xung quanh sau chọn điểm thủ công | Mẫu `lat=10.778401&lng=106.695975&distance=5000`; không body; H + Bearer | 200 JSON/gzip/chunked/weak ETag; UI 90 kết quả. Body schema chi tiết vẫn từ probe lượt 2, không gọi đó là body app đã thu; cap/pagination vẫn chưa biết |
| GET cùng host `/v4/cameras/{_id}/snapshot` | Thumbnail grid/Quan tâm, preview, refresh | Không body/query trong mẫu; chỉ `user-agent`, `accept-encoding`, `host`; không Authorization/cookie trong mẫu | 200; đầy đủ header mẫu có `transfer-encoding:chunked`, `set-cookie` (giá trị bỏ); không thấy Content-Type/ETag/Cache-Control ở mẫu header đầy đủ. JPEG đã xác nhận bằng probe; runtime body ảnh không lưu. Không thấy conditional header trong mẫu; không suy ra không cache |
| GET `https://api-thongtingiaothong.paas.ttgt.vn/ttgt-tphcm/routing/geocoding` | Nhập địa điểm trong flow camera | Query `q` đã che; không body; H + Bearer | 404 Not Found, JSON content-length 46, weak ETag; khớp ErrorLog Route not found lượt 5. Đã xác nhận method/host/path bằng runtime, không còn chỉ literal/log app |
| attempted GET `http://camera.thongtingiaothong.vn/s/{camera_id}/index.m3u8` | LIVE Ký Con, Java `p1.p.p` | Tái sử dụng hook Java/REA method lượt 4; không có query; headers chưa thu | Android cleartext chặn trước response. Chưa có playlist/segment/codec hay playback thành công. Không ép HTTP thành HTTPS để tuyên bố app hoạt động |

Reverse geocoding điểm map là Android `Geocoder` qua `q3.r.onMethodCall`, không phải C-07 trên; provider HTTP hệ thống và request Java ngoài native Flutter hook chưa thu. Tile host HCMGIS có trong cấu hình; request tile chưa thấy trong cửa sổ này, cache/tầng network có thể khác. Không gọi đó là endpoint nghiệp vụ đã capture.

## 3. Ma trận bao phủ flow

| Flow | Đã kiểm tra | Giới hạn |
|---|---|---|
| Khởi tạo / cấu hình camera | Spawn Android 13 và restart Android 9; GET tenants/homepage, 200; body tenants app xác nhận base/16 khu vực | Không chứng minh mọi endpoint bootstrap ở mọi tenant/account |
| Bản đồ / pan / chọn khu vực | GET bbox thay đổi tọa độ; 200 và shape body app | Cluster/zoom rộng chưa exhaust mọi trạng thái; request tile chưa thu |
| Xung quanh | Android 13 denied GPS → chọn tọa độ → request distance=5000 → 200 → grid 90; 90 GET snapshot thumbnail trong capture | Chưa có hợp đồng đủ bán kính/phân trang; emulator-5580 mất kết nối sau capture, không xác định nguyên nhân |
| Preview / refresh | GET snapshot thực tế lặp, 200; header khác nhóm H của danh sách | Không có Dart symbol; cache nội bộ/TTL server/ảnh hỏng khác chưa exhaust |
| Quan tâm | Thêm []→[Pasteur] và xóa→[]; window hook native từ trước add đến sau remove chỉ có GET snapshot | Không chứng minh không có API sync khi đăng nhập/tenant khác/Java/background muộn |
| Tìm chữ | GET geocoding q, Bearer, 404 | Chưa có flow trả kết quả thành công, history/saved address chưa debug đầy đủ |
| Chọn thủ công / reverse geocode | Mẫu Android 13 thành công + native Geocoder REA lượt 5 | Backend hệ thống chưa capture; Android 9 lỗi đã biết |
| LIVE | Attempted GET + cleartext error lượt 4 | Playlist/segments và hai nguồn streamingUrl khác chưa phát/capture |
| Biểu tượng camera nổi | Thử trên preview Pasteur; frame thu vẫn preview | Không xác nhận vai trò hay kết luận không có network từ một click/frame |

Window Quan tâm: `favorite-network-window-pass7.json`. Add bắt đầu `1791969834114`; remove kết thúc `1791969862657`; observer kết thúc `1791969903067` (khoảng 40,4 giây sau remove). Trong window từ add đến hết chỉ có GET snapshot tại `1791969836347`. Không phát hiện POST/PUT/DELETE sync qua hook Flutter này. Key local vẫn `flutter.CameraCare_ttgt-tphcm`; cleanup về `[]`.

## 4. Đầu mối tĩnh và phần còn mở

Quét ASCII toàn runtime `libapp.so` x86_64 (runs ≥5 và <240 bytes, filter camera/media): 70 literal. SHA-256 `a78b160ee7c9d7fd4c9418549745dccfd6f7dec592387bbce8852cc6ce90682e`. `runtime-camera-literals-pass7.json`: `cameras/bybbox?lat1=` `0xbc9a8`, `cameras?lat=` `0xc1e04`, `/transit/cameras?routeId=` `0x82be9`, `url-api-camera` `0x135c29`, `CameraCare_` `0x7c76e`. Các literal bbox/nearby khớp flow đã capture, không tự xác lập Dart call chain. Transit vẫn chưa gắn với màn Camera; không gọi endpoint này chỉ để đoán.

Không có cơ sở tuyên bố toàn bộ API camera trong mọi trạng thái đã lấy hết. Những phần còn mở cụ thể: request hệ thống Geocoder/tile; LIVE thành công và các media con; sync khi tài khoản khác; saved address/history; Dart handler; giới hạn server/pagination, cache/retry/error contract đầy đủ. API chính của các flow đã tái hiện đã được đối chiếu runtime; đây là tiến triển khác với catalog probe trước.

## 5. Tái hiện và bằng chứng

- `scripts/observe-camera-http-pass7.js`: offsets chỉ áp dụng đúng runtime libflutter hash ở trên; không áp dụng cho ARM/workspace APK khác.
- `py -V:3.14 scripts/run-camera-http-observer.py emulator-5554 <pid> <output.jsonl> --duration 120 --body-shapes`: attach app đang chạy. `--spawn` khởi động app để thu bootstrap. Chỉ chạy trên artifact đúng hash; kiểm tra module trước khi dùng cho build khác.
- `scripts/build-camera-http-har.py` dựng HAR từ log đã che; REA đọc bằng `rea inspect-web-network-capture <absolute.har> har --format json --full-output`.
- Log authoritative: `app-http-pass7-google.jsonl`, `app-http-pass7-map-favorite.jsonl`, `app-http-pass7-search-favorite.jsonl`, `app-http-pass7-bodies.jsonl`; file body chứa start/end/time để đánh giá coverage. Các trace/candidate pass7 trước là thử điều tra, không thay thế log authoritative.
- `run-camera-http-observer.py` bản đầu dùng message handler cho console log nên log không vào file, đã sửa bằng `set_log_handler`; stdout thu được giữ riêng `app-http-pass7-fav-add-stdout.json`. Window kết luận Quan tâm dùng lượt body observer đã sửa, không dựa file final rỗng.
- Không cấp thêm quyền, không đổi rule mạng; Android 13 mất kết nối ngoài ý muốn sau khi capture đã lưu, nguyên nhân chưa biết. Android 9 favorite cuối `[]`; observer đã detach sau duration. Không sửa APK gốc.

Bước tiếp theo nếu cần đóng những nhánh còn mở: ưu tiên LIVE HTTPS từ provider có quyền, tài khoản thử nghiệm được cung cấp cho sync và history/saved-address; capture provider Geocoder/tile theo đúng tầng. Không coi API có Bearer trong app là bắt buộc ở server, hoặc response 200 là quyền dùng trong sản phẩm mới.
