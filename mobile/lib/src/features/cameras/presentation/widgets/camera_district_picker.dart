import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/theme/camera_glass_theme.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// An accessible district picker button that opens a selection sheet/dialog.
/// Styled with Liquid Glass or opaque fallback.
class CameraDistrictPicker extends StatefulWidget {
  const CameraDistrictPicker({
    super.key,
    required this.districts,
    required this.selectedDistrict,
    required this.onChanged,
    this.embedded = false,
    this.forceOpaque = false,
  });

  final List<DistrictOption> districts;
  final String? selectedDistrict;
  final ValueChanged<String?> onChanged;
  final bool embedded;
  final bool forceOpaque;

  @override
  State<CameraDistrictPicker> createState() => _CameraDistrictPickerState();
}

class _CameraDistrictPickerState extends State<CameraDistrictPicker> {
  final _triggerFocus = FocusNode();

  @override
  void dispose() {
    _triggerFocus.dispose();
    super.dispose();
  }

  String _allDistrictsLabel() {
    final trLabel = 'camera.all_districts'.tr();
    return (trLabel == 'camera.all_districts') ? 'Tất cả' : trLabel;
  }

  String _getDisplayLabel() {
    if (widget.selectedDistrict == null || widget.selectedDistrict!.isEmpty) {
      return _allDistrictsLabel();
    }
    for (final d in widget.districts) {
      if (d.name == widget.selectedDistrict) {
        return '${d.name} (${d.count})';
      }
    }
    return widget.selectedDistrict!;
  }

  Future<void> _showPicker(BuildContext context) async {
    final allLabel = _allDistrictsLabel();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      requestFocus: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final isDark = theme.brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              CameraUiTokens.spacing12,
              CameraUiTokens.spacing8,
              CameraUiTokens.spacing12,
              MediaQuery.viewInsetsOf(sheetContext).bottom +
                  CameraUiTokens.spacing8,
            ),
            child: CameraGlassSurface(
              role: CameraGlassRole.sheetHeader,
              forceOpaque: widget.forceOpaque,
              borderRadius: BorderRadius.circular(CameraUiTokens.radius24),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white30 : Colors.black26),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 20,
                            color: isDark
                                ? CameraUiTokens.accentTeal
                                : CameraUiTokens.primaryTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              allLabel,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'shared.close'.tr(),
                            constraints: const BoxConstraints(
                              minHeight: CameraUiTokens.minTouchTarget,
                              minWidth: CameraUiTokens.minTouchTarget,
                            ),
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          ListTile(
                            minTileHeight: CameraUiTokens.minTouchTarget,
                            selected: widget.selectedDistrict == null ||
                                widget.selectedDistrict!.isEmpty,
                            title: Text(allLabel),
                            trailing: (widget.selectedDistrict == null ||
                                    widget.selectedDistrict!.isEmpty)
                                ? const Icon(Icons.check,
                                    color: CameraUiTokens.primaryTeal, size: 20)
                                : null,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              widget.onChanged(null);
                            },
                          ),
                          ...widget.districts.map((d) {
                            final isSelected =
                                d.name == widget.selectedDistrict;
                            return ListTile(
                              minTileHeight: CameraUiTokens.minTouchTarget,
                              selected: isSelected,
                              title: Text('${d.name} (${d.count})'),
                              trailing: isSelected
                                  ? const Icon(Icons.check,
                                      color: CameraUiTokens.primaryTeal,
                                      size: 20)
                                  : null,
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                widget.onChanged(d.name);
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (mounted) _triggerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;
    final textColor =
        isLight ? CameraUiTokens.primaryTeal : CameraUiTokens.accentTeal;

    final content = InkWell(
      focusNode: _triggerFocus,
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(CameraUiTokens.radius24),
      child: Container(
        height: CameraUiTokens.minTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 18, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _getDisplayLabel(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: textColor),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Container(
        height: CameraUiTokens.minTouchTarget,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CameraUiTokens.radius24),
          border: Border.all(
            color: isLight
                ? CameraUiTokens.glassBorderLight
                : CameraUiTokens.glassBorderDark,
            width: 1,
          ),
        ),
        child: content,
      );
    }

    return CameraGlassSurface(
      role: CameraGlassRole.control,
      forceOpaque: widget.forceOpaque,
      borderRadius: BorderRadius.circular(CameraUiTokens.radius24),
      child: content,
    );
  }
}
