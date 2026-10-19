# API lỗi: cache và asset đã kiểm chứng runtime

Thử trên AVD nghiên cứu Android 13 `emulator-5580`, fresh process từng ca. Probe chỉ đổi `api.udrivex.com` thành hostname `.invalid` trong `getaddrinfo` của app. Notis, các nguồn camera, mạng Windows và entitlement giữ nguyên. Quan sát native `open/read` cho file cache và `AAssetManager_open` cho đúng asset CG01; không thay dữ liệu response.

| Ca | Quan sát | UI |
|---|---|---|
| API lỗi, cache từ API/Notis | DNS lỗi → đọc 338.721 byte cache → mở asset mã hóa → ghi lại cache | Có danh sách TP.HCM |
| API lỗi, tạm cất cache | DNS lỗi → không đọc cache → mở asset mã hóa → tạo cache mới | Có danh sách TP.HCM |
| API lỗi, cache đã tạo từ asset | DNS lỗi → đọc 1.221.342 byte cache; không có sự kiện mở asset trong capture | Có danh sách TP.HCM |

Cả ba phiên native observer không có lỗi, không chạm byte limit, kết thúc timeout. Positive controls ở hai ca đầu xác nhận probe phát hiện asset open. [Summary và timeline](../evidence/runtime/catalog-fallback-summary.json). Screenshot ở `api-fault-native-ui`, `api-fault-no-cache-ui`, `api-fault-valid-cache-ui`.

Kết luận: app có đường phục hồi danh sách khi API không truy cập được. Cache có tồn tại chưa đủ để được chấp nhận; một biến thể cache bị bỏ qua để dùng asset. Các ca này không chứng minh ảnh/video vẫn hoạt động khi mất toàn bộ mạng, vì chỉ hostname API bị gây lỗi.

## Điều kiện stale

Disassembly `_looksLikeStaleNotisCatalog` tại `0x690608` lấy tối đa 40 camera, đếm URL chứa `notis.vn` và URL có `camerahandler.ashx`. Nhánh trả kết quả dựa vào hai số đếm, không phải phép so sánh `fetchedAt` với thời gian hiện tại trong routine này.

Cache đầu có 40/40 URL Notis, 0/40 ashx; cache tạo từ asset có 0/40 Notis, 40/40 ashx. Hành vi runtime khớp heuristic từ nội dung URL. Chưa kết luận toàn bộ app không có TTL ở nơi khác hoặc mô tả được mọi điều kiện invalidation.

## Bảo toàn fixture và giới hạn instrumentation

Sau ca đầu, chính app ghi cache mới. Trước ca không-cache, đã force-stop app, pull bản sao rồi đổi tên đúng một file thành `.research-backup`. Sau thử, cache mới được pull làm bằng chứng, file sao lưu được trả về đường dẫn cũ. Hash khôi phục khớp `e683737fe79a7fc9a6b820c571fc9eb262a76ace0aacad1651f177d594e83eb7`; đây là hash fixture trước bước tạm cất, không phải khẳng định file cache không bị app cập nhật trong cả cuộc điều tra.

Phiên đầu `api-fault-cache` có probe tại entry các hàm Dart và crash SIGSEGV sau bước parse cache. Không dùng phiên đó làm ca phục hồi thành công, chưa chốt root cause crash. Các phiên xác nhận đã bỏ toàn bộ Dart entry hook, chỉ kiểm tra byte prefix và quan sát native file/asset. Không dùng việc thiếu event từ phiên crash để suy ra thiếu chức năng. Phiên cuối đã tới timeout nhưng cleanup detach chờ lâu; sau khi lưu UI/file, đã force-stop đúng app nghiên cứu để kết thúc collector và gỡ probe. File tạm `.research-generated` đã đối chiếu hash với bản pull rồi xóa; bản sao trước thử được khôi phục.

Scripts: `build-catalog-branch-symbols.py`, `frida/observe-catalog-fallback.js`, `summarize-catalog-fallback.py`; raw buffer/cache chỉ lưu private. Chưa thử cache JSON hỏng, HTTP 4xx/5xx, TLS failure hoặc các tỉnh khác.
