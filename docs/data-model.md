# Mô hình dữ liệu — phần đã thấy và phần đề xuất

Đã phục hồi schema quan sát từ HTTP Dart ở pass1/pass3. Đây là schema của mẫu response, chưa phải contract server hoặc schema catalog CG01 local. Nguồn: `evidence/runtime/dart-capture/catalog-schema-summary.json` và [dart-network-findings.md](dart-network-findings.md).

## Response camera quan sát được

Top-level object có `list: Camera[]`. Các field dưới đây có mặt trong tất cả phần tử của năm catalog mẫu, trừ phần ghi optional:

| Field | Kiểu quan sát | Ý nghĩa / giới hạn |
|---|---|---|
| uniqueId, id | string | Hai ID khác nhau; quy tắc sinh và key favorites chưa phục hồi |
| displayName | string | Khớp tên camera UI trong trace 11B |
| lat, lng | number | Tọa độ; chưa kiểm toán độ chính xác |
| district | string hoặc null | Hà Nội null trong mẫu; Đà Nẵng/TP.HCM có null và string |
| address | string hoặc null | Đà Nẵng có null; còn lại string trong mẫu |
| camViewURL | string | Có thể URL snapshot/WSS/HLS hoặc source identifier không có scheme |
| method | string | GET/POST theo descriptor; không mặc định là method API catalog hay WSS handshake |
| body, header | object | Cấu hình request nguồn; có thể rỗng, header bí mật đã che |
| status, hideClipper | integer | Chưa chốt đầy đủ semantics |
| isHls, hlsType | integer | Flag chọn playback rộng hơn HLS; xem API catalog |
| angle | string | Chưa xác minh cách dùng |
| duration | integer | Giá trị 0/10/11/60 trong mẫu; đơn vị/refresh policy chưa chốt cho mọi loại |
| backupCamera | object hoặc null, optional | 19 object ở catalog TP.HCM, có shape tương tự camera |
| message | string, optional | Có ở WSS Hà Nội/Quảng Trị; native bridge nhận message handshake |
| isSlowConnection | integer, optional | Có trong catalog Huế và một số backup; chưa chốt semantics |

Schema summary ghi số field xuất hiện và null trên toàn bộ response mẫu, không chỉ camera đầu. Không diễn giải field có mặt trong mẫu thành quy tắc required phía server.

| Đối tượng | Điều đã biết | Giới hạn |
|---|---|---|
| Tỉnh | UI có năm tỉnh; API-001 gửi provinceKey=tp_hcm, các tỉnh khác có endpoint riêng | Chưa kiểm tra giá trị provinceKey khác hoặc contract slug tổng quát |
| Camera | Có response schema, ID, tọa độ, descriptor và trace 11B tới snapshot Notis | Còn thiếu default, enforcement và toàn bộ caller Dart |
| Playback session | Native `play` nhận url/message; trả textureId=-1 và epoch; stop có epoch | Chỉ contract Flutter↔native EVUP, không phải API backend |
| Unavailable catalog | JSON local có slug:string, reason:string, fingerprint:{sha256:string,bytes:number,png:number[]}, ids:string[] | File có 174 ID; không suy ra mọi ID là camera chết vĩnh viễn |
| Catalog chính | CG01 AES-256-GCM đã giải mã; 726 camera trong `cameras`, thêm metadata catalog và field index | Tập ID khớp API 900 trừ 174 unavailable local; xem catalog-cache-favorites.md |
| Favorites | SharedPreferences StringList, key `camera_favorite_ids`, lưu `id` | Đã thêm/bỏ đối chiếu XML; chưa thử migration, ID đổi hoặc camera bị gỡ |

Các literal `camera_id`, `image_url`, `longitude`, `province`, `title` trong E-05 không phải tên field của catalog đã capture; không gộp chúng vào DTO chỉ vì xuất hiện trong cùng binary. Schema runtime dùng `id`, `camViewURL`, `lat`/`lng`, `displayName`.

## Contract đề xuất cho app mới

Các field sau là quyết định thiết kế đề xuất, không gán cho app gốc:

- `Province`: id, displayName, enabled, catalogVersion.
- `Camera`: id, provinceId, name, address?, area?, latitude?, longitude?, sourceId, capabilities, updatedAt?.
- `PlaybackDescriptor`: cameraId, kind(snapshot/hls/evup), endpoint, expiresAt?, refreshInterval?, capturedAt?.
- `CameraHealth`: cameraId, state(unknown/online/offline/degraded), checkedAt, reason?.
- `Favorite`: cameraId, addedAt, userLabel?; MVP lưu local.

Điểm bắt buộc khi triển khai: ID ổn định giữa lần cập nhật; URL có hạn không lưu như định danh camera; tách `capturedAt` của nguồn với `fetchedAt` của client; field chưa có giá trị phải hiển thị là chưa biết, không tự điền thời gian hiện tại.
