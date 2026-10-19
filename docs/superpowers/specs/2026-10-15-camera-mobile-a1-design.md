# Mobile A1 — danh sách, snapshot và Quan tâm

Ngày thiết kế: 2026-10-15; cập nhật hiện trạng 2026-10-19. Mobile A1 đã có mã nguồn trong repository chung và [báo cáo nghiệm thu](../../ui/mobile-a1-verification.md). Kết quả chạy lại 45 unit/widget tests và các giới hạn kiểm chứng được ghi tại [hiện trạng dự án](../../project-status.md). Các ghi chú trước triển khai bên dưới là lịch sử thiết kế; chúng không thay thế báo cáo nghiệm thu. Review tài liệu gốc: [document-review-2026-10-16.md](../../ui/document-review-2026-10-16.md).

## 1. Mục tiêu và phạm vi

Người dùng đã đồng ý tiến hành bước tiếp theo sau backend: chọn một tính năng cốt lõi, đối chiếu API và dựng flow đầu tiên. Brief đã lưu: Android + iOS, TP.HCM trước, giúp kiểm tra đường trước chuyến đi; backend riêng, nguồn Notis đã được người dùng chọn. Lát này hoàn thành **danh sách/tìm kiếm → chọn camera → xem snapshot → lưu/xóa Quan tâm → mở lại**.

Đây là thiết kế cho app mới; không phải kết luận về nội bộ app gốc. Mã nằm trong `mobile/`, cùng repository với `backend/`, tách khỏi APK và evidence điều tra. Không cần sửa contract backend để hoàn thành lát này.

Vietmap/bản đồ/nearby, LIVE, thời tiết/cảnh báo, tài khoản, quảng cáo/VIP tiếp tục thuộc roadmap sau. Không thêm tab chức năng chưa hoạt động vào bản đầu.

## 2. Phương án công nghệ

| Phương án | Lợi ích | Đánh đổi |
|---|---|---|
| Flutter cho Android + iOS (đã chọn) | Một codebase UI và logic; khớp hướng stack-review hiện có | Cần Flutter SDK; vẫn phải nghiệm thu iOS riêng |
| Kotlin + Swift native | Chủ động sâu về nền tảng và media | Hai codebase; tăng công sức cho flow snapshot hiện tại |
| Web responsive trước | Kiểm tra UI/API nhanh qua browser | Chưa hoàn thành mục tiêu app Android + iOS |

**Quyết định từ người dùng:** Flutter, state management BLoC vì đã quen sử dụng, starter [Arjun544/flutter_init](https://github.com/Arjun544/flutter_init). Riverpod và notifier SDK trong đề xuất trước được thay bằng BLoC/Cubit.

**Starter hiện có theo tài liệu/config:** architecture `feature-first`, state management `bloc`, navigation `go_router`, Dio, Shared Preferences, custom backend, preset Cupertino và dark mode. Hướng UI đã chốt là **Liquid Glass dùng `liquid_glass_widgets`**, thay đề xuất Material 3 trước đây. Backend dùng REST service NestJS hiện có; không thêm Firebase/Supabase/Appwrite cho A1. Đây là quan sát tài liệu/config, chưa phải kiểm chứng source/build của starter. Phần thiết kế được chuẩn bị trong [Stitch brief](../../ui/stitch-brief.md).

Tổ chức feature với presentation/data/models, luồng `View → Bloc/Cubit → Repository → Service`. Bloc/Cubit giữ vai trò quản lý presentation state, không tạo thêm ViewModel trùng trách nhiệm. Domain/use cases thêm khi logic phức tạp hoặc dùng lại thực sự. Dependency truyền qua constructor; RepositoryProvider/BlocProvider quản lý scope ở UI. Không thêm DI container riêng trước khi kiểm tra output starter. Client HTTP và local storage được bọc sau interface để test độc lập. Chốt version SDK/dependency, revision starter và lockfile khi triển khai sau kiểm tra môi trường thực tế.

`CameraCatalogBloc`: query/filter/page events và generation chống response cũ; `CameraDetailBloc`: mở camera, refresh, lifecycle, giữ ảnh khi lỗi; `FavoritesCubit`: state dùng chung toàn app qua repository lưu bền. Timer/request dọn trong close và xử lý background riêng, không phụ thuộc việc widget rebuild. Animation Liquid Glass giữ local ở widget, không phát event BLoC từng frame.

FlutterInit là generator tạo project. Cấu hình hiện tại đã khai báo `liquid_glass_widgets: 1.13.0` trong `mobile/pubspec.yaml` và có lockfile. Phần mô tả starter và tên state/controller ở trên ghi lại đề xuất ban đầu; khi tiếp tục phát triển, dùng hướng dẫn repository và báo cáo nghiệm thu cho hiện trạng. Kiểm thử widget không thay thế nghiệm thu shader trên thiết bị Android/iOS.

## 3. Màn hình và điều hướng

**Điều chỉnh mới nhất theo ảnh bottom sheet:** người dùng không muốn trang riêng cho Quan tâm hoặc chi tiết chỉ để xem snapshot. A1 dùng **một màn Camera**, Quan tâm là section có thể thu gọn/bộ lọc local trong màn đó; chạm camera mở **modal bottom sheet có thể kéo mở rộng**. Bỏ hai-tab Camera/Quan tâm và route detail độc lập của các mockup trước. Đây là thay đổi navigation, không bỏ tính năng lưu Quan tâm hoặc các roadmap đã chốt.

**Điều chỉnh mới nhất 16/10 theo feedback UI của người dùng:** bộ chọn khu vực dạng dropdown thay chips; có Card/Grid/List (Grid 2 cột và mật độ gọn 3 cột khi đủ chỗ); **hiển thị snapshot thumbnail cho camera trong danh sách đang xem**; tự tải trang tiếp bằng **infinite scroll** thay nút tải thêm. Các mô tả text-first/no-list-image/tải thêm thủ công trước đây bị thay thế. Liquid Glass cần thấy rõ nền ảnh qua search/dropdown/mode switch/dock, giữ nội dung chính rõ nét. Ba ảnh mẫu được lưu trong `docs/ui/stitch/references/`; label phường trong ảnh không phải bằng chứng backend có danh mục phường.

- **Camera:** tiêu đề TP.HCM, ô tìm tên/địa chỉ, dropdown khu vực theo catalog nếu có dữ liệu; mode Card/Grid/List, ảnh visible, tên/địa chỉ/khu vực nullable, nút Quan tâm và infinite scroll. Fetch thumbnail cho items visible + prefetch giới hạn, không tải toàn danh mục. Tách loading/lỗi ảnh của từng camera khỏi lỗi danh sách; không tự gọi camera offline từ lỗi tải ảnh.
- **Quan tâm trong Camera:** section ảnh camera đã lưu theo ID backend, có thể thu gọn và bộ lọc “Chỉ quan tâm” trên cùng màn. Rỗng thì hướng dẫn đánh ngôi sao inline; không push page hoặc xin đăng nhập. Khi mở section/filter revalidate metadata từng ID, tối đa 4 request đồng thời; lỗi mạng giữ metadata đã lưu. Chỉ 404 mới đánh dấu camera không còn trong catalog, vẫn cho xóa. Không biến favorites local thành API phân trang server.
- **Snapshot bottom sheet:** mở trên Camera từ bất kỳ card nào; header có handle, đóng X, tên đầy đủ và saved star; metadata nullable, ảnh giữ đầy đủ tỷ lệ, làm mới và Toàn màn hình. Chiều cao theo nội dung, mức mở mặc định khoảng 55–65% khi phù hợp màn/ảnh, kéo lên tối đa khoảng 90%; màn nhỏ/font lớn dùng sheet cuộn hoặc mở rộng, không cắt ảnh hoặc tạo khoảng trắng lớn. Header/controls Liquid Glass, ảnh không blur. Đóng bằng X/swipe-down/Back/scrim, trả về đúng query/filter/mode/scroll. Không thêm nút sửa tên/pencil từ reference khi chưa có yêu cầu. Không cần related section trong quick sheet A1; API related vẫn là năng lực backend.
- **Xem toàn màn hình:** chạm ảnh trong sheet mở overlay dùng chung camera/controller/bytes; đóng overlay quay về sheet đúng trạng thái. Hỗ trợ portrait/landscape theo xoay thiết bị, pinch-to-zoom, pan khi đã zoom; double-tap chuyển fit/zoom. Back/X đóng viewer trước sheet. Fit mặc định giữ toàn ảnh; xoay không reset camera hoặc tạo request/timer mới, thoát viewer khôi phục chính sách orientation trước đó. Semantics ảnh là nút mở viewer; pan/zoom không dismiss sheet phía dưới. Không phải route detail mới. Có loading/unsupported/error/stale đúng trạng thái; ảnh cũ giữ khi refresh lỗi, không gọi snapshot là LIVE.

**Feedback mới nhất — sheet tối giản:** bỏ nút Làm mới và Toàn màn hình, bỏ toàn bộ text giờ nhận/giờ cập nhật/giờ chụp unknown. Chỉ giữ header, saved star và ảnh có vùng chạm mở viewer. Chiều cao sheet co theo nội dung sau khi bỏ controls; không ép tối thiểu 55–65%. Không xóa timestamp đã được nguồn in trực tiếp trong ảnh. Thời điểm nhận vẫn lưu nội bộ phục vụ cache/stale; trạng thái lỗi/ảnh cũ chỉ hiển thị khi cần. Mục này thay thế các mô tả controls/thời gian hiển thị trước đó.

Giao diện tiếng Việt, bố cục riêng, Liquid Glass dùng package đã chọn: `GlassScaffold`, `GlassAppBar`, `GlassModalSheet`, search/dropdown/mode controls. Không cần `GlassTabBar.bottom` chỉ để chuyển Camera/Quan tâm. Danh sách/metadata giữ nền đặc, ảnh snapshot không bị blur. Light/dark và giảm hiệu ứng phải được review. Giữ tokens starter và shared UI, không thêm navigation/state library. Saved star có semantics thêm/bỏ Quan tâm và filled/outline. Mở sheet giữ nguyên list context; đóng sheet trả focus về camera đã mở. Khi sheet modal mở, focus/semantics giới hạn trong sheet và thao tác scroll không lọt xuống grid phía sau.

## 4. Contract backend đã đối chiếu

**Quan sát tĩnh, artifact: mã nguồn backend hiện tại.** Các endpoint đọc cần reader `x-api-key`; `createApp` cài global guard, gồm cả snapshot. Không dùng admin key trên client.

| API | Cách client sử dụng |
|---|---|
| `GET /v1/cameras` | `provinceId=tp_hcm`, `q?`, `district?`, `limit=50`, `offset`; đọc `data`, `meta.page.{limit,offset,total}`, `meta.catalog.{version,fetchedAt,isStale,coverage,syncState}`, `meta.dataMode` |
| `GET /v1/camera-districts?provinceId=tp_hcm` | Danh sách district/count thực có; rỗng thì ẩn bộ lọc |
| `GET /v1/cameras/{id}` | UUID backend, dữ liệu nullable; lấy mới khi mở chi tiết |
| `GET /v1/cameras/{id}/playback` | `kind=snapshot`, `snapshotEndpoint`, `refreshIntervalMs`, `capturedAt=null`; capability không hỗ trợ thì hiển thị thông báo |
| `GET /v1/cameras/{id}/snapshot` | Binary 200, `ETag`, `X-Image-Fetched-At`, `X-Data-Mode`; gửi `If-None-Match` khi đang giữ bytes tương ứng; 304 giữ ảnh |
| `GET /v1/cameras/{id}/related?limit=6` | Camera cùng district; rỗng không được diễn giải là không có camera gần vị trí |

Lỗi JSON: `{error:{code,message,requestId,retryable}}`. Map sang thông báo tiếng Việt theo status/code; không hiển thị nguyên body lỗi server. 401/403 báo lỗi cấu hình kết nối, không retry tự động; 404 báo camera không còn khả dụng; 422 báo chưa hỗ trợ phát; 429 báo giới hạn truy cập; timeout/5xx cho thử lại. Giữ requestId để hỗ trợ chẩn đoán, không log key hoặc payload nhạy cảm.

`q` trim, rỗng thì bỏ param; 1 ký tự hiện hướng dẫn nhập ít nhất 2 ký tự và không gửi query không hợp lệ; tối đa 120 ký tự. Debounce 350 ms. District chỉ lấy nhãn API. Offset tối đa 10000 theo backend; đạt giới hạn thì dừng tải thêm và hướng dẫn thu hẹp tìm kiếm.

## 5. State, phân trang và polling

Catalog giữ `query/district/items/page/catalog/loading/error`. Mỗi lần đổi query/filter tăng generation và reset phân trang. Chỉ nhận response của generation còn hiệu lực, không cho hai request tải thêm đồng thời. Trang sau offset tăng theo số record nhận từ server, merge hiển thị theo ID. Nếu version catalog thay đổi giữa trang thì tải lại từ trang đầu, báo danh mục đã cập nhật. Dừng theo total hoặc trang rỗng; không suy độ phủ nguồn từ total local. Nhãn số lượng là “Đã tải N camera”; catalog partial/stale phải được thể hiện.

Thumbnail list: tải ảnh khi card vào vùng nhìn thấy, prefetch tối đa một hàng, tối đa 4 request đồng thời và cache bytes có ngân sách riêng cần chốt khi triển khai. Không tự polling toàn danh mục; refresh list có chủ đích chỉ cập nhật ảnh visible. Rời viewport/tab hoặc background thì hủy request không còn cần, giữ placeholder/ảnh cuối có timestamp theo state. Vào chi tiết thì ưu tiên request chi tiết, không tạo polling trùng list-detail. Chuyển mode giữ query/filter/ID mốc cuộn và favorites.

Infinite scroll: trigger gần cuối danh sách, tối đa một request trang sau đang chạy; loading footer, lỗi trang sau giữ items có “Thử lại”, hết dữ liệu hiển thị thông báo. Thay query/filter reset generation/page; đổi catalog version tải lại trang đầu như quy tắc trên. Không có nút “Tải thêm” trong happy path; không cần đổi limit/offset backend sang cursor.

Preview giữ bytes/ETag theo camera ID, status và thời điểm nhận ảnh. Chỉ poll camera trong sheet/fullscreen đang hiển thị; không poll nền grid/section Quan tâm. Mỗi camera tối đa một snapshot request đang chạy; lần tiếp theo lên lịch sau request trước, interval tối thiểu 3 giây, dùng descriptor hợp lệ, fallback 12 giây. Timeout 15 giây; retry backoff 12/24/48/60 giây, 429 chờ ít nhất 60 giây và tôn trọng Retry-After hợp lệ. Không tự retry 401/403/404/422.

Background hoặc sheet bị dismiss: dừng timer/hủy request không cần, vô hiệu hóa kết quả cũ bằng generation. Kéo sheet lên/xuống giữa detents không tạo polling mới. Fullscreen dùng chung controller/bytes, chỉ overlay trên sheet; đóng fullscreen không nhân timer hoặc đóng nhầm sheet. Resume khi sheet/fullscreen còn mở thì refresh ngay. Đổi camera A sang B dùng một active controller, không xếp chồng nhiều sheet hoặc render ảnh A trong B. Bỏ saved star của camera đang xem cập nhật list ngay nhưng không tự đóng sheet.

Refresh tự động lỗi giữ ảnh cuối cùng và hiện cảnh báo. 304 không có nghĩa nguồn chụp ảnh mới; giữ thời điểm của ảnh cuối trong state. `X-Image-Fetched-At` là thời điểm backend lấy ảnh, không phải capturedAt. Không hiển thị text giờ nhận/cập nhật hoặc unknown timestamp; khi quá 60 giây hiện trạng thái “Ảnh chưa được cập nhật”. Không khẳng định freshness của ảnh nguồn khi capturedAt chưa có.

Mỗi ảnh tối đa 2 MiB theo contract backend; loại phản hồi quá cỡ, không phải ảnh hoặc decode lỗi. Detail giữ ảnh đang xem; thumbnails có RAM cache hữu hạn, không giữ bytes toàn catalog. Không lưu album/cache ảnh trên đĩa trong lát này.

## 6. Quan tâm và cấu hình kết nối

`FavoritesRepository` là nguồn state chung giữa danh sách, chi tiết và Quan tâm. Lưu schema có version gồm `id,name,address?,district?,addedAt`; ID backend là khóa duy nhất. Serialize thao tác ghi; rollback state và báo lỗi nếu ghi thất bại. Restart phục hồi bền; dữ liệu local hỏng không làm crash, hiển thị lỗi phục hồi và cho người dùng chủ động reset dữ liệu Quan tâm.

`CameraApiClient` chịu trách nhiệm JSON/binary, timeout, header và kiểm tra endpoint tương đối cùng backend origin; không forward reader key đến host tùy ý từ descriptor. Base URL và reader key lấy từ cấu hình build phát triển không commit giá trị thật; thiếu cấu hình hiển thị trạng thái rõ. Reader key trong mobile không được coi là bí mật bảo vệ được; cơ chế xác thực/rate limit cho phát hành công khai cần thiết kế riêng trước release. Không đưa key vào UI, URL hoặc log.

Mode mặc định nối backend đang cấu hình; fixture/demo phải bật explicit và hiện nhãn “Dữ liệu mẫu”, không tự chuyển sang fixture khi nguồn thật lỗi. API test sử dụng fixture độc lập có ảnh hợp lệ và nhiều trang.

## 7. Kiến trúc module đề xuất

| Thành phần | Trách nhiệm |
|---|---|
| `core/config`, `core/network` | Cấu hình, client, timeout, error mapping, same-origin guard |
| `features/cameras/data` | DTO mapping, camera repository, snapshot transport |
| `features/cameras/presentation` | Catalog/detail BLoCs, immutable states/events, widgets và điều hướng |
| `features/favorites` | Lưu bền, nguồn state chung, section/filter Quan tâm trong Camera; không route riêng |

Không dùng sourceRef/upstream URL của app gốc. Mobile chỉ đọc API backend; không sync catalog quản trị hoặc gọi Notis trực tiếp.

## 8. Tiêu chí nghiệm thu

1. Android mở danh sách backend, tìm tên/địa chỉ, lọc district khi có và tải trang sau không trùng ID.
2. Query A trả chậm hơn B không ghi đè kết quả B; version thay đổi giữa trang không tạo danh sách trộn.
3. Mở camera đúng ID, lấy descriptor và render snapshot; không hiển thị ảnh A sau khi chuyển sang B.
4. ETag/304 giữ ảnh; lỗi refresh giữ ảnh và cảnh báo; capturedAt unknown không biến thành giờ chụp giả.
5. Đóng chi tiết/background dừng polling; resume chỉ có một chuỗi refresh; mở rộng không tăng số timer.
6. Thêm/xóa Quan tâm nhất quán trên các màn; restart vẫn còn; lỗi ghi local hoặc metadata 404 có hành vi rõ.
7. Có empty/error/retry, auth error, timeout, 429, malformed response và ảnh lỗi; fixture được gắn nhãn.
8. Chạy analyze, test state/repository với clock/transport giả và widget tests các trạng thái chính. Chạy tích hợp Android với backend fixture trước, sau đó một camera thật từ catalog hiện có, không tự import toàn TP.HCM.
9. Android cần bằng chứng thao tác/screenshot và request lifecycle. iOS chỉ đánh dấu đạt khi build/chạy trên môi trường macOS phù hợp; không suy từ Android hoặc unit test.
10. Dropdown khu vực chọn/clear đúng dữ liệu; đổi Card/Grid/List giữ filter/favorites và ID mốc cuộn. Snapshot visible tải đúng camera, lỗi ảnh độc lập và không biến thành kết luận offline; request/cache thumbnail hữu hạn và dừng khi offscreen/background.
11. Infinite scroll không gửi trùng trang, không trộn generation/version; loading/error/end footer rõ, lỗi trang sau giữ các thẻ đã tải. Không có nút tải thêm trong happy path. Grid/font lớn thích ứng chiều rộng, không cắt tên và không để popup ngoài safe area.
12. Chạm camera mở một sheet trên cùng grid; X/Back/scrim/swipe dismiss giữ query/dropdown/mode/vị trí cuộn. Thay detent/fullscreen không tăng polling; dismiss/background dừng. Không có route Quan tâm/detail riêng hoặc bottom tab thừa. Lỗi/unknown timestamp và focus modal có nghiệm thu riêng.

## 9. Bằng chứng, giới hạn và bước tiếp

- **Quan sát tĩnh:** `backend/src/catalog/catalog.controller.ts` methods list/districts/detail/playback/related; `catalog.service.ts` methods list/playback; `catalog.types.ts` CatalogState; `dto/camera.dto.ts` CameraDto/PlaybackDto; `query-schema.ts` parseCatalogQuery; `snapshot/snapshot.controller.ts` getSnapshot; `http/api-error.filter.ts` catch; `create-app.ts` createApp/global guard. File tham chiếu tương đối từ workspace root; code hiện tại là artifact cho đối chiếu contract.
- **Giới hạn graph:** index TTGT-Tphcm generation `2026-10-14T03:17:26Z`, search CatalogController/SnapshotController/CameraDto không có kết quả. check_index_coverage trả freshness `not_tracked` cho các file trên; đã đọc source trực tiếp. Không dùng graph vắng symbol để kết luận backend thiếu chức năng.
- **Bằng chứng lịch sử:** `backend/docs/verification.md` ghi 49 tests và smoke thật ngày 14/10; lượt thiết kế này chưa chạy lại, không tuyên bố runtime hiện tại pass.
- **Quan sát môi trường:** Get-Command flutter/dart/adb không trả executable trong PATH của shell hiện tại; chưa đủ kết luận SDK chưa được cài. Kiểm tra vị trí SDK thực khi triển khai, chỉ cài nếu xác định thiếu.
- **Chưa xác minh:** build/chạy mobile, iOS, deployment công khai và auth production. Không phát sinh bằng chứng APK/REA mới trong lượt này.

Bước tiếp cập nhật 16/10: tạo/review mockup Stitch theo brief Liquid Glass trước khi viết implementation plan Flutter. Không hỏi lại Flutter/BLoC/FlutterInit, nguồn Notis hoặc package glass đã chốt. Self-review: flow, input validation, phân trang, freshness, lifecycle và tiêu chí nghiệm thu đã đối chiếu. Starter đã có; lượt review này chưa sửa product code hoặc thêm dependency Flutter.
