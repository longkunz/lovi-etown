import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';

/// Entries of the district-grouped catalog list (T11, part 1). Grouping
/// covers the cameras loaded so far; order follows first appearance in the
/// catalog, and cameras without a district label fall into a final
/// "Khác" (Other) section. The district label is the provider's display
/// label (D3) — not an official administrative key.
sealed class CatalogListEntry {
  const CatalogListEntry();
}

class DistrictHeaderEntry extends CatalogListEntry {
  final String name;
  final int count;
  const DistrictHeaderEntry(this.name, this.count);
}

class CameraEntry extends CatalogListEntry {
  final Camera camera;
  const CameraEntry(this.camera);
}

const otherDistrictLabel = 'Khác';

List<CatalogListEntry> buildDistrictSections(List<Camera> items) {
  final order = <String>[];
  final byDistrict = <String, List<Camera>>{};
  for (final camera in items) {
    final label = (camera.district != null && camera.district!.trim().isNotEmpty)
        ? camera.district!.trim()
        : otherDistrictLabel;
    if (!byDistrict.containsKey(label)) {
      order.add(label);
      byDistrict[label] = [];
    }
    byDistrict[label]!.add(camera);
  }
  // "Khác" always last, regardless of first appearance.
  order.sort((a, b) {
    if (a == otherDistrictLabel) return 1;
    if (b == otherDistrictLabel) return -1;
    return 0;
  });

  final entries = <CatalogListEntry>[];
  for (final label in order) {
    final group = byDistrict[label]!;
    entries.add(DistrictHeaderEntry(label, group.length));
    entries.addAll(group.map(CameraEntry.new));
  }
  return entries;
}

/// Section header row for a district group in the catalog list.
class DistrictSectionHeader extends StatelessWidget {
  const DistrictSectionHeader({
    required this.name,
    required this.count,
    super.key,
  });

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('district_header_$name'),
      padding: const EdgeInsets.fromLTRB(
        CameraUiTokens.spacing16,
        CameraUiTokens.spacing16,
        CameraUiTokens.spacing16,
        CameraUiTokens.spacing4,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.place_outlined,
            size: 16,
            color: CameraUiTokens.primaryTeal,
          ),
          const SizedBox(width: CameraUiTokens.spacing4),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: CameraUiTokens.primaryTeal,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
