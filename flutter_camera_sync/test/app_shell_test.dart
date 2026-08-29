// Smoke test for the placeholder application shell.
//
// This asserts only that the app boots and applies its theme. It is replaced by
// real widget tests (see docs/flutter/TEST_STRATEGY.md) once the production UI
// is unlocked; it exists now so `flutter test` is a live gate rather than an
// empty one during the planning phase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/main.dart';

void main() {
  testWidgets('app boots and shows its identity', (WidgetTester tester) async {
    await tester.pumpWidget(const PresenceLensCaptureApp());

    expect(find.text('PresenceLens Capture'), findsOneWidget);
  });

  testWidgets('app builds a Material 3 scheme from the shared seed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PresenceLensCaptureApp());

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.theme, isNotNull);
    expect(app.darkTheme, isNotNull);
    expect(app.theme!.colorScheme.brightness, Brightness.light);
    expect(app.darkTheme!.colorScheme.brightness, Brightness.dark);
  });
}
