import 'package:flutter/material.dart';
import 'package:flutter_starter/src/theme/camera_glass_policy.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A surface component providing single-layer Liquid Glass or solid opaque fallback.
class CameraGlassSurface extends StatelessWidget {
  const CameraGlassSurface({
    super.key,
    required this.child,
    this.role = CameraGlassRole.control,
    this.borderRadius,
    this.forceOpaque = false,
    this.brightness,
    this.opaqueColor,
    this.borderColor,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final CameraGlassRole role;
  final BorderRadius? borderRadius;
  final bool forceOpaque;
  final Brightness? brightness;
  final Color? opaqueColor;
  final Color? borderColor;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context) ?? const MediaQueryData();
    final policy =
        CameraGlassPolicy.resolve(mediaQuery, forceOpaque: forceOpaque);
    final brightness = this.brightness ?? Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(CameraUiTokens.radius12);

    if (policy.opaque) {
      final solidBg = opaqueColor ??
          (isLight
              ? CameraUiTokens.opaqueSurfaceLight
              : CameraUiTokens.opaqueSurfaceDark);
      final solidBorder = borderColor ??
          (isLight
              ? CameraUiTokens.glassBorderOpaqueLight
              : CameraUiTokens.glassBorderOpaqueDark);

      return Container(
        decoration: BoxDecoration(
          color: solidBg,
          borderRadius: effectiveRadius,
          border: Border.all(color: solidBorder, width: 1),
        ),
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    final topRadius = effectiveRadius.topLeft.x;
    final bottomRadius = effectiveRadius.bottomLeft.x;
    final side = BorderSide(
      color: borderColor ??
          (isLight
              ? CameraUiTokens.glassBorderLight
              : CameraUiTokens.glassBorderDark),
      width: 1,
    );

    final LiquidShape shape = (topRadius == bottomRadius)
        ? LiquidRoundedSuperellipse(borderRadius: topRadius, side: side)
        : LiquidVerticalRoundedSuperellipse(
            topRadius: topRadius,
            bottomRadius: bottomRadius,
            side: side,
          );

    final settings = CameraGlassTheme.settingsFor(role, brightness);

    return AdaptiveGlass(
      shape: shape,
      settings: settings,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
