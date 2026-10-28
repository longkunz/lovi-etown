import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_starter/src/shared/widgets/ui/app/feedback/app_error_widget.dart';
import 'package:flutter_starter/src/theme/theme.dart';

void main() {
  testWidgets('retry button defaults to Try Again and fires onRetry',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      // AppButton reads AppColorsExtension from the theme, so a bare
      // default ThemeData is not enough — use the product light theme.
      theme: buildLightTheme(primaryColorHex: '#00796B'),
      home: Scaffold(
        body: AppErrorWidget(
          title: 'Something went wrong',
          onRetry: () => retries++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    expect(retries, 1);
  });

  testWidgets('retryLabel overrides the default English label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(primaryColorHex: '#00796B'),
      home: Scaffold(
        body: AppErrorWidget(
          title: 'Không thể tải danh sách camera',
          retryLabel: 'Thử lại',
          onRetry: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
    expect(find.text('Không thể tải danh sách camera'), findsOneWidget);
  });
}
