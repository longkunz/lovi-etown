import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'camera_ui_tokens.dart';

/// Semantic role for liquid glass surfaces in the camera feature.
enum CameraGlassRole {
  header,
  control,
  sheetHeader,
}

/// Glass theme configuration for Camera Mobile A1 & Liquid Glass refresh.
/// Provides role-based and brightness-aware Liquid Glass styling for controls, sheets, and chrome.
abstract final class CameraGlassTheme {
  CameraGlassTheme._();

  /// Resolves [LiquidGlassSettings] based on surface [role] and [brightness].
  static LiquidGlassSettings settingsFor(
    CameraGlassRole role,
    Brightness brightness,
  ) {
    final isLight = brightness == Brightness.light;
    switch (role) {
      case CameraGlassRole.header:
        return LiquidGlassSettings(
          blur: CameraUiTokens.glassBlur,
          thickness: isLight ? CameraUiTokens.glassThicknessHeader : 12,
          glassColor: isLight ? const Color(0x1A00796B) : const Color(0x26004D40),
          ambientStrength: isLight ? 0.15 : 0.05,
          saturation: 1.4,
        );
      case CameraGlassRole.control:
        return LiquidGlassSettings(
          blur: CameraUiTokens.glassControlBlur,
          thickness: isLight ? CameraUiTokens.glassThicknessControl : 7,
          glassColor: isLight ? const Color(0x1400796B) : const Color(0x20004D40),
          ambientStrength: isLight ? 0.12 : 0.04,
          saturation: 1.3,
        );
      case CameraGlassRole.sheetHeader:
        return LiquidGlassSettings(
          blur: CameraUiTokens.glassSheetBlur,
          thickness: isLight ? CameraUiTokens.glassThicknessSheet : 14,
          glassColor: isLight ? const Color(0x2000796B) : const Color(0x2D004D40),
          ambientStrength: isLight ? 0.18 : 0.06,
          saturation: 1.4,
        );
    }
  }

  /// Preserved for bootstrap compatibility.
  static GlassThemeData get themeData {
    return GlassThemeData(
      light: GlassThemeVariant.light.copyWith(
        settings: const GlassThemeSettings(
          blur: CameraUiTokens.glassBlur,
          thickness: 14,
          glassColor: Color(0x1A00796B), // subtle teal glass tint
          ambientStrength: 0.15,
        ),
        glowColors: const GlassGlowColors(
          primary: CameraUiTokens.primaryTealLight,
          secondary: CameraUiTokens.accentTeal,
        ),
        borderRadius: CameraUiTokens.radius16,
      ),
      dark: GlassThemeVariant.dark.copyWith(
        settings: const GlassThemeSettings(
          blur: CameraUiTokens.glassBlur,
          thickness: 12,
          glassColor: Color(0x26004D40), // dark teal glass tint
          ambientStrength: 0.05,
        ),
        glowColors: const GlassGlowColors(
          primary: CameraUiTokens.accentTeal,
          secondary: CameraUiTokens.primaryTealDark,
        ),
        borderRadius: CameraUiTokens.radius16,
      ),
    );
  }
}
