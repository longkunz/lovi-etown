import 'package:flutter_test/flutter_test.dart';

/// Wait for route transitions without waiting for the refresh countdown,
/// which animates throughout the lifetime of an open camera preview.
Future<void> pumpCameraTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}
