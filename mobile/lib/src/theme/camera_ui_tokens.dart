import 'package:flutter/widgets.dart';

/// Design tokens for Camera Mobile A1 UI.
/// Avoids magic numbers in widgets; ensures accessible touch targets and consistent theme.
abstract final class CameraUiTokens {
  CameraUiTokens._();

  // ── Touch Target ──────────────────────────────────────────────────────────
  /// Apple HIG & Material accessibility minimum interactive target (48x48)
  static const double minTouchTarget = 48;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double spacing2 = 2;
  static const double spacing4 = 4;
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  // ── Corner Radii ──────────────────────────────────────────────────────────
  static const double radius8 = 8;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius24 = 24;
  static const double radiusFull = 999;

  // ── Glass Surface Properties ──────────────────────────────────────────────
  static const double glassBlur = 12;
  static const double glassControlBlur = 10;
  static const double glassSheetBlur = 18;
  static const double glassOpacityLight = 0.72;
  static const double glassOpacityDark = 0.65;
  static const double glassThicknessHeader = 14;
  static const double glassThicknessControl = 8;
  static const double glassThicknessSheet = 16;

  // ── Border & Opaque Colors ────────────────────────────────────────────────
  static const Color glassBorderLight = Color(0x8CFFFFFF);
  static const Color glassBorderDark = Color(0x38A2DCE8);
  static const Color glassBorderOpaqueLight = Color(0xFFBAC9D2);
  static const Color glassBorderOpaqueDark = Color(0xFF3D5668);
  static const Color opaqueSurfaceLight = Color(0xFFFFFFFF);
  static const Color opaqueSurfaceDark = Color(0xFF1E2F3D);
  static const Color controlForegroundLight = Color(0xFF182D3B);
  static const Color controlForegroundDark = Color(0xFFE9F3F8);
  static const Color mutedForegroundLight = Color(0xFF61737D);
  static const Color mutedForegroundDark = Color(0xFFA8BAC5);
  static const Duration controlTransition = Duration(milliseconds: 200);
  static const double segmentInset = 3;
  static const double compactFilterBreakpoint = 420;
  static const double favoriteCardBaseHeight = 96;
  static const double favoriteCardTextHeight = 64;

  // ── Brand & Accent Colors (Teal theme based on Stitch prototype) ───────────
  static const Color primaryTeal = Color(0xFF00796B);
  static const Color primaryTealLight = Color(0xFF48A999);
  static const Color primaryTealDark = Color(0xFF004C40);
  static const Color accentTeal = Color(0xFF26A69A);

  // Background and Surface Colors
  static const Color backgroundLight = Color(0xFFF4F7F6);
  static const Color backgroundDark = Color(0xFF101817);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1B2625);

  // Status & Metadata Colors
  static const Color starActive = Color(0xFFFFB300);
  static const Color starInactive = Color(0xFF9E9E9E);
  static const Color badgeDemoBg = Color(0xFFFFF3E0);
  static const Color badgeDemoText = Color(0xFFE65100);
  static const Color errorRed = Color(0xFFD32F2F);

  // ── Cache & Constraints ───────────────────────────────────────────────────
  static const int thumbnailMaxConcurrent = 4;
  static const int snapshotMaxSizeBytes = 2 * 1024 * 1024; // 2 MiB
  static const int snapshotCacheMaxEntries = 32;
  static const int snapshotCacheMaxBytes = 8 * 1024 * 1024; // 8 MiB
  static const int searchDebounceMs = 350;
  static const int minSearchQueryLength = 2;
  static const int maxSearchQueryLength = 120;
}
