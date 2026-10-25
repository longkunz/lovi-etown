# Đề xuất đồng bộ UI Liquid Glass

Ngày: 2026-10-24. Trạng thái: **Đã có triển khai và review mã nguồn; kiểm thử tự động PASS, nghiệm thu thiết bị/profile chưa hoàn tất**.

## Mục tiêu và giả định

Người dùng yêu cầu lập plan đổi thiết kế app sang Liquid Glass. Bản này đề xuất làm hiệu ứng kính rõ và nhất quán trên các màn camera hiện có, xây tiếp trên Flutter và `liquid_glass_widgets: 1.13.0`.

**Giả định do người lập kế hoạch đề xuất:** giữ màu nhấn teal, bố cục và luồng sử dụng hiện tại; đồng bộ cả catalog, Quan tâm inline, sheet, viewer, lưới nhiều camera và controls bản đồ. Người dùng chưa chốt mức thay đổi bố cục. Các lựa chọn dưới đây là đề xuất để review, không ghi nhận là quyết định đã được người dùng duyệt.

## Hiện trạng đã đối chiếu

Đọc cùng [project-status](../../project-status.md), [thiết kế A1](2026-10-15-camera-mobile-a1-design.md) và [DESIGN.md](../../../mobile/DESIGN.md). Đây là refresh giao diện đã có glass, không phải thêm package từ đầu.

| Phần hiện tại | Bằng chứng nguồn | Khoảng cần cải thiện |
|---|---|---|
| Theme | `mobile/lib/src/theme/camera_glass_theme.dart`, `camera_ui_tokens.dart` | Có theme light/dark nhưng settings còn được khai báo lại trong từng widget |
| Catalog | `camera_screen.dart`, `camera_filters.dart` | AppBar có `AdaptiveGlass`; search, dropdown và segmented control vẫn dùng bề mặt Material đặc |
| Camera tile | `camera_tile.dart` | Card bọc glass cả khối; Grid/List dùng Card thường; ngôi sao nổi có nền đen riêng |
| Sheet và viewer | `camera_snapshot_sheet.dart`, `camera_viewer_screen.dart`, `camera_image_viewer.dart` | Có snapshot/live/map/brief; header, mode switch và actions chưa cùng hệ bề mặt |
| Bản đồ | `camera_traffic_map_card.dart`, `camera_traffic_map_viewer_screen.dart` | Có glass wrapper; helper nút bản đồ dùng container bán trong suốt 36×36 |
| Nhiều camera | `multi_camera_screen.dart` | Header còn dùng AppBar thường; cần cùng hệ controls |

Các đường dẫn widget/screen trong bảng thuộc `mobile/lib/src/features/cameras/presentation/`. Đã tra graph project `Users-admin-Sources-lovi-etown`, trace từ `CameraScreen.build`, kiểm tra coverage các file dựa vào và đọc nguồn bổ sung nơi snippet method chỉ trả dòng khai báo. Coverage không ghi nhận vấn đề trên các đường dẫn này; đây là bằng chứng tĩnh, chưa phải quan sát render app.

Workspace đang có thay đổi chưa commit, gồm T18 Google Maps và cấu hình native. Khi triển khai phải đọc lại diff và graph, tích hợp trên trạng thái mới nhất, giữ nguyên công việc đang có.

## Các hướng đã cân nhắc

| Hướng | Đánh đổi |
|---|---|
| Chỉ tăng blur/tint hiện tại | Ít sửa nhưng search và controls vẫn không nhất quán; không giải quyết vùng bấm nhỏ |
| **Đồng bộ theme + controls trên luồng hiện tại — đề xuất** | Thấy thay đổi ở các điểm tương tác chính, tái sử dụng package và state hiện có; cần review shader, bản đồ và độ tương phản trên thiết bị |
| Thiết kế lại cả layout/điều hướng | Có thể thay đổi mạnh hơn nhưng cần chốt lại hành trình, mockup và phạm vi trước khi ước lượng |

Plan đi kèm lập theo hướng thứ hai. Nếu người dùng chọn đổi điều hướng, cập nhật spec và plan trước khi thực thi.

## Hướng hình ảnh

- Kính là lớp điều khiển nằm trên nội dung: nền truyền qua vừa đủ, blur/refraction nhẹ, viền sáng mảnh, màu teal tiết chế. Không dùng glow liên tục hoặc nền chuyển động trang trí.
- Thanh tiêu đề và tìm kiếm dùng cùng ngôn ngữ bo góc. Dropdown mở thành popover kính có vùng cuộn, trạng thái đang chọn rõ và nhãn khu vực từ catalog.
- Chuyển Card/Grid/List thành cụm điều khiển kính; trạng thái chọn dùng cả nền và semantics. Trên màn hẹp, đưa dropdown và mode switch thành hai hàng.
- Camera tile dùng nền nội dung đặc, ảnh sắc nét; ngôi sao nổi dùng kính ở Card/Grid. List dùng ngôi sao trên nền đặc để giảm lớp render.
- Quan tâm giữ inline. Weather, district header và Traffic Brief dùng nền nội dung đặc, typography/spacing thống nhất; chỉ actions cần kính.
- Sheet giữ handle, X, tên và star; media phía dưới rõ, không bị shader xử lý. Giữ live switch, bản đồ và actions hiện có; nội dung dài được cuộn.
- Viewer dùng header/actions kính trên nền tối phục vụ xem media. Giữ zoom/pan, full-screen, chuyển live/snapshot và đường quay lại đang có.
- Bản đồ giữ canvas và màu traffic nguyên vẹn; đặt controls ở lớp sibling overlay. Header và controls có thể fallback sang nền đặc nếu platform view không hỗ trợ lấy mẫu nền đúng.

Không tạo tab mới, màn settings mới, font dependency mới hoặc đổi định dạng dữ liệu trong lần refresh này.

## Quy tắc kỹ thuật và thiết kế

1. Giữ `liquid_glass_widgets: 1.13.0`; đọc API từ package đã resolve trước khi chọn component. Không tự nâng Flutter hoặc package trong refresh.
2. Giữ BLoC/Cubit, repositories, lịch polling/cache và xử lý lifecycle hiện tại; animation không phát state nghiệp vụ từng frame.
3. Dùng chung tokens màu/chữ/spacing/radius; không thêm hex color hay settings shader vào feature widget ngoài lớp theme.
4. Kính chỉ ở chrome/controls; ảnh snapshot, video và canvas bản đồ không đi qua blur/refraction.
5. Một bề mặt chỉ có một lớp glass; control nằm trong header glass dùng nền transparent, không tạo glass lồng glass.
6. Vùng bấm nhỏ nhất 48×48 logical pixels; glyph có thể nhỏ hơn vùng bấm.
7. Hỗ trợ light/dark, chiều rộng 320/390/600 logical pixels và text scale 1.0/2.0; giảm cột hoặc xuống hàng thay vì tràn nội dung.
8. High contrast hoặc `forceOpaque` dùng bề mặt đặc. `disableAnimations` hoặc `accessibleNavigation` tắt motion trang trí; giảm motion không tự đồng nghĩa tắt transparency.
9. Giữ semantics/focus, keyboard search, modal dismiss và ngôi sao filled/outline. Cảnh báo lỗi/stale và trạng thái selected không chỉ dựa vào màu.
10. Không đổi API, native configuration hoặc quyền thiết bị trong refresh UI.

Thông số khởi đầu để mockup: giữ spacing hiện có 8/12/16/24, radius 12 cho controls và 20 cho sheet, capsule cho icon action; blur 12 ở chrome và 18 ở sheet header theo tokens hiện có. Đây là điểm bắt đầu để review, không phải bằng chứng thông số đã phù hợp trên thiết bị. Mọi hiệu chỉnh được ghi tập trung vào tokens.

## Cấu trúc đề xuất

- `mobile/lib/src/theme/camera_ui_tokens.dart`: bổ sung token cho radius, viền, tint, shadow và motion; không đổi các token cache/network trong file.
- `mobile/lib/src/theme/camera_glass_theme.dart`: bổ sung resolver settings theo vai trò và brightness; giữ `themeData` để tương thích bootstrap.
- `mobile/lib/src/theme/camera_glass_policy.dart` mới: phân biệt opaque fallback và giảm motion; có override để test/platform-view composition.
- `mobile/lib/src/features/cameras/presentation/widgets/glass/` mới: bộ component dùng lại trong feature, gồm surface, icon button, search field và segmented control. Control trong bề mặt glass có chế độ không tự tạo glass.
- `camera_district_picker.dart` mới bên cạnh `camera_filters.dart`: quản lý popover khu vực, selection và focus; dùng callback hiện có, không tự gọi repository.

Không sửa hàng loạt App* widgets của starter. Dùng composition theo convention của App*; chỉ đưa component ra shared khi có nhu cầu thực ở feature khác.

## Tiêu chí nghiệm thu

- **AC1 — Đồng bộ:** catalog, sheet, hai viewer, lưới nhiều camera và bản đồ dùng chung theme; có bộ screenshot light/dark trước/sau.
- **AC2 — Glass thấy được:** trên thiết bị, nền thực cuộn phía sau header/control làm thay đổi hình ảnh qua kính; viền/tint không che chữ. HTML và golden không chứng nhận shader.
- **AC3 — Media rõ:** ảnh giữ tỷ lệ ở sheet/full-screen, không blur; video/map không bị phủ shader toàn khối; traffic và attribution vẫn đọc được.
- **AC4 — Tương tác:** search, clear, dropdown, mode switch, favorites, retry và Back/X hoạt động; trở lại catalog giữ query/filter/mode/scroll theo hành vi hiện có.
- **AC5 — Khả năng tiếp cận:** 48×48, không overflow ở ma trận viewport/text scale; semantics, focus và fallback đúng; TalkBack/VoiceOver được kiểm tra trên thiết bị.
- **AC6 — Live/map:** lỗi live vẫn chuyển về snapshot theo logic hiện có; controls map toggle/recenter/fullscreen/directions dùng được; thiếu tọa độ không xuất hiện map rỗng.
- **AC7 — Tài nguyên:** không thêm polling do mở overlay hoặc đổi theme; profile 20 lần mở/đóng và cuộn nhanh không tăng bộ nhớ liên tục sau khi ổn định. Ở thiết bị 60 Hz, ghi riêng p95 UI/raster frame time, mục tiêu mỗi loại ≤16.7 ms trong đoạn cuộn đại diện.
- **AC8 — Bằng chứng:** chạy `flutter analyze`, `flutter test` và ba suite backend theo AGENTS.md; ghi ngày, lệnh, thiết bị và kết quả thực. Mọi mục thiết bị chưa chạy được ghi còn thiếu.

## Review trước khi viết UI

Tạo bộ mockup đề xuất tại `docs/ui/liquid-glass-refresh/`: catalog Grid + search/dropdown mở, sheet có map/live, viewer dọc/ngang và map fullscreen; light/dark cho mỗi bố cục chính. Dùng JPEG local hiện có và dữ liệu mẫu có nhãn; không sao chép số liệu hoặc nhãn trạng thái giả từ bản Stitch cũ.

Đầu vào cần người dùng review là mức kính, bố cục controls và phạm vi giữ luồng hiện tại. Chưa có yêu cầu tạo mockup trong lượt lập plan này; đó là deliverable đầu tiên khi thực thi kế hoạch.

## Giới hạn bằng chứng

Lượt lập spec ban đầu chỉ đọc nguồn/tài liệu. Cập nhật review 2026-10-24: đã kiểm tra mã nguồn, sửa regression và chạy test tự động; chưa nghiệm thu shader/native Maps, screen reader hoặc profile. Xem [báo cáo](../../ui/liquid-glass-refresh-verification.md). Kết quả test lịch sử ở project-status không được tính là kiểm chứng cho refresh đề xuất.

Kế hoạch: [Liquid Glass refresh implementation plan](../plans/2026-10-24-liquid-glass-refresh.md).
