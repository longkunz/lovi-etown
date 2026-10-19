# Superpowers — thiết kế app camera mới

## Plan triển khai Mobile A1 — 16/10/2026

Đã tạo [implementation plan](plans/2026-10-16-camera-mobile-a1.md) theo yêu cầu người dùng: 7 task từ boot/glass → Camera fixture → sheet/viewer → Quan tâm bền → backend/infinite/thumbnails → polling lifecycle → nghiệm thu thiết bị. Có prototype tương tác và artboard light/dark/loading/error/empty. Feedback hiện hành: sheet không có hai nút hoặc text thời gian, chạm ảnh mở viewer xoay ngang/zoom. Chờ review plan và lựa chọn cách thực thi; chưa sửa product Flutter code hoặc dependencies. Inventory starter hiện chưa có runner Android/iOS; Flutter SDK chưa resolve trong PATH, không kết luận chưa cài.

## Quyết định navigation mới nhất — một màn Camera + sheet

Người dùng không muốn page Quan tâm/chi tiết riêng; cung cấp ảnh snapshot bottom sheet. Đã cập nhật Mobile A1/brief/mobile DESIGN: Quan tâm inline section/filter, card mở modal sheet có detents và fullscreen overlay dùng chung preview. Bỏ hai-tab Camera/Quan tâm trong A1, giữ BLoC/go_router/backend và roadmap. Đã tạo lại hai artboard và sửa HTML asset/content; [review hiện hành](../ui/stitch/README.md). Gesture/focus/scroll restore/lifecycle còn phải nghiệm thu Flutter. Các đoạn page riêng bên dưới là lịch sử.

## Đã thiết kế Chi tiết và Quan tâm

Sau khi người dùng chấp thuận v3 và đồng ý tiếp tục, đã tạo/import bản review Chi tiết snapshot `12538486518867795532`, Quan tâm có dữ liệu `6984728961356815463` và Quan tâm rỗng `13088157116766237497` trong cùng project Stitch. [Link/ảnh/giới hạn](../ui/stitch/README.md). Bản thiết kế dùng asset JPEG đã kiểm tra, nhãn dữ liệu mẫu; chưa code Flutter. Các màn mới chờ review; dark/List/expanded/loading-error variants còn thiếu.

## Phản hồi v3 — người dùng chấp thuận hướng UI

Người dùng trả lời “ok” sau bàn giao Grid/Card/Dropdown v3. Hướng hình ảnh được chốt để tiếp tục thiết kế Chi tiết snapshot/Quan tâm và các biến thể còn thiếu. Chưa triển khai Flutter; chấp thuận visual direction không chứng nhận renderer, pagination tương tác hoặc dữ liệu production. Xem [trạng thái thiết kế](../ui/stitch/README.md).

## Thiết kế mới nhất — Camera v3 theo ảnh mẫu, 2026-10-16

Người dùng chỉnh hướng: dropdown địa điểm, mode Card/Grid/List, ảnh camera trong danh sách hiện tại, infinite loading thay load more; UI phải Liquid Glass rõ hơn. Yêu cầu này supersede text-first/no-list-thumbnails/chips/tải thêm thủ công. Đã tạo và import ba artboard review dùng asset camera đã kiểm tra: Grid `8278298733313211302`, Card `5363005408800856859`, Dropdown `18241151456201549198`. [Review](../ui/stitch/README.md), [brief](../ui/stitch-brief.md). Chờ review phong cách; chưa code Flutter. Giữ BLoC/go_router/backend và các roadmap khác; label phường mock chưa chứng minh backend có dữ liệu phường. Snapshot visible + prefetch hữu hạn, pagination dùng limit/offset hiện có.

## Thiết kế Stitch — Camera v2, 2026-10-16

Người dùng đã yêu cầu tiến hành tạo design. Đã tạo project `15634181901662145156`, màn Camera light đầu và refinement v2 `f4b077a13f3a42db99b0df38fc835b88`. Đã tải/đọc screenshot và HTML; v2 sửa wrap tên/địa chỉ, count 6 thẻ và touch target. [Bản review và giới hạn](../ui/stitch/README.md). Chờ người dùng chọn hướng hình ảnh để mở rộng Chi tiết/Quan tâm/dark/state variants; chưa có Flutter UI hoặc dependency glass mới. Các trạng thái “chưa tạo màn Stitch” phía dưới là lịch sử trước lệnh tạo design.

## Cập nhật mới nhất — 2026-10-16, UI trước code

Người dùng đã setup starter ở `mobile/`, chọn Stitch CLI để thiết kế trước khi code và chốt style **Liquid Glass dùng `liquid_glass_widgets`**. CLI 0.11.1 đã cài; `stitch status` trả Valid/OAuth Canvas credential present. Chưa tạo màn Stitch hoặc thêm dependency Flutter trong lượt review. A1 vẫn là danh sách/tìm kiếm → snapshot → Quan tâm; map/Vietmap/LIVE/cảnh báo/VIP giữ trong roadmap sau A1.

Đã review 40 tài liệu Markdown dự án trong docs/mobile/backend và cập nhật Mobile A1, brief và hướng UI trong mobile/DESIGN.md. [Review + giới hạn](../ui/document-review-2026-10-16.md), [brief hiện hành](../ui/stitch-brief.md). Các dòng dưới ghi “chưa generate mobile/chưa có backend” là lịch sử, không mô tả hiện trạng. Báo cáo backend acceptance ngày 14/10 chưa chạy lại. Bước tiếp là tạo mockup theo brief Liquid Glass để review; chưa triển khai Flutter.

## Trạng thái mới nhất — 2026-10-15, Mobile A1

**Quyết định mới nhất:** người dùng chốt Flutter; chọn BLoC vì đã quen và yêu cầu dùng https://github.com/Arjun544/flutter_init làm starter. Đã cập nhật Mobile A1 spec, thay đề xuất Riverpod/notifier SDK bằng BLoC/Cubit. Cấu hình đề xuất: Feature-First, go_router, Dio, Shared Preferences, REST backend hiện có. Chưa generate hoặc kiểm chứng code output. Các đoạn bên dưới ghi Flutter chưa chốt là lịch sử.

Người dùng đồng ý tiến hành bước tiếp theo sau backend. Đã đọc mã contract backend và soạn `docs/superpowers/specs/2026-10-15-camera-mobile-a1-design.md` cho danh sách/tìm kiếm → snapshot → Quan tâm local. Flutter là đề xuất cần review trong spec. Chưa scaffold mobile hoặc cài dependency. Backend có báo cáo acceptance lịch sử ngày 14/10; chưa chạy lại trong lượt này. Các đoạn “chưa có product code backend” bên dưới là lịch sử, không mô tả hiện trạng.

Graph hiện chưa track source backend; đã check coverage và dùng đọc trực tiếp cho contract. Workspace root không phải git repository; repo backend riêng, không đưa spec mobile vào commit backend. Bước tiếp: người dùng review written spec Mobile A1, rồi writing-plans và thực thi theo lựa chọn.

Path: Architectural. Stage hiện tại: spec backend A1 camera-first đã được người dùng xem/xác nhận; implementation plan đã viết và tự review, đang chờ người dùng review plan/chọn phương thức thực thi. Chưa scaffold hoặc viết product code.

Plan: `docs/superpowers/plans/2026-10-14-camera-backend-a1.md`. Khuyến nghị Native/inline trong session; sáu task gồm nền API → catalog → Notis sync → danh sách/detail → snapshot → real-source acceptance. Node24 và Docker server đã kiểm tra hoạt động; chưa cài dependency hay tạo container sản phẩm.

## Cập nhật backend trước — 2026-10-14

**Nguồn/vai trò đã làm rõ:** người dùng xác nhận Notis/TTGT là public và chọn dùng cho A1; Udrivex chỉ tham khảo catalog/descriptor, thay bằng backend riêng. Default app mode là notis + PostgreSQL catalog, fixture chỉ test/demo explicit. Không cần Udrivex app-check/client; nghiệm thu A1 gồm smoke sync/list/detail/snapshot với Notis thật. Không yêu cầu người dùng xác nhận lại việc chọn nguồn public này.

**Điều chỉnh từ người dùng:** spec phải tập trung danh sách và xem camera. A1 là list/search tên/detail/playback snapshot/refresh; LIVE theo nguồn ở A2. Vietmap/map/geocoding/route chuyển sang lát hỗ trợ sau, không là dependency nghiệm thu A1. Spec đã sửa tại đường dẫn bên dưới, vẫn chờ review. Không coi việc người dùng có Vietmap là yêu cầu triển khai map trước.

Đã bổ sung đối chiếu rõ với tài liệu Genius tại `docs/backend-reverse-traceability.md`: list/district/address/search, detail/related, cache/version/stale, favorites ID, playback đa nguồn, backup và các giới hạn kiểm chứng. Spec A1 cập nhật search tên + địa chỉ, filter district, related camera, catalog freshness và nullable fields. Tích hợp hành vi từ hai bộ reverse không đồng nghĩa đã tích hợp Udrivex hoặc có đủ 900 camera.

Người dùng xác nhận có cả ba dịch vụ Vietmap (bản đồ, tìm địa điểm/geocoding, tính tuyến) và muốn build API backend trước. Vietmap thay đề xuất Google Maps; quyền/version của key chưa thử bằng request thật, key không yêu cầu gửi vào chat. Đã soạn `docs/superpowers/specs/2026-10-14-camera-backend-design.md` cho lát camera + Vietmap với NestJS/Fastify/PostGIS; spec chờ review, chưa có implementation plan được duyệt hay product code. Roadmap cảnh báo khu vực/vị trí/tuyến và mục tiêu ngân sách giữ nguyên.

## Hiểu biết hiện tại

Người dùng muốn hiểu tech stack, flow và API của app gốc để xây app có tính năng tương tự nhưng cải tiến tạo khác biệt. Điều tra artifact/runtime đã có báo cáo trong docs; tái sử dụng bằng chứng đó, không làm lại reverse toàn bộ.

Đã chốt qua hỏi đáp:

- Người dùng: kiểm tra đường trước chuyến đi và theo dõi thời tiết/mưa ngập.
- Nền tảng: Android + iOS; địa lý đầu tiên: TP.HCM.
- Nguồn: nguồn camera công khai cho phép sử dụng, backend riêng; chưa chọn nhà cung cấp hoặc xác minh quyền từng nguồn.
- Doanh thu: quảng cáo nhẹ + VIP bỏ quảng cáo. Chính sách quảng cáo cụ thể còn là đề xuất.
- Cảnh báo: đủ ba phạm vi khu vực lưu, vị trí hiện tại, tuyến đường thường đi.
- Chưa có dữ liệu ngập xác minh: chỉ thông báo mưa/nguy cơ và ghi rõ chưa xác nhận ngập; chỉ thông báo ngập khi có nguồn đáng tin cậy.
- Ngân sách vận hành: dưới 1 triệu đồng/tháng, là giới hạn mong muốn chứ chưa phải dự toán đã chứng minh.
- Cách triển khai đã chọn: từng lát tính năng, camera/tìm kiếm/bản đồ/favorites trước; cảnh báo khu vực rồi vị trí/tuyến đường. Không tự bỏ hai phạm vi cảnh báo đã chọn khỏi mục tiêu.

Đang đề xuất, chưa chốt: Flutter, kiến trúc app/backend, provider thời tiết/bản đồ/push, giới hạn vận hành theo số người dùng và tiêu chí hiệu năng.

`docs/rebuild-spec.md` là đề xuất sơ bộ, không phải written spec đã được phê duyệt. Thành công của sản phẩm phải được xác định với người dùng, không mặc định bằng việc sao chép đủ tính năng app gốc.

## Checklist theo brainstorming Architectural

- [x] Đọc skill using-superpowers và brainstorming; phân loại Architectural.
- [x] Đọc bối cảnh dự án, đề xuất rebuild và hướng dẫn workspace.
- [x] Làm rõ người dùng, nhu cầu, nền tảng, nguồn, phạm vi và ngân sách; tiêu chí nghiệm thu chi tiết tiếp tục trong thiết kế.
- [x] Phản ánh brief qua các bước hỏi đáp và nhận lựa chọn.
- [x] So sánh 3 cách tiếp cận; người dùng chọn triển khai từng lát tính năng.
- [ ] Trình bày các phần thiết kế, nhận phản hồi từng phần.
- [ ] Viết spec tại docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md.
- [ ] Self-review spec về scope, consistency, ambiguity và placeholder.
- [ ] Người dùng review written spec.
- [ ] Dùng writing-plans để viết implementation plan.
- [ ] Người dùng review plan và chọn phương thức thực thi.

Chỉ đề nghị visual companion khi có quyết định thực sự cần hình minh họa. Chưa scaffold hoặc viết product code trước các bước prerequisite tương ứng của skill.

