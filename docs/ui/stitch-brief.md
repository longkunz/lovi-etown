# Brief UI Stitch — Mobile A1

Feedback sheet mới nhất (thay thế controls/thời gian bên dưới): chỉ giữ header, saved star và ảnh; bỏ nút Làm mới/Toàn màn hình, bỏ text giờ nhận/cập nhật/giờ chụp unknown. Chạm ảnh mở viewer overlay hỗ trợ xoay ngang, pinch zoom, pan và double-tap fit/zoom. Sheet co chiều cao theo nội dung, giữ list context. Timestamp in sẵn trong JPEG không bị chỉnh sửa.

Ngày: 2026-10-16. Trạng thái: sau feedback ba ảnh mẫu đã tạo **v3 Card/Grid/Dropdown có ảnh camera và infinite loading**, import bản HTML sửa asset lên Stitch. Người dùng chốt **Liquid Glass dùng `liquid_glass_widgets`**. Chờ review hình ảnh; chưa triển khai Flutter. [Bản review hiện tại](stitch/README.md). Cơ sở hợp nhất: [review tài liệu](document-review-2026-10-16.md), được yêu cầu v3 bên dưới cập nhật.

## Mục tiêu

Thiết kế UI trước khi code Flutter trong `mobile/`. Giúp người dùng TP.HCM kiểm tra camera trước chuyến đi: tìm camera → xem ảnh snapshot → lưu Quan tâm → mở lại. Kế thừa phạm vi của `docs/superpowers/specs/2026-10-15-camera-mobile-a1-design.md`; đây là đề xuất cho sản phẩm mới, không phải bằng chứng hành vi app gốc.

## Navigation mới nhất — Camera + bottom sheet

Người dùng yêu cầu không tạo riêng page cho Quan tâm/chi tiết chỉ để xem snapshot. Thay hướng cũ bằng một màn Camera: Quan tâm là section thu gọn/bộ lọc local “Chỉ quan tâm”; card mở modal snapshot bottom sheet. Bỏ dock hai tab Camera/Quan tâm trong A1; không thêm tab placeholder khác. Reference: `stitch/references/camera-bottom-sheet.jpg` đã mở xem và upload.

Sheet mặc định theo nội dung (đề xuất khoảng 55–65% chiều cao), kéo lên gần full khi cần; handle, X, tên, saved star, metadata, ảnh đầy đủ tỷ lệ, nhãn giờ nhận/unknown giờ chụp và controls Làm mới/Toàn màn hình. Không có khoảng trắng lớn dưới ảnh, không pencil sửa tên, không cần related trong quick view. X/Back/swipe/scrim đóng về đúng list context; fullscreen là overlay dùng chung ảnh/controller, không page mới. Modal semantics/focus, lifecycle/polling, gesture và detents cần nghiệm thu Flutter. Các mô tả hai tab/page riêng bên dưới là lịch sử bị mục này thay thế.

## Điều chỉnh đã chốt từ ba ảnh mẫu — 2026-10-16

Yêu cầu mới của người dùng thay thế hướng text-first/chips/“Tải thêm” trong vòng v1/v2 bên dưới:

- Danh sách địa điểm/khu vực dùng **dropdown** cạnh search; mở thành popover Liquid Glass có scroll, tìm khu vực, lựa chọn hiện tại và “Tất cả khu vực”. Không dùng hàng chip quận như bản cũ.
- Có **Card**, **Grid 2 cột**, **Grid gọn 3 cột** và **List gọn**; tên mode là mô tả thiết kế, UI có thể dùng segmented control Card/Grid/List và tùy chọn mật độ của Grid. Trên màn nhỏ hoặc font lớn tự giảm cột, không cố ép 3 cột.
- **Hiển thị ảnh snapshot camera ngay trong danh sách hiện tại**, ảnh đúng tỷ lệ, tim nổi trên ảnh, tên và địa điểm bên dưới. Có placeholder/loading/lỗi ảnh riêng từng camera. “Không tải được ảnh” khác kết luận camera offline.
- **Infinite scroll** tự tải trang tiếp khi gần cuối, spinner “Đang tải thêm…”; lỗi trang sau giữ danh sách và có “Thử lại”, hết dữ liệu có trạng thái kết thúc. Không có nút Load more/Tải thêm trong happy path.
- Liquid Glass rõ ở search, dropdown, mode switch, favorite overlay và bottom dock: nội dung ảnh phía sau thật sự thấy mờ qua kính, viền specular mảnh và chiều sâu. Không mô phỏng bằng capsule trắng đặc + shadow. Nội dung ảnh/text giữ sắc nét ngoài chrome.
- Quan tâm nằm ngay trong Camera (section/filter), snapshot mở bottom sheet. Thời tiết/account/map trong ảnh là tham khảo visual, chưa phải yêu cầu thêm vào A1.

References đã xem: `stitch/references/grid-compact.jpg`, `location-dropdown.jpg`, `grid-comfortable.jpg`. Copy nguyên ảnh người dùng cung cấp, không sửa ảnh. Mockup dùng nhãn “Dữ liệu mẫu”; không sao chép số 718 hoặc tự gán danh mục phường/online status của nguồn mẫu cho backend mới.

**Ràng buộc dữ liệu khi triển khai:** dropdown hiển thị đúng label khu vực có trong catalog; dữ liệu phường/xã như ảnh mẫu chưa được xác minh. Thumbnail chỉ fetch cho camera visible + prefetch nhỏ, concurrency/budget hữu hạn, không poll toàn bộ danh mục. Khi vào chi tiết, thumbnail của list dừng refresh; khi background/offscreen thì pause/cancel. Infinite scroll dùng limit/offset hiện có, không bắt buộc đổi API sang cursor; giữ query/filter/version, bỏ response cũ, dedupe theo ID, dừng theo total/trang rỗng/giới hạn offset 10000.

**Đầu ra vòng v3:** Card có ảnh, Grid 2 cột và dropdown đang mở; cùng visual system để review. List gọn/grid 3 cột là khả năng thiết kế tiếp sau khi chọn bản chính. Phần “Prompt màn đầu tiên” bên dưới là prompt lịch sử v1; prompt v3 và output lưu trong `stitch/`.

## Hướng thiết kế đề xuất

- Giao diện tiếng Việt, mobile Android + iOS; mockup dọc khoảng 390 × 844, thích ứng màn nhỏ và chữ lớn.
- Liquid Glass là ngôn ngữ hình ảnh chính, triển khai bằng package người dùng chọn; bám tinh thần Cupertino của starter. Thanh nổi dạng capsule, blur/refraction có kiểm soát, viền highlight mảnh và cảm giác chiều sâu rõ ở navigation/controls. Nền sáng trung tính, màu nhấn teal và typography cụ thể là đề xuất để review.
- Theo triết lý `liquid_glass_widgets`: glass ở thanh điều hướng, search/filter, controls và sheets; thẻ nội dung/metadata nền đặc, ảnh snapshot không blur. Không biến toàn bộ app thành các lớp kính chồng nhau. Dark mode dùng cùng hệ thống component; có biến thể giảm transparency/motion.
- Một màn Camera, Quan tâm inline và snapshot sheet; đóng sheet giữ query/filter/mode/scroll.
- Đã tạo ba artboard Camera Card/Grid/Dropdown để chốt phong cách; sau đó áp dụng cùng design system cho Chi tiết/Quan tâm và các trạng thái.

## Màn hình và trạng thái

1. **Camera:** tiêu đề TP.HCM, tìm tên/địa chỉ, dropdown khu vực, chuyển Card/Grid/List; ảnh camera visible trong list, tên/địa điểm, Quan tâm và mở chi tiết. Infinite scroll với spinner/error/end; nhãn “Đã tải N camera”, catalog cũ/không đầy đủ khi phù hợp. Không tải/poll ảnh toàn danh mục.
2. **Snapshot sheet:** tên, metadata nullable, ảnh đúng tỷ lệ, Toàn màn hình overlay, saved star và làm mới. Nhãn “Ảnh chụp” + giờ nhận khác giờ chụp unknown. Loading/error/stale/unsupported nằm trong sheet; không LIVE, không page detail riêng.
3. **Quan tâm inline:** ảnh camera lưu local, section thu gọn hoặc lọc cùng grid, card mở sheet. Rỗng có hướng dẫn inline và xóa bộ lọc; camera 404 vẫn cho bỏ Quan tâm. Không page/tab riêng.
4. Sau khi chọn phong cách: thiết kế biến thể dark, tìm không có kết quả, mất mạng, catalog cũ/partial, ảnh chưa cập nhật/thiếu timestamp, chưa hỗ trợ snapshot, rate limit, lỗi lưu/phục hồi local và danh sách Quan tâm rỗng. Giữ hành động thử lại/lối tiếp tục rõ, không loading vô hạn.

Không đưa map, tuyến đường, video LIVE, đăng nhập hoặc VIP vào A1. Không thêm tab/chức năng chỉ để lấp bố cục. Dữ liệu minh họa phải được nhận diện là dữ liệu mẫu; không bịa chất lượng giao thông hoặc trạng thái online của camera.

## Prompt màn đầu tiên — lịch sử v1, đã được yêu cầu v3 thay thế

```text
Design one polished MOBILE screen for a Vietnamese traffic-camera app serving Ho Chi Minh City. This is a visual mockup for a future Flutter app, not an implementation request. All visible copy must be natural Vietnamese with correct accents.

Screen: Camera catalog. Purpose: quickly find a camera before a journey, open a snapshot, and save favorites. Use a Cupertino-inspired visual language, restrained translucent Liquid Glass navigation, calm neutral surfaces, a teal accent, crisp accessible typography, and generous but practical spacing. Portrait reference approximately 390x844, safe areas, readable on small phones. Avoid excessive blur or low-contrast text.

The product's chosen visual language is Liquid Glass, intended to be implemented in Flutter with liquid_glass_widgets (reference 1.13.0). Make glass clearly visible and refined in floating navigation chrome and controls: translucent capsule tab bar, subtle lens-like refraction, restrained rim highlights, layered depth and rounded glass search/filter controls. Keep content rows and camera cards opaque and highly legible; never blur or distort camera imagery. Do not nest multiple glass controls inside another glass wrapper. Design for GlassScaffold, GlassAppBar, GlassTabBar.bottom, GlassSearchBar, GlassChip and GlassIconButton; these are implementation references, not visible UI copy. The mockup illustrates appearance; real shader and motion fidelity will be validated in Flutter.

Header: “Camera” and “TP.HCM”. Search: “Tìm camera theo tên hoặc địa chỉ”. Optional district filter chips represent sample district data, not a location permission prompt. Use text-first camera cards with name, optional address/district, a clearly tappable favorite heart, and a detail affordance. No image thumbnails on catalog cards. No fake traffic severity, LIVE badges, or online status. Show “Đã tải 12 camera” and a “Tải thêm” action. Bottom navigation has exactly “Camera” and “Quan tâm”. Clearly mark mock content “Dữ liệu mẫu”. Do not add maps, weather, route planning, sign-in, ads, or VIP. Minimum 48 logical-pixel touch targets, labels as well as icons, no clipped content at larger text sizes.

Create a coherent reusable visual system that can extend to camera snapshot detail and favorites. Deliver the normal populated light-mode screen first.
```

## Đầu ra cần lưu

- Project ID, screen IDs, prompt và ngày tạo.
- Screenshot, HTML tham khảo và biến thể được chọn dưới `docs/ui/stitch/` khi có.
- Bảng token màu/chữ/spacing/radius, component và trạng thái cần triển khai.
- HTML từ Stitch là tài liệu tham khảo; triển khai Flutter sau khi review, ánh xạ vào App* widgets và tokens theo `mobile/DESIGN.md`.
- Giữ hệ thống tokens hiện có; `mobile/DESIGN.md` đã bổ sung hướng Liquid Glass, giá trị token cụ thể sẽ hòa giải sau review mockup.

## Mapping package và giới hạn cần giữ

`GlassScaffold` cho bố cục/chrome; `GlassAppBar` cho header; `GlassModalSheet` cho snapshot; `GlassSearchBar` cho tìm camera; `GlassPullDownButton`/`GlassMenu` hoặc `GlassPopover` cho dropdown; `GlassSegmentedControl` cho mode; `GlassIconButton`/`GlassButton` cho thao tác. Không cần bottom tabs Camera/Quan tâm. Nội dung opaque dùng shared App* widgets/tokens của starter khi phù hợp. Không ép mọi App* widget thành glass và không thay BLoC/go_router.

Package tham chiếu 1.13.0 yêu cầu Flutter ≥3.41.0; chưa thêm dependency. Khi triển khai dùng initialization/wrap và brightness resolver phù hợp root app thật, tránh glass lồng glass; không dùng premium cho thẻ trong danh sách cuộn. Shader/refraction, motion, fallback thiết bị yếu và accessibility cần nghiệm thu Android/iOS riêng. [Tài liệu package](https://pub.dev/packages/liquid_glass_widgets).

Camera liên quan là cùng district nếu API có dữ liệu, nhãn “Camera cùng khu vực”, không gọi “Gần bạn” hoặc bịa khoảng cách. Không xin GPS cho A1. Danh sách district có thể rỗng; mockup chuẩn bị cả trạng thái ẩn bộ lọc. Favorites local không cần account. Timestamp ảnh unknown phải hiển thị unknown; lỗi refresh giữ ảnh cuối kèm cảnh báo.

## Công cụ đã kiểm tra

- Package npm chính thức `@google/stitch`, phiên bản đã cài 0.11.1; `stitch --version` đã chạy thành công.
- README package cung cấp generate/edit/variants/serve và cấu hình project. Nguồn: https://www.npmjs.com/package/@google/stitch ; tài liệu người dùng chọn: https://stitch.withgoogle.com/docs/cli/overview/ .
- CLI đã generate/edit/import thành công project `15634181901662145156`; bản review mới nhất Grid `8278298733313211302`, Card `5363005408800856859`, Dropdown `18241151456201549198`. Prompt, response, PNG và HTML lưu trong `docs/ui/stitch/`; không lưu email/token ở đây.
- Chưa kiểm tra source Flutter bằng graph, chưa build/chạy app; nhận xét starter ở brief chỉ dựa trên `mobile/AGENTS.md`, `mobile/DESIGN.md` và `mobile/pubspec.yaml`.

## Bước tiếp

Người dùng thay navigation page riêng bằng Camera + snapshot sheet và Quan tâm inline. Đã tạo/cập nhật hai mockup theo hướng mới; các page riêng giữ làm lịch sử. [Link/ảnh/giới hạn hiện hành](stitch/README.md). Sau khi chốt sheet và section/filter, bổ sung List/grid gọn, dark mode, ảnh mở rộng và state variants còn thiếu. Chưa chuyển mockup thành Flutter trước khi chốt thiết kế.

