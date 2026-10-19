# Design system — flutter_starter

**Trạng thái triển khai:** Đã hoàn thành và nghiệm thu đầy đủ trên Flutter Mobile A1 (docs/ui/mobile-a1-verification.md).
- Liquid Glass widgets (liquid_glass_widgets: 1.13.0) tích hợp hoàn chỉnh với tokens CameraUiTokens.
- Snapshot sheet tối giản loại bỏ nút thừa, chạm ảnh mở viewer overlay.
- Section Quan tâm tích hợp inline trong Camera, lưu bền vững và đồng bộ.

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

## Responsive layout (no ScreenUtil)

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

