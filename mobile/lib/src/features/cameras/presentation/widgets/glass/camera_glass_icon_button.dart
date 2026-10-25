import 'package:flutter/material.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';

/// An accessible icon button with a minimum 48x48 tap target and glass surface.
/// When [embedded] is true, avoids creating an inner glass surface inside a parent glass container.
class CameraGlassIconButton extends StatelessWidget {
  const CameraGlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.selected = false,
    this.embedded = false,
    this.forceOpaque = false,
    this.iconColor,
    this.size = CameraUiTokens.minTouchTarget,
    this.iconSize = 22,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool selected;
  final bool embedded;
  final bool forceOpaque;
  final Color? iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;

    final defaultColor = isLight
        ? CameraUiTokens.controlForegroundLight
        : CameraUiTokens.controlForegroundDark;
    final selectedColor = (icon == Icons.star ||
            icon == Icons.star_border ||
            icon == Icons.star_rounded)
        ? CameraUiTokens.starActive
        : (isLight ? CameraUiTokens.primaryTeal : CameraUiTokens.accentTeal);

    final effectiveColor =
        iconColor ?? (selected ? selectedColor : defaultColor);

    final content = Center(
      child: Icon(
        icon,
        size: iconSize,
        color:
            isEnabled ? effectiveColor : effectiveColor.withValues(alpha: 0.38),
      ),
    );

    final buttonCore = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: content,
        ),
      ),
    );

    final Widget buttonWidget;
    if (embedded) {
      buttonWidget = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? (isLight
                  ? CameraUiTokens.primaryTeal.withValues(alpha: 0.12)
                  : CameraUiTokens.accentTeal.withValues(alpha: 0.2))
              : Colors.transparent,
        ),
        child: buttonCore,
      );
    } else {
      buttonWidget = CameraGlassSurface(
        role: CameraGlassRole.control,
        forceOpaque: forceOpaque,
        borderRadius: BorderRadius.circular(size / 2),
        child: buttonCore,
      );
    }

    final effectiveTooltip = tooltip ?? label;
    final buttonWithTooltip = effectiveTooltip.isNotEmpty
        ? Tooltip(message: effectiveTooltip, child: buttonWidget)
        : buttonWidget;

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: selected,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: CameraUiTokens.minTouchTarget,
          minHeight: CameraUiTokens.minTouchTarget,
        ),
        child: buttonWithTooltip,
      ),
    );
  }
}
