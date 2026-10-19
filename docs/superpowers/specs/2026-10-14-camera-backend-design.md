# Thiết kế backend — danh sách và xem camera trước

Ngày 2026-10-14. Trạng thái: **người dùng đã xem và xác nhận spec**; implementation plan đã soạn tại `docs/superpowers/plans/2026-10-14-camera-backend-a1.md`, chờ review plan/chọn phương thức thực thi. Đây là đặc tả app mới, không mô tả cấu trúc app gốc. Workspace hiện chưa là Git repository; tài liệu đã lưu trên filesystem, chưa commit.

## 1. Brief và phạm vi

**Trọng tâm do người dùng chỉnh lại:** backend phục vụ danh sách camera và xem camera. Có Vietmap không có nghĩa phải triển khai map/search địa điểm/route trước camera. Flow cốt lõi: mở danh sách → tìm theo tên camera → chọn camera → lấy playback descriptor → xem snapshot hoặc live theo nguồn → làm mới/xử lý lỗi. Flow này không cần bản đồ, GPS hoặc Vietmap.

Người dùng đã xác nhận có đủ dịch vụ Vietmap và muốn build backend trước. Giữ định hướng Android/iOS, TP.HCM trước, camera và theo dõi mưa/ngập, quảng cáo nhẹ/VIP, ba phạm vi cảnh báo khu vực/vị trí/tuyến, ngân sách mong muốn dưới 1 triệu/tháng. Vietmap là dependency cho lát hỗ trợ vị trí/tuyến sau. Cơ sở: `docs/superpowers/brainstorming-status.md`, `docs/stack-review.md` và trao đổi hiện tại.

Lát A1 cung cấp backend chạy local/Docker: catalog chuẩn hóa, phân trang danh sách/thumbnail, tìm camera theo tên không dấu, chi tiết camera, playback descriptor snapshot, tải ảnh và refresh có giới hạn/cache/lỗi rõ. Có migration/seed fixture, adapter Notis bật bằng cấu hình, đồng bộ catalog bằng thao tác quản trị và OpenAPI để thử toàn flow. Không xây mobile app, không thuê/deploy dịch vụ, không mua API trong lát này.

**Vai trò nguồn đã được người dùng làm rõ:** Notis/TTGT là nguồn public được chọn cho A1. Udrivex được tham khảo để hiểu cách trả danh sách camera và descriptor; **backend mới thay vai trò catalog/resolver của Udrivex**. App mới gọi backend này để lấy danh sách/chi tiết/playback; backend quản lý catalog riêng trong PostgreSQL và dùng Notis/TTGT cho metadata/ảnh nguồn. Không có dependency runtime Udrivex trong thiết kế. Tính public là thông tin người dùng xác nhận; quota/SLA/độ đầy đủ vẫn là câu hỏi kỹ thuật, không phải yêu cầu phê duyệt lại nguồn.

| Vai trò | Thành phần thực hiện |
|---|---|
| API danh sách, filter/search, detail, playback descriptor từng có ở Udrivex | Backend mới + catalog PostgreSQL |
| Thu thập/cập nhật metadata camera nguồn | Notis adapter → upsert catalog riêng |
| Nội dung ảnh snapshot | Notis/TTGT public → snapshot pipeline/cache backend → client |
| UI/flow học từ Genius | Danh sách → chọn → xem → refresh/favorites với ID mới ổn định |
| Bản đồ/tìm địa điểm/tuyến khi đến lát hỗ trợ | Vietmap đã có của người dùng |

Lát A2 vẫn thuộc chức năng xem camera: thêm descriptor LIVE cho nguồn HTTPS đã chọn và được xác minh trên client mục tiêu, trạng thái loading/error/fallback về snapshot. Tách A2 vì nguồn LIVE chưa có contract thành công cho Notis đã điều tra; không giả coi snapshot 12 giây/lần là video LIVE. Bản đầu không báo `live=true` chỉ vì response có chuỗi m3u8.

Các lát hỗ trợ sau A1: khu vực/bản đồ/nearby và Vietmap Autocomplete/Place/Reverse/Route; weather/health sâu, durable worker/FCM, cảnh báo khu vực rồi vị trí/tuyến; VIP/quảng cáo. Favorites hiện local ở app tương lai theo ID backend ổn định; không tạo user/account/favorite CRUD backend khi chưa chọn sync. Không dựng live relay/transcoding EVUP trong A1; không khai thác API Udrivex/AppCheck như nguồn mặc định.

### 1.1. Hợp nhất hai bộ reverse

Spec dùng **Genius cho flow danh sách/chi tiết, schema đa nguồn, cache và favorites**; dùng **Notis cho adapter danh sách/snapshot đã đối chiếu HTTP thực tế**. [Ma trận bằng chứng → yêu cầu → giai đoạn](../../backend-reverse-traceability.md) ghi artifact, nguồn, loại quan sát và giới hạn của từng kết luận. Đây không phải chỉ thêm Vietmap vào spec Notis và cũng không phải tự động dùng API Udrivex/private catalog của Genius.

Những yêu cầu A1 được bổ sung từ đối chiếu Genius: tên + địa chỉ/quận nullable trên thẻ; tìm tên/địa chỉ không dấu; lọc district có trong catalog; camera liên quan khi có district; catalog version/fetchedAt/stale; ID ổn định cho favorites; descriptor nguồn không đánh đồng GET/POST/WSS/HLS; không giả có backup tự động. Fullscreen/tim là flow client, backend cung cấp data/ID/ảnh phục vụ flow đó.

## 2. Stack và bố trí

- Tạo project mới tại `backend/` của workspace, tách APK, mã dịch ngược và evidence.
- Node.js 24 LTS, TypeScript strict, NestJS + Fastify, Undici, OpenAPI.
- PostgreSQL 17 + PostGIS, driver `pg`, migrations SQL có version. PostGIS geography SRID 4326 và GiST index cho camera.
- Một API process; catalog sync quản trị gọi có lock chống chạy trùng, chưa cần distributed worker.
- Cache RAM có giới hạn cho snapshot và gộp concurrent requests cùng camera. Không cần Redis lúc đầu.
- Docker Compose cho API + PostGIS; volume bền và healthcheck. Có hướng dẫn chạy Node trực tiếp nếu Docker không khả dụng; không coi chưa chạy integration DB là đã pass.
- Dependency được khóa bằng lockfile khi triển khai; chọn patch tương thích và ghi rõ trong README. Chưa cài dependency ở giai đoạn spec.

So sánh đã review ở stack-review: Fastify thuần ít abstraction nhưng phải tự tổ chức các module; hai native app tăng công sức và không giải quyết backend. Chọn NestJS/Fastify tiếp tục phù hợp scope nhiều adapter và cảnh báo về sau; không có benchmark khẳng định framework này tối ưu tuyệt đối.

Module boundaries:

| Module | Trách nhiệm |
|---|---|
| Config | Parse/validate env, chế độ dữ liệu và upstream allowlist |
| Database | Pool, migrations, spatial repository, transactional catalog update |
| Camera catalog | Danh sách/thumbnail/district/address, search tên + địa chỉ, lọc district, phân trang, chi tiết/related và ID ổn định |
| Camera providers | Fixture và Notis mapping; không để source schema rò vào API public |
| Playback descriptor | Khai báo khả năng xem thực sự; snapshot trước, contract LIVE mở rộng sau |
| Snapshot | Resolve source theo camera ID, fetch có giới hạn, nhận dạng bytes, cache/cancel/error |
| Admin sync | Import catalog theo vùng seed/config; khóa, báo số upsert và coverage |
| HTTP infrastructure | Authentication nội bộ, rate limit, validation, error mapping, request ID, health/OpenAPI |

Vietmap, nearby và route không là module phải cài/viết/test trong A1. Database có thể chuẩn bị tọa độ/PostGIS cho roadmap; không vì vậy biến spatial query thành đầu ra chính.

## 3. Contract HTTP v1

JSON thành công có `data` và `meta:{requestId,dataMode}`; catalog list có `meta.page` và `meta.catalog:{version,fetchedAt,isStale,coverage}`. Version gắn lần import thành công, fetchedAt là thời điểm sync catalog, không phải chụp ảnh. Default đề xuất stale sau 24 giờ (`CATALOG_STALE_AFTER_MS=86400000`), khác heuristic của app Genius và cấu hình được. Source lỗi vẫn trả catalog cuối cùng với stale đúng, DB chưa có dữ liệu trả list rỗng với coverage unknown. Snapshot trả binary. Lỗi thống nhất `{error:{code,message,requestId,retryable}}`. Không trả upstream body/stack/key/URL có credential.

| Method/path | Input | Kết quả |
|---|---|---|
| GET `/health/live` | Không auth | Process sống; không gọi provider |
| GET `/health/ready` | Không auth | DB sẵn sàng; không lộ credentials; không phụ thuộc Vietmap |
| GET `/docs`, `/openapi.json` | Auth nội bộ | OpenAPI hợp đồng và ví dụ |
| GET `/v1/cameras` | `provinceId=tp_hcm`, `q?`, `district?`, `limit=50`, `offset=0` | Trang catalog: ID, tên, địa chỉ/district nullable, thumbnailEndpoint, khả năng xem/trạng thái; total local, fetchedAt và coverage nguồn |
| GET `/v1/camera-districts` | `provinceId=tp_hcm` | Các district label thực sự có trong catalog + số camera; không gọi Vietmap hoặc giả danh mục hành chính mới |
| GET `/v1/cameras/{id}` | UUID domain | Tên, vị trí nếu có, capability, trạng thái nguồn với thời điểm kiểm tra, playbackEndpoint; không trả raw IP/source secret |
| GET `/v1/cameras/{id}/playback` | UUID domain | Descriptor kind=snapshot, snapshotEndpoint, refreshIntervalMs, capturedAt nullable; không tải ảnh hoặc mở stream khi chỉ đọc descriptor |
| GET `/v1/cameras/{id}/related` | UUID domain, `limit=6` (1–20) | Camera cùng province/district đã có, loại chính camera hiện tại, sort tên rồi ID; district thiếu thì [] với reason `DISTRICT_UNKNOWN`, không đoán gần nhất |
| GET `/v1/cameras/{id}/snapshot` | UUID domain, `If-None-Match?` | Binary có MIME từ magic, ETag; 304 khi ảnh còn phù hợp validator sau kiểm tra cache/freshness |
| POST `/v1/admin/camera-providers/notis/sync` | JSON `{provinceId:"tp_hcm",bbox:[west,south,east,north]}` | Số upsert, thời điểm/vùng coverage; chỉ hoạt động khi adapter được bật |

V1 chỉ hỗ trợ province `tp_hcm`; slug khác trả 400 `UNSUPPORTED_PROVINCE`, không âm thầm chuyển tỉnh. Query q trim; rỗng tương đương không lọc, còn lại độ dài 2–120; tìm tên + địa chỉ đã chuẩn hóa không dấu trong catalog, không gọi geocoder. District trim 1–80 ký tự nếu có, so label chuẩn hóa chính xác, label không có trả list rỗng. Limit 1–100, offset 0–10000; list sort tên đã chuẩn hóa rồi ID. Không trả tổng global nguồn từ count trang.

Bbox `[west,south,east,north]` chỉ là input **quản trị import dữ liệu nguồn** trong A1, không là thao tác bắt buộc của người xem. WGS84 longitude/latitude, phải west<east và south<north; lat/lng finite trong range hợp lệ, không hỗ trợ antimeridian. Request danh sách/chi tiết không tự tải mọi thumbnail hoặc mở session của tất cả camera.

**Playback A1:** descriptor `kind=snapshot`, `refreshIntervalMs=12000` mặc định cấu hình được; đây là đề xuất dựa mẫu, không áp đặt cho mọi nguồn. Client gọi snapshot để xem/làm mới, hủy request cũ khi đổi camera hoặc rời màn. Backend không giữ timer polling cho mỗi camera khi không có người xem. ThumbnailEndpoint dùng pipeline snapshot/cache chung; client tương lai chỉ tải các thẻ visible.

**Playback A2:** bổ sung `kind=hls` khi đã có provider hợp lệ; descriptor không lộ secret lâu dài, có expiresAt nếu URL hạn dùng. Nếu camera chỉ có stream chưa được hỗ trợ thì trả capability rõ/422 `PLAYBACK_UNSUPPORTED`, không trả URL đoán. Contract và kiểm thử nguồn thật được mở rộng trong spec A2; không coi đây là chức năng đã triển khai A1.

## 4. Domain và database

`Camera`: `id` UUID ổn định, `provider`, `providerCameraId`, `provinceId`, `name`, `address?`, `district?`, `location:{lat,lng}|null`, `capabilities:{snapshot:boolean,live:boolean}`, `availability:unknown|online|offline|degraded`, `checkedAt?`, `updatedAt`, `thumbnailEndpoint`, `playbackEndpoint`, `snapshotEndpoint` của backend. Camera thiếu tọa độ vẫn được list/xem nếu có nguồn ảnh; không invent tọa độ 0,0. Không gửi source IP hoặc secret tới client. A1 live=false; trạng thái chưa kiểm tra là unknown, không gọi camera đang online chỉ vì catalog có record. Chỉ khai báo capability đã có descriptor hợp lệ; không coi `ptz` là tính năng điều khiển.

District/address chỉ điền khi nguồn có field được xác minh hoặc metadata bổ sung hợp lệ; không mặc định Notis `dist` tương đương quận của Genius. Không copy district overlay/174-ID blacklist/asset CG01 từ app gốc vào seed sản phẩm. Số local/Genius API/available/visible khác nhau phải được phân biệt.

`CameraSource` phân loại nội bộ `snapshot|hls|evup|youtube|unknown`, tách `sourceKind` với `supportedKinds`. Metadata có method/body/header là provider request config nội bộ, không phải input HTTP proxy public; A1 chỉ Fixture/Notis GET được bật. Không diễn giải Genius `isHls=1` thành mọi nguồn HLS hoặc dùng `duration=11` làm 11 milliseconds/seconds khi chưa có contract. Backup chỉ được thêm vào adapter khi có rule/nguồn/test riêng; A1 không tự chuyển qua URL backup chưa xác minh.

Camera không có snapshot khả dụng được list với capability rõ; `thumbnailEndpoint`/`snapshotEndpoint` là null khi capability snapshot=false. Gọi playback/snapshot không được hỗ trợ trả 422 `PLAYBACK_UNSUPPORTED`; không tạo endpoint giả hoặc ảnh lỗi được mô tả như camera thật.

`CameraArea`: UUID ổn định, province, name, center, source/version. `CatalogImport`: provider, bbox, startedAt/finishedAt, outcome, receivedCount/upsertedCount, coverage. `CameraSource`: snapshot reference chuẩn hóa nội bộ, status metadata nguồn dạng nullable; dữ liệu nhạy cảm không vào public DTO/log.

DB unique `(provider,providerCameraId)`; upsert giữ UUID cũ. Không gộp chỉ vì tên giống. Sync lỗi hoặc response malformed không xóa catalog tốt đang có. V1 không tự xóa camera do một response vắng ID. Coverage là `unknown|partial|verified` với vùng/thời điểm; adapter Notis mặc định `unknown` hoặc `partial`, không tự nâng verified vì HTTP 200.

V1 search tên/địa chỉ local có/không dấu bằng normalized search columns được tạo khi import; index/normalization phải được kiểm thử bằng fixture tên tiếng Việt, địa chỉ null và district thiếu. Tổng và trang thuộc catalog đã nhập, không được diễn đạt là toàn bộ camera ngoài thực tế. Catalog giữ qua restart, upsert không đổi ID để favorites client resolve được; favorites không lưu source URL làm định danh. Truy vấn gần tôi/PostGIS matching là lát hỗ trợ sau.

## 5. Provider camera và dữ liệu mẫu

`CAMERA_PROVIDER_MODE=notis|fixture`, mặc định ứng dụng là `notis` để phục vụ dữ liệu thật từ nguồn đã chọn. Fixtures dùng cho test và demo explicit, không tự fallback sang dữ liệu giả khi nguồn thật lỗi. Fixture tự tạo có ID ổn định, public tọa độ mẫu TP.HCM, ít nhất 12 camera thuộc ít nhất 2 district và một district null; gồm địa chỉ null, tọa độ null, trùng tên khác ID, và một source kind chưa hỗ trợ. Có ảnh mẫu do dự án tạo; không sao chép raw asset/catalog CG01 của app gốc. Khi chạy fixture trả `meta.dataMode=fixture` và `X-Data-Mode:fixture`; khi dùng nguồn thật ghi `dataMode=notis`.

Notis là adapter nguồn public chính A1 theo xác nhận của người dùng, dựa bằng chứng kỹ thuật `docs/camera-api-debug-pass7.md`: GET bbox và snapshot ở `https://api.notis.vn/v4/`. App có gửi Bearer cho list nhưng probes đã 200 không credentials; adapter mặc định gọi không credentials. Secret chỉ cấu hình nếu contract nguồn thay đổi, không tái sử dụng token thu từ app gốc. Vẫn cần đo timeout/quota/cache/coverage để vận hành ổn định; đây không phải lý do trì hoãn triển khai adapter public đã được chọn.

Chỉ upstream camera đã định danh trong DB; snapshot ID Notis phải đáp ứng dạng 24 hex, không nhận raw URL từ client. Base origin cố định allowlist; tắt follow redirect tới host khác. Không connect `values.ip`, không phục vụ generic HTTP proxy.

`notis` cần import trước khi list local có dữ liệu. Có CLI `npm run camera:sync -- --bbox=west,south,east,north` dùng cùng sync service với admin endpoint; README hướng dẫn migrate → sync Notis → list → detail → snapshot. Import thực hiện GET bbox cấu hình và map DTO; không dùng count 89/90 làm cap hoặc dữ liệu complete. Khi DB chưa import, list [] có `meta.catalog.syncState=never_synced`; không thay bằng fixtures. Sau import thành công `syncState=synced`; lỗi sau đó giữ catalog/version cuối và ghi sync outcome. Area có thể từ seed đã ghi nhận, phải có source/version; không tự gọi `/tenants` mỗi request. Nếu thêm tenant-config sync sau này phải là thay đổi contract có kiểm thử riêng.

Test suite dùng fixture/fake upstream; demo fixture là chế độ được chọn rõ ràng. Đường chạy ứng dụng thực tế A1 là đồng bộ Notis → catalog của backend → danh sách → chi tiết → playback → snapshot/refresh. Không cần `VIETMAP_API_KEY` hoặc Udrivex app-check để thực hiện đường này. Nghiệm thu tích hợp thật cần smoke test Notis thành công và ghi thời điểm/vùng/số record/ảnh đã lấy, không chỉ test fixture.

## 6. Vietmap v4 — ghi chú tích hợp sau A1, không phải scope triển khai hiện tại

Các endpoint `/v1/camera-areas`, `/v1/cameras/nearby`, `/v1/places/autocomplete`, `/v1/places/detail`, `/v1/places/reverse`, `/v1/routes/preview` được chuyển sang lát hỗ trợ bản đồ/vị trí sau. Không tạo controller/stub giả cho chúng trong A1. Ghi chú tài liệu dưới đây giữ để tái sử dụng khi đến lát đó; không là điều kiện hoàn thành backend danh sách/xem camera.

Theo tài liệu chính thức kiểm tra ngày 2026-10-14: Route v3 được ghi ngừng hỗ trợ, thiết kế mới chọn v4. Không fallback âm thầm sang v3 khi gói/key không dùng được; báo lỗi cấu hình/enforcement để đối chiếu tài khoản của người dùng.

| Thao tác | Upstream GET `https://maps.vietmap.vn` | Mapping |
|---|---|---|
| Autocomplete | `/api/autocomplete/v4?apikey=…&text=…&focus=lat,lng&display_type=6` | Giữ ref_id nguyên nghĩa; không tự gọi Place cho mọi gợi ý |
| Detail | `/api/place/v4?apikey=…&refid=…` | Lấy tọa độ sau khi client chọn một gợi ý |
| Reverse | `/api/reverse/v4?apikey=…&lat=…&lng=…&display_type=6` | Chuẩn hóa địa chỉ, list rỗng khác lỗi |
| Route | `/api/route/v4?apikey=…&point=lat,lng&point=lat,lng&points_encoded=true&vehicle=…` | Decode polyline5 ra GeoJSON [lng,lat]; giữ distance mét và time milliseconds |

Autocomplete không trả tọa độ theo docs; Place là bước lấy tọa độ. Bản đồ nền/SDK render nằm ở mobile, không build tile proxy trong backend v1. Server API key không trả trong OpenAPI/example/log; SDK mobile key nếu cần được cấu hình riêng khi xây client.

Khi đến lát Vietmap: không cache bền place/route responses trước khi xác nhận điều kiện gói; timeout/rate limit và budget phải được thiết kế theo quota thực tế. Provider có quota/transaction khác request. Không tự thêm các cơ chế này vào A1.

Nguồn chính thức: [Vietmap overview](https://maps.vietmap.vn/docs/vi/map-api/overview/), [Autocomplete v4](https://maps.vietmap.vn/docs/vi/map-api/autocomplete-version/autocomplete-v4/), [Place v4](https://maps.vietmap.vn/docs/vi/map-api/place-v4/), [Reverse v4](https://maps.vietmap.vn/docs/vi/map-api/reverse-version/reverse-v4/), [Route v4](https://maps.vietmap.vn/docs/vi/map-api/route-version/route-v4/). Chỉ đọc docs, chưa gọi bằng key người dùng.

## 7. Timeout, cache, lỗi và truy cập

Các số dưới là **default thiết kế v1**, không phải SLA hoặc contract nguồn đã reverse:

- Upstream timeout 5 giây camera/snapshot; abort khi client hủy, trừ shared fetch còn client khác chờ. Không có request Vietmap trong A1.
- Snapshot tối đa 2 MiB, cache RAM tổng tối đa 32 MiB, TTL 3 giây, tối đa 4 upstream camera fetch đồng thời. Hết ngân sách queue chờ 32 request thì 503 `BUSY`. Coalesce request cùng ID, hủy một client không làm mất response client khác còn chờ.
- Snapshot MIME dựa magic JPEG/PNG/WebP, không giả `image/jpeg` từ URL; từ chối HTML/JSON trả status 200. Ảnh quá lớn trả 502 `INVALID_UPSTREAM_RESPONSE`. Lát v1 không trả stale image khi upstream lỗi; trả lỗi rõ. Metadata chỉ `fetchedAt`, `capturedAt=null` nếu nghĩa timestamp chưa xác minh.
- Cache ETag hash ảnh; validator được xét trên cached bytes còn TTL hoặc bytes mới sau TTL. Không giữ ảnh vô hạn bởi 304. `Cache-Control:private,no-cache`, response chỉ rõ thời điểm nhận, không gọi đó là thời điểm chụp.
- JSON body tối đa 64 KiB. Reject NaN/Infinity, bbox quản trị sai, query thừa trong request public. Provider JSON validate trước mapping; thiếu field bắt buộc không làm crash hoặc ghi hỏng DB.
- HTTP 400 input; 401 auth; 404 camera; 422 playback unsupported; 429 backend quota/rate limit; 502 upstream lỗi/schema; 503 missing config/busy; 504 timeout. Upstream 401/403/429 là mã nghiệp vụ `UPSTREAM_AUTH|UPSTREAM_RATE_LIMIT`, không trả nguyên secret URL/body; trả Retry-After đã kiểm tra nếu có. Error response có `retryable` đúng nhóm, không toàn bộ lỗi đều retry.
- Backend v1 là môi trường nội bộ/local: bind localhost mặc định; `X-Api-Key` từ `BACKEND_API_KEY` cho mọi API/docs trừ health. Admin có `ADMIN_API_KEY` riêng; không nhúng hai khóa này vào app phát hành. Docker expose API trên localhost host. Public mobile deployment cần thiết kế installation/session auth và quota riêng ở lát sau.
- Rate limit v1 theo API credential + IP: 120 request/phút, cấu hình được. Không tin X-Forwarded-For nếu chưa cấu hình trusted proxy. TLS/upstream certificate kiểm tra chuẩn, không sao chép trust bypass của app gốc.
- Log method, route template, status, duration, requestId, provider code; không log full URL/query/API key, auth/cookie, tọa độ/tuyến/search text hoặc upstream body. Secret nằm `.env` local được ignore; `.env.example` chỉ tên biến/placeholder.

Env tối thiểu A1: `DATABASE_URL`, `PORT=3000`, `BACKEND_API_KEY`, `ADMIN_API_KEY`, `CAMERA_PROVIDER_MODE=notis`, `NOTIS_AUTH_TOKEN` tùy chọn và để trống mặc định; các timeout/size/rate limit có default ở trên. `.env.example` và Compose dùng notis; test/demo fixture override explicit. Không cần biến Vietmap hoặc Udrivex trong A1. Không hardcode khóa hoặc nhận key provider từ request client.

## 8. Nghiệm thu và kiểm chứng

1. DB migration + fixture seed chạy lặp không tạo trùng; restart giữ cùng ID; ready lỗi khi DB không sẵn sàng.
2. **Flow nghiệm thu chính:** không có Vietmap key/GPS vẫn list → search tên/địa chỉ không dấu → lọc district → phân trang → chọn đúng camera → detail/playback → snapshot → refresh được. Thumbnail và preview cùng ID; related loại chính ID, district null trả [] rõ lý do; count local khác source coverage. List không fetch ảnh mọi camera khi chưa được yêu cầu.
3. Snapshot đúng ID/MIME, coalesce concurrent requests, TTL hết phải fetch lại; không leak buffer memory; 304 đúng validator; timeout, HTML 200, oversized body, disconnect đều được xử lý.
4. Fake camera provider kiểm tra import/upsert giữ ID, thiếu/null district/address/location, timeout/401/429/malformed response; import lỗi không làm mất catalog tốt. Source lỗi và restart vẫn trả catalog cũ với version/fetchedAt/stale đúng; timestamp catalog không thành capturedAt. Không kiểm thử Vietmap/route như prerequisite A1.
5. Playback snapshot descriptor đúng endpoint và interval, không mở source session khi đọc descriptor; live=false trong A1. Request ảnh camera A chậm không làm response camera B mang sai ID/nội dung; hủy shared fetch tôn trọng client còn chờ. Stream chưa hỗ trợ báo rõ thay vì giả LIVE.
6. API/admin auth tách biệt; rate limit/input bounds/body limit có test; captured logs không chứa secret/query/coords test fixture.
7. OpenAPI phản ánh path/DTO/default/auth thật; README có local/Docker/migration/seed/test, phân biệt fixture và provider thật.
8. Chạy typecheck/build/unit/API integration + database integration khi triển khai. Unit/integration dùng fake camera upstream. Chạy thêm smoke test nguồn Notis public thật để nghiệm thu A1: sync một bbox giới hạn → GET danh sách backend → detail/playback → ảnh đúng MIME. Giữ CLI smoke riêng để CI không tự gọi nguồn ở mọi lần test. Không cần smoke-test Vietmap hoặc gọi Udrivex để hoàn tất A1.

Không coi typecheck hoặc fixture pass là đã xác minh nguồn thật, iOS hoặc ngân sách production. Không mua/thuê/deploy trong kế hoạch local này.

## 9. Review tự kiểm

- Scope: danh sách/search tên camera/chi tiết/playback snapshot/refresh là đầu ra A1. LIVE là A2; bản đồ/Vietmap là hỗ trợ sau. Roadmap cảnh báo còn nguyên, chưa ôm AI/billing/weather vào lát đầu.
- IDs/schema: provider ID khác domain ID, GeoJSON/lat-lng khác nhau được quy định, không gộp hai app reverse.
- Secrets/quota: key qua env, server-only, không raw URL proxy, không ghi raw URL trong lỗi/log; không retry âm thầm API trả phí.
- Mất dữ liệu: import không xóa theo absence, sync có lock, DB bền; RAM cache không là source of truth.
- Prerequisite hiện tại: spec đã được xác nhận; implementation plan chờ review và chọn cách thực thi trước khi viết product code theo workflow đang áp dụng.
