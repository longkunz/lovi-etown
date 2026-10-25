import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_district_picker.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_search_field.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_segmented_control.dart';
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

  List<ButtonSegment<CameraViewMode>> _buildSegments({bool compact = false}) {
    return [
      ButtonSegment<CameraViewMode>(
        value: CameraViewMode.card,
        icon: const Icon(Icons.view_agenda_outlined, size: 18),
        label: compact ? null : const Text('Card'),
        tooltip: 'camera.view_card'.tr(),
      ),
      ButtonSegment<CameraViewMode>(
        value: CameraViewMode.grid,
        icon: const Icon(Icons.grid_view_outlined, size: 18),
        label: compact ? null : const Text('Grid'),
        tooltip: 'camera.view_grid'.tr(),
      ),
      ButtonSegment<CameraViewMode>(
        value: CameraViewMode.list,
        icon: const Icon(Icons.view_list_outlined, size: 18),
        label: compact ? null : const Text('List'),
        tooltip: 'camera.view_list'.tr(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CameraUiTokens.spacing16,
        vertical: CameraUiTokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CameraGlassSearchField(
            controller: _controller,
            hintText: 'camera.search_hint'.tr(),
            onChanged: widget.onQueryChanged,
            onClear: () {
              widget.onQueryChanged('');
            },
            validationMessage: widget.validationMessage,
          ),
          const SizedBox(height: CameraUiTokens.spacing8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth <
                      CameraUiTokens.compactFilterBreakpoint ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CameraDistrictPicker(
                      districts: widget.districts,
                      selectedDistrict: widget.selectedDistrict,
                      onChanged: widget.onDistrictChanged,
                    ),
                    const SizedBox(height: CameraUiTokens.spacing8),
                    Center(
                      child: CameraGlassSegmentedControl<CameraViewMode>(
                        segments: _buildSegments(compact: true),
                        value: widget.viewMode,
                        onChanged: widget.onViewModeChanged,
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: CameraDistrictPicker(
                      districts: widget.districts,
                      selectedDistrict: widget.selectedDistrict,
                      onChanged: widget.onDistrictChanged,
                    ),
                  ),
                  const SizedBox(width: CameraUiTokens.spacing8),
                  CameraGlassSegmentedControl<CameraViewMode>(
                    segments:
                        _buildSegments(compact: constraints.maxWidth < 420),
                    value: widget.viewMode,
                    onChanged: widget.onViewModeChanged,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
