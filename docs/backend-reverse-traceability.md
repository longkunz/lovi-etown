# Đối chiếu backend với hai bộ reverse

Ngày 2026-10-14. Đây là **review tài liệu/bằng chứng đã lưu**, không phải lượt capture hoặc reverse mới. Backend mới lấy hành vi camera làm trung tâm; không tự động được quyền dùng API/asset/token của hai app.

**Làm rõ từ người dùng:** Notis/TTGT là nguồn public được chọn; Udrivex chỉ được dùng để hiểu catalog camera/descriptor và sẽ được thay bằng backend riêng. Do đó A1 triển khai catalog PostgreSQL + Notis adapter làm luồng dữ liệu thật; không phụ thuộc Udrivex runtime. Fixture chỉ dành test/demo explicit. Các lưu ý nguồn chưa chốt ở phần lịch sử không là yêu cầu phê duyệt lại Notis; giới hạn quota/coverage/media vẫn được ghi riêng theo bằng chứng.

## Nguồn và danh tính

- **Genius:** `com.genius.cameragiaothong` 2.0.0 / 202609282; base SHA-256 `a0a93d37e753903b6c8b8e493566406bd9ba3ca9d39835ba83ac3ca5383eff87`, theo [investigation.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/investigation.md). REA package `ev_3124a915c6c61bbb2aef298f519bced2d8c2dcbfff5d0a77b3c8ce21620bf3bb`; HTTP/flow E-13/E-14 là Frida/local evidence, không gán thành REA ID.
- **Notis:** runtime `com.fts.notis` 5.2.1 / 502001; base SHA-256 `1cef9bf94c18d37a9d83eb7de97bff8e32644b9f2d56ea86107c625d615a0f54`; [debug API lượt 7](camera-api-debug-pass7.md), REA HAR dẫn xuất `ev_e83f5decb7d2b302bacd89bc87d1f38766b2e49bc5870461f745effc816f0ca8`. Không đồng nhất bản này với base.apk khác hash trong workspace.

Các báo cáo đời đầu có câu “chưa xác minh” đã được các lượt sau bổ sung. Review ưu tiên báo cáo chuyên đề mới hơn: favorites/cache đã có key; CG01 đã giải mã; Hà Nội đã phát HEVC trên Android 13; Huế/Đà Nẵng đã có playback ở một mẫu. Không dùng trạng thái cũ để phủ nhận bằng chứng mới, cũng không suy rộng một mẫu sang mọi nguồn/iOS.

## Ma trận hợp nhất hành vi và yêu cầu

| Phát hiện từ tài liệu | Loại / giới hạn | Ảnh hưởng tới backend mới | Giai đoạn |
|---|---|---|---|
| Genius F-003/F-004/F-005: danh sách có tên, thumbnail, quận/địa chỉ; tìm tên/địa chỉ; lọc khu vực, Yêu thích | **Runtime theo báo cáo**; tìm không dấu là cải tiến chưa được chứng minh ở app gốc | Catalog DTO có district/address nullable; tìm tên + địa chỉ không dấu; filter district từ dữ liệu thực, không cần Vietmap/GPS; phân trang ổn định | A1 |
| Genius F-006: detail có snapshot, tim, fullscreen, camera liên quan; trace 11B metadata→GET Notis→JPEG→UI | **Runtime E-13/E-14**; không khôi phục mọi Dart caller | List → detail → playback → snapshot là flow nghiệm thu; related camera cùng district khi có dữ liệu; fullscreen là client, backend phục vụ ảnh đúng tỷ lệ/bytes | A1 |
| Genius API mẫu 900 TP.HCM: 860 GET Notis, 40 HTTP POST; catalog các tỉnh khác trả descriptor WSS/HLS/identifier | **Runtime mẫu**, không chứng minh tất cả hoạt động hoặc được phép dùng | Playback/source adapter riêng; giữ method/body/header nội bộ theo adapter được chọn; không coi mọi nguồn là GET/JPEG/HLS. A1 chỉ adapter Notis GET đã biết; không cam kết phủ 900 camera | A1 model, adapter khác sau |
| Genius `uniqueId`, `id`, source ID trong URL khác nhau; favorites lưu `id`, không phải uniqueId | **Runtime/storage + data model**, quy tắc sinh ID chưa biết | Domain UUID ổn định, unique provider/source ID; external aliases chỉ khi cần migration có nguồn hợp lệ. Không dùng URL/ID app Genius làm PK backend | A1 |
| Genius cache/asset 726 ID = API 900 trừ đúng 174 unavailable; disk/asset fallback khi lỗi DNS API | **Static disassembly + runtime theo báo cáo**; TTL đầy đủ chưa biết | Catalog bền, version/fetchedAt/stale và coverage; source lỗi vẫn trả catalog cuối, không xóa DB. Không copy 174-ID blacklist/CG01/private catalog sang sản phẩm; fixture riêng | A1 |
| Genius routine stale nhìn tối đa 40 URL Notis/ashx, không phải kiểm tra thời gian | **Disassembly**, không chứng minh app không có TTL khác | Chính sách stale riêng, dựa thời điểm sync; không sao chép heuristic URL. Catalog freshness khác capturedAt ảnh | A1 |
| Genius favorites StringList bền qua restart; resolve qua catalog; Notis favorites lưu object | **Runtime/storage**, migration/sync chưa đủ | Backend ID ổn định, detail lookup theo ID; favorites client local-first, không giả có server sync; record không biến mất chỉ vì import lỗi | A1 contract; sync sau |
| Genius có 19 backupCamera; DNS fault Notis 200 giây chưa thấy failover tới backup | **Runtime có giới hạn**, không phủ mọi failure | Không bật fallback chỉ vì có descriptor. Mỗi fallback sau này cần nguồn được phép, điều kiện kích hoạt và nghiệm thu riêng; không báo đang live khi chỉ giữ ảnh cũ | A2+ |
| Genius Hà Nội EVUP HEVC phát ở một mẫu Android 13; Huế media_kit và Đà Nẵng YouTube hiển thị playback | **Runtime theo các báo cáo chuyên đề**, chưa xác minh iOS/toàn bộ nguồn | `snapshot|hls|evup|youtube|unknown` là source classification, khác khả năng backend/client hỗ trợ. A1 snapshot; LIVE A2 theo nguồn; EVUP riêng, không tự coi WSS là HLS | A1 model; A2+ playback |
| Genius mất mạng player lỗi, ~29 giây sau phục hồi cần Retry; Quảng Trị handshake nhưng chưa có frame | **Runtime bounded** | Phân biệt unavailable/timeout/auth/protocol; retryable có nghĩa, không loading vô hạn; không kết luận offline toàn nguồn chỉ vì một lỗi. Reconnect player là client, backend không mở session thay user | A1 errors; A2 reconnect |
| Notis app gửi GET bbox/nearby/snapshot; Bearer có ở list/search, snapshot mẫu không auth | **Runtime lượt 7**; auth bắt buộc/quota chưa biết | Adapter nguồn camera cụ thể, DTO normalized, credentials env, snapshot kiểm tra magic/size. Không dùng camera source API làm auth của backend mới | A1 |
| Notis nearby 89/90, bbox có thêm ID trong 5 km; snapshot ~12 giây trong mẫu | **Probe + runtime có giới hạn** | Không hardcode 90 hoặc cam kết toàn bộ nguồn. Tổng API mới là local catalog; refreshInterval cấu hình, không suy từ duration=11 của Genius hoặc nextUpdate chưa xác minh | A1 |
| Đã chốt camera-first, sau đó cảnh báo khu vực/vị trí/tuyến; người dùng có Vietmap | **Yêu cầu sản phẩm**, không phải reverse finding | Vietmap không là prerequisite xem camera; giữ map/nearby/route và cả ba cảnh báo trong roadmap | Sau A1 |

## Bản đồ tài liệu gốc đã đọc

| Tài liệu Genius | Dùng để đối chiếu |
|---|---|
| [feature-matrix.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/feature-matrix.md) | F-003–F-007: list/search/filter/detail/favorites |
| [flows.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/flows.md) | Trace 11B, related camera và EVUP session/epoch |
| [api-catalog.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/api-catalog.md) | Catalog API vs media nguồn, 860/40, custom app-check |
| [data-model.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/data-model.md) | ID/descriptor/schema, nullable fields |
| [catalog-cache-favorites.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/catalog-cache-favorites.md) | 726/174, storage favorites, backup fault |
| [catalog-fallback-runtime.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/catalog-fallback-runtime.md) | Cache/asset acceptance và giới hạn heuristic stale |
| [android13-playback.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/android13-playback.md) | EVUP/HEVC thành công ở một nguồn |
| [player-runtime.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/player-runtime.md) | HLS/YouTube renderer theo nguồn |
| [recovery-and-backup.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/recovery-and-backup.md) | Recovery/backoff opportunity, backup chưa xác minh đầy đủ |
| [superpowers/brainstorming-status.md](D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/superpowers/brainstorming-status.md) | Mục tiêu đã chốt; supersede giả định cũ trong rebuild-spec |

## Giới hạn tích hợp dữ liệu

Backend mới **thay thế Udrivex ở tầng catalog/resolver**, không phải proxy Udrivex. Spec A1 dùng Notis public cho dữ liệu thật, lưu/chuẩn hóa và phục vụ qua API của chính backend; fixture dành test/demo. Không cần Udrivex client/app-check để list/xem camera. Con số 900/726, 40 nguồn POST và mọi backup/media live vẫn là bằng chứng về app Genius, không phải số lượng hay khả năng backend mới đã đạt.

Đây là review báo cáo và JSON summary đã được báo cáo trích dẫn; không đọc lại code Java/Dart để xác lập quan hệ mới, không tạo graph claim hoặc runtime proof mới. Yêu cầu mới (search không dấu, catalog TTL riêng, DTO version, related rule) là **thiết kế đề xuất**, không gán cho hành vi app gốc.
