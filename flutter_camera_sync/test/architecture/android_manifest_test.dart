// `CONFIG` tier — source guards for Android permission minimisation.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String manifest;

  setUpAll(() {
    manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
  });

  test(
    'retains only app-required runtime permissions after manifest merging',
    () {
      expect(manifest, contains('android.permission.CAMERA'));
      expect(manifest, contains('android.permission.INTERNET'));
      expect(manifest, contains('android.permission.ACCESS_NETWORK_STATE'));

      for (final String permission in <String>[
        'android.permission.RECORD_AUDIO',
        'android.permission.READ_EXTERNAL_STORAGE',
        'android.permission.WRITE_EXTERNAL_STORAGE',
        'android.permission.POST_NOTIFICATIONS',
      ]) {
        final RegExp removal = RegExp(
          '<uses-permission\\s+android:name="$permission"\\s+'
          'tools:node="remove"\\s*/>',
          multiLine: true,
        );
        expect(
          manifest,
          matches(removal),
          reason: '$permission must stay removed from plugin manifests',
        );
      }

      expect(
        manifest,
        isNot(contains('android.permission.MANAGE_EXTERNAL_STORAGE')),
      );
    },
  );

  test('camera hardware remains optional for graceful degradation', () {
    expect(
      manifest,
      matches(
        RegExp(
          '<uses-feature\\s+android:name="android.hardware.camera.any"\\s+'
          'android:required="false"\\s*/>',
          multiLine: true,
        ),
      ),
    );
  });
}
