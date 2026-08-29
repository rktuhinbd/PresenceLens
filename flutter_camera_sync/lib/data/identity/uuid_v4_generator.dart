import 'dart:math';

import '../../domain/ports/id_generator.dart';

/// Generates RFC 4122 version 4 identifiers from a cryptographic source.
///
/// These ids are the primary keys, the on-disk file names **and** the upload
/// idempotency keys, so they have to be unique without any coordination between
/// the two isolates that create rows.
///
/// Written here rather than taken as a dependency: the project's rule is that a
/// package needs a concrete need, and 122 random bits with two fixed nibbles is
/// not one. The format is asserted by a test, and [Random] is injectable so a
/// seeded generator produces a fixed sequence for tests that want one
/// (`ADR-F15`).
class UuidV4Generator implements IdGenerator {
  /// Creates a generator, optionally over a supplied [random] source.
  UuidV4Generator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String newId() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );

    // Version 4 in the high nibble of byte 6, and the RFC 4122 variant in the
    // two high bits of byte 8. Without these two lines the output is 128 random
    // bits that merely look like a UUID.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex = bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
