# PresenceLens Capture

Task 2 of the PresenceLens submission: a custom camera screen and a resilient
upload queue that survives process death and drains itself when the network
allows.

The root [README.md](../README.md) covers the submission as a whole. This file is
the entry point for the Flutter application specifically.

## Status

**Planning complete; visual direction approved; feature implementation next.**

The design direction was reviewed and **approved on 2026-08-29**, so the visual
gate is cleared and the decisions in [UX_SPEC](../docs/flutter/UX_SPEC.md) are
frozen. The production UI — `CameraPreviewScreen` and the Pending Uploads
manager — **is still not implemented**. What builds today is a placeholder shell
that keeps the verification gates meaningful. The next work is gate F1, the data
layer and queue.

| Gate | Result |
| --- | --- |
| `flutter analyze` | Clean, under `strict-casts` / `strict-inference` / `strict-raw-types` |
| `flutter test` | Passing (app-shell smoke only so far) |
| `flutter build apk --debug` | Passing |
| Device QA | Not started |

## Engineering documentation

The design is specified before it is built. Start with whichever question you have:

| Document | Answers |
| --- | --- |
| [REQUIREMENTS_SPEC](../docs/flutter/REQUIREMENTS_SPEC.md) | What must be true, with IDs and verification methods |
| [ARCHITECTURE](../docs/flutter/ARCHITECTURE.md) | Where each responsibility lives, and why Bloc in one place and Cubit in another |
| [DATA_MODEL](../docs/flutter/DATA_MODEL.md) | The queue schema, its states, and the invariants that must survive a crash |
| [CAMERA_ENGINE](../docs/flutter/CAMERA_ENGINE.md) | Lifecycle, zoom, focus — and why the zoom presets are derived rather than hard-coded |
| [SYNC_ENGINE](../docs/flutter/SYNC_ENGINE.md) | How an image reaches the API, and what happens at every point it can fail |
| [UX_SPEC](../docs/flutter/UX_SPEC.md) | Tokens, screen hierarchy, motion, accessibility |
| [TEST_STRATEGY](../docs/flutter/TEST_STRATEGY.md) | What is tested, and what deliberately is not |
| [RISK_REGISTER](../docs/flutter/RISK_REGISTER.md) | What could go wrong and what is being done about it |
| [DECISIONS](../docs/flutter/DECISIONS.md) | The twelve choices worth questioning |
| [RESEARCH](../docs/flutter/RESEARCH.md) | What was verified against primary sources, and what is still open |
| [EXECUTION_PLAN](../docs/flutter/EXECUTION_PLAN.md) | The build order and each gate's exit criteria |

Visual prototypes for the seven key screen states:
**[docs/flutter/design/index.html](../docs/flutter/design/index.html)** — open it in
any browser; the pages are self-contained.

## Two findings worth knowing before reading the code

1. **Android cannot tell you which physical lens a camera is.**
   `camera_android_camerax` never populates `CameraDescription.lensType`, so the
   app derives its zoom presets from the zoom range the device actually reports
   rather than printing a `0.5x` it cannot substantiate
   ([ADR-F03](../docs/flutter/DECISIONS.md)).
2. **The background worker runs in a separate isolate with its own database
   connection**, so no Dart-level lock can coordinate it with the UI. Mutual
   exclusion is enforced inside SQLite by an atomic conditional update
   ([ADR-F04](../docs/flutter/DECISIONS.md)).

## Running it

Requires Flutter 3.47.2 or later on the stable channel, and JDK 21.

```bash
flutter pub get
flutter run
```

Verification gates:

```bash
flutter analyze && flutter test && flutter build apk --debug
```
