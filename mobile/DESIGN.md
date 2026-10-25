# Design system — flutter_starter

**Trạng thái triển khai:**
- **Mobile A1 (2026-10-16):** Đã hoàn thành và nghiệm thu đầy đủ (docs/ui/mobile-a1-verification.md).
- **Google Maps & Traffic Layer T18 (2026-10-24):** Có báo cáo triển khai; native/lifecycle cần nghiệm thu riêng (docs/ui/t18-google-maps-traffic-verification.md).
- **Liquid Glass Refresh (2026-10-24):** Đã review mã nguồn và kiểm thử tự động 174/174 Flutter tests PASS, 86/86 Backend tests PASS (docs/ui/liquid-glass-refresh-verification.md). Bộ component kính dùng chung `CameraGlassSurface`, `CameraGlassIconButton`, `CameraGlassSearchField`, `CameraGlassSegmentedControl`, `CameraDistrictPicker` áp dụng xuyên suốt catalog, sheet, viewers, multi-camera grid và map; các mục đo đạc profile frame time/RAM và TalkBack/VoiceOver được bảo lưu cho bước kiểm thử trên thiết bị vật lý.
- Snapshot sheet tối giản loại bỏ nút thừa, tách biệt header glass khỏi body media solid; chạm ảnh mở viewer overlay.
- Minimum touch target: Controls kính dùng tối thiểu 48×48 logical pixels; cần tiếp tục walkthrough toàn app trên thiết bị (`CameraUiTokens.minTouchTarget`).
- Zero glass over media: Toàn bộ ảnh snapshot, live video và canvas Google Maps nằm độc lập, không đi qua shader mờ.

This file documents the design conventions established at generation time. Consult it before changing UI code.

## Product direction — 2026-10-16

Người dùng đã chốt **Liquid Glass**, triển khai bằng [`liquid_glass_widgets`](https://pub.dev/packages/liquid_glass_widgets), và thiết kế trên Stitch trước khi code. Preset Cupertino bên dưới là cấu hình scaffold ban đầu; không thay thế hướng sản phẩm mới này.

- Brief hiện hành: [Stitch brief](../docs/ui/stitch-brief.md); [review toàn bộ tài liệu dự án](../docs/ui/document-review-2026-10-16.md).
- Glass tập trung ở navigation bars, tab bar, search/filter, floating controls và sheets. Nội dung danh sách/metadata giữ nền đặc; ảnh camera giữ tỷ lệ và không blur.
- Dùng chung tokens màu/chữ/spacing/radius, light/dark và fallback giảm hiệu ứng. Tích hợp qua shared UI thay vì cấu hình shader riêng ở từng feature.
- `GlassScaffold`, `GlassAppBar`, `GlassTabBar.bottom`, `GlassSearchBar`, `GlassChip`, `GlassIconButton` là component tham chiếu cho thiết kế. Không lồng controls glass trong một glass surface wrapper khác.
- Package tham chiếu ngày review: 1.13.0, yêu cầu Flutter ≥3.41.0. Chưa cài/pin dependency hoặc kiểm chứng shader/build trên SDK local.
- Mockup Stitch chỉ là tham chiếu thiết kế; cần nghiệm thu glass/motion/contrast/performance trên Flutter Android và iOS khi triển khai.

### Feedback mới từ ba ảnh mẫu — Camera v3

Người dùng yêu cầu dropdown địa điểm thay chip, mode Card/Grid/List với ảnh camera hiển thị ngay trong danh sách và infinite scroll thay nút tải thêm. Grid mặc định 2 cột, mật độ 3 cột khi đủ chỗ; Card ảnh lớn một cột, List gọn có thumbnail. Giữ label khu vực từ catalog thực, không tự nhận backend đã có tên phường trong ảnh mẫu.

Liquid Glass phải thể hiện nền ảnh thực phía sau qua search/dropdown/mode switch/sheet controls: blur có chiều sâu, viền sáng mảnh, màu nền ảnh truyền qua kính; tránh capsule trắng đục chỉ có shadow. Nội dung ảnh và tên vẫn sắc nét. Nút Quan tâm nổi trên ảnh dùng ngôi sao filled/outline như reference; label semantics vẫn là thêm/bỏ Quan tâm. **Feedback mới nhất:** Quan tâm là section/bộ lọc inline trong Camera, chạm camera mở bottom sheet thay page riêng; bỏ hai tab Camera/Quan tâm trong A1. Không thêm thời tiết/tài khoản/bản đồ từ reference.

Snapshot sheet dùng `GlassModalSheet` hoặc composition tương thích package: header/control glass, ảnh sắc nét đầy đủ tỷ lệ, chiều cao theo nội dung, kéo mở rộng và overlay toàn màn hình dùng chung preview. Close X/Back/swipe/scrim giữ list context. Không kéo theo khoảng trắng lớn hoặc nút pencil của reference khi chưa yêu cầu edit. Focus modal và touch targets cần kiểm chứng khi triển khai.

Thumbnail chỉ fetch visible + prefetch hữu hạn; không poll toàn catalog. Loading/lỗi ảnh theo từng camera, không quy lỗi fetch thành offline. Infinite loading có footer spinner, lỗi trang sau giữ items và có Retry, hết dữ liệu có thông báo. Bản v1/v2 text-only là lịch sử thiết kế bị thay thế bởi feedback này.

---

## Theme overview

- **Preset:** `cupertino` (Cupertino-style widgets where applicable)
- **Material 3:** Cupertino preset — still uses shared tokens from `lib/src/theme/`.
- **Dark mode:** Light and dark themes are supported; app can follow system brightness. Use semantic colors — do not branch on brightness in widgets for basic surfaces.
- **Customization:** Global `ThemeData` lives in `lib/src/theme/theme.dart` — avoid one-off `ThemeData` overrides in feature widgets.

- **Seed color:** `#fafafa` (used to derive `ColorScheme` via `ColorScheme.fromSeed` where applicable).

---

## Color system

- Use `context.colors` (`ColorScheme`) for standard Material roles: `primary`, `onPrimary`, `secondary`, `surface`, `onSurface`, `error`, etc.
- Use `context.appColors` for semantic extensions: `success`, `warning`, `info`, and their `on*` / container variants (see `lib/src/theme/color_schemes.dart`).
- Definitions: `lib/src/theme/color_schemes.dart`, applied through `lib/src/theme/theme.dart`.
- **Do not** hardcode hex colors in widgets — use theme roles or `appColors`.

---

## Typography

- Use `context.textTheme` (alias `context.typography`) for all text styles.
- Roles follow Material 3: `display*`, `headline*`, `title*`, `body*`, `label*`.
- No custom fonts uploaded — platform default typography (Roboto / SF Pro) via Material/Cupertino theme.

---

## Spacing, borders, motion

Import tokens via `package:flutter_starter/src/theme/theme_constants.dart`.

| Token class | Purpose |
|-------------|---------|
| `AppSpacing` | Padding, gaps (`xxs` … `xxxl`, plus `pagePadding`, `itemGap`, `cardPadding`) |
| `AppBorders` | Border radii (`xs` … `xl`, `button`, `card`, `input`, `dialog`, …) |
| `AppShadows` | Elevation shadows (`none`, `subtle`, `card`, `elevated`, `modal`) |
| `AppDurations` | Animation durations (`fast`, `normal`, `medium`, `slow`, …) |
| `AppCurves` | Standard curves (`standard`, `emphasized`, `pageEnter`, …) |

**Rules**

- Do not use magic numbers for padding — use `AppSpacing`.
- Do not use inline `BorderRadius.circular(n)` — use `AppBorders`.
- Prefer Material 3 tonal elevation on `Card` / `Surface` — custom shadows only via `AppShadows`.

---

## Liquid Glass Component System (`features/cameras/presentation/widgets/glass/`)

Hệ thống component kính được chuẩn hóa qua `CameraGlassTheme`, `CameraGlassPolicy` và `CameraUiTokens`:

| Component | Vị trí / Mục đích | Đặc tính kỹ thuật |
|---|---|---|
| `CameraGlassSurface` | Khung nền kính dùng cho AppBar, Sheet Header, floating panels | Nhận `CameraGlassRole` (`header`, `sheetHeader`, `control`), tự động fallback sang `Container` khi `forceOpaque` hoặc `highContrast`. |
| `CameraGlassIconButton` | Nút bấm thao tác icon (Back, Close, Star, Recenter, Traffic, MapType) | Đạt chuẩn touch target ≥ 48×48 px (`minTouchTarget`), hỗ trợ `embedded: true` (tránh lồng kính 2 lớp) và `forceOpaque: true`. |
| `CameraGlassSearchField` | Ô tìm kiếm camera nổi | Nền kính bo tròn 24px, tích hợp nút Clear 48×48 px, responsive chống tràn text scale 2.0. |
| `CameraGlassSegmentedControl` | Chuyển đổi Card / Grid / List | Bố cục co giãn với scroll ngang chống tràn layout ở 320dp / text scale 2.0. |
| `CameraDistrictPicker` | Popover bộ lọc quận/huyện | Hiển thị số lượng camera trong label, modal lựa chọn có keyboard inset và trả focus sau Back. |

### Quy tắc bất biến (Invariants):
1. **Single-layer glass rule:** Không bao giờ lồng một widget kính bên trong một container kính khác. Các controls con trong header dùng `embedded: true`.
2. **Zero glass over media:** Snapshot JPEG, video live HLS và Google Maps platform view tuyệt đối không đi qua shader blur hay khúc xạ.
3. **Platform view isolation:** Trên bản đồ Google Maps, mọi floating controls và header sử dụng `forceOpaque: true` để triệt tiêu nguy cơ lỗi shader lấy mẫu texture native.
4. **Accessible touch target:** Tất cả controls tương tác đều có diện tích bấm tối thiểu 48×48 logical pixels.

---

- Use `MediaQuery`, `LayoutBuilder`, `Flexible`, and `Expanded` for responsiveness.
- Fixed pixel sizes are acceptable only for elements that should not scale (e.g. icon touch targets defined by tokens).

---

## Context extensions

Defined in `lib/src/extensions/context_extension.dart`:

| Member | Use |
|--------|-----|
| `context.colors` | `ColorScheme` |
| `context.textTheme` / `context.typography` | Text styles |
| `context.appColors` | Semantic success/warning/info |
| `context.designTokens` | Theme extension tokens |
| `context.isDarkMode` | Brightness check |
| `context.width` / `context.height` | Screen size |
| `context.showAppDialog` | Dialog helper |
| `context.showTypedSnackBar` | Status snackbars |

Prefer these shortcuts over repeating `Theme.of(context)` in widgets.

---

## Component conventions

- Reusable widgets belong in `lib/src/shared/widgets/`.
- Default style parameters to theme values, not hardcoded colors.
- Widget file names match the widget class (`primary_button.dart` → `PrimaryButton`).
- Do not read theme inside `const` constructors.

### Dark mode checklist

- No raw `Colors.white` / `Colors.black` for surfaces — use `colorScheme` roles.
- Verify new screens in both light and dark theme.

---

## Localization

- User-visible strings use `easy_localization` — files in `assets/translations/`.
- Do not hardcode display strings in widgets.
- Add keys to JSON translation files, then run the generate command in **SETUP.md**.
- Use interpolation in JSON — do not concatenate translated strings in Dart.

---

## Do / Don't

**Do**

- `context.colors` / `context.appColors` for color
- `context.textTheme` for typography
- `AppSpacing`, `AppBorders`, `AppShadows`, `AppDurations`, `AppCurves` for layout and motion
- `showAppDialog` and shared widgets for consistent UX

---

## UI component library

Product widgets live under `lib/src/shared/widgets/ui/`.

### Platform style

- Config: `cupertino` (adaptive | material | cupertino)
- Runtime: wrap with `AppPlatformScope`; override per widget via `platform:`
- Helper: `context.isCupertinoUi` / `context.resolveCupertinoUi(platform)`
- Prefer **App\*** widgets over raw `ElevatedButton` / `TextField` / `CupertinoButton`

### App kit (`ui/app/`) — always generated

| Category | Widgets |
|---|---|
| actions | `AppButton`, `AppIconButton`, `AppTextButton`, `AppFab`, `AppSegmentedControl`, `AppToggleGroup`, `AppChip` |
| inputs | `AppTextField`, `AppSearchField`, `AppPasswordField`, `AppTextArea`, `AppOtpField`, `AppCheckbox`, `AppRadio`, `AppSwitch`, `AppSlider`, `AppNumberStepper`, `AppDropdown`, `AppDatePicker`, `AppTimePicker`, `AppRating`, `AppForm` |
| display | `AppCard`, `AppAvatar`, `AppBadge`, `AppListTile`, `AppDivider`, `AppIcon`, `CommonImage`, `AppProgressBar`, `AppCircularProgress`, `AppSkeleton`, `AppTooltip`, `AppExpansionPanel`, `AppTimeline`, `AppDataTable` |
| feedback | `AppLoading`, `AppErrorWidget`, `AppEmptyState`, dialogs/sheets/banner/snack + toast |
| navigation | `AppScaffold`, `AppTopBar`, `AppBottomNavBar`, `AppTabBar`, `AppNavigationDrawer`, `AppPageIndicator` |
| layout | `AppGap`, `AppResponsiveBuilder`, `AppSection` |

Debug gallery: `AppRoutes.uiShowcase` (`/debug/ui-showcase`) in debug builds.

### Design tokens (required)

```dart
AppSpacing.md
AppBorders.card
AppShadows.elevated
AppDurations.normal
AppCurves.standard
context.colors.primary
context.appColors.success
context.textTheme.titleMedium
context.designTokens.paddingMedium
```

**Never** hardcode hex colors or magic spacing numbers in feature UI.

### shadcn kit

Not enabled for this project. Re-generate with shadcn opted in from the UI & Theme step to add `ShadApp` wrappers.

---

**Don't**

- Hardcode hex colors or arbitrary font families in widgets
- Magic padding/radius numbers
- Duplicate theme definitions per screen
- Bypass design tokens for one-off “quick” UI

For agent workflows and architecture boundaries, see **[AGENTS.md](AGENTS.md)**.

