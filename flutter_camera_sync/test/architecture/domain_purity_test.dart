// FLT-GEN-002, FLT-GEN-007, FLT-TEST-008.
//
// Layering that is claimed but not enforced drifts within a sprint. This is the
// automated version of the rule, mirroring the Android `DomainLayerPurityTest`:
// the architecture document says `domain` depends on no framework, and this
// fails the build the first time that stops being true.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final Directory domain = Directory('lib/domain');

  /// Packages the domain layer may never import.
  ///
  /// Flutter itself is on the list, not only the plugins: a domain type that
  /// reaches for `Color` or `Offset` has stopped being testable without a
  /// binding, which is the practical cost the rule exists to prevent.
  const List<String> forbiddenPackages = <String>[
    'package:flutter/',
    'package:flutter_bloc/',
    'package:camera/',
    'package:sqflite/',
    'package:sqflite_common_ffi/',
    'package:workmanager/',
    'package:connectivity_plus/',
    'package:path_provider/',
    'package:path/',
  ];

  List<File> domainSources() => domain
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList(growable: false);

  test('the scan actually finds domain sources', () {
    // Without this guard, a moved or renamed directory would make every
    // assertion below vacuously true and the purity rule would silently stop
    // being checked — a passing test that verifies nothing.
    expect(domain.existsSync(), isTrue, reason: 'lib/domain must exist');
    expect(domainSources().length, greaterThanOrEqualTo(10));
  });

  test('no domain file imports Flutter or a plugin package', () {
    final Map<String, List<String>> violations = <String, List<String>>{};

    for (final File file in domainSources()) {
      final List<String> offending = file
          .readAsLinesSync()
          .where((String line) => line.trimLeft().startsWith('import '))
          .where(
            (String line) => forbiddenPackages.any(
              (String forbidden) => line.contains(forbidden),
            ),
          )
          .toList(growable: false);
      if (offending.isNotEmpty) {
        violations[p.relative(file.path)] = offending;
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'domain must not depend on Flutter or any plugin:\n$violations',
    );
  });

  test('no domain file imports the data or presentation layer', () {
    // Dependencies point inward. The concrete direction that matters here is
    // that `data` implements interfaces declared in `domain`, never the
    // reverse.
    final Map<String, List<String>> violations = <String, List<String>>{};

    for (final File file in domainSources()) {
      final List<String> offending = file
          .readAsLinesSync()
          .where((String line) => line.trimLeft().startsWith('import '))
          .where(
            (String line) =>
                line.contains('/data/') ||
                line.contains('/presentation/') ||
                line.contains('../data') ||
                line.contains('../presentation'),
          )
          .toList(growable: false);
      if (offending.isNotEmpty) {
        violations[p.relative(file.path)] = offending;
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'inward dependencies only\n$violations',
    );
  });

  test('the domain layer does not reach for dart:io or dart:ui', () {
    // The reason `CaptureStore` speaks in `String` paths rather than `File`
    // objects. A domain that opens files is a domain that needs a disk to test.
    final Map<String, List<String>> violations = <String, List<String>>{};

    for (final File file in domainSources()) {
      final List<String> offending = file
          .readAsLinesSync()
          .where((String line) => line.trimLeft().startsWith('import '))
          .where(
            (String line) =>
                line.contains('dart:io') || line.contains('dart:ui'),
          )
          .toList(growable: false);
      if (offending.isNotEmpty) {
        violations[p.relative(file.path)] = offending;
      }
    }

    expect(violations, isEmpty, reason: 'domain stays pure Dart\n$violations');
  });

  test('the camera plugin is confined to the camera adapter', () {
    // `ARCHITECTURE.md` §5 says the plugin stops at `data/camera`. The purity
    // test above already keeps it out of `domain`; this keeps it out of
    // `presentation` too, which is the boundary that actually decays — a widget
    // reaching for `CameraController` is the shortest path to a disposed
    // controller being rendered (`FLT-CAM-013`).
    //
    // `data/camera` is the whole allowance, and the preview seam inside it is
    // deliberate and documented (`CAMERA_ENGINE.md` §9).
    const String cameraImport = 'package:camera/';
    final Map<String, List<String>> violations = <String, List<String>>{};

    final List<File> sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList(growable: false);
    expect(sources.length, greaterThanOrEqualTo(20));

    for (final File file in sources) {
      final String relative = p.relative(file.path).replaceAll(r'\', '/');
      if (relative.startsWith('lib/data/camera/')) {
        continue;
      }
      final List<String> offending = file
          .readAsLinesSync()
          .where((String line) => line.trimLeft().startsWith('import '))
          .where((String line) => line.contains(cameraImport))
          .toList(growable: false);
      if (offending.isNotEmpty) {
        violations[relative] = offending;
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'the camera plugin belongs to lib/data/camera only:\n$violations',
    );
  });

  test('the camera adapter really is where the plugin lives', () {
    // The complement of the rule above: a scan that matched nothing because the
    // adapter moved would pass vacuously, which is the same defect the
    // empty-scan guard exists to prevent.
    final Directory adapter = Directory('lib/data/camera');
    expect(adapter.existsSync(), isTrue);

    final bool importsPlugin = adapter
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .any(
          (File f) => f.readAsStringSync().contains("import 'package:camera/"),
        );
    expect(importsPlugin, isTrue);
  });

  test('the ports directory declares interfaces, not implementations', () {
    // A spot-check that the seam is real: if `domain/ports` filled up with
    // concrete classes, the layering would be nominal.
    final Directory ports = Directory(p.join(domain.path, 'ports'));
    expect(ports.existsSync(), isTrue);

    final List<File> portFiles = ports
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList(growable: false);
    expect(portFiles, isNotEmpty);

    for (final File file in portFiles) {
      final String source = file.readAsStringSync();
      expect(
        source.contains('abstract interface class'),
        isTrue,
        reason: '${p.basename(file.path)} should declare a port',
      );
    }
  });
}
