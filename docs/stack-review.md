# Review stack theo mục tiêu hợp nhất

Ngày 2026-10-14. Trạng thái: khuyến nghị kiến trúc để review, chưa phải thiết kế/kế hoạch triển khai đã duyệt. Không scaffold, cài dependency hay thay đổi ứng dụng trong lượt này.

**Cập nhật theo xác nhận mới:** người dùng có Vietmap cho bản đồ, tìm địa điểm/geocoding và tính tuyến; Vietmap thay Google Maps trong đề xuất bên dưới. Người dùng chọn build backend trước. Spec lát đầu tại `docs/superpowers/specs/2026-10-14-camera-backend-design.md`; adapter server dùng v4 theo tài liệu hiện tại, chưa smoke-test key của người dùng. Các đoạn so sánh Google Maps phía dưới là lịch sử review trước xác nhận này.

## 1. Cơ sở và điểm tài liệu cần thống nhất

Đã đọc tài liệu trong `D:/REVERSE_TOOLS/com.genius.cameragiaothong/docs/`: `rebuild-spec.md`, `improvement-backlog.md`, `tech-stack.md`, `data-model.md`, `api-catalog.md`, `android13-playback.md`, `player-runtime.md`, `superpowers/brainstorming-status.md`. Đồng thời đối chiếu các tài liệu camera Notis đã có tại workspace hiện tại.

**Yêu cầu đã ghi nhận từ trao đổi trong brainstorming-status**, ưu tiên hơn các giả định của rebuild-spec sơ bộ:

- Android + iOS; TP.HCM trước, chưa cần phủ nhiều tỉnh khi phát hành đầu.
- Kiểm tra đường trước chuyến đi và theo dõi thời tiết/mưa ngập.
- Camera công khai được phép sử dụng, backend riêng; provider cụ thể chưa chốt.
- Quảng cáo nhẹ + VIP bỏ quảng cáo.
- Cảnh báo đủ ba phạm vi: khu vực lưu, vị trí hiện tại, tuyến đường thường đi. Triển khai theo lát; không bỏ vị trí/tuyến đường khỏi mục tiêu cuối.
- Ngân sách vận hành mong muốn dưới 1 triệu đồng/tháng; chưa có số người dùng, thời lượng xem, quota/provider để xác nhận dự toán.
- Chỉ gọi là thông báo ngập khi có nguồn đáng tin cậy; dự báo mưa/nguy cơ phải ghi đúng mức độ bằng chứng.

**Mâu thuẫn tài liệu:** rebuild-spec sơ bộ bên workspace Genius vẫn ghi cảnh báo chưa thuộc MVP và người dùng là giả định; rebuild-spec Notis ở workspace này loại thông báo giao thông khỏi phạm vi camera. Đây là các phạm vi soạn trước, không được dùng để bỏ các mục đã chốt trong brainstorming-status. Bản review này dùng camera-first là lát đầu và giữ cả ba loại cảnh báo trong roadmap; không tự sửa/phê duyệt thay các spec cũ.

**Bằng chứng được tái sử dụng, không reverse lại:** báo cáo Genius ghi nhiều loại nguồn snapshot/HLS/EVUP/YouTube; Hà Nội EVUP đã phát qua native HEVC trên Android 13 ở một mẫu; chưa có chứng minh playback iOS. TP.HCM API mẫu có 860/900 descriptor trỏ snapshot Notis và 40 HTTP descriptor khác. Báo cáo Notis lượt 7 xác nhận GET list/snapshot/config thực tế. Hai app và schema/ID khác nhau: cần adapter riêng, không gộp ID hoặc coi toàn bộ camera đều HLS. Các con số là mẫu điều tra, không bảo đảm nguồn hợp lệ/khả dụng khi phát hành.

## 2. Kết luận stack

**Thiết kế đề xuất:** Flutter + NestJS/Fastify + PostgreSQL/PostGIS + Firebase Cloud Messaging, một backend và một worker trên cùng VPS lúc đầu. Redis bổ sung theo tải; không là dependency mặc định. VIP dùng RevenueCat, quảng cáo dùng AdMob qua integration Flutter tương ứng. Backend không chuyển tiếp toàn bộ live video mặc định.

| Tầng | Chọn đề xuất | Lý do / điều kiện |
|---|---|---|
| App Android/iOS | Flutter, views/view models/repositories/services | Phù hợp hai nền tảng và offline metadata/favorites. Tách player/source adapter khỏi UI; không sao chép kiến trúc từ tên class app gốc |
| Local data | SQLite cho catalog/cache/favorites; preferences cho settings nhỏ | Favorites local ở lát đầu; không cần tài khoản chỉ để xem camera. ID ổn định và migration khi catalog đổi |
| API | Node.js LTS, TypeScript, NestJS + Fastify | Module catalog/source adapter/health/weather/alerts/entitlements có trách nhiệm riêng; vẫn một application deploy |
| HTTP nguồn | Undici, timeout/abort/concurrency limit | Stream ảnh khi cần proxy; coalesce request cùng camera; không dùng server như relay URL tùy ý |
| DB | PostgreSQL; thêm PostGIS khi bắt đầu dữ liệu camera/vùng/tuyến | Lưu catalog chuẩn hóa, device installation, subscriptions cảnh báo, event/outbox, entitlement; spatial query cho gần tôi/vùng/tuyến |
| Job | Worker Node cùng codebase, DB jobs/outbox; scheduler kích hoạt | Job sống qua restart, retry/backoff, khóa tránh chạy trùng, notification dedupe. Cron đơn lẻ không tự tạo durable delivery |
| Cache | Cache RAM có giới hạn cho một API instance + catalog/version trong DB | Chỉ thêm Redis khi nhiều instance/worker hoặc thực tế cần cache/queue dùng chung |
| Push | Firebase Cloud Messaging; iOS cấu hình APNs | Push từ worker cho ba phạm vi cảnh báo; kiểm thử trên thiết bị thật, xử lý token/registration thay đổi và retry |
| Map | Google Maps Flutter cho mobile, provider adapter cho geocoding/routes | Phân biệt giá Maps SDK với Places/Geocoding/Routes; quota theo tính năng, không xem toàn bộ Google Maps Platform là miễn phí |
| Snapshot | Image pipeline có cancel, freshness, stale/unknown state | Chỉ tải camera visible/đang xem, dừng timer khi đóng/background; interval theo contract nguồn, không áp 12 giây cho mọi provider |
| HLS | Thử `video_player` trên nguồn HTTPS đã chọn | Kiểm chứng codec/auth/expiry trên Android và iOS; không mặc định plugin phát mọi descriptor |
| EVUP | Module riêng, hoãn khỏi lát đầu TP.HCM nếu không phải nguồn bắt buộc | Cần prototype iOS/native riêng hoặc gateway được phép dùng có dự toán; Kotlin/MediaCodec bridge không tự chạy trên iOS |
| VIP | RevenueCat khi đến lát monetization | Giảm phần tự làm billing đa store; entitlement xác nhận phía server/webhook, không tin cờ VIP từ client |
| Deploy | Docker Compose, VPS gần người dùng, DB volume + backup ngoài máy | Điểm khởi đầu tiết kiệm ở tải nhỏ; không có HA mặc định; sizing và vendor cần đo/báo giá trước khi thuê |

Flutter architecture guide khuyến nghị views/view models/repositories/services; Nest có Fastify adapter chính thức. Đây là nền tảng cho đề xuất, không phải bằng chứng rằng framework nào nhanh nhất trong workload này. [Flutter architecture](https://docs.flutter.dev/app-architecture/guide), [NestJS Fastify](https://docs.nestjs.com/techniques/performance), [Undici fetch](https://github.com/nodejs/undici/blob/main/docs/docs/api/Fetch.md).

PostGIS `ST_DWithin` hỗ trợ geography với khoảng cách mét và sử dụng spatial index; phù hợp proximity/corridor. Khu vực polygon dùng spatial relationship phù hợp, tuyến cần geometry thực hoặc người dùng xác nhận, không thay bằng đường thẳng mà gọi là tuyến giao thông. Chọn PostGIS không tự giải quyết coverage/độ chính xác nguồn. [PostGIS ST_DWithin](https://postgis.net/docs/ST_DWithin.html).

## 3. Điều chỉnh so với đề xuất backend trước

1. **Giữ NestJS/Fastify**: scope nay gồm cả weather/alerts/VIP nên module boundary có giá trị; chưa có benchmark buộc đổi Go/Rust hoặc tách microservice.
2. **Redis từ mặc định thành có điều kiện**: một app server/worker tải nhỏ có thể bắt đầu với bounded cache và PostgreSQL. Đánh đổi là cache RAM mất khi restart; jobs/outbox phải lưu DB, không dùng timer RAM làm nguồn sự thật.
3. **PostGIS từ “có thể sau này” thành một phần kế hoạch cảnh báo**: lưu vùng, vị trí có timestamp và tuyến, spatial index. Không cần GIS server riêng ở giai đoạn đầu.
4. **Favorites từ backend CRUD bắt buộc thành local-first ở lát đầu**: user account/sync chưa chốt. Installation identity và push registration vẫn cần cho cảnh báo cá nhân; chúng không đồng nghĩa user login hoặc sync đa thiết bị.
5. **Tách control API và media path**: catalog/health/resolver/alerts đi qua backend. Nguồn cho phép client truy cập trực tiếp thì player đi trực tiếp; nguồn cần giữ bí mật hoặc compatibility thì proxy chọn lọc. Không phát upstream secret lâu dài cho client.
6. **Bổ sung worker/push/entitlement adapters**: không lấy FCM hoặc RevenueCat làm nơi lưu toàn bộ business data; Postgres vẫn giữ business state cần thiết.

## 4. Ba phương án so sánh

| Phương án | Ưu điểm theo mục tiêu | Đánh đổi | Kết luận |
|---|---|---|---|
| Flutter + NestJS/Fastify + Postgres/PostGIS trên VPS | Hai mobile platform, module rõ, địa lý và durable jobs cùng DB, deployment ít thành phần | Tự vận hành backup/OS; giới hạn một máy; phải viết job retry/dedupe đúng | Khuyến nghị với scope hiện tại và tải khởi đầu nhỏ |
| Flutter + Fastify thuần + cùng DB | Ít framework abstraction, phù hợp adapter API rất nhỏ | Tự tổ chức DI/module/job/error contracts; lợi ích tiết kiệm tài nguyên chưa được đo | Hợp lý nếu đội quen Fastify và chủ động tổ chức backend; chưa có lý do đổi ngay |
| Hai app native Kotlin/Swift + backend trên | Điều khiển media/native sâu | Hai codebase và hai native EVUP implementations; chi phí phát triển cao hơn | Chỉ xem lại nếu prototype nguồn bắt buộc không đáp ứng trên Flutter/iOS |

Không chọn backend theo stack Flutter của app gốc. Node/Python/Go đều có thể proxy metadata/ảnh; quyết định hiện tại dựa vào phạm vi, công sức vận hành và dữ liệu địa lý, không vào tên công nghệ đã reverse.

## 5. Nguồn media và giới hạn ngân sách

**Suy luận thiết kế:** rủi ro chi phí lớn là traffic media và provider thời tiết/routes, không phải chỉ RAM của NestJS. Ví dụ giả định 100 người xem đồng thời, mỗi luồng 1 Mbit/s, 1 giờ/ngày ×30 ngày: riêng egress live xấp xỉ 1,35 TB/tháng nếu tất cả đi qua server. Đây là phép tính tải giả định, không phải đo app hoặc báo giá VPS.

Để giữ mục tiêu dưới 1 triệu/tháng:

- Không transcode/relay EVUP hoặc live toàn bộ ngay từ đầu; không lưu lịch sử video mặc định.
- Refresh metadata theo version/TTL nguồn; chỉ probe health có giới hạn và ưu tiên nguồn đang sử dụng, không poll mọi camera mỗi 12 giây.
- Gom truy vấn thời tiết theo vùng/grid phù hợp độ phân giải nguồn và lịch cập nhật, thay vì một request/provider cho mỗi user. Batch endpoint có thể vẫn tính nhiều đơn vị quota; đo theo quy tắc provider.
- Cache snapshot theo freshness contract; bounded bytes/TTL, gộp request đồng thời. Không tăng TTL tùy tiện để đổi ảnh cũ thành “live”.
- Tách ngân sách VPS, backup, weather, Places/Routes và traffic. Chưa có vendor/quote/MAU/peak concurrent nên **chưa thể xác nhận tổng chi phí <1 triệu**. Cần làm rõ phí store, commission, công phát triển có nằm trong ngân sách này không khi lập dự toán, không tự coi bằng 0.

FCM đang được Firebase niêm yết no-cost; backend compute/database/egress không vì vậy miễn phí. Flutter iOS cần APNs setup. [Firebase pricing](https://firebase.google.com/pricing), [FCM Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

Google niêm yết Maps SDK mobile với free usage cap Unlimited, trong khi Places/Geocoding/Routes có SKU và giới hạn riêng. Vì chỉ Android/iOS, Google Maps Flutter là đề xuất khả thi; không dùng giá mobile này để dự toán Maps JavaScript/web. [Maps pricing](https://developers.google.com/maps/billing-and-pricing/pricing), [Google Maps Flutter](https://developers.google.com/maps/flutter-package/overview).

Không mặc định dùng Open-Meteo free cho sản phẩm có quảng cáo/VIP: free API công khai ghi non-commercial, commercial API cần subscription. Chưa chọn nhà cung cấp thời tiết trước khi có giá/quyền dùng và mẫu forecast TP.HCM đủ cho nhu cầu. Cũng không coi có Flood API là đã có nguồn ngập đường đô thị được xác minh. [Open-Meteo pricing](https://open-meteo.com/en/pricing).

RevenueCat hiện ghi miễn phí tới $2.500 monthly tracked revenue, sau ngưỡng tính 1% MTR. Không đồng nghĩa bỏ commission/phí tài khoản của store; kiểm tra giá lại trước khi phát hành. [RevenueCat pricing](https://www.revenuecat.com/pricing).

## 6. Cảnh báo và playback phải có phép thử riêng

- **Khu vực lưu:** subscription có vùng, loại cảnh báo và thời gian; worker lấy weather/cảnh báo nguồn, tạo event có nguồn/thời điểm/mức độ xác minh, dedupe trước gửi.
- **Vị trí hiện tại:** lưu vị trí cập nhật kèm timestamp/độ chính xác và consent; hết freshness thì không gọi vị trí cũ là “hiện tại”. Không cam kết tracking liên tục khi app bị đóng; background policy Android/iOS cần quyết định và thử riêng.
- **Tuyến thường đi:** polyline/corridor đã lưu; cập nhật nguồn cho các vùng dọc tuyến; không gọi Routes API lại ở mỗi tick. Dữ liệu tuyến/provider và quyền cache cần xác nhận.
- **Mưa và ngập:** forecast có thể tạo thông báo mưa/nguy cơ; trạng thái ngập chỉ từ nguồn xác minh, không suy ra từ tên camera hoặc một timestamp ảnh.
- **Playback:** snapshot TP.HCM trước; HLS source fixture hợp lệ trên cả hai OS; EVUP là adapter riêng. `video_player` dùng AVPlayer trên iOS và ExoPlayer trên Android, không có bằng chứng nó xử lý binary EVUP của app gốc. [Flutter video](https://docs.flutter.dev/cookbook/plugins/play-video).
- **TLS:** không sao chép trust manager rỗng/hostname bypass được báo cáo ở app Genius. API Udrivex/AppCheck đã reverse là bằng chứng điều tra, không phải credentials/contract được phép dùng cho backend mới.

## 7. Thứ tự áp dụng

1. Lát camera TP.HCM: adapter nguồn được chọn → catalog/search/bbox → snapshot → favorites local/cache → trạng thái freshness/lỗi. Xác nhận nguồn và iOS thực tế.
2. Cảnh báo khu vực: weather adapter → subscription/event/outbox → FCM → thử lỗi/retry/dedupe, kiểm tra quota và chi phí thực.
3. Cảnh báo vị trí và tuyến: giữ nguyên trong mục tiêu; bổ sung freshness/location lifecycle và corridor matching.
4. Quảng cáo nhẹ + VIP: triển khai khi flow cốt lõi ổn định; tích hợp entitlement/restore và giữ chính sách trải nghiệm đã chọn.
5. Thêm Redis, nhiều instance, media gateway hoặc tỉnh mới chỉ theo đo tải/nguồn được chọn; không coi đó là prerequisite cho camera-first.

Chưa có benchmark/app iOS/nguồn production trong lượt review này. Bước thiết kế tiếp cần thống nhất spec hợp nhất với brainstorming-status và kiểm tra khả thi nguồn + weather budget; bản review này không thay cho phê duyệt thiết kế hoặc thực hiện triển khai.
