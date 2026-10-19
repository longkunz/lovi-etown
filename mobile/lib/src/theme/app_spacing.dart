
/// Named spacing constants aligned with an 8-pt grid.
///
/// Usage:
/// ```dart
/// SizedBox(height: AppSpacing.md)        // 16 pt gap
/// Padding(padding: EdgeInsets.all(AppSpacing.lg))
/// ```
abstract final class AppSpacing {
  AppSpacing._();

  static const double _xxs = 2;
  static const double _xs = 4;
  static const double _sm = 8;
  static const double _ms = 12;
  static const double _md = 16;
  static const double _ml = 20;
  static const double _lg = 24;
  static const double _xl = 32;
  static const double _xxl = 48;
  static const double _xxxl = 64;

  /// 2 pt — hairline gap, icon-to-label spacing.
  static double get xxs => _xxs;

  /// 4 pt — tightest spacing, between tightly coupled elements.
  static double get xs => _xs;

  /// 8 pt — small spacing, inside compact components (chip padding, icon gap).
  static double get sm => _sm;

  /// 12 pt — medium-small, inner card padding on dense layouts.
  static double get ms => _ms;

  /// 16 pt — base unit, standard component padding and list item gaps.
  static double get md => _md;

  /// 20 pt — medium-large, comfortable section spacing.
  static double get ml => _ml;

  /// 24 pt — large, between content sections on a page.
  static double get lg => _lg;

  /// 32 pt — extra large, major section breaks or hero padding.
  static double get xl => _xl;

  /// 48 pt — 2× large, top-of-page safe area offsets, empty state padding.
  static double get xxl => _xxl;

  /// 64 pt — maximum, full-bleed header heights.
  static double get xxxl => _xxxl;

  // ── Semantic aliases ──────────────────────────────────────────────────────

  /// Standard horizontal page margin.
  static double get pagePadding => md;

  /// Gap between list/grid items.
  static double get itemGap => sm;

  /// Inner padding for cards.
  static double get cardPadding => md;

  /// Vertical gap between form fields.
  static double get formFieldGap => ms;
}

/// Extension to provide identity scaling when ScreenUtil is disabled.
/// This allows using .h, .w, .sp, .r on numbers without conditional checks.
extension ResponsiveNumberExtension on num {
  double get h => toDouble();
  double get w => toDouble();
  double get sp => toDouble();
  double get r => toDouble();
}
