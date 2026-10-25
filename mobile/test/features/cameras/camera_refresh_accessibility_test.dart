import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/providers/camera_preview_cubit.dart';
import 'package:flutter_starter/src/features/cameras/presentation/screens/camera_viewer_screen.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_district_picker.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_filters.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_image_viewer.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_snapshot_sheet.dart';

import '../../support/camera_fakes.dart';
import '../../support/camera_localization.dart';

void main() {
  setUpAll(loadCameraTestTranslations);

  for (final language in ['vi', 'en']) {
    final modeLabels = language == 'vi'
        ? ['Thẻ', 'Lưới', 'Danh sách']
        : ['Card', 'Grid', 'List'];
    final clearLabel = language == 'vi' ? 'Xóa tìm kiếm' : 'Clear search';
    final closeLabel = language == 'vi' ? 'Đóng' : 'Close';

    testWidgets('wide filters localize captions and clear action in $language',
        (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(localizedCameraTestApp(
        language: language,
        home: Scaffold(
          body: CameraFilters(
            districts: const [],
            selectedDistrict: null,
            onDistrictChanged: (_) {},
            query: 'Pasteur',
            onQueryChanged: (_) {},
            viewMode: CameraViewMode.card,
            onViewModeChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final label in modeLabels) {
        expect(find.text(label), findsOneWidget);
      }
      final clear = find.widgetWithIcon(IconButton, Icons.clear);
      expect(tester.getSemantics(clear).tooltip, clearLabel);
      expect(find.byTooltip(clearLabel), findsOneWidget);
    });

    for (final surface in ['sheet', 'image viewer', 'fullscreen viewer']) {
      testWidgets('$surface localizes close action in $language',
          (tester) async {
        final repository = FakeIntegrationCameraRepository();
        final preview = CameraPreviewCubit(repository: repository);
        final favorites = InMemoryFavoritesRepository();
        addTearDown(preview.close);
        addTearDown(favorites.dispose);
        final Widget child = switch (surface) {
          'sheet' =>
            CameraSnapshotSheet(preview: preview, favorites: favorites),
          'image viewer' => CameraImageViewer(preview: preview),
          _ => CameraViewerScreen(
              cameraId: 'cam-uuid-0',
              repository: repository,
              favoritesRepository: favorites,
            ),
        };
        await tester.pumpWidget(
            localizedCameraTestApp(language: language, home: child));
        await tester.pumpAndSettle();
        if (surface == 'fullscreen viewer') {
          await tester
              .tap(find.byKey(const ValueKey('viewer_fullscreen_button')));
          await tester.pumpAndSettle();
        }
        expect(find.byTooltip(closeLabel), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(closeLabel)), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final selectedDistrict in <String?>['Quận 1', null, '']) {
    testWidgets('picker exposes selection for district=$selectedDistrict',
        (tester) async {
      await tester.pumpWidget(localizedCameraTestApp(
        home: Scaffold(
          body: CameraDistrictPicker(
            districts: const [
              DistrictOption(name: 'Quận 1', count: 12),
              DistrictOption(name: 'Quận 3', count: 8),
            ],
            selectedDistrict: selectedDistrict,
            onChanged: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CameraDistrictPicker));
      await tester.pumpAndSettle();
      final selectedLabel =
          selectedDistrict == 'Quận 1' ? 'Quận 1 (12)' : 'Tất cả quận/huyện';
      final selected = find.widgetWithText(ListTile, selectedLabel);
      expect(tester.getSemantics(selected).flagsCollection.isSelected,
          Tristate.isTrue);
      final unselected = find.widgetWithText(ListTile, 'Quận 3 (8)');
      expect(tester.getSemantics(unselected).flagsCollection.isSelected,
          Tristate.isFalse);
    });
  }
}
