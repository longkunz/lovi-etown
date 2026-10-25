import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/theme/camera_glass_policy.dart';
import 'package:flutter_starter/src/theme/camera_ui_tokens.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_surface.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_icon_button.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_search_field.dart';
import 'package:flutter_starter/src/features/cameras/presentation/widgets/glass/camera_glass_segmented_control.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

void main() {
  group('CameraGlassPolicy', () {
    test('default mediaQuery produces opaque=false and reduceMotion=false', () {
      const mq = MediaQueryData();
      final policy = CameraGlassPolicy.resolve(mq);
      expect(policy.opaque, isFalse);
      expect(policy.reduceMotion, isFalse);
    });

    test('highContrast produces opaque=true independently of motion', () {
      const mq = MediaQueryData(highContrast: true);
      final policy = CameraGlassPolicy.resolve(mq);
      expect(policy.opaque, isTrue);
      expect(policy.reduceMotion, isFalse);
    });

    test('forceOpaque produces opaque=true independently of mediaQuery', () {
      const mq = MediaQueryData();
      final policy = CameraGlassPolicy.resolve(mq, forceOpaque: true);
      expect(policy.opaque, isTrue);
      expect(policy.reduceMotion, isFalse);
    });

    test('disableAnimations produces reduceMotion=true independently of opaque',
        () {
      const mq = MediaQueryData(disableAnimations: true);
      final policy = CameraGlassPolicy.resolve(mq);
      expect(policy.opaque, isFalse);
      expect(policy.reduceMotion, isTrue);
    });

    test('accessibleNavigation produces reduceMotion=true', () {
      const mq = MediaQueryData(accessibleNavigation: true);
      final policy = CameraGlassPolicy.resolve(mq);
      expect(policy.opaque, isFalse);
      expect(policy.reduceMotion, isTrue);
    });
  });

  group('CameraGlassSurface', () {
    testWidgets('renders child inside AdaptiveGlass by default',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CameraGlassSurface(
              child: Text('Surface Child'),
            ),
          ),
        ),
      );

      expect(find.text('Surface Child'), findsOneWidget);
      expect(find.byType(AdaptiveGlass), findsOneWidget);
    });

    testWidgets('dark media header keeps a dark opaque surface in light theme',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
            body: CameraGlassSurface(
          brightness: Brightness.dark,
          forceOpaque: true,
          child:
              Text('White media title', style: TextStyle(color: Colors.white)),
        )),
      ));
      final surface = find
          .descendant(
              of: find.byType(CameraGlassSurface),
              matching: find.byType(Container))
          .first;
      expect(
          (tester.widget<Container>(surface).decoration! as BoxDecoration)
              .color,
          CameraUiTokens.opaqueSurfaceDark);
    });

    testWidgets('does not use AdaptiveGlass when forceOpaque=true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CameraGlassSurface(
              forceOpaque: true,
              child: Text('Opaque Surface'),
            ),
          ),
        ),
      );

      expect(find.text('Opaque Surface'), findsOneWidget);
      expect(find.byType(AdaptiveGlass), findsNothing);
    });

    testWidgets('does not use AdaptiveGlass under highContrast media query',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(highContrast: true),
          child: MaterialApp(
            home: Scaffold(
              body: CameraGlassSurface(
                child: Text('High Contrast Surface'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('High Contrast Surface'), findsOneWidget);
      expect(find.byType(AdaptiveGlass), findsNothing);
    });
  });

  group('CameraGlassIconButton', () {
    testWidgets('has at least 48x48 tap target and correct semantics',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGlassIconButton(
              icon: Icons.star,
              label: 'Thêm Quan tâm',
              onPressed: () => tapped = true,
              selected: true,
            ),
          ),
        ),
      );

      final finder = find.byType(CameraGlassIconButton);
      expect(finder, findsOneWidget);
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));

      final semantics = tester.getSemantics(finder);
      expect(semantics.label, contains('Thêm Quan tâm'));

      await tester.tap(finder);
      expect(tapped, isTrue);
    });

    testWidgets(
        'disabled button does not trigger callback and has reduced opacity',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CameraGlassIconButton(
              icon: Icons.star,
              label: 'Thêm Quan tâm',
              onPressed: null,
            ),
          ),
        ),
      );

      final finder = find.byType(CameraGlassIconButton);
      await tester.tap(finder);
      // No exceptions, onPressed is null
    });

    testWidgets('embedded=true avoids nested AdaptiveGlass', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGlassIconButton(
              icon: Icons.close,
              label: 'Đóng',
              embedded: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(AdaptiveGlass), findsNothing);
    });
  });

  group('CameraGlassSearchField', () {
    testWidgets(
        'typing updates text and tapping clear clears text while keeping focus',
        (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      String changedValue = '';
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGlassSearchField(
              controller: controller,
              focusNode: focusNode,
              hintText: 'Tìm camera...',
              onChanged: (val) => changedValue = val,
              onClear: () {
                cleared = true;
                controller.clear();
              },
            ),
          ),
        ),
      );

      expect(find.text('Tìm camera...'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'Nguyễn Bỉnh Khiêm');
      await tester.pump();

      expect(changedValue, 'Nguyễn Bỉnh Khiêm');
      expect(find.byIcon(Icons.clear), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(cleared, isTrue);
      expect(controller.text, isEmpty);
      expect(focusNode.hasFocus, isTrue);
    });
  });

  group('CameraGlassSegmentedControl', () {
    testWidgets('renders segments, marks selected, and notifies single change',
        (tester) async {
      String selected = 'grid';
      final receivedValues = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGlassSegmentedControl<String>(
              value: selected,
              segments: const [
                ButtonSegment(value: 'card', label: Text('Card')),
                ButtonSegment(value: 'grid', label: Text('Grid')),
                ButtonSegment(value: 'list', label: Text('List')),
              ],
              onChanged: (val) {
                receivedValues.add(val);
                selected = val;
              },
            ),
          ),
        ),
      );

      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);

      await tester.tap(find.text('List'));
      await tester.pump();

      expect(receivedValues, ['list']);
    });

    testWidgets(
        'segments honor size, disabled state, labels and reduced motion',
        (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
            body: CameraGlassSegmentedControl<String>(
          value: 'card',
          segments: const [
            ButtonSegment(
                value: 'card',
                icon: Icon(Icons.view_agenda),
                tooltip: 'Card view'),
            ButtonSegment(
                value: 'grid',
                icon: Icon(Icons.grid_view),
                tooltip: 'Grid view'),
            ButtonSegment(
                value: 'list',
                icon: Icon(Icons.view_list),
                tooltip: 'List view',
                enabled: false),
          ],
          onChanged: changes.add,
        )),
      ));
      for (final icon in [
        Icons.view_agenda,
        Icons.grid_view,
        Icons.view_list
      ]) {
        final target = find
            .ancestor(of: find.byIcon(icon), matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Card view'))
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('List view'))
              .flagsCollection
              .isEnabled,
          Tristate.isFalse);
      await tester.tap(find.byIcon(Icons.view_list));
      expect(changes, isEmpty);
      await tester.tap(find.byIcon(Icons.grid_view));
      await tester.pump();
      expect(changes, ['grid']);
      for (final animation in tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))) {
        expect(animation.duration, Duration.zero);
      }
    });

    testWidgets('embedded=true avoids creating own AdaptiveGlass',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CameraGlassSegmentedControl<String>(
              value: 'card',
              embedded: true,
              segments: const [
                ButtonSegment(value: 'card', label: Text('Card')),
                ButtonSegment(value: 'grid', label: Text('Grid')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(AdaptiveGlass), findsNothing);
    });
  });
}
