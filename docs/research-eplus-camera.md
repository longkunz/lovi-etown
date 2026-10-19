# Nghiên cứu ePlus-DEV/camera cho dự án hiện tại

Ngày khảo sát: 2026-10-15. **Kết luận: có ích nhất ở catalog để đối chiếu độ phủ và tham khảo UI danh sách/chi tiết. Không có cơ sở đổi stack backend hoặc chuyển nguồn ảnh mặc định khỏi Notis.** Repo bổ sung một cách gọi snapshot trực tiếp từ cổng giao thông TP.HCM, nhưng probe giới hạn trong lượt này trả 403.

## Phạm vi và artifact

- Repo nguồn: <https://github.com/ePlus-DEV/camera>; bản clone bằng chứng: `evidence/external/eplus-camera/`.
- Commit cố định: [`1a560b7f9a5b0e9009dd5a0c508dc51289a8345a`](https://github.com/ePlus-DEV/camera/commit/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a), ngày 2026-10-07; clone sạch, lịch sử reachable có 78 commit. Trang GitHub nhánh mặc định qua web có dữ liệu cache cũ, nên kết luận lấy từ clone tại commit này.
- SHA-256 `data-camera.json`: `73f43e17a8cb28c07960d00c96e747e36ab833eb08dee648782b2af49ad5b07d`.
- Đối chiếu dataset hiện tại: `data/cameras_tphcm.json`, SHA-256 `fbbb6b1c775175b3bc69f1740718c61c80f5c294f44255e2c7dc7376ccd08a01`.
- Bối cảnh hiện tại lấy từ `backend/README.md`, `docs/superpowers/specs/2026-10-14-camera-backend-design.md` và `docs/camera-contract-pass6.md`: backend A1 đã có theo README, stack NestJS/Fastify/PostGIS, nguồn Notis, catalog riêng và snapshot pipeline; list → search → detail → snapshot trước, LIVE sau. Lượt này không kiểm thử lại backend.
- Không chạy PHP, Composer, JavaScript hay workflow của repo ngoài. Chỉ đọc source/history, phân tích JSON local và gửi hai GET giới hạn. Không thu cookie/token.

## 1. Repo thực sự làm gì?

**Quan sát tĩnh:** đây là web viewer PHP + JavaScript thuần, catalog JSON nằm trong repo, dùng Guzzle để proxy ảnh. `composer.json` yêu cầu `guzzlehttp/guzzle:^7.9`; lockfile chốt 7.9.2. Không phải Android SDK/backend catalog đầy đủ. Nguồn: [composer.json L1–10](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/composer.json#L1-L10), [composer.lock L8–12](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/composer.lock#L8-L12).

**Quan sát tĩnh:** flow trang chủ: `loadCameras()` đọc `data-camera.json` không cache → loại record thiếu ID/tên → lập danh sách district → `applyFilters()` tìm tên + district local → phân trang → tạo thẻ → `setCardImage()` gọi `proxy.php?id=…&t=…`. Mỗi trang 6/9/12/18/24 thẻ; tùy chọn refresh 0/5/10/15/30 giây, mặc định cấu hình 10. Timer dừng khi `document.hidden`; trở lại tab thì refresh. Từ “visible” trong `refreshVisible` là tất cả thẻ của trang hiện tại, chưa kiểm tra viewport bằng IntersectionObserver. Nguồn: [index.html L673–815](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/index.html#L673-L815), [L949–1113](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/index.html#L949-L1113).

**Quan sát tĩnh:** chi tiết camera được PHP render từ catalog; 404 khi ID không có; related lấy tối đa sáu camera cùng district; refresh snapshot mỗi 10 giây; chia sẻ bằng Web Share API hoặc clipboard. Có canonical, OpenGraph, Schema.org và sitemap cho một website public sau này. Đây là ảnh polling; không thấy HLS/WebRTC player trong `index.html` và `camera.php` ở commit khảo sát. Nguồn: [camera.php L17–106](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/camera.php#L17-L106), [L325–398](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/camera.php#L325-L398).

## 2. Catalog: 123 ứng viên bổ sung, chưa phải 123 camera đang hoạt động

**Quan sát tĩnh + phép tính local:** parse hai JSON bằng PowerShell, join theo `CamId == mongoId`, phân biệt exact string với chuẩn hóa tên. Kết quả áp dụng đúng hai hash trên:

| Chỉ số | Kết quả |
|---|---:|
| Record / ID duy nhất ePlus | 797 / 797 |
| Record / ID duy nhất dataset hiện tại | 674 / 674 |
| ID giao nhau | 674 |
| ID chỉ có ở ePlus | 123 |
| ID hiện tại không có ở ePlus | 0 |
| Tên trùng exact trong 674 ID chung | 123 |
| District trùng exact trong 674 ID chung | 145 |
| ePlus district thiếu hoặc `N/A` | 619 |
| ePlus có tọa độ | 0 |
| `SnapshotUrl == "tth"` | 579 |

Schema ePlus chỉ có `CamId`, `CamName`, `Disctrict` (giữ lỗi chính tả), `SnapshotUrl`, `ManagementUnit`. Nguồn: [data-camera.json cố định](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/data-camera.json), dataset local và phép join nêu trên. Không dùng `ManagementUnit` làm trạng thái online. Proxy dùng ID để tạo URL riêng, hoàn toàn không đọc `SnapshotUrl` của catalog; vì vậy các giá trị `tth` không mô tả protocol playback.

Ví dụ khác tên, **quan sát tĩnh**, không tự chọn tên nào đúng:

| ID | ePlus | Dataset hiện tại |
|---|---|---|
| `586e28a0f9fab7001111b0b3` | Quốc Lộ 1 - Khu Chế Xuất Linh Trung | Quốc lộ 1 - KCX Linh Trung 1 |
| `63ae7a50bfd3d90017e8f2b2` | Ba Tháng Hai - Sư Vạn Hánh | Ba Tháng Hai – Sư Vạn Hạnh |

**Suy luận:** dataset có thể giúp tìm camera chưa được import trong phạm vi khảo sát Notis hiện tại; không chứng minh 123 ID còn tồn tại, có snapshot, thuộc phạm vi sản phẩm hoặc có tọa độ. Giữ 123 ID trong danh sách ứng viên có provenance, xác minh metadata và ảnh trước khi upsert. Không ghi đè tên/district tốt hiện có bằng ePlus; `N/A` nên chuẩn hóa thành null. Không tuyên bố 797 là toàn bộ camera TP.HCM.

**Quan sát tĩnh lịch sử:** HEAD là commit revert loại bỏ thay đổi địa chỉ/Vietmap; `git show --stat HEAD` cho thấy xóa `scripts/enrich-vietmap.php`, workflow Vietmap và phần enrichment. Các commit ngày 2026-10-06/07 từng thêm tọa độ/địa chỉ không phải dữ liệu còn có tại HEAD. Không coi lịch sử này là một giải pháp enrichment đang hoạt động. Nguồn: [commit HEAD](https://github.com/ePlus-DEV/camera/commit/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a).

## 3. Hợp đồng snapshot và phép thử giới hạn

**Quan sát tĩnh:** [proxy.php L22–70](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/proxy.php#L22-L70) khai báo:

| Thuộc tính | Bằng chứng |
|---|---|
| Host/base | `https://giaothong.hochiminhcity.gov.vn:8007` |
| Method/path | GET `/Render/CameraHandler.ashx` |
| Caller | `proxy.php`, được `index.html`/`camera.php` gọi qua ID |
| Query | `id` 24 hex, `_` Unix time giây |
| Body/auth | Không body; code không gửi Authorization/cookie |
| Headers | Accept image, Accept-Language, no-cache, Referer cổng giao thông, User-Agent CameraViewer |
| Response mong đợi | 2xx và Content-Type bắt đầu `image/`; trả binary |
| Timeout | 8 giây tổng, connect 3 giây; verify TLS bật |
| Cache/lỗi | Proxy trả no-store/no-cache; đầu vào sai 400, nguồn lỗi/type khác image 502 |
| Phân trang | Không áp dụng ảnh; catalog là JSON tĩnh, không có API đồng bộ catalog nguồn trong flow này |
| Chưa rõ | Credentials/điều kiện truy cập thực tế, quota, SLA, thời điểm chụp, độ phủ |

**Quan sát runtime — HTTP probe độc lập, không phải traffic Android/ePlus:** 2026-10-15 03:04:06 UTC, cùng camera `586e28a0f9fab7001111b0b3`; hai GET song song, timeout 10 giây, không cookie/auth; headers phỏng theo proxy. Chỉ lưu metadata/hash/magic, không giữ ảnh. Bằng chứng: `evidence/external/eplus-camera-probe-2026-10-15/summary.json`.

| Nguồn | Kết quả |
|---|---|
| Cổng giao thông `:8007/Render/CameraHandler.ashx` | HTTP 403 Forbidden |
| `https://api.notis.vn/v4/cameras/{id}/snapshot` | HTTP 200; 24.979 bytes; JPEG magic `ffd8ffe000104a464946000101000001` |

Hash ảnh Notis: `6940afb854071d8e05376a2b4bd04ae7af1aa41a9d7d2c459c1f481bf3db1b90`. **Giới hạn:** một ID/thời điểm/môi trường, dùng Python urllib chứ không chạy Guzzle. 403 không chứng minh dịch vụ chết hoặc mọi camera bị chặn; chưa biết phản hồi do upstream hay lớp trung gian. 200/JPEG không chứng minh ảnh mới hoặc camera live. Không so độ trễ/độ tươi giữa hai nguồn vì không có hai ảnh thành công.

## 4. Những điểm không nên sao chép nguyên trạng

Các mục dưới là **quan sát tĩnh trong phạm vi mã ứng dụng đã đọc**, không phải kiểm thử xâm nhập hay chứng nhận an toàn:

- Proxy có ID regex và host cố định, TLS verification, timeout, kiểm tra MIME; đây là mẫu tốt để hiểu source adapter. Nhưng trong `proxy.php` không thấy giới hạn body ảnh, kiểm tra magic, shared cache/coalescing, rate limit, queue/concurrency cap hoặc kiểm tra ID thuộc catalog. Cấu hình request cũng không tắt redirect. Không suy ra cố định URL ban đầu đã chặn mọi trường hợp redirect tới host khác. Nguồn: [proxy.php L22–70](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/proxy.php#L22-L70).
- Mỗi lần refresh bỏ cache và tất cả thẻ trang được gọi lại. **Suy luận:** 24 thẻ/5 giây có thể tạo khoảng 4,8 upstream request/giây/người xem nếu mỗi fetch được thực hiện; chưa đo cache hạ tầng hay tải production. Backend hiện tại đã thiết kế bounded cache/pool/coalescing phù hợp hơn.
- `normalize()` loại combining marks nhưng không map riêng `đ → d`; không sao chép làm chuẩn tìm kiếm tiếng Việt đầy đủ. “Trực tuyến” được gán khi `image.onload`, không chứng minh ảnh đang cập nhật hoặc nguồn là LIVE. Nguồn: [index.html L721–727, L799–804](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/index.html#L721-L804).
- CI có PHP lint, kiểm tra JSON/ID trùng, sitemap, anchors và HTTP smoke trang local. Trong workflow đã đọc không có kiểm thử thành công ảnh upstream, cache/pool hay tải nhiều người; lượt này chưa kiểm tra CI chạy pass. Nguồn: [ci.yml L31–118](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/.github/workflows/ci.yml#L31-L118).
- **Quan sát tĩnh về license:** `composer.json` khai báo MIT, trong khi `index.html` có “All rights reserved”; `git ls-tree -r HEAD` không thấy LICENSE/COPYING riêng của project ở root (LICENSE bên trong vendor thuộc dependencies). Tình trạng cấp phép source/data chưa nhất quán. Đây chưa là kết luận pháp lý; tham khảo hành vi/thiết kế riêng trước, làm rõ quyền nếu muốn chép source hoặc phân phối dataset. Nguồn: [composer.json L6](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/composer.json#L6), [index.html L2](https://github.com/ePlus-DEV/camera/blob/1a560b7f9a5b0e9009dd5a0c508dc51289a8345a/index.html#L2).

## 5. Khuyến nghị cho dự án

Tất cả đề xuất ở bảng là **suy luận/khuyến nghị**, chưa được triển khai trong lượt nghiên cứu.

| Ưu tiên | Cách dùng | Giá trị và tiêu chí kiểm chứng |
|---|---|---|
| Ngay khi mở rộng catalog | Lập diff 123 ID ứng viên, lưu commit/hash/provenance; đối chiếu nguồn metadata hợp lệ | Tìm độ phủ thiếu; chỉ thêm sau khi xác minh, giữ ID domain cũ và không overwrite tên/district theo dữ liệu N/A |
| Khi làm client | Tham khảo lưới, skeleton/error từng camera, tắt polling nền, refresh chọn lọc, chia sẻ permalink | Hợp flow A1; timer tuân descriptor backend, không đổi snapshot thành LIVE; chỉ tải thẻ thực sự cần xem |
| Sau khi xử lý được 403 qua truy cập hợp lệ | Spike provider snapshot cổng giao thông, dùng allowlist/TLS/size limit/cache của backend hiện tại | Chỉ cân nhắc adapter phụ sau khi nhiều ID có response ảnh đúng, đo độ tươi/lỗi/quota; chưa tự bật fallback |
| Khi có website public | Canonical/detail SSR/sitemap/share | Giúp tìm kiếm/chia sẻ; không phải điều kiện cho Android/iOS hoặc backend local A1 |
| Giữ nguyên | Stack NestJS/Fastify/PostGIS và Notis mặc định | Repo PHP không giải quyết thêm contract catalog, độ phủ, LIVE, mưa/ngập/cảnh báo hoặc vận hành nguồn so với backend đã có |

## Giới hạn graph và bước tiếp theo

Đã dùng codebase-memory Tier 2: `list_projects` → index repo ngoài tên `eplus-camera-research` (`fast`, generation `2026-10-15T03:02:29Z`) → `search_graph` → `trace_path(loadCameras,both,depth=3)` → `get_code_snippet(setCardImage)` → `check_index_coverage` cho `index.html`, `proxy.php`, `camera.php`, `data-camera.json`, `composer.json`, `composer.lock`, `README.md`, `.github/workflows/ci.yml`, `agents.md`.

Coverage báo `camera.php` parse unusable L1–402, `composer.lock` bị skip-list, các file còn lại `metadata_changed`. Đã đọc trực tiếp toàn bộ `camera.php`, `proxy.php`, README/CI và các đoạn index liên quan; parse trực tiếp toàn bộ JSON để thống kê, đọc literal dependency/version trong lockfile. Vì vậy graph chỉ hỗ trợ tìm đường; kết luận dựa source commit cố định, không coi graph sạch/đầy đủ. `vendor/` bị loại khỏi index và chưa audit dependencies; chưa audit secrets toàn bộ history, chưa đo runtime UI/mobile/production.

Kết thúc lượt: đã xác định ích lợi, catalog diff và khả năng truy cập một ảnh; **chưa** import 123 ID, sửa backend hoặc xác nhận nguồn cổng giao thông vận hành được. Bước tiếp theo có ích nhất là đối chiếu 123 ứng viên với catalog Notis đã nhập và metadata nguồn; không cần đổi thiết kế A1 để làm việc đó.
