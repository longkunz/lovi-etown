# Tab Bản đồ và khám phá camera gần tôi

Ngày: 2026-10-24. Trạng thái: **Đã chốt Vietmap và Bản đồ mở mặc định**; chi tiết triển khai đang ở bản kế hoạch, chưa viết mã sản phẩm.

Theo dõi: [GitHub issue #40](https://github.com/longkunz/lovi-etown/issues/40). Builder check bản thiết kế ban đầu đã hoàn tất; phần chuyển SDK Vietmap được cập nhật sau quyết định của người dùng.

## Ý định và phạm vi

### Quyết định nhà cung cấp: Vietmap

Người dùng đã chọn **Vietmap** vì hiện không đăng ký được Google Maps API. Dùng `vietmap_flutter_gl` cho tab khám phá và bản đồ mini/toàn màn hình hiện có. API camera/PostGIS và go_router giữ thiết kế bên dưới. Không còn chờ lựa chọn nhà cung cấp; API key Vietmap là điều kiện cấu hình runtime, không ngăn viết code hoặc chạy test với fake.

- SDK dự kiến pin `vietmap_flutter_gl: 4.1.1`; cần xác minh build với SDK Flutter và lockfile hiện hành khi triển khai. Chỉ thêm gói hiển thị map, không thêm navigation SDK hoặc REST wrapper khi chưa có nhu cầu.
- Native setup theo package: Android minSdk tối thiểu 24, repository JitPack; iOS deployment target tối thiểu 12.0 và giữ mức cao hơn mà dự án đang dùng. Không sao chép quyền location background từ ví dụ SDK.
- Khóa cấu hình qua `--dart-define=VIETMAP_API_KEY`, cùng cách đọc build environment hiện có. Không commit key thật hoặc dùng key mẫu thay key hợp lệ. Thiếu key/lỗi style chỉ ảnh hưởng map: hiện thông báo và nút tới tab Camera, không khóa cả danh mục. Demo/widget test dùng fake canvas, không cần key.
- Mặc định style đường phố Vietmap. Có kế hoạch tích hợp hybrid và traffic riêng của Vietmap, nhưng nghiệm thu phải dùng key thật và kiểm tra quyền truy cập từng nguồn; lỗi lớp phụ giữ bản đồ nền hoạt động và báo trạng thái rõ ràng.
- Chuyển toàn bộ bản đồ trong ứng dụng, loại dependency/import/native setup của Google Maps sau khi không còn nơi sử dụng. Nút chỉ đường mở ứng dụng bên ngoài giữ luồng hiện có, không cần Maps API key.

Nguồn: [Flutter SDK](https://maps.vietmap.vn/docs/sdk-mobile/Flutter/map/), [package và native setup](https://pub.dev/packages/vietmap_flutter_gl), [Vietmap Console](https://maps.vietmap.vn/console-v2/register).

Người dùng cần một điểm truy cập rõ ràng trong navigation để khám phá camera theo vị trí. Thêm hai tab chính **Bản đồ | Camera**. **Người dùng đã xác nhận Bản đồ là tab đầu tiên (index 0) và màn hình mở mặc định khi khởi động app thông thường**; Camera là tab thứ hai (index 1). Trong Bản đồ có hai chế độ **Vùng đang xem | Gần tôi**. Giữ Quan tâm inline trong Camera và tái sử dụng luồng mở chi tiết/viewer hiện tại.

Nhà cung cấp Vietmap, thứ tự tab và màn hình mở mặc định là yêu cầu đã được người dùng xác nhận. Các chi tiết và giá trị mặc định còn lại do agent đề xuất từ yêu cầu “plan làm đi”. Chỉ cập nhật kế hoạch trong lượt chốt nhà cung cấp, chưa viết mã sản phẩm.

## Bằng chứng hiện trạng

- `mobile/lib/src/routing/app_router.dart`: `/` mở `CameraFeature`; chưa có route khám phá bản đồ.
- `presentation/screens/camera_screen.dart`: màn hình danh mục, bộ lọc và Quan tâm inline; chưa có thanh tab chính.
- `presentation/screens/camera_traffic_map_viewer_screen.dart`: bản đồ cho một camera, có traffic/vệ tinh/chỉ đường; không thực hiện truy vấn khám phá camera.
- `CameraRepository`: có list/detail/related/playback/snapshot; `related` là cùng quận, không phải khoảng cách.
- `backend/src/catalog/query-schema.ts`: list chỉ chấp nhận provinceId/q/district/limit/offset.
- `backend/src/catalog/catalog.repository.ts`: đã lưu `geography(Point,4326)`; migration 001 có GiST trên `geom`; migration 002 thêm stream URL.
- Đã có `geolocator`, `google_maps_flutter`, `go_router`, `LocationService`. Main Android manifest chưa khai báo quyền vị trí và iOS Info.plist chưa có usage description; phải kiểm tra merged manifest khi thực thi.
- Workspace có nhiều thay đổi đang làm, gồm chính các màn hình liên quan. Khi triển khai phải giữ các thay đổi đó và kiểm tra lại baseline.
- Graph project `Users-admin-Sources-lovi-etown`, generation `2026-10-24T14:37:20Z`; các đường dẫn nguồn chính đã check coverage, không có gap được ghi nhận. Migration 001 có parse gap đã được đọc trực tiếp ở phiên này. Đây là bằng chứng tĩnh, không phải nghiệm thu runtime.

## Các phương án

1. **Đề xuất: API địa lý + tab Bản đồ.** Truy vấn trên PostGIS, trả kết quả có giới hạn theo vùng/bán kính. Dữ liệu không phụ thuộc việc danh mục mobile đã tải bao nhiêu trang; cần thêm API và kiểm thử DB.
2. **Lọc trên điện thoại.** Ít thay đổi backend, nhưng phải tải đủ toàn bộ catalog trước mới có thể khẳng định kết quả đầy đủ. Không phù hợp với danh mục phân trang hiện tại.
3. **Chỉ thêm lối vào bản đồ một camera.** Công ít hơn, nhưng không giải quyết khám phá camera gần vị trí người dùng.

Kế hoạch đi theo phương án 1 để có kết quả cụ thể có thể review; lựa chọn renderer đã được người dùng chốt là Vietmap.

## Trải nghiệm đề xuất

- Navigation theo thứ tự **Bản đồ | Camera**. Bản đồ là tab mặc định tại `/`; Camera có route `/cameras`. `/map` redirect về `/` để giữ đường dẫn bản đồ đã đề xuất trước đó. Khởi động thông thường luôn vào Bản đồ, không tự khôi phục tab Camera từ phiên trước; deep link tường minh vẫn mở đúng đích. Chuyển tab trong phiên giữ query/quận/vị trí cuộn danh mục và tâm/zoom/mode bản đồ.
- Khi mở app thông thường, hiển thị Bản đồ ở chế độ Vùng đang xem, tâm TP.HCM `(10.7769,106.7009)`, zoom 13. Chưa hỏi GPS. Tìm theo vùng nhìn thấy sau khi map sẵn sàng. Không khởi tạo danh mục hoặc tải thumbnail của tab Camera trước khi người dùng vào tab đó.
- Vùng đang xem: sau `onCameraIdle`, debounce 400 ms rồi tải bbox mới; giữ bộ lọc quận của bản đồ riêng với Camera. Không có tìm theo tên trong bản v1.
- Gần tôi: chỉ xin quyền khi người dùng chọn chế độ này hoặc bấm nút vị trí. Lấy một vị trí hiện tại, timeout 10 giây, không stream GPS nền. Bán kính chọn 1/2/5 km, mặc định 2 km. Hiển thị vòng bán kính và danh sách theo khoảng cách tăng dần.
- Trong Gần tôi, kéo bản đồ không đổi tâm tìm kiếm; muốn xem vùng khác phải chuyển Vùng đang xem. Nút “Cập nhật vị trí” lấy lại vị trí và truy vấn lại.
- Quyền denied: hiển thị thử lại; deniedForever: nút mở cài đặt app; GPS tắt: nút mở cài đặt vị trí; timeout: thử lại. Người dùng vẫn xem được Vùng đang xem.
- Chạm marker hoặc dòng danh sách mở chi tiết camera hiện có; từ đó mở viewer như hiện tại. Chỉ camera được chọn tải snapshot, không tải ảnh của toàn bộ marker.
- Camera thiếu tọa độ bị loại khỏi kết quả địa lý nhưng vẫn ở danh mục thường. Kết quả rỗng không được diễn đạt là không có camera trên toàn thành phố.
- Có loading, lỗi và thử lại, rỗng, catalog cũ/phủ chưa đầy đủ, và cảnh báo vượt giới hạn. Giữ kết quả tốt cuối cùng khi lỗi, đánh dấu là kết quả cũ; không gắn nhãn chúng là kết quả thành công của truy vấn mới.
- `hasMore=true`: Vùng đang xem hiện “Phóng to để xem đủ camera”; Gần tôi hiện “Đang hiển thị các camera gần nhất, hãy giảm bán kính để xem đủ”. Không có phân trang bản đồ trong v1.
- Traffic dùng nguồn Vietmap, giữ preference bật/tắt hiện có. Đổi đường phố ↔ hybrid phải giữ center/zoom/marker và phục hồi traffic nếu đang bật. Nếu lớp phụ lỗi hoặc key không truy cập được thì giữ đường phố, báo không tải được lớp đó; không giả vờ có traffic/vệ tinh. Tái sử dụng chính sách glass opaque trên native map, vùng chạm tối thiểu 48×48 dp; kiểm tra 320 dp và text scale 2.0.

## Hợp đồng API đề xuất

Thêm **GET `/v1/map-cameras`**, reader/admin `x-api-key`, giữ cơ chế rate limit/error/requestId hiện có. Route riêng tránh xung đột `cameras/:id` và không đổi nghĩa API list.

Query chung: `provinceId=tp_hcm`, `district` tùy chọn (trim, tối đa 80 ký tự), `limit` nguyên trong 1..200, mặc định 200. Chỉ nhận đúng một dạng:

```text
?provinceId=tp_hcm&bbox=west,south,east,north&limit=200
?provinceId=tp_hcm&lat=10.7769&lng=106.7009&radiusMeters=2000&limit=200
```

- Bbox gồm bốn số hữu hạn: longitude [-180,180], latitude [-90,90], west < east, south < north; không hỗ trợ bbox qua kinh tuyến 180. App chỉ gửi bbox hợp lệ; nếu viewport vượt biên độ kinh/vĩ độ này thì hiện yêu cầu zoom vào, không gửi request sai.
- Nearby bắt buộc đủ lat/lng/radiusMeters; radiusMeters là số nguyên 100..5000. Mobile chỉ chọn 1000/2000/5000. Giới hạn 200 kết quả là giới hạn tải, không phải bán kính tự mở rộng.
- Reject query lạ, query lặp dạng array, số rỗng/NaN/Infinity, số nguyên có hậu tố hoặc phần lẻ, thiếu trường, trộn hai dạng: 400 `INVALID_INPUT`. Tỉnh khác: lỗi `UNSUPPORTED_PROVINCE` hiện có.
- Response `data`: `Array<{camera: CameraDto, distanceMeters: number | null}>`. Khoảng cách chỉ có trong nearby và là mét đường thẳng địa lý, không phải quãng đường di chuyển.
- Response `meta`: `{requestId, dataMode, result:{limit,returned,hasMore}, catalog:{version,fetchedAt,isStale,coverage,syncState}}`. `catalog` giữ đúng nghĩa và shape hiện có, lấy từ cùng đường xử lý catalog metadata để tránh copy lệch.
- Query lấy `limit+1` để xác định hasMore rồi cắt về limit. Nearby sort khoảng cách tăng, id tăng làm tie-breaker; bbox sort id tăng. Không trả sourceRef/token upstream và không làm lộ thông tin vị trí trong log ngoài chính sách request log hiện hành.

## PostGIS và tổ chức mã

- Giữ PostgreSQL/PostGIS hiện có. Nearby dùng `ST_DWithin(geom, point::geography, radiusMeters)` và `ST_Distance`; tận dụng index geography sẵn có.
- Bbox dùng `ST_Intersects(geom::geometry, ST_MakeEnvelope(west,south,east,north,4326))` để diễn đạt khung kinh/vĩ độ. Thêm migration `003_map_geometry_index.sql` tạo GiST expression index `(geom::geometry)`; index geography hiện có không mặc nhiên phục vụ biểu thức cast này. Giữ migration cũ nguyên vẹn.
- SQL parameterized, loại geom null, scope province và district nhất quán. Kiểm tra EXPLAIN trên dữ liệu đủ lớn; không khẳng định index được dùng chỉ từ dataset vài dòng.
- Thêm `MapCatalogRepository`, `MapCatalogService`, `MapCatalogController` trong `catalog/`, đăng ký qua `CatalogModule`. Tách khỏi file repository hiện đã lớn; dùng lại pool, normalization và CameraDto. Repository chịu transaction read-only REPEATABLE READ khi đọc rows và catalog metadata để response nhất quán trong lúc sync.
- Mobile thêm interface `CameraMapRepository` riêng, không thêm method vào `CameraRepository` làm ảnh hưởng toàn bộ fake hiện có. Một adapter API gọi `CameraApiClient.getMapCameras`; một adapter fixture thực hiện lọc/sort/hạn chế tương đương hợp đồng.
- `CameraMapCubit` độc lập với `CameraCatalogCubit`; mỗi thay đổi bbox/mode/radius/district tăng generation ngay lập tức, hủy request/timer trước đó. Response muộn của API hoặc GPS không được ghi đè mode/tab mới.
- `CameraLocationGateway` injectable bọc geolocator, trả kết quả typed, không parse chuỗi lỗi. Dùng check/request quyền có chủ đích; không gọi getter hiện tại tự xin quyền trong lúc build. Không cần sửa rộng service dùng chung.
- `CameraNavigationShell` sở hữu repository dùng chung, tab selection và camera/map state. Khởi tạo map cho tab mặc định; lazy tạo CameraScreen/catalog cubit/scheduler khi lần đầu chọn Camera. Giữ state Dart nhưng dispose native map khi tab ẩn, app background hoặc viewer che; tạo lại theo tâm/zoom đã lưu khi trở về. Tạm dừng thumbnail scheduler của danh mục khi tab Camera ẩn; không làm hỏng cơ chế lifecycle foreground/background hiện có.
- Root `/` (Bản đồ) và `/cameras` (Camera) nằm trong shell, `/map` redirect về `/`; `/camera/:id` vẫn hoạt động qua deep link, Back từ viewer trở về tab nguồn. Quan tâm đọc lại khi quay về tab Camera để phản ánh thay đổi từ chi tiết camera bản đồ. Bản đồ mặc định phải có xử lý not-configured/demo và API key bị từ chối tương đương Camera, không phụ thuộc việc đã mở danh mục.
- Navigation dùng `go_router` hiện có (`pubspec.lock`: 17.5.0), cụ thể `StatefulShellRoute.indexedStack` với hai `StatefulShellBranch`, thứ tự Bản đồ rồi Camera, `preload: false`. Chuyển tab bằng `StatefulNavigationShell.goBranch(index)`; bấm lại tab đang chọn không reset stack/state. Viewer nằm trên root navigator, mở bằng push để Back về đúng tab nguồn; truy cập viewer bằng deep link không có lịch sử thì nút quay lại fallback `/`. IndexedStack giữ widget branch nên phải truyền trạng thái active/route visibility rõ ràng để tháo native map và dừng scheduler; không trông chờ Offstage tự dispose.
- Khai báo quyền foreground Android fine/coarse và iOS `NSLocationWhenInUseUsageDescription`; không xin quyền background. Chấm vị trí người dùng của Vietmap chỉ bật khi quyền hợp lệ, gồm cả bản đồ một camera hiện tại.

### Canvas Vietmap dùng chung

`CameraMapCanvas` bọc SDK; `CameraMapViewConfig` và builder test dùng tọa độ/marker do app định nghĩa, không mang `GoogleMapController`, `LatLng` hoặc `Marker` của Google vào tầng gọi. Adapter dùng `VietmapGL`, nhận idle/viewport và sự kiện chọn marker; khi style sẵn sàng thì dựng lại marker/lớp phụ theo state. Callback từ controller cũ sau dispose hoặc đổi style phải bị bỏ qua.

Style đường phố là `tm`, hybrid là `hm`. Traffic `tf` là overlay: merge sources/layers sau khi style nền tải xong, không dùng nó thay style nền; đổi style phải thêm lại overlay. Chỉ có một adapter quản lý các layer ID để bật/tắt hoặc reload không trùng ID. Việc kiểm thử với key thật phải xác nhận cả map, hybrid và traffic trước khi đánh PASS. [Tilemap](https://maps.vietmap.vn/docs/map-api/tilemap/), [Traffic layer](https://maps.vietmap.vn/docs/map-api/traffic-layer/).

Tạo `MapConnectionConfig` riêng với `VIETMAP_API_KEY`; URL chỉ trỏ máy chủ Vietmap, encode query bằng Uri. HTTP tải style/overlay dùng client riêng không gắn reader key của backend camera, không ghi toàn bộ URL chứa key vào log. Không ép proxy toàn bộ tile qua API camera. Smoke cấu hình phải phân biệt lỗi key/style với catalog lỗi hoặc camera không có tọa độ.

## Ngoài phạm vi v1

Không dẫn đường trong app, camera dọc tuyến, ranh giới polygon quận, cảnh báo nền theo GPS, clustering hoặc tài khoản mới. Chuyển nguồn bản đồ sang Vietmap nằm trong phạm vi; nút chỉ đường tiếp tục dùng luồng hiện có. Không cam kết mở rộng vùng phủ dữ liệu: đó là công việc T13 riêng.

## Nghiệm thu

1. Khởi động thông thường mở Bản đồ, tab index 0; Camera ở index 1 và chỉ khởi tạo khi được chọn. Không xin GPS hoặc tải thumbnail danh mục lúc mở app. Chuyển Bản đồ ↔ Camera giữ state, không nhân đôi polling/scheduler. Deep link `/cameras`, `/map`, viewer và Back vẫn đúng; đóng app sau khi ở Camera rồi mở thông thường vẫn về Bản đồ.
2. Bbox chỉ trả camera có tọa độ trong vùng và đúng quận; biên vùng được tính vào. Nearby trả đúng trong bán kính, đúng thứ tự khoảng cách; null tọa độ không làm lỗi.
3. API có 400/401/403/429 như hợp đồng; 201 kết quả khớp với limit 200 tạo hasMore, không bị mô tả là đầy đủ.
4. Kéo nhanh map hoặc đổi chế độ khi GPS/API chậm không hiển thị response cũ; chỉ truy vấn sau debounce, không gọi snapshot hàng loạt.
5. Từ chối quyền, từ chối vĩnh viễn, GPS tắt, vị trí gần đúng, timeout, mất mạng và catalog rỗng đều có trạng thái thao tác được; không tự xin lại quyền khi resume.
6. Chọn marker mở được chi tiết/Quan tâm/viewer/chỉ đường; sau khi trở lại Camera, Quan tâm cập nhật.
7. Tab ẩn/background/viewer che không giữ native map hoặc tải ảnh nền không cần thiết. Headless test inject map builder/location fake, không gọi plugin thật.
8. Flutter analyze, toàn bộ flutter test; backend typecheck và lần lượt unit → API → DB PASS trên PostgreSQL/PostGIS. Test thiết bị Android/iOS riêng cho quyền, map gesture, tab và lifecycle; ghi rõ bằng chứng chưa có.
9. Tab đầu tiên, bản đồ mini và toàn màn hình đều dùng Vietmap, không cần Google API key. Thiếu/sai Vietmap key không làm hỏng tab Camera. Với key thật, kiểm tra đường phố/hybrid/traffic và đổi style nhiều lần không mất marker hoặc nhân đôi layer; nếu thiếu key thì ghi chưa kiểm chứng runtime, không đánh PASS.

## Nguồn kỹ thuật

- [PostGIS ST_DWithin](https://postgis.net/docs/ST_DWithin.html): geography dùng mét và hỗ trợ lọc với index.
- [PostGIS spatial queries](https://postgis.net/docs/using_postgis_query.html): toán tử địa lý và sử dụng index.
- [Geolocator](https://pub.dev/packages/geolocator): quyền foreground, dịch vụ vị trí, deniedForever, timeout.
- [go_router StatefulShellRoute](https://pub.dev/documentation/go_router/latest/go_router/StatefulShellRoute-class.html): navigation có state riêng cho từng tab; dùng package hiện có, không yêu cầu nâng version.
- [Vietmap Flutter SDK](https://maps.vietmap.vn/docs/sdk-mobile/Flutter/map/), [package](https://pub.dev/packages/vietmap_flutter_gl), [Tilemap](https://maps.vietmap.vn/docs/map-api/tilemap/), [Traffic layer](https://maps.vietmap.vn/docs/map-api/traffic-layer/).

## Lựa chọn còn dành cho người dùng

Vietmap và tab Bản đồ mở mặc định đã chốt. Các giá trị bán kính, giới hạn kết quả và chi tiết UI là đề xuất trong kế hoạch; không còn câu hỏi về việc chọn Google/OpenStreetMap. Cần key Vietmap cho nghiệm thu bản đồ thật, không cần key để làm API, navigation và test fake.
