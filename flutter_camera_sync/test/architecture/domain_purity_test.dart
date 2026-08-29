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
