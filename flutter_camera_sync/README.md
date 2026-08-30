# PresenceLens Capture

Task 2 of the PresenceLens submission: a custom camera screen and a resilient
upload queue that survives process death and drains itself when the network
allows.

The root [README.md](../README.md) covers the submission as a whole. This file is
the entry point for the Flutter application specifically.

## Status

**Software complete; awaiting physical-device QA.**

The application is built end to end: a custom camera screen over the live
preview, a durable SQLite queue that survives process death, a WorkManager drain
that runs in its own isolate, and a Pending Uploads manager that says truthfully
what the queue is doing.

State is managed as the assessment requires, and the choice is made per feature
rather than applied uniformly (see [ARCHITECTURE](../docs/flutter/ARCHITECTURE.md) §3):

| Holder | Kind | Owns |
| --- | --- | --- |
| `CameraCubit` | Cubit | The live session, and the sequencing that keeps camera races from producing a disposed preview |
| `BatchCubit` | Cubit | The open draft batch and the act of finishing it |
| `SyncBloc` | Bloc | Four fan-in sources — queue changes, connectivity, resume, local actions — reconciled into one queue view |

| Gate | Result |
| --- | --- |
| `flutter analyze` | Clean, under `strict-casts` / `strict-inference` / `strict-raw-types` |
| `flutter test` | **516 passing** |
| `flutter build apk --debug` | Passing |
| Device QA | **Not started — and nothing in this repository claims otherwise** |

**What the 516 tests do not prove.** They run on a Windows host with no device.
They say nothing about whether a real lens focused, whether a pinch felt attached
to the fingers, or whether Android actually ran the background worker. Those are
device checks, they are enumerated in
[CAMERA_ENGINE](../docs/flutter/CAMERA_ENGINE.md) §8 and
[SYNC_ENGINE](../docs/flutter/SYNC_ENGINE.md) §10, and they are outstanding.

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
| [DECISIONS](../docs/flutter/DECISIONS.md) | The twenty-five choices worth questioning |
| [RESEARCH](../docs/flutter/RESEARCH.md) | What was verified against primary sources, and what is still open |
| [EXECUTION_PLAN](../docs/flutter/EXECUTION_PLAN.md) | The build order and each gate's exit criteria |

Visual prototypes for the seven key screen states:
**[docs/flutter/design/index.html](../docs/flutter/design/index.html)** — open it in
any browser; the pages are self-contained.

## Four findings worth knowing before reading the code

1. **Android cannot tell you which physical lens a camera is.**
   `camera_android_camerax` never populates `CameraDescription.lensType`, so the
   app derives its zoom presets from the zoom range the device actually reports
   rather than printing a `0.5x` it cannot substantiate
   ([ADR-F03](../docs/flutter/DECISIONS.md)).
2. **The background worker runs in a separate isolate with its own database
   connection**, so no Dart-level lock can coordinate it with the UI. Mutual
   exclusion is enforced inside SQLite by an atomic conditional update
   ([ADR-F04](../docs/flutter/DECISIONS.md)).
3. **"Finish batch" performs no network operation.** It closes the batch, moves
   its images to `PENDING` in one transaction, and asks the OS to schedule a
   drain — which is why it works, and is offered, with no connection at all. The
   label says *finish* rather than *upload* for exactly that reason
   ([ADR-F14](../docs/flutter/DECISIONS.md)).
4. **The app drains the queue itself while it is on screen**, in addition to the
   background worker. Android may defer a worker substantially under Doze, and a
   correct queue that nobody can observe working is a poor demonstration. Both
   paths are safe together because the claim is atomic
   ([ADR-F25](../docs/flutter/DECISIONS.md)).

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
