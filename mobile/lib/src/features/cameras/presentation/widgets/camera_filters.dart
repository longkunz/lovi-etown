import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

class CameraFilters extends StatefulWidget {
  const CameraFilters({
    required this.districts,
    required this.selectedDistrict,
    required this.onDistrictChanged,
    required this.query,
    required this.onQueryChanged,
    required this.viewMode,
    required this.onViewModeChanged,
    this.validationMessage,
    super.key,
  });

  final List<DistrictOption> districts;
  final String? selectedDistrict;
  final ValueChanged<String?> onDistrictChanged;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final CameraViewMode viewMode;
  final ValueChanged<CameraViewMode> onViewModeChanged;
  final String? validationMessage;

  @override
  State<CameraFilters> createState() => _CameraFiltersState();
}

class _CameraFiltersState extends State<CameraFilters> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant CameraFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
        vertical: CameraUiTokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search box
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'camera.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search, color: CameraUiTokens.primaryTeal),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _controller.clear();
                        widget.onQueryChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: CameraUiTokens.spacing16,
                vertical: CameraUiTokens.spacing12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
                borderSide: BorderSide(
                  color: widget.validationMessage != null
                      ? CameraUiTokens.errorRed
                      : theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CameraUiTokens.radius12),
                borderSide: BorderSide(
                  color: widget.validationMessage != null
                      ? CameraUiTokens.errorRed
                      : theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
            ),
            onChanged: widget.onQueryChanged,
          ),
          if (widget.validationMessage != null) ...[
            const SizedBox(height: CameraUiTokens.spacing4),
            Text(
              widget.validationMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: CameraUiTokens.errorRed,
              ),
            ),
          ],
          const SizedBox(height: CameraUiTokens.spacing8),

          // District selector & view mode toggle
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: CameraUiTokens.spacing12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(CameraUiTokens.radius8),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: widget.selectedDistrict,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: CameraUiTokens.primaryTeal),
                      hint: Text('camera.all_districts'.tr()),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('camera.all_districts'.tr()),
                        ),
                        ...widget.districts.map(
                          (d) => DropdownMenuItem<String?>(
                            value: d.name,
                            child: Text(
                              '${d.name} (${d.count})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: widget.onDistrictChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CameraUiTokens.spacing12),

              // View mode toggles
              SegmentedButton<CameraViewMode>(
                segments: [
                  ButtonSegment<CameraViewMode>(
                    value: CameraViewMode.card,
                    icon: const Icon(Icons.view_agenda_outlined, size: 20),
                    tooltip: 'camera.view_card'.tr(),
                  ),
                  ButtonSegment<CameraViewMode>(
                    value: CameraViewMode.grid,
                    icon: const Icon(Icons.grid_view_outlined, size: 20),
                    tooltip: 'camera.view_grid'.tr(),
                  ),
                  ButtonSegment<CameraViewMode>(
                    value: CameraViewMode.list,
                    icon: const Icon(Icons.view_list_outlined, size: 20),
                    tooltip: 'camera.view_list'.tr(),
                  ),
                ],
                selected: {widget.viewMode},
                onSelectionChanged: (newSelection) {
                  widget.onViewModeChanged(newSelection.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
