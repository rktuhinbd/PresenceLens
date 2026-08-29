# Flutter Task — Camera Engine

**What this document is for:** it specifies how the camera is acquired, kept
alive, controlled and released, and — most importantly — what the app is and is
not allowed to claim about the hardware it found.

Covers `FLT-CAM-001` … `FLT-CAM-018`, `FLT-ERR-001` … `FLT-ERR-005`.

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
| `CameraFailure` | Initialisation or runtime fault; offers retry | Any other plugin exception |

There is no state for "capturing" — capture is a flag inside `CameraReady`
(`isCapturing`), because the preview must keep rendering while a shot is taken.
Making it a separate state would tear down the preview for the duration.

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
  tap: Offset,            // local to the preview widget
  widgetSize: Size,
  previewAspectRatio: double,
) -> Offset?              // null when the tap lands on a letterbox band
```

Returning `null` for a tap outside the image is the correct behaviour — focusing
on a black bar is meaningless. This is pure arithmetic, so it is unit-tested at
the aspect-ratio boundaries with no camera present.

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

| Situation | State | Offered action |
| --- | --- | --- |
| Not yet asked | `CameraPreparing` → OS dialog | — |
| Denied once | `CameraPermissionDenied` | "Allow camera access" (retries `initialize()`) |
| Denied permanently | `CameraPermissionPermanentlyDenied` | "Open settings" (`FLT-ERR-002`) |
| Granted later, app resumed | `CameraPreparing` → `CameraReady` | Automatic on resume |

Re-acquisition on resume is what makes the settings round-trip work without the
user having to find a retry button.

---

## 8. Device verification checklist

`FLT-TEST-009`. Cannot be satisfied on an emulator alone — emulator cameras are
synthetic and report capabilities unlike real hardware.

| # | Check |
| --- | --- |
| 1 | Preview renders at the correct aspect ratio with no stretch |
| 2 | `availableCameras()` — record how many back cameras are actually returned (`FQ-01`) |
| 3 | Record each camera's reported min/max zoom |
| 4 | Pinch tracks fingers; no drift; clamps at both ends |
| 5 | Slider and pinch stay synchronised in both directions |
| 6 | Presets set the exact value and reflect the active state |
| 7 | Tap focus visibly changes focus; reticle lands exactly on the tap |
| 8 | Tap on a letterbox band is ignored |
| 9 | Capture produces a file; double-tap produces exactly one |
| 10 | Camera switch under rapid tapping never crashes or shows a dead preview |
| 11 | Background/foreground releases and restores the preview |
| 12 | Permission denied and permanently-denied paths both render correctly |
| 13 | Reduced-motion enabled: reticle still appears |
