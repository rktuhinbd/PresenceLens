// `WIDGET` tier — the application root.
//
// Deliberately small. `PresenceLensCaptureApp` requires an assembled
// `DataLayer`, which requires `path_provider` and a real SQLite file, and
// neither is available inside `testWidgets` — so the *screens* are exercised in
// `test/presentation/` and what is asserted here is only what can be asserted
// honestly without a device: the theme definition, and the storage-failure
// shell.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/app.dart';
import 'package:presence_lens_capture/presentation/theme/app_theme.dart';

void main() {
  test('both themes are built from the one shared seed', () {
    final ThemeData light = AppTheme.light();
    final ThemeData dark = AppTheme.dark();

    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    // One seed, two brightnesses — not two hand-tuned palettes that drift apart
    // (`FLT-UX-008`). The seed is shared with the native attendance app so the
    // two read as one product family.
    expect(AppTheme.seedColor, const Color(0xFF00A884));
    expect(light.colorScheme.primary, isNot(equals(dark.colorScheme.primary)));
  });

  testWidgets(
    'storage that will not open says so, rather than opening a camera',
    (WidgetTester tester) async {
      await tester.pumpWidget(const StartupFailureApp());
      await tester.pumpAndSettle();

      // The one failure that must not present as a camera which silently loses
      // photographs: if the local store cannot be opened, nothing can be promised
      // about a capture, and the app says that instead of pretending.
      expect(find.text("Storage isn't available"), findsOneWidget);
      expect(
        find.textContaining('cannot guarantee a captured photo would be kept'),
        findsOneWidget,
      );
    },
  );
}
