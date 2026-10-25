# Liquid Glass Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Only use subagents if the user separately requests that execution method.

**Status:** Đã có triển khai Task 1–5; review 2026-10-24 đã sửa lỗi layout, semantics, focus và reduced motion. Kiểm thử tự động sau review: 174 Flutter tests, 86 backend tests PASS; analyze 0 issues. Task 6 chưa hoàn tất: còn ảnh app trước/sau, shader/native Maps, screen reader và profile p95/RAM. Xem báo cáo nghiệm thu; PR để Draft.

**Goal:** Đồng bộ UI hiện có thành Liquid Glass rõ, dễ đọc và nhất quán trên catalog, sheet, viewer, nhiều camera và bản đồ.

**Architecture:** Giữ feature-first/BLoC và các luồng hiện tại. Tập trung settings/policy trong theme, tạo component glass trong feature cameras rồi thay thế chrome/controls theo từng màn; media giữ lớp riêng.

**Tech Stack:** Flutter/Dart của workspace, `liquid_glass_widgets: 1.13.0`, flutter_bloc, easy_localization, google_maps_flutter hiện có; không thêm dependency.

**Spec:** [Đề xuất Liquid Glass refresh](../specs/2026-10-24-liquid-glass-refresh-design.md). Đọc cả [project-status](../../project-status.md), [DESIGN.md](../../../mobile/DESIGN.md) và diff hiện tại trước khi làm.

## Global Constraints

- Giữ `liquid_glass_widgets: 1.13.0`; không tự nâng Flutter/package.
- Giữ BLoC/Cubit, repositories, lịch polling/cache và xử lý lifecycle hiện tại.
- Dùng chung tokens màu/chữ/spacing/radius; không thêm hex color hay settings shader vào feature widget ngoài lớp theme.
- Kính chỉ ở chrome/controls; ảnh snapshot, video và canvas bản đồ không đi qua blur/refraction.
- Một bề mặt chỉ có một lớp glass; không tạo glass lồng glass.
- Vùng bấm nhỏ nhất 48×48 logical pixels.
- Hỗ trợ light/dark, chiều rộng 320/390/600 logical pixels và text scale 1.0/2.0.
- High contrast hoặc `forceOpaque` dùng bề mặt đặc; `disableAnimations` hoặc `accessibleNavigation` tắt motion trang trí.
- Giữ semantics/focus, keyboard search, modal dismiss và ngôi sao filled/outline.
- Không đổi API, native configuration hoặc quyền thiết bị trong refresh UI.
- Workspace đang có thay đổi T18/native chưa commit; giữ nguyên edits của người khác, không reset hoặc stage chúng trong commit refresh.

## Review Focus

1. 320px + text scale 2 + tên quận dài: search/dropdown/modes vẫn dùng được, không overflow — Task 3.
2. Đổi theme/high contrast khi đang mở sheet: ảnh và state được giữ, không request lại vì đổi style — Task 4.
3. Popover khu vực mở cùng bàn phím: Back đóng đúng lớp, focus trả về trigger, không reset query — Task 3.
4. Google Maps platform view hoặc live texture: controls dễ đọc và bấm được ngay cả khi kính không lấy mẫu được nền — Task 5 và kiểm tra thiết bị Task 6.
5. Favorites/retry/state lỗi khi đổi Card/Grid/List: dữ liệu và semantics ổn định, lỗi ảnh không biến thành nhãn offline — Task 3/4.

## File map và giao diện dùng chung

Các đường dẫn dưới đây tính từ root repository. Trong task, `presentation/` là `mobile/lib/src/features/cameras/presentation/`; `camera-tests/` là `mobile/test/features/cameras/`.

| File | Trách nhiệm |
|---|---|
| `mobile/lib/src/theme/camera_ui_tokens.dart` | Token hiện có và token thị giác mới |
| `mobile/lib/src/theme/camera_glass_theme.dart` | Resolver settings theo role/brightness, giữ getter themeData |
| `mobile/lib/src/theme/camera_glass_policy.dart` mới | Opaque fallback và reduced motion |
| `presentation/widgets/glass/camera_glass_surface.dart` mới | Một lớp kính hoặc surface đặc |
| `presentation/widgets/glass/camera_glass_icon_button.dart` mới | Action 48×48, semantics, embedded mode |
| `presentation/widgets/glass/camera_glass_search_field.dart` mới | Input, controller/focus/clear, validation |
| `presentation/widgets/glass/camera_glass_segmented_control.dart` mới | Selection generic, keyboard/semantics |
| `presentation/widgets/camera_district_picker.dart` mới | Popover chọn quận và focus |
| Widgets/screens hiện có | Composition/layout; giữ callback và state ownership |

API đề xuất cho implementer; không giả định đây là API của package:

```dart
enum CameraGlassRole { header, control, sheetHeader }

// camera_glass_policy.dart
class CameraGlassPolicy {
  final bool opaque;
  final bool reduceMotion;
  const CameraGlassPolicy({required this.opaque, required this.reduceMotion});
  factory CameraGlassPolicy.resolve(MediaQueryData mediaQuery,
      {bool forceOpaque = false});
}

// Bổ sung vào CameraGlassTheme; giữ themeData hiện tại.
static LiquidGlassSettings settingsFor(
    CameraGlassRole role, Brightness brightness);

// Constructor contracts; các lớp là widget, trả UI qua build().
CameraGlassSurface({Key? key, required Widget child,
  CameraGlassRole role = CameraGlassRole.control,
  BorderRadius? borderRadius, bool forceOpaque = false});
CameraGlassIconButton({Key? key, required IconData icon,
  required String label, required VoidCallback? onPressed,
  bool selected = false, bool embedded = false,
  bool forceOpaque = false});
CameraGlassSearchField({Key? key,
  required TextEditingController controller, required String hintText,
  required ValueChanged<String> onChanged, required VoidCallback onClear,
  FocusNode? focusNode, String? validationMessage});
CameraGlassSegmentedControl<T extends Object>({Key? key,
  required List<ButtonSegment<T>> segments, required T value,
  required ValueChanged<T> onChanged, bool embedded = false});
CameraDistrictPicker({Key? key, required List<DistrictOption> districts,
  required String? selectedDistrict,
  required ValueChanged<String?> onChanged});
```

`embedded: true` dùng trong parent glass, không tự tạo surface. Không đặt search field hoặc district picker tự có glass trong header glass. `forceOpaque` là override kỹ thuật/test, không thêm màn settings. Resolver: `opaque = highContrast || forceOpaque`; `reduceMotion = disableAnimations || accessibleNavigation`.

## Task 1: Chốt mockup và bảng bề mặt

**Files:** Create `docs/ui/liquid-glass-refresh/README.md` và các ảnh review trong cùng thư mục; update spec này sau review.

**Interfaces:** Consumes spec; produces bộ mockup được review, danh sách bề mặt kính/đặc và token đã chốt cho Task 2–5.

- [x] Đọc lại git diff, project-status và graph/coverage những file định sửa. Ghi baseline commit + local changes để phân biệt refresh với T18 đang làm.
- [x] Tạo mockup catalog Grid, dropdown mở, sheet snapshot/live + map, viewer dọc/ngang và map fullscreen, với light/dark. Dùng ảnh local từ `docs/ui/stitch/assets/`, label dữ liệu mẫu và bố cục có thật trong app hiện tại.
- [x] Ghi token/radius/tint và từng bề mặt kính trong README; có ví dụ fallback nền đặc. Không dùng ảnh toàn card bị blur làm tham chiếu.
- [ ] Review thiết kế cụ thể với người dùng trước khi viết product UI (chưa có biên bản duyệt có thể đối chiếu trong lượt review này). Cập nhật spec để phản ánh lựa chọn thật; nếu đổi navigation, sửa lại plan trước Task 2.
- [ ] Ghi lại kết quả duyệt mockup của người dùng; hiện mới có báo cáo review mã nguồn.

**Deliverable:** Bộ hình cho phép đánh giá được mức kính, readability, layout và phạm vi. Không có test code cho task này.

## Task 2: Theme, policy và controls dùng chung

**Files:** Modify hai file theme hiện có; create `camera_glass_policy.dart` và bốn file `presentation/widgets/glass/` trong file map. Create `camera-tests/camera_glass_controls_test.dart`.

**Interfaces:** Produces đúng API trong file map. Dùng themeData bootstrap hiện có; không thay root app hoặc App* toàn cục.

- [x] Viết test hành vi: input gõ/clear giữ focus; segmented control thông báo giá trị đúng một lần; icon action 48×48 có label/selected/disabled đúng. Policy có test high contrast, forceOpaque và reduced-motion độc lập; reduced-motion không vô hiệu hóa input.
- [x] Chạy `flutter test test/features/cameras/camera_glass_controls_test.dart` trong `mobile/`; xác nhận fail do API mới chưa có.
- [x] Đọc API package đã resolve trong local pub cache qua cấu hình package hiện hành. Implement resolver và component bằng composition; sử dụng semantics/focus theo convention App*. Không đoán tên component package, không tải dependency mới.
- [x] Surface chỉ xử lý backdrop, không filter child/media. Tách settings light/dark theo role; tokens chứa mọi số đo mới. Embedded control không tạo lớp glass thứ hai; fallback đặc vẫn giữ outline và trạng thái chọn.
- [x] Chạy test trên tới PASS và `flutter analyze`; ghi kết quả. Commit chỉ file của task nếu được yêu cầu.

**Deliverable:** Controls hoạt động được trong light/dark/opaque/reduced-motion với cùng hợp đồng tương tác.

## Task 3: Catalog, filters, tiles và Quan tâm inline

**Files:** Modify `presentation/screens/camera_screen.dart`; `presentation/widgets/{camera_filters,camera_tile,camera_favorites_section,district_sections,weather_card}.dart`; create `presentation/widgets/camera_district_picker.dart`. Extend `camera-tests/{camera_screen,camera_favorites,camera_a11y_layout}_test.dart`; create `camera-tests/camera_filters_test.dart`. Translation keys mới ở `mobile/assets/translations/{vi,en}.json` nếu cần.

**Interfaces:** Consumes Task 2. Giữ constructor/callback CameraFilters và CameraTile đang có; picker trả tên quận hoặc null, không phát request trực tiếp.

- [x] Viết regression test tìm kiếm/clear, chọn quận và Card/Grid/List; star cập nhật favorites và giữ selected mode. Kiểm thử viewport 320/390/600, text scale 1/2, tên quận dài; popover khi bàn phím mở phải chọn được và Back trả focus đúng.
- [x] Chạy `flutter test test/features/cameras/camera_filters_test.dart test/features/cameras/camera_screen_test.dart test/features/cameras/camera_favorites_test.dart test/features/cameras/camera_a11y_layout_test.dart`; ghi các case mới fail trước sửa.
- [x] Thay input/dropdown/mode controls bằng Task 2 và picker. Khi không đủ rộng, xuống hàng theo LayoutBuilder; không ép hàng có độ cao cố định ở text scale lớn.
- [x] Cho feed thực cuộn phía sau vùng header kính, với safe-area/padding bù chiều cao để item đầu không bị che. Search/picker/mode đã tự có surface thì không bọc thêm header glass; vùng tiêu đề có surface riêng. Giữ scroll controller và callbacks hiện có.
- [x] Bỏ glass wrapper cả CameraTile Card; thống nhất nền đặc/typography cho Card/Grid/List, kính ở star overlay Card/Grid. Chuẩn hóa header Quan tâm/weather/district bằng tokens; không đổi fetching, persistence hoặc số lượng ảnh preload.
- [x] Chạy lại nhóm test trên và `flutter analyze`; kiểm tra lỗi ảnh còn là placeholder/error, không thêm nhãn offline. Commit giới hạn file của task nếu được yêu cầu.

**Deliverable:** Catalog có glass rõ ở controls, ảnh rõ và các mode/favorites tiếp tục dùng được ở màn hẹp/chữ lớn.

## Task 4: Sheet, media viewer và lưới nhiều camera

**Files:** Modify `presentation/widgets/{camera_snapshot_sheet,camera_image_viewer,traffic_brief_card}.dart`; `presentation/screens/{camera_viewer_screen,multi_camera_screen}.dart`. Extend `camera-tests/{camera_snapshot_sheet,camera_image_viewer,camera_viewer,camera_live,multi_camera_grid,camera_flow_integration}_test.dart`.

**Interfaces:** Consumes Task 2; giữ preview/favorites/repository hiện có và ownership/dispose của chúng. Không tạo preview cubit hoặc player bổ sung để phục vụ glass.

- [x] Viết test sheet → image overlay → Back về sheet → Back về catalog giữ context; đóng X và toggle star vẫn đúng. Thêm case đổi theme/highContrast khi sheet mở không mất frame hoặc tăng snapshot requests trong fake repository; không dùng pumpAndSettle vô hạn với polling.
- [x] Chạy nhóm test này và xác nhận case mới cần thay đổi fail trước sửa. Với case hồi quy đã PASS, giữ làm baseline, không sửa để ép fail.
- [x] Tách header glass khỏi body sheet: close/star dùng embedded, media và metadata nằm ngoài glass. Giữ live/map/directions/brief hiện có, lỗi live và stale/retry rõ trên nền đặc. Sheet dài cuộn được, không cố áp chiều cao A1 cũ khi có bản đồ.
- [x] Dùng surface/header/actions chung cho CameraViewerScreen và CameraImageViewer; không thay zoom 1–5×, gesture, orientation hoặc điều hướng. Chuẩn hóa header của MultiCameraScreen và actions của TrafficBriefCard; giữ nội dung hai phần này trên nền đặc.
- [x] Chạy `flutter test test/features/cameras/camera_snapshot_sheet_test.dart test/features/cameras/camera_image_viewer_test.dart test/features/cameras/camera_viewer_test.dart test/features/cameras/camera_live_test.dart test/features/cameras/multi_camera_grid_test.dart test/features/cameras/camera_flow_integration_test.dart` và `flutter analyze`; ghi kết quả. Commit giới hạn file của task nếu được yêu cầu.

**Deliverable:** Các lối xem media nhất quán, không mất nội dung hoặc nhân request khi thay style.

## Task 5: Controls bản đồ và composition với platform view

**Files:** Modify `presentation/widgets/camera_traffic_map_card.dart`, `presentation/screens/camera_traffic_map_viewer_screen.dart`; extend `camera-tests/{camera_traffic_map,camera_directions,camera_snapshot_sheet,camera_viewer}_test.dart`.

**Interfaces:** Consumes Task 2; giữ `CameraTrafficMapConfig`, mapBuilder, controller callbacks, traffic preference và directions helper hiện có. Dùng `forceOpaque` cho controls/header bản đồ trong lần refresh đầu; chỉ bật glass lấy mẫu map sau khi có bằng chứng device cho nền tảng tương ứng.

- [x] Viết test tất cả nút toggle/recenter/fullscreen/directions có vùng bấm ≥48×48 và semantics đúng, action gọi callback hiện có; thiếu tọa độ ẩn map. Test fallback opaque và chữ lớn vẫn chọn/bấm được mà không chặn vùng map bên ngoài controls.
- [x] Chạy `flutter test test/features/cameras/camera_traffic_map_test.dart test/features/cameras/camera_directions_test.dart`; ghi case mới fail trước sửa.
- [x] Bỏ wrapper glass quanh cả map card; canvas nằm riêng, header/controls ở lớp sibling overlay hoặc cạnh canvas. Dùng controls chung thay helper 36×36. Bố trí safe-area và tránh đè attribution hoặc vùng tương tác thiết yếu của map.
- [ ] Kiểm tra thật Android/iOS: pan/zoom map, toggle traffic, recenter, fullscreen và Back; opaque fallback không nhấp nháy hay tạo mảng đen. Widget mapBuilder chỉ kiểm tra dispatch/config, không chứng nhận native rendering (Chưa chạy trên thiết bị vật lý; automated widget test đã xác nhận dispatch và callback).
- [x] Chạy lại nhóm test trên cùng snapshot_sheet/viewer tests và `flutter analyze`; ghi kết quả. Commit giới hạn file của task nếu được yêu cầu.

**Deliverable:** Controls map thống nhất, dễ bấm; composition không phụ thuộc việc shader lấy mẫu được platform view.

## Task 6: Nghiệm thu và cập nhật tài liệu

**Files:** Create `docs/ui/liquid-glass-refresh-verification.md`; update `mobile/DESIGN.md`, `docs/README.md`, `docs/project-status.md` sau khi có bằng chứng thực.

**Interfaces:** Consumes Task 1–5; produces bảng AC1–AC8 với link evidence, lệnh test và mục còn thiếu nếu có.

- [x] Chạy `flutter analyze` và `flutter test` trong `mobile/`; không lấy số lượng test lịch sử làm kỳ vọng cứng (174/174 PASS, 0 analyze issues).
- [x] Chuẩn bị PostgreSQL/PostGIS theo `backend/README.md`; chạy lần lượt `npm run test:unit`, `npm run test:api`, `npm run test:db` trong `backend/` theo AGENTS.md (86/86 PASS).
- [ ] Chụp light/dark trước/sau từ app trên cùng fixture, ghi device/OS/build cho đủ màn. 12 PNG hiện có là mockup HTML; chưa đạt bước này. Ma trận widget filters 320/390/600 × scale 1/2 và case focus/bàn phím đã PASS sau review.
- [ ] Trên Android và iOS thật hoặc simulator phù hợp, kiểm tra shader, xoay, live texture/map controls, TalkBack/VoiceOver. Đánh dấu rõ test simulator so với thiết bị thật và nền tảng chưa chạy (Chưa chạy TalkBack/VoiceOver trên thiết bị thật; automated semantics tests đã PASS).
- [ ] Profile trong build profile: cuộn catalog, mở sheet/viewer/map và đóng 20 lần; ghi p95 UI/raster frame times riêng, mục tiêu mỗi loại ≤16.7 ms ở 60 Hz; ghi đồ thị/bảng memory sau warm-up. Nếu quá budget, giảm phạm vi glass/quality trong theme và kiểm tra lại phần bị ảnh hưởng (Chưa thực hiện profile run trên thiết bị; chưa có số liệu p95 frame time và memory).
- [x] Viết báo cáo theo AC1–AC8: PASS/FAIL/NOT RUN, evidence và giới hạn. Cập nhật DESIGN.md, README và project-status bằng trạng thái thực, giữ lịch sử A1.
- [x] Kiểm tra diff cuối: không lẫn edits T18/native/backend ngoài phạm vi; không tự publish, merge hoặc triển khai. Bàn giao bản review và commit tài liệu/refresh riêng nếu được yêu cầu.

**Done:** Phần mã nguồn được review và kiểm thử tự động PASS; nghiệm thu toàn bộ plan vẫn chưa xong. Không coi mockup HTML là screenshot app, hoặc widget test là kiểm chứng shader/native Maps/screen reader/profile. Các bước chưa có bằng chứng giữ checkbox trống.

## Thứ tự và điểm dừng

Task 1 → 2 → 3 → 4 → 5 → 6. Triển khai và kiểm thử tự động đã PASS sau review; các bước duyệt mockup, ảnh trước/sau và nghiệm thu thiết bị/profile còn mở. PR Draft dựa trên nhánh T18 tiền đề; không merge trước khi giải quyết dependency và các bước nghiệm thu còn thiếu.
