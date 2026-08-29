// Identifier generation (ADR-F15).
//
// These ids are primary keys, on-disk file names and upload idempotency keys,
// created independently in two isolates with no coordination between them, so
// the format is worth pinning rather than assuming.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:presence_lens_capture/data/identity/uuid_v4_generator.dart';

void main() {
  final RegExp uuidV4 = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  test('produces a well-formed RFC 4122 version 4 identifier', () {
    // The version nibble and the variant bits are the two things a
    // hand-written generator gets wrong; without them the output is 128 random
    // bits that merely look like a UUID.
    final UuidV4Generator generator = UuidV4Generator();

    for (int i = 0; i < 200; i++) {
      expect(generator.newId(), matches(uuidV4));
    }
  });

  test('is 36 characters with hyphens in the canonical positions', () {
    final String id = UuidV4Generator().newId();

    expect(id, hasLength(36));
    expect(<int>[8, 13, 18, 23].map((int i) => id[i]).toSet(), <String>{'-'});
  });

  test('does not repeat across a large sample', () {
    final UuidV4Generator generator = UuidV4Generator();
    final Set<String> ids = <String>{
      for (int i = 0; i < 5000; i++) generator.newId(),
    };

    expect(ids, hasLength(5000));
  });

  test('a seeded source gives a reproducible sequence', () {
    // Not a security property — it is what lets a test that needs fixed ids
    // have them without a second implementation.
    final List<String> first = <String>[
      for (final UuidV4Generator g in <UuidV4Generator>[
        UuidV4Generator(random: Random(7)),
      ])
        for (int i = 0; i < 3; i++) g.newId(),
    ];
    final List<String> second = <String>[
      for (final UuidV4Generator g in <UuidV4Generator>[
        UuidV4Generator(random: Random(7)),
      ])
        for (int i = 0; i < 3; i++) g.newId(),
    ];

    expect(first, second);
    expect(first.first, matches(uuidV4));
  });

  test('is usable as a file name on any platform', () {
    // The id becomes `<id>.jpg` on disk, so a character Windows or POSIX
    // refuses would turn every capture into a storage failure.
    final String id = UuidV4Generator().newId();

    expect(id, matches(RegExp(r'^[0-9a-f-]+$')));
  });
}
