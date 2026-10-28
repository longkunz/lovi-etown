import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'camera_glass_surface.dart';

/// An accessible search field wrapped in a Liquid Glass capsule surface or opaque fallback.
class CameraGlassSearchField extends StatefulWidget {
  const CameraGlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.focusNode,
    this.validationMessage,
    this.forceOpaque = false,
    this.embedded = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final FocusNode? focusNode;
  final String? validationMessage;
  final bool forceOpaque;
  final bool embedded;

  @override
  State<CameraGlassSearchField> createState() => _CameraGlassSearchFieldState();
}

class _CameraGlassSearchFieldState extends State<CameraGlassSearchField> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleClear() {
    widget.controller.clear();
    widget.onClear();
    _effectiveFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;
    final hintColor = isLight
        ? CameraUiTokens.mutedForegroundLight
        : CameraUiTokens.mutedForegroundDark;

    final inputField = ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Icon(
                Icons.search,
                size: 20,
                color: isLight
                    ? CameraUiTokens.primaryTeal
                    : CameraUiTokens.accentTeal,
              ),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _effectiveFocusNode,
                onChanged: widget.onChanged,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: hintColor,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            if (hasText)
              Semantics(
                button: true,
                label: 'camera.clear_search'.tr(),
                child: IconButton(
                  tooltip: 'camera.clear_search'.tr(),
                  icon: const Icon(Icons.clear, size: 18),
                  color: hintColor,
                  constraints: const BoxConstraints(
                    minWidth: CameraUiTokens.minTouchTarget,
                    minHeight: CameraUiTokens.minTouchTarget,
                  ),
                  onPressed: _handleClear,
                ),
              )
            else
              const SizedBox(width: 8),
          ],
        );
      },
    );

    final Widget containerWidget;
    if (widget.embedded) {
      containerWidget = Container(
        constraints:
            const BoxConstraints(minHeight: CameraUiTokens.minTouchTarget),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CameraUiTokens.radius24),
          border: Border.all(
            color: isLight
                ? CameraUiTokens.glassBorderLight
                : CameraUiTokens.glassBorderDark,
            width: 1,
          ),
        ),
        child: inputField,
      );
    } else {
      containerWidget = CameraGlassSurface(
        role: CameraGlassRole.control,
        forceOpaque: widget.forceOpaque,
        borderRadius: BorderRadius.circular(CameraUiTokens.radius24),
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: CameraUiTokens.minTouchTarget),
          child: inputField,
        ),
      );
    }

    if (widget.validationMessage != null &&
        widget.validationMessage!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          containerWidget,
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 4),
            child: Text(
              widget.validationMessage!,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    return containerWidget;
  }
}
