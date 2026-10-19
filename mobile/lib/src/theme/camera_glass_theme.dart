import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'camera_ui_tokens.dart';

/// Glass theme configuration for Camera Mobile A1.
/// Provides teal-tinted Liquid Glass styling for controls, sheets, and chrome.
abstract final class CameraGlassTheme {
  CameraGlassTheme._();

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
