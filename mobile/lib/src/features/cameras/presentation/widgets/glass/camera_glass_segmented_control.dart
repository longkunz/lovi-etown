import 'package:flutter/material.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:flutter_starter/src/theme/camera_glass_policy.dart';
import 'camera_glass_surface.dart';

/// A segmented control widget styled with Liquid Glass or opaque fallback.
class CameraGlassSegmentedControl<T extends Object> extends StatelessWidget {
  const CameraGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.embedded = false,
    this.forceOpaque = false,
  });

  final List<ButtonSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool embedded;
  final bool forceOpaque;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    final activeBg =
        isLight ? CameraUiTokens.primaryTeal : CameraUiTokens.accentTeal;
    final unselectedFg = isLight
        ? CameraUiTokens.mutedForegroundLight
        : CameraUiTokens.mutedForegroundDark;
    final policy = CameraGlassPolicy.resolve(MediaQuery.of(context));

    final row = Padding(
      padding: const EdgeInsets.all(CameraUiTokens.segmentInset),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: segments.map((seg) {
            final isSelected = seg.value == value;

            Widget labelWidget = seg.label ?? const SizedBox.shrink();
            if (seg.icon != null && seg.label != null) {
              labelWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  seg.icon!,
                  const SizedBox(width: 4),
                  seg.label!,
                ],
              );
            } else if (seg.icon != null) {
              labelWidget = seg.icon!;
            }

            final segmentItem = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: !seg.enabled || isSelected
                    ? null
                    : () => onChanged(seg.value),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: policy.reduceMotion
                      ? Duration.zero
                      : CameraUiTokens.controlTransition,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  constraints: const BoxConstraints(
                    minHeight: CameraUiTokens.minTouchTarget,
                    minWidth: CameraUiTokens.minTouchTarget,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: isSelected ? activeBg : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.white : unselectedFg,
                      ),
                      child: IconTheme(
                        data: IconThemeData(
                          size: 16,
                          color: isSelected ? Colors.white : unselectedFg,
                        ),
                        child: labelWidget,
                      ),
                    ),
                  ),
                ),
              ),
            );

            final accessibleSegment = Semantics(
              button: true,
              enabled: seg.enabled,
              selected: isSelected,
              label: seg.tooltip,
              excludeSemantics: seg.tooltip != null,
              onTap: !seg.enabled || isSelected
                  ? null
                  : () => onChanged(seg.value),
              inMutuallyExclusiveGroup: true,
              child: segmentItem,
            );
            return seg.tooltip == null
                ? accessibleSegment
                : Tooltip(
                    message: seg.tooltip!,
                    excludeFromSemantics: true,
                    child: accessibleSegment,
                  );
          }).toList(),
        ),
      ),
    );

    if (embedded) {
      return Container(
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isLight
                ? CameraUiTokens.glassBorderLight
                : CameraUiTokens.glassBorderDark,
            width: 1,
          ),
        ),
        child: row,
      );
    }

    return CameraGlassSurface(
      role: CameraGlassRole.control,
      forceOpaque: forceOpaque,
      borderRadius: BorderRadius.circular(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: row,
      ),
    );
  }
}
