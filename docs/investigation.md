# Điều tra chức năng camera

## Navigation mới — snapshot bottom sheet, Quan tâm inline

Theo feedback/ảnh mới của người dùng, không tạo page riêng chỉ để xem snapshot hoặc Quan tâm. Đã sửa spec/brief/mobile DESIGN và mockup: một màn Camera, Quan tâm section/filter, card mở bottom sheet, ảnh toàn màn hình là overlay cùng preview. [Review](ui/stitch/README.md). **Quan sát output thiết kế:** ảnh/HTML Stitch được lưu, JPEG local tái sử dụng, không phát sinh probe nguồn/REA mới. Script tái dựng artifact ở `scripts/ui/build-camera-sheet-review.ps1`; chưa sửa product code hoặc nghiệm thu gestures/polling Flutter. Các page mock trước đó giữ làm lịch sử.

## Thiết kế tiếp theo — Chi tiết snapshot và Quan tâm

Theo phản hồi đồng ý tiếp tục của người dùng, đã tạo ba mockup Chi tiết snapshot, Quan tâm có dữ liệu và Quan tâm rỗng. [Bản review](ui/stitch/README.md). **Quan sát output thiết kế**, không phải runtime app: đã dùng JPEG camera local từ lượt trước, không gọi lại nguồn ảnh; có timestamp nhận ảnh/unknown capturedAt, stale notice, remove favorite khi metadata không còn và empty CTA. Chưa sửa product code, build hoặc test backend/mobile; chờ review các màn mới rồi bổ sung dark/state variants.

## Camera v3 — feedback ba ảnh mẫu, 2026-10-16

Người dùng yêu cầu dropdown địa điểm, Card/Grid/List, ảnh camera trong list, infinite loading và Liquid Glass rõ hơn. Đã cập nhật brief/Mobile A1/mobile DESIGN; đã xem/upload 3 ảnh mẫu, tạo 3 artboard, sửa asset HTML vì Stitch tự thay ảnh sai, rồi import lại bản Grid/Card/Dropdown. [Link review + giới hạn](ui/stitch/README.md). **Quan sát thiết kế:** đã mở screenshot import và đọc HTML, không phải runtime Flutter. **Quan sát HTTP giới hạn:** ba GET snapshot Notis trả JPEG 200, đã mở xem và lưu hash/source dưới `docs/ui/stitch/assets/`; chỉ làm asset mockup, không nghiệm thu backend/độ tươi hoặc đối chiếu đúng tên camera mock. Chưa code/build mobile; mode/pagination cần nghiệm thu riêng khi triển khai.

## Cập nhật 2026-10-16 — Camera mockup trên Stitch

Theo yêu cầu tiến hành tạo design, đã generate Camera light và edit refinement thành v2. Project `15634181901662145156`; screen v2 `f4b077a13f3a42db99b0df38fc835b88`. **Quan sát output thiết kế:** screenshot/HTML đã tải và đọc, không phải runtime Flutter hoặc app gốc. Prompt/ảnh/HTML/metadata và giới hạn lưu tại [docs/ui/stitch](ui/stitch/README.md). V2 sửa count/wrap/touch target; còn cần review độ glass, icon selected và layout viewport thật. Chưa code, build hoặc tích hợp backend; bước tiếp là review phong cách rồi làm màn Chi tiết/Quan tâm và các trạng thái.

## Cập nhật 2026-10-16 — review tài liệu trước UI Liquid Glass

Người dùng xác nhận starter tại `mobile/`, dùng Stitch CLI thiết kế trước khi code và chốt `liquid_glass_widgets` cho Liquid Glass. Đã review tài liệu dự án, đối chiếu lịch sử với phạm vi A1 và cập nhật brief/spec mobile. [Kết quả review](ui/document-review-2026-10-16.md), [brief](ui/stitch-brief.md). **Quan sát CLI:** đăng nhập Stitch Valid, Canvas credential present. **Quan sát tài liệu upstream:** package tham chiếu 1.13.0 yêu cầu Flutter ≥3.41.0; chưa kiểm chứng SDK/rendering local. Không phát sinh reverse/REA/runtime APK mới; chưa tạo màn Stitch, sửa product code hoặc chạy lại backend/mobile tests. Bước tiếp: thiết kế Camera Liquid Glass rồi review cùng Chi tiết/Quan tâm và các trạng thái lỗi/light/dark.

## Cập nhật 2026-10-15 — chuẩn bị Mobile A1 sau backend

Đã soạn [đặc tả Mobile A1](superpowers/specs/2026-10-15-camera-mobile-a1-design.md) theo yêu cầu tiến hành bước tiếp: danh sách/tìm kiếm → snapshot → Quan tâm local, đề xuất Flutter Android/iOS. Trạng thái: chờ review spec, chưa viết mobile hoặc cài dependency.

**Quan sát tĩnh:** contract đủ đầu vào cho flow trên trong mã backend: `catalog.controller.ts:18` list, `catalog.service.ts:41` playback, `dto/camera.dto.ts:3` CameraDto, `catalog.types.ts:46` CatalogState, `query-schema.ts:25` parseCatalogQuery, `snapshot.controller.ts:12` getSnapshot, `api-error.filter.ts:8` catch và `create-app.ts:19` createApp. Các file thuộc `backend/src/` với module tương ứng. Graph TTGT-Tphcm chưa track các file này; đã gọi check_index_coverage và đọc trực tiếp, không có call-chain graph được xác minh.

**Giới hạn:** báo cáo backend acceptance ngày 14/10 là bằng chứng lịch sử, chưa chạy lại trong lượt này. Không phân tích APK hoặc thu runtime/REA mới. Chưa xác minh mobile/iOS; Flutter/Dart/ADB không xuất hiện trong PATH shell hiện tại, không kết luận chúng chưa được cài. Bước tiếp: review spec Mobile A1 → implementation plan → triển khai và kiểm thử Android, iOS kiểm chứng riêng.

Ngày cập nhật: 2026-10-14. Yêu cầu: dùng REA lấy spec chức năng theo dõi camera.

## Cập nhật lượt 7 — debug runtime API

Đã vượt giới hạn HTTP Flutter: tìm boundary plaintext trên runtime x86_64 bằng phân tích relocation/disassembly và hook thụ động. Đã xác nhận app GET bbox, nearby distance=5000, snapshot, geocoding q (404), tenants và homepage. Response tenants app chứa base camera và 16 khu vực; body bbox app đã thu shape/hash. Danh sách dùng Bearer trong mẫu, snapshot không gửi Authorization; chưa suy header nào bắt buộc ở server. Window add/remove Quan tâm chỉ thấy GET ảnh qua hook này, local cleanup [] được xác nhận.

REA đã đọc HAR dẫn xuất đã che dữ liệu, Evidence `ev_e83f5decb7d2b302bacd89bc87d1f38766b2e49bc5870461f745effc816f0ca8`. [Báo cáo chi tiết và ma trận bao phủ](camera-api-debug-pass7.md); [catalog cập nhật](api-catalog.md). Không bypass TLS, không sửa APK, không giữ token/cookie/device ID/raw body. Android 13 mất kết nối sau capture đã lưu; chưa biết nguyên nhân. Observer Android 9 kết thúc/detach, favorites [].

Các trạng thái “chưa capture HTTP app” ở lượt 1–6 bên dưới là lịch sử. Còn mở: LIVE playlist/segment thành công, request hệ thống Geocoder/tile, sync account/saved address/history, Dart handler và hợp đồng cache/pagination/retry. Không đánh dấu toàn bộ API mọi nhánh đã hoàn tất.

## Cập nhật lượt 6

Đã tạo [rebuild-spec.md](rebuild-spec.md): phạm vi, UI/flow, dữ liệu độc lập, interface backend đề xuất, state/lỗi, cải tiến và nghiệm thu. Đủ để bắt đầu UI/logic trên fixture; chưa đóng tích hợp dữ liệu thật.

Probe độc lập mới trả snapshot JPEG; nearby radius 500 có 10 record, 5000/10000 cùng 89; thử limit/page không đổi body. Bbox rộng có 201 ID trong 5km không có trong nearby, nên không cam kết đủ camera trong radius hay cap 90. Chi tiết [camera-contract-pass6.md](camera-contract-pass6.md). Snapshot request app/auth/cache/Dart caller vẫn mở; lượt này không capture TLS. Không thay đổi app/thiết bị, không cài engine.

Bước tiếp theo: nếu mục tiêu là xây app mới, triển khai fixture và flow theo rebuild-spec, chốt provider dữ liệu trước tích hợp thật. Nếu cần tương thích nguồn gốc, tiếp tục capture request app có mục tiêu trên đúng runtime artifact. Các cải tiến vẫn là đề xuất, chưa có yêu cầu triển khai.

## Cập nhật lượt 5

Đã hoàn tất flow Xung quanh đầu-cuối trên emulator Google Android 13 dùng cùng runtime APK set: chọn điểm thủ công → địa chỉ/xác nhận → 90 camera có khoảng cách → mở preview. FINE/COARSE denied vẫn thực hiện được. Tách hai lỗi: tìm chữ ghi 404 Route not found ở routing/geocoding; chọn điểm trên Android 9 gặp Geocoder Service not Available. REA/JADX xác nhận q3.r.onMethodCall và nhánh SDK sync/async. Đã cập nhật camera-spec và API catalog; [báo cáo lượt 5](camera-runtime-pass5.md). Snapshot HTTP app đầy đủ/cache/auth/pagination vẫn mở; native provider REA chưa cấu hình, chưa cài thêm engine. App test mới đã force-stop, bộ APK/evidence giữ để tái hiện.

## Cập nhật lượt 4

Đã đo lifecycle snapshot (30 giây nền không thấy write host camera, resume gửi lại), xác nhận UI LIVE Ký Con, attempted GET playlist qua caller Java p1.p.p và nguyên nhân cleartext policy chặn bằng log + REA manifest/method của đúng runtime APK. Đã thử cấp quyền vị trí, thấy dialog dịch vụ vị trí riêng và trả grant về denied. Chọn điểm/Xung quanh có dữ liệu chưa hoàn tất. Spec/API catalog cập nhật; chi tiết [camera-runtime-pass4.md](camera-runtime-pass4.md). Các lượt bên dưới là lịch sử.

## Cập nhật lượt 2

> **Lượt 3 supersedes trạng thái dưới:** đã sửa nhận định splash (vuốt lên thấy menu), xác nhận Quan tâm phục hồi trên UI sau process restart, đo nhịp khoảng 12 giây và thử ngắt host/phục hồi. Đã cleanup favorite và rule mạng. Chưa giải mã HTTP app. Xem [camera-runtime-pass3.md](camera-runtime-pass3.md); camera-spec đã cập nhật flow/tiêu chí nghiệm thu.

Đã xác nhận cấu hình runtime base API `https://api.notis.vn/v4/`, 16 vùng camera, local key Quan tâm chứa camera object và tồn tại trên disk sau restart. Ba GET độc lập trả bbox 18 record, nearby 90 record và snapshot JPEG; schema đã bổ sung vào api-catalog. Chưa capture request app; không gán probe thành traffic app. App dừng ở splash sau restart nên UI restore, đo timer và kiểm thử lỗi vẫn mở. Chi tiết/bằng chứng: [camera-runtime-pass2.md](camera-runtime-pass2.md). Các trạng thái lượt 1 dưới đây là lịch sử, không ghi đè kết quả lượt 2.

Kết quả chính: [camera-spec.md](camera-spec.md). API đầu mối: [api-catalog.md](api-catalog.md). Evidence index: [../evidence/camera/evidence-index.md](../evidence/camera/evidence-index.md).

## Tiến độ theo câu hỏi (cập nhật lượt 6)

| Câu hỏi | Trạng thái | Bằng chứng |
|---|---|---|
| Artifact workspace là app nào? | Đã xác định metadata/hash; chưa xác minh chữ ký | REA `package.json`, `native-extraction.json` |
| Entry và các màn camera là gì? | Đã quan sát runtime trên bản cùng version, khác hash | HOME/ENTRY/MAP/NEAR/SEARCH |
| Xem và đánh dấu camera hoạt động thế nào? | Đã tái hiện thêm/mở/xóa và phục hồi qua restart | PREVIEW/ADD/DETAIL/REMOVE; rea-pass3-restored |
| Chọn khu vực làm gì? | Đã tái hiện một khu vực | AREA/AREA-RESULT |
| Camera refresh bằng cơ chế nào? | Đã đo UI/socket ~12 giây và một mẫu lifecycle; chưa giải mã HTTP app | timing-summary-pass3; lượt 4 |
| UI → handler → data/API → UI? | Chưa xác minh tầng handler và data/API | Flutter/AOT là đầu mối, chưa có Dart xrefs |
| Có spec sử dụng được không? | Có đặc tả tái dựng độc lập để làm UI/logic với fixture; hợp đồng nguồn thật chưa hoàn tất | camera-spec.md; rebuild-spec.md |

## Công cụ và giới hạn (lịch sử lượt 1; các cập nhật trên thay thế trạng thái đã xác minh)

- REA MCP `inspect_android_package` ban đầu báo `capability_unavailable`: thiếu `REA_JADX_MCP_JAR` trong môi trường server. Đã dùng REA CLI 6.4.0 với JAR có sẵn `D:/REVERSE_TOOLS/jadx-headless-mcp-0.7.1-all.jar` trong môi trường process; không sửa cấu hình toàn cục.
- REA/JADX xác định `com.fts.notis` 5.2.1 (502001). REA MCP trích xuất split ARM64; REA CLI thu screenshot và metadata runtime. ADB dùng thao tác UI và dump XML.
- Workspace đã index `TTGT-Tphcm` chế độ fast trước khám phá. `check_index_coverage` trên manifest, libapp.so và JSON literal trả `freshness: not_tracked`, yêu cầu đọc trực tiếp/reindex. Đã đọc trực tiếp manifest, inventory trích xuất và bytes literal bằng script. Không có source Dart đã phục hồi để graph truy vấn handler; không dùng graph vắng symbol làm bằng chứng không có chức năng.
- `Camera` search DEX có phạm vi 16.271 class và 12 kết quả. Chưa tìm exhaustive mọi tên obfuscated, reflection hoặc native. Các class camera thiết bị không được coi là caller tính năng camera giao thông.
- Runtime `emulator-5554`: Android 9, x86_64, 1600×900. Bản cài từ Aurora theo dumpsys; hash khác workspace. Chỉ tái sử dụng bản cài cho bằng chứng hành vi riêng, không coi artifact đồng nhất.
- Chưa capture HTTP/Frida, chưa phân tích control flow AOT. Không có bằng chứng về response/auth, timer nền hay lưu trữ Quan tâm. Không gọi endpoint tìm được để suy đoán quyền truy cập.

## Bước tiếp theo (lịch sử lượt 1)

Ưu tiên đồng nhất artifact hoặc giữ hai track rõ ràng, rồi capture network có mục tiêu cho bản đồ/ảnh/Quan tâm. Sau đó hoàn thiện spec data/API, kiểm tra restart và các nhánh lỗi. Các yêu cầu cải tiến trong camera-spec là đề xuất, chưa phải lựa chọn triển khai.
