import 'package:flutter/material.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_favorites_section.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/features/cameras/domain/camera_models.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_filters.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/camera_district_picker.dart';

void main() {
  const sampleDistricts = [
    DistrictOption(name: 'Quận 1', count: 12),
    DistrictOption(name: 'Quận 3', count: 8),
    DistrictOption(name: 'TP. Thủ Đức', count: 24),
  ];

  group('CameraDistrictPicker', () {
    testWidgets('shows all districts when selectedDistrict is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraDistrictPicker(
              districts: sampleDistricts,
              selectedDistrict: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Tất cả'), findsOneWidget);
    });

    testWidgets('shows district name when selectedDistrict is set',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraDistrictPicker(
              districts: sampleDistricts,
              selectedDistrict: 'Quận 1',
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Quận 1 (12)'), findsOneWidget);
    });

    testWidgets('tapping opens modal and choosing district triggers onChanged',
        (tester) async {
      String? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraDistrictPicker(
              districts: sampleDistricts,
              selectedDistrict: null,
              onChanged: (val) => chosen = val,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(CameraDistrictPicker));
      await tester.pumpAndSettle();

      expect(find.text('TP. Thủ Đức (24)'), findsOneWidget);
      await tester.tap(find.text('TP. Thủ Đức (24)'));
      await tester.pumpAndSettle();

      expect(chosen, 'TP. Thủ Đức');
    });
  });

  testWidgets('saved favorites remain usable at 320dp with text scale 2',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
          body: SingleChildScrollView(
              child: CameraFavoritesSection(
        favorites: [
          FavoriteCamera(
            id: 'favorite',
            name: 'Giao lộ Nguyễn Thị Minh Khai – Cách Mạng Tháng Tám',
            district: 'Thành phố Thủ Đức',
            addedAt: DateTime(2026),
          )
        ],
        onToggleFavorite: (_) {},
      ))),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('CameraFilters', () {
    testWidgets('search, district, and viewMode controls work seamlessly',
        (tester) async {
      String currentQuery = '';
      String? currentDistrict;
      CameraViewMode currentMode = CameraViewMode.card;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CameraFilters(
                  districts: sampleDistricts,
                  selectedDistrict: currentDistrict,
                  onDistrictChanged: (d) => setState(() => currentDistrict = d),
                  query: currentQuery,
                  onQueryChanged: (q) => setState(() => currentQuery = q),
                  viewMode: currentMode,
                  onViewModeChanged: (m) => setState(() => currentMode = m),
                );
              },
            ),
          ),
        ),
      );

      // Search typing
      await tester.enterText(find.byType(TextField), 'Hai Bà Trưng');
      await tester.pump();
      expect(currentQuery, 'Hai Bà Trưng');

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(currentQuery, '');

      // Change view mode to Grid
      await tester.tap(find.byIcon(Icons.grid_view_outlined));
      await tester.pump();
      expect(currentMode, CameraViewMode.grid);

      // Change view mode to List
      await tester.tap(find.byIcon(Icons.view_list_outlined));
      await tester.pump();
      expect(currentMode, CameraViewMode.list);
    });

    for (final width in [320.0, 390.0, 600.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('filters remain usable at $width with text scale $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
                body: CameraFilters(
              districts: const [
                DistrictOption(
                    name: 'Thành phố Thủ Đức – Khu công nghệ cao', count: 123)
              ],
              selectedDistrict: 'Thành phố Thủ Đức – Khu công nghệ cao',
              onDistrictChanged: (_) {},
              query: 'Hai Bà Trưng',
              onQueryChanged: (_) {},
              viewMode: CameraViewMode.grid,
              onViewModeChanged: (_) {},
            )),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.bySemanticsLabel('camera.view_grid'), findsOneWidget);
          for (final icon in [
            Icons.view_agenda_outlined,
            Icons.grid_view_outlined,
            Icons.view_list_outlined
          ]) {
            final target = find
                .ancestor(of: find.byIcon(icon), matching: find.byType(InkWell))
                .first;
            expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
          }
        });
      }
    }

    testWidgets(
        'picker stays above keyboard and Back returns focus without clearing query',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
          child: child!,
        ),
        home: Scaffold(
            body: CameraFilters(
          districts: sampleDistricts,
          selectedDistrict: null,
          onDistrictChanged: (_) {},
          query: 'Hai Bà Trưng',
          onQueryChanged: (_) {},
          viewMode: CameraViewMode.grid,
          onViewModeChanged: (_) {},
        )),
      ));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.tap(find.byType(CameraDistrictPicker));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.text('TP. Thủ Đức (24)')).dy,
          lessThanOrEqualTo(500));
      expect(tester.takeException(), isNull);
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      final trigger = tester.widget<InkWell>(find
          .descendant(
              of: find.byType(CameraDistrictPicker),
              matching: find.byType(InkWell))
          .first);
      expect(trigger.focusNode!.hasFocus, isTrue);
      expect(find.text('Hai Bà Trưng'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
