# Flutter Task — Camera Engine

**What this document is for:** it specifies how the camera is acquired, kept
alive, controlled and released, and — most importantly — what the app is and is
not allowed to claim about the hardware it found.

Covers `FLT-CAM-001` … `FLT-CAM-018`, `FLT-ERR-001` … `FLT-ERR-005`.

**Updated at gate F3 (2026-08-30).** The engine below is built and host-verified:
`CameraEngine`/`CameraSession` ports, the `CameraXAdapter`, four pure policies, and
`CameraCubit` with its generation guard, capture guard and zoom pump. Three things
in this document changed because the implementation found something the design had
not: the permission table (§7) lost a state Android cannot reach (`ADR-F22`), the
coordinate mapper gained a second fit (§5, `ADR-F23`), and the state list gained
`CameraReleased` (§1). **No production UI exists** — `CameraPreviewScreen` and the
reticle are still gate F5, and every row whose evidence is `DEVICE` remains
unverified and unclaimed.

---

## 1. Camera states

`CameraCubit` exposes one sealed state. Every branch below is a state a reviewer
can reach, and every one is reachable in a `BLOC` test.

| State | Meaning | Reached from |
| --- | --- | --- |
| `CameraInitial` | Nothing attempted yet | Construction |
| `CameraPreparing` | Enumerating and initialising | `initialize()`, `switchCamera()` |
| `CameraReady` | Live preview; carries capabilities and current zoom/focus | Successful init |
| `CameraPermissionDenied` | Denied, retryable | Init threw a permission error |
| `CameraPermissionPermanentlyDenied` | Denied for good; offers app settings | Init threw the permanent variant |
| `CameraUnavailable` | Device reports no usable camera | `availableCameras()` empty |
| `CameraFailed` | Initialisation or runtime fault; offers retry | Any other plugin exception |
| `CameraReleased` | Hardware handed back, camera remembered | `release()`, lifecycle `paused`/`detached` |

There is no state for "capturing" — capture is a flag inside `CameraReady`
(`isCapturing`), because the preview must keep rendering while a shot is taken.
Making it a separate state would tear down the preview for the duration.

**Two refinements made during implementation.**

`CameraReleased` was added. Without it, a background/foreground cycle would have to
return to `CameraInitial`, which is indistinguishable from a cold start: the screen
would lose which camera the user had selected, and nothing could tell "we gave the
hardware back" apart from "nothing has happened yet". It carries the device so
resume reopens the same camera, which is asserted by test.

`CameraPreparing` carries a `phase` — `discovering`, `initializing`, `switching`,
`restoring` — rather than becoming four states. All four render the same thing (a
viewfinder that is not live yet), so splitting them would force every consumer to
handle four cases to say one sentence; keeping the fact as a field costs nothing and
stays assertable.

The class is named `CameraFailed` rather than `CameraFailure`, because
`CameraFailure` is the *error value* it carries. Two types one letter apart, one a
state and one an exception, is a naming trap.

---

## 2. Lifecycle

The `camera` package puts lifecycle ownership on the app (`RESEARCH.md` `FR-02`),
so this is explicit rather than incidental.

```
AppLifecycleState.resumed   →  cubit.acquire()    (re-init if released)
AppLifecycleState.inactive  →  ignored — transient (notification shade,
                               permission dialog, incoming-call banner)
AppLifecycleState.paused    →  cubit.release()    (dispose the controller)
AppLifecycleState.detached  →  cubit.release()
```

`inactive` is deliberately ignored. On both platforms it fires for momentary
overlays — including the system permission dialog — and disposing there causes a
teardown/rebuild flicker on the very first launch, when the app is asking for
camera permission. Releasing on `paused` is sufficient to free the hardware for
other apps.

Full dispose is preferred over `pausePreview()` because it unambiguously releases
the device; whether `pausePreview()` would be adequate for short switches is
`FQ-04`, open until device testing.

**Route-level release:** navigating to the Upload Manager also releases the
camera. Holding a live camera behind another screen wastes power and blocks other
apps for no benefit.

---

## 3. Initialisation and races

```
initialize()
  ├─ availableCameras()
  │    ├─ throws            → CameraFailure
  │    └─ empty             → CameraUnavailable          (FLT-ERR-003)
  ├─ filter lensDirection == back                        (FLT-CAM-011)
  │    └─ none back-facing  → fall back to any available, and say so
  ├─ pick the active camera (default: first back camera)
  ├─ CameraController(..., enableAudio: false)           (FLT-CAM-017)
  ├─ controller.initialize()
  │    ├─ CameraException('CameraAccessDenied')          → CameraPermissionDenied
  │    ├─ permanent-denial variant                       → ...PermanentlyDenied
  │    └─ other                                          → CameraFailure
  └─ read getMinZoomLevel() / getMaxZoomLevel()          → CameraReady
```

`enableAudio: false` is not a detail: leaving it on makes the plugin request the
**microphone** permission for an app that only takes stills, which a reviewer will
notice and which would be a genuine privacy defect.

### Switch-race protection (`FLT-CAM-013`)

Rapid taps on the camera selector are the classic way to end up rendering a
disposed controller. Two guards:

1. A `_switchGeneration` counter, incremented on every switch request. When an
   `initialize()` completes, it checks whether its generation is still current and,
   if not, disposes what it just built and emits nothing.
2. Switch requests are refused while `CameraPreparing` unless they name a
   *different* camera, in which case the pending one is superseded.

The result: the last requested camera always wins, and no disposed controller is
ever handed to `CameraPreview`.

### Capture guard (`FLT-CAM-014`)

`isCapturing` is set before `takePicture()` and cleared in a `finally`. A second
shutter press while it is set is dropped. The shutter control is also visually
disabled, so the guard is not the only feedback.

---

## 4. Zoom — and the honesty problem

### What the platform actually tells us

From `RESEARCH.md` `FR-04`, verified in the resolved package source:

- `CameraDescription` carries `lensType` (`wide` / `telephoto` / `ultraWide` /
  `unknown`), defaulting to `unknown`.
- **iOS** (`camera_avfoundation` 0.10.3) populates it.
- **Android** (`camera_android_camerax` 0.7.4+7) **never** does — the string
  `lensType` does not appear in the package at all. Every Android camera is
  `unknown`, named by its raw Camera2 ID.

Android is the only platform with a mandated deliverable (root `AMB-12`).

### The consequence

**The app must not print "0.5x" beside a camera it cannot identify.** Doing so
would be inventing a hardware claim — precisely the kind of detail this assessment
says it is looking for.

The assessment's own text for this bullet is truncated in the source PDF
(`...rounded buttons (0.5x, 1x, .. available back cameras).` — root `AMB-01`), so
the exact preset set was never fully specified. That makes a device-derived
approach the only one that is correct under every plausible completion.

### What is built instead (`FLT-CAM-005`, `FLT-CAM-016`)

`ZoomPresetPolicy` is a pure function:

```
presetsFor(zoomRange: [min, max], cameras: List<CameraInfo>) -> List<ZoomPreset>
```

Rules:

1. **`1.0x` is always present** — the active camera's own baseline, which is what
   `setZoomLevel(1.0)` means by definition.
2. **Below 1.0** a preset appears **only if `min < 1.0`**, i.e. the device really
   reported that it can go wider. It is labelled with the actual minimum
   (e.g. `0.6x`), not a rounded marketing `0.5x`.
3. **Above 1.0**, stops are chosen from `{2, 5, 10}` and included only while
   `stop <= max`.
4. Presets never exceed the reported range in either direction (`FLT-CAM-007`).
5. If `lensType` **is** available (iOS), presets may be upgraded to true optical
   names, and physically distinct back cameras are offered as a lens selector.
   On Android, multiple back cameras are still offered when
   `availableCameras()` returns more than one — labelled neutrally
   ("Camera 1 / Camera 2"), never with a fabricated multiplier.

So on a typical Android phone the row is `1x` plus whatever the reported range
justifies; on a device reporting `min = 0.5` it shows `0.5x` **because the device
said so**.

This is documented in the README as a deliberate limitation with its evidence.
It is a better answer than a hard-coded `0.5x / 1x / 2x` row that lies on most
hardware, and it is defensible in an interview in one sentence: *the Android
implementation of the plugin does not expose lens identity, so the app derives its
presets from the zoom range the device actually reports.*

### One zoom value, three controls (`FLT-CAM-006`)

Pinch, slider and presets are three *inputs* to a single `currentZoom` held in
`CameraReady`. Each writes through `ZoomPolicy.clamp()`; the slider and preset row
render from the same value. They cannot disagree because there is nothing to
disagree with.

Pinch maths (`ZoomPolicy`, pure and unit-tested):

```
newZoom = clamp(zoomAtGestureStart * scaleFactor, min, max)
```

Anchoring to the zoom at gesture *start* rather than accumulating per-frame deltas
is what makes a pinch feel attached to the fingers instead of drifting.

Plugin calls are rate-limited to one in flight: a pending `setZoomLevel` suppresses
further calls until it resolves, and the latest requested value is applied on
completion. The UI still updates every frame, so the interaction stays smooth while
the device is not flooded.

---

## 5. Tap-to-focus

### Coordinate mapping (`FLT-CAM-008`)

`setFocusPoint` expects a normalised `Offset` between `(0,0)` and `(1,1)`
(`FR-01`). The preview is letterboxed inside its box, so the tap must be mapped
through the *displayed* preview rect, not the widget rect:

```
FocusPointMapper.toNormalized(
  tapX: double, tapY: double,   // local to the preview widget
  layout: PreviewLayout,        // box size + preview aspect ratio + fit
) -> NormalizedPoint?           // null when the tap lands on no image
```

**Both fits are implemented** (`ADR-F23`). This document originally specified
letterboxing only, while `UX_SPEC.md` §4 specifies a full-bleed viewfinder; both
are approved and they are different renderings, so the mapper takes the fit as an
input rather than assuming one:

* `PreviewFit.contain` — the image is letterboxed. A tap on a band returns `null`,
  because focusing on a black bar is meaningless, and clamping it to the image edge
  instead would silently move the reticle away from the finger.
* `PreviewFit.cover` — the image fills the box and overflows it. Every tap is on
  image, but part of the image is off-screen, so the visible window has to be
  re-expressed against the whole frame. A tap at the visible left edge of a 4:3
  sensor in a tall box is **a third of the way into the image**, not at its edge.

The types are the app's own (`NormalizedPoint`, `PreviewLayout`), not `dart:ui`'s
`Offset` and `Size` — partly because the domain layer may not import `dart:ui`
(`FLT-GEN-007`), and partly because an `Offset` here would be ambiguous about
whether it holds pixels or a fraction, which is exactly the confusion that puts
the focus point in the wrong place.

This is pure arithmetic, unit-tested at the aspect-ratio boundaries with no camera
present. No prototype geometry is hard-coded anywhere; the UI supplies the box.

Exposure point is set alongside focus where supported (`FLT-CAM-018`, bonus): on
most hardware, tapping a subject and having it stay dark is a worse experience
than not offering focus at all.

### The indicator (`FLT-CAM-009`, `FLT-CAM-010`)

The reticle appears **at the tap coordinates**, which is what the assessment
requires. Its lifecycle:

```
tap ─▶ appear at point (scale 1.15 → 1.0, 120 ms)
    ─▶ acquiring: subtle pulse while the focus future is pending
    ─▶ settle on completion (or after a 1 s cap if the platform never reports)
    ─▶ hold 600 ms ─▶ fade out 200 ms
```

Under reduced motion (`FLT-UX-004`) the reticle still appears instantly at the
point and holds, then disappears — the *feedback* is required, only the animation
is optional.

The 1-second cap matters: not every device resolves the focus future promptly, and
an indicator that never resolves reads as a frozen app.

---

## 6. Capture → durable storage

```
takePicture() -> XFile   (plugin temp directory — NOT durable)
      │
      ▼
CaptureStore.persist(xfile, batchId, imageId)
      │   copy into <app documents>/captures/<batchId>/<imageId>.jpg
      │   ├─ IO failure → CaptureFailure, surfaced, NO row written
      │   └─ success    → durable absolute path
      ▼
BatchCubit.append(imageId, path)  → queue row inserted (DRAFT)
```

The plugin's `XFile` lives in a cache directory the OS may clear at any time.
Treating it as storage is the single most likely way to lose a queued image, so
the copy is mandatory and the queue row is written only after it succeeds
(`FLT-CAM-015`, `FLT-ERR-005`, invariant I1).

---

## 7. Permission handling

No `permission_handler` dependency. The `camera` plugin already surfaces denial as
a `CameraException`, and adding a second permission library for a single
permission is not justified.

**Corrected at F3.** This table previously listed a separate
`CameraPermissionPermanentlyDenied` state, taken from the plugin's example app.
Reading the resolved plugin sources showed that state is **unreachable on
Android**: `camera_android_camerax` 0.7.4+7 emits only `CameraAccessDenied`, and
the `...WithoutPrompt` and `...Restricted` codes exist solely in
`camera_avfoundation` (`RESEARCH.md` `FR-12`). One state now carries the platform's
verdict as a *field*, so the app cannot assert something it was never told
(`ADR-F22`):

| Situation | State | Offered action |
| --- | --- | --- |
| Not yet asked | `CameraPreparing` → OS dialog | — |
| Denied, first time | `CameraPermissionDenied(isPermanentPerPlatform: false, consecutiveDenials: 1)` | "Allow camera access" (retries) |
| Denied again | same state, `consecutiveDenials: n` | Retry **plus** "Open settings" — an escalated *offer*, never a claim (`FLT-ERR-002`) |
| iOS, denied without prompt | `isPermanentPerPlatform: true` | "Open settings" — the platform actually said so |
| iOS, restricted by policy | `isRestricted: true` | Explain; `canRetry` is false |
| Granted later, app resumed | `CameraPreparing` → `CameraReady` | Automatic on resume |

Re-acquisition on resume is what makes the settings round-trip work without the
user having to find a retry button — and it is the reason the counter is enough:
a user who grants permission in Settings comes back to a live camera regardless of
what the app had guessed. The counter resets on any successful acquisition.

"Open settings" itself needs a `MethodChannel` in this app's `MainActivity` firing
`Settings.ACTION_APPLICATION_DETAILS_SETTINGS`. Route chosen and recorded at F3;
**built at F5**, with the screen that calls it (`ADR-F22`).

---

## 8. Ownership, and the one seam

**Exactly one object owns the platform controller.** `CameraXSession` creates it,
holds it, and destroys it; `CameraCubit` holds at most one session at a time and is
the only thing that calls `dispose()`. No widget constructs a controller, and none
can dispose one.

```
CameraCubit ──owns──▶ CameraSession (domain port, pure Dart)
                          ▲
                          │ implements
                    CameraXSession ──owns──▶ CameraController
                          │
                          │ also implements
                          ▼
                  CameraPreviewSource      ── previewController (read-only)
                          │
                          ▼
              buildCameraPreview(session)  ── the only caller
```

`CameraPreviewSource` is a single getter. `CameraPreview` needs a real
`CameraController` and there is no pure substitute; an abstraction whose only
implementation hands the controller back anyway would be theatre that makes the
integration worse rather than safer (`ADR-F23`). A session that does not implement
it — a fake in a test — renders a placeholder, which is what makes the production
screen widget-testable without a camera.

An automated test confines `package:camera/` imports to `lib/data/camera/`, with a
companion assertion that the adapter still imports it — so the rule cannot pass
vacuously if the adapter moves.

**Stale-async protection.** One `_generation` counter, bumped by every acquire,
switch and release. Each asynchronous step captures the value it began with and
must prove it is still current before publishing state or keeping a session. Two
distinct outcomes, both tested:

* superseded **before** its open began — the camera is never acquired at all;
* superseded **after** its open began — the session that arrives late is disposed
  and no state is emitted for it.

**Zoom pump.** One `setZoomLevel` in flight at a time; a newer request replaces a
pending one rather than queueing behind it, and the last value the user asked for is
always the one finally applied. State moves immediately on every request, so the
slider tracks the finger while the device is not flooded.

---

## 9. Device verification checklist

`FLT-TEST-009`. **Not executed. Nothing in this repository claims any of it has
passed.** Cannot be satisfied on an emulator alone — emulator cameras are synthetic
and report capabilities unlike real hardware (`RF-03`).

`CameraDiagnostics.report()` produces checks 2–4 as one copyable block; paste its
output into the evidence column rather than paraphrasing it.

| # | Check | Records |
| --- | --- | --- |
| 1 | Preview renders at the correct aspect ratio with no stretch | — |
| 2 | `availableCameras()` — exact output: `name`, `lensDirection`, `lensType`, `sensorOrientation` for **every** camera | `FQ-01`; confirms or overturns `FR-04` |
| 3 | Exact count of **back** cameras | `FQ-01` |
| 4 | `getMinZoomLevel()` / `getMaxZoomLevel()` per rear camera | `FQ-01`; validates `ZoomPresetPolicy` against real hardware |
| 5 | `focusPointSupported` and `exposurePointSupported` per rear camera | `FLT-CAM-008`, `FLT-CAM-018` |
| 6 | Pinch tracks fingers; no drift; clamps at both ends | `FLT-CAM-003` |
| 7 | Slider and pinch stay synchronised in both directions | `FLT-CAM-006` |
| 8 | Presets set the exact value and reflect the active state | `FLT-CAM-005` |
| 9 | Tap focus visibly changes focus; reticle lands exactly on the tap | `FLT-CAM-008/009` |
| 10 | Tap outside the active preview area behaves per the chosen fit | `FLT-CAM-008` |
| 11 | Capture produces a file; double-tap produces exactly one | `FLT-CAM-014` |
| 12 | A real plugin `XFile` reaches durable storage and survives | `FLT-CAM-015` |
| 13 | Camera switching works, and rapid tapping never crashes or shows a dead preview | `FLT-CAM-013` |
| 14 | Background/foreground releases and restores the preview; captures survive | `FLT-CAM-012` |
| 15 | Camera permission **denied** renders correctly and retry works | `FLT-ERR-001` |
| 16 | Permission denied twice, then granted in Settings, then return to the app — camera comes back with no retry tap | `FLT-ERR-002`, `ADR-F22` |
| 17 | Reduced-motion enabled: reticle still appears | `FLT-UX-004` |

**Check 2 is the one that matters most.** It is the only thing that can confirm or
overturn `FR-04`, and the honest-label policy (`ADR-F03`) — the most visible design
decision in this task — rests on it. If a real device *does* report `lensType`, the
preset policy already upgrades its labels; nothing needs rewriting, but the README's
limitation note would need correcting.
