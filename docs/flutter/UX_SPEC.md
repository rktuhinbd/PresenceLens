# Flutter Task — UX Specification

**What this document is for:** it fixes the design tokens, screen hierarchy,
interaction behaviour, motion and accessibility rules that the production UI will
be built to, so that implementation is transcription rather than invention — and
so the static prototypes in [design/](design/) can be judged against a written
intent.

Covers `FLT-UX-001` … `FLT-UX-013`, and the presentation half of `FLT-CAM-*` and
`FLT-BAT-*`.

> **VISUAL DIRECTION APPROVED — 2026-08-29.** This specification and the
> prototypes in `design/` were reviewed and approved, and the decisions they
> record are now **frozen as the production design direction**. They should not
> be redesigned during implementation without an evidenced device or usability
> problem.
>
> No production `CameraPreviewScreen` or Upload Manager widget exists yet; this
> document is what they will be built to.

---

## 1. Design position

**Material 3 is the foundation.** This is a Flutter app that will be judged on an
Android device; it should look and behave like an excellent Android application,
not like a port. Colour is expressed through M3 **roles** derived from a seed, so
light and dark are one definition (`RESEARCH.md` `FR-10`).

**Apple's HIG is used as a quality reference, not a visual one.** Four principles
are borrowed, and none of them make the app look like iOS:

| HIG principle | How it is applied here | Where |
| --- | --- | --- |
| Content deserves the screen | The viewfinder is the interface; chrome floats over it and stays out of the optical centre | Camera screen |
| Direct manipulation | Pinch changes zoom continuously; the reticle lands exactly where the finger did; the slider tracks 1:1 | Zoom, focus |
| Feedback is immediate and specific | Every control confirms in under 100 ms, before any async work resolves | Shutter, focus, presets |
| Restraint in motion | Animation explains a state change or does not happen | §7 |

**PresenceLens Capture** should read as the same product family as the native
attendance app — shared seed colour, shared tone of voice, shared restraint —
without copying any Compose implementation detail.

---

## 2. Tokens

### 2.1 Colour — application surfaces

Derived by `ColorScheme.fromSeed`. One seed, both brightnesses.

| Token | Value | Role |
| --- | --- | --- |
| `seed` | `#00A884` | Shared with the attendance app. Signal green: presence, confirmation. |
| `primary` | from seed | Primary actions, active states |
| `surface` / `surfaceContainer*` | from seed | Cards, sheets, list rows |
| `error` | M3 default | Permanent failure only |
| `outlineVariant` | from seed | Row dividers, inactive borders |

Semantic roles for sync state — mapped to scheme roles, never raw hex, and each
one paired with an icon so state never depends on colour alone (`FLT-UX-005`):

| Sync state | Colour role | Icon | Word |
| --- | --- | --- | --- |
| In queue | `onSurfaceVariant` | `schedule` | "In queue" |
| Waiting for connection | `onSurfaceVariant` | `cloud_off` | "Waiting for connection" |
| Uploading | `primary` | `arrow_upward` | "Uploading" |
| Retrying | `tertiary` | `refresh` | "Retrying · attempt N" |
| Synced | `primary` | `check_circle` | "Synced" |
| Failed | `error` | `error_outline` | "Can't upload" |

### 2.2 Colour — camera surfaces

The camera route uses a **fixed dark control palette that does not follow the
system theme** (`ADR-F07`). The content behind the controls is always a live
image, so a light-mode camera UI would be unreadable outdoors and would wash out
the preview.

| Token | Value | Use |
| --- | --- | --- |
| `camera.scrim` | `#000000` @ 40% | Gradient bands top and bottom, so controls stay legible over any scene |
| `camera.control` | `#FFFFFF` @ 92% | Icons, labels |
| `camera.controlBg` | `#000000` @ 45% | Circular control backing |
| `camera.controlActive` | `#00E5A8` | Selected preset text |
| `camera.controlActiveBg` | `#000000` @ 62% | Selected preset backing, with a 1.5 px accent inset ring |
| `camera.shutterRing` | `#FFFFFF` | Shutter outer ring |
| `camera.shutterCore` | `#FFFFFF` | Shutter fill |
| `camera.accent` | `#00E5A8` | Focus reticle, batch count badge — the seed lifted for dark |
| `camera.warning` | `#FFB74D` | Offline hint |

Scrims are gradients, not flat fills: a flat panel over a viewfinder reads as an
obstruction, a gradient reads as the image continuing underneath. They are
deliberately strong at the edges — the bottom scrim reaches 88% black — because
every control sits over a subject that may be a bright document in daylight.

**Changed after prototyping.** The active zoom preset was originally specified as
white text on a 22%-white fill. Rendering it over a bright document
([03-camera-active-batch](design/03-camera-active-batch.html)) showed it failing
contrast badly — white on translucent white over a light subject is close to
invisible. The active state is now the accent colour on a *darker* pill, which
also gives the accent one consistent meaning across the screen: this is the
current value. This is the kind of defect the prototype gate exists to catch.

### 2.3 Typography

Material 3 type scale, unmodified. Deviating from it buys nothing here.

| Use | Style |
| --- | --- |
| Screen title | `titleLarge` |
| Batch title in list | `titleMedium` |
| Body / status line | `bodyMedium` |
| Item sub-status, attempt count | `bodySmall` |
| Zoom preset label | `labelLarge`, tabular figures |
| Section overline | `labelSmall`, +0.5 letter-spacing, uppercase |

Text scales with the system setting. Camera control labels are capped at 1.3× so
a large accessibility setting cannot push the preset row over the preview.

### 2.4 Spacing, shape, elevation

4 dp base grid. Steps: `4, 8, 12, 16, 24, 32, 48`.

| Element | Radius |
| --- | --- |
| Cards, sheets | 16 |
| List rows | 12 |
| Zoom preset pill | full (circular) |
| Buttons | full (M3 default) |
| Focus reticle | full |
| Thumbnail | 8 |

Elevation is M3 tonal, not shadow-heavy: level 0 for the page, level 1 for cards,
level 2 for the bottom action bar. Camera controls use **no** elevation — they sit
on scrims, and a drop shadow over a photograph looks like a defect.

### 2.5 Motion tokens

| Token | Duration | Curve | Use |
| --- | --- | --- | --- |
| `instant` | 80 ms | `easeOut` | Press feedback |
| `quick` | 120 ms | `easeOutCubic` | Reticle appear, preset selection |
| `standard` | 200 ms | `easeInOutCubic` | State cross-fades, list item change |
| `deliberate` | 320 ms | `easeInOutCubic` | Route transition, batch commit |

Every value here collapses to 0 ms when `MediaQuery.disableAnimations` is true.

### 2.6 Haptics

Sparing and meaningful — haptics on every touch become noise.

| Event | Feedback |
| --- | --- |
| Shutter press | `HapticFeedback.mediumImpact` |
| Zoom preset change | `HapticFeedback.selectionClick` |
| Zoom reaching min or max | `selectionClick`, once per arrival, not per frame |
| Batch enqueued | `HapticFeedback.lightImpact` |
| Permanent failure appears | `HapticFeedback.heavyImpact` |

Tap-to-focus deliberately has **no** haptic: the reticle is the feedback, and a
buzz on every preview tap becomes irritating quickly.

---

## 3. `CameraPreviewScreen` hierarchy

```
┌─────────────────────────────────────────┐
│ ░░░ top scrim ░░░                       │  ← safe-area top
│  [ ⚠ Offline ]              ↑ Uploads 12 › │  ← no close control; see 3.1
│                                         │
│                                         │
│                                         │
│            LIVE PREVIEW                 │  ← full-bleed, tap = focus,
│              (full bleed)               │    pinch = zoom
│                    ◎                    │  ← focus reticle at exact tap point
│                                         │
│                                    ┌──┐ │
│                                    │▓▓│ │  ← zoom slider, right edge,
│                                    │▒▒│ │    vertical, thumb-reachable
│                                    │░░│ │
│                                    └──┘ │
│              ( 1x ) ( 2x )              │  ← presets, device-derived
│ ░░░ bottom scrim ░░░                    │
│   [▣ 4]        ( ◉ )         [ ⇄ ]      │  ← thumbnail+count, shutter, switch
│         ✓ Finish batch (4)              │  ← appears only when count > 0
└─────────────────────────────────────────┘  ← safe-area bottom
```

Region by region:

| Region | Contents | Rules |
| --- | --- | --- |
| **Top bar** | Offline chip; Pending Uploads entry with count. **No close control** — see §3.1. | Over a scrim, not a solid bar. The offline chip appears only when there is something queued *and* no link — otherwise it is noise. |
| **Viewport** | Full-bleed `CameraPreview` | The entire area is the tap-to-focus and pinch target. No control sits in the optical centre. |
| **Focus reticle** | Ring at the tap point | §7. Never clipped: near an edge it stays fully on-screen by nudging inward. |
| **Zoom slider** | Vertical, right edge, ~40% of height | Right-edge vertical is the one-handed-reachable position for a thumb; a horizontal slider at the bottom would collide with the shutter. Labelled with min/max. |
| **Preset row** | Circular pills above the bottom scrim | Derived from device capability (`CAMERA_ENGINE.md` §4). Hidden entirely if the device reports no usable zoom range — an inert `1x` pill is worse than nothing. |
| **Bottom bar** | Thumbnail + count · shutter · camera switch | Shutter centred, 72 dp, unmissable. Switch appears only when more than one camera exists. |
| **Batch action** | "Finish batch (n)", with a completion mark, not a send glyph | **Contextual** — absent at count 0. A permanently visible disabled button is clutter. Wording per §3.2. |

**One-handed ergonomics.** Shutter centred and low; zoom slider on the right edge
within thumb arc; navigational controls at the top, out of accidental reach.

### 3.1 Navigation semantics — why there is no close control

The camera route has **no X, no back arrow, and no exit affordance.**

An X sitting over a live viewfinder beside a batch of unsaved captures is
genuinely ambiguous. A user can read it as any of: discard this batch, close the
camera, cancel the capture in progress, or quit the app. Three of those four
readings are destructive, and the control gives no way to tell which one it
means. A destructive-looking control next to unsaved work is a defect, not a
convenience.

It is also unnecessary. `CameraPreviewScreen` is the app's launch destination and
its primary surface — there is nothing behind it to go back to, and inventing an
"exit app" action is not something an Android application should do.

Navigation is therefore **one-way outward**:

```
CameraPreviewScreen  ──"Uploads ›"──▶  UploadManagerScreen
        ▲                                      │
        └──────────── back / "Open camera" ────┘
```

The back affordance belongs to the Upload Manager, where it means exactly one
thing and nothing is at risk. That screen already has it (§4).

**Invariant — the draft batch is never silently discarded.**

| Event | Effect on the open batch |
| --- | --- |
| Navigate to Pending Uploads and back | **None.** The batch is still open with the same count. |
| App backgrounded, camera released | **None.** Captures are already durable on disk (`FLT-CAM-015`). |
| Process death | **None.** The batch is rebuilt from SQLite on next launch as `DRAFT`. |
| Camera permission revoked | **None.** The queue stays reachable; the batch survives. |

There is deliberately no gesture, control, or navigation path that destroys an
open batch as a side effect. Discarding a batch, if it is ever offered, must be
an explicit and separately confirmed action — it is not in scope for this
submission. Verified by `FLT-BAT-004` and the process-death rows of
[DATA_MODEL.md](DATA_MODEL.md) §5.

### 3.2 Batch action language — "Finish", not "Upload"

The primary batch control reads **"Finish batch (n)"** with a completion mark.

Pressing it is a **purely local, durable act**: it closes the open batch, moves
its images to `PENDING` in one transaction, and asks the OS to schedule a drain.
No network operation occurs, and none is guaranteed to occur soon afterwards —
WorkManager decides when the worker runs (`SYNC_ENGINE.md` §9).

"Upload batch" promised the wrong thing twice over. It implied the press performs
a transfer, and it made the offline case read as a contradiction: a screen
showing **Offline** while offering **Upload batch** invites the user to conclude
the button is broken or will fail. It is neither — finishing a batch offline is
completely normal and is exactly what the resilient queue exists to support.

| | Wrong | Right |
| --- | --- | --- |
| Label | "Upload batch (4)" | **"Finish batch (4)"** |
| Icon | Send / paper plane | **Completion mark** |
| Implies | A network transfer starts now | Capture is complete and safely handed over |
| Offline | Reads as contradictory | Reads as normal |

The same reasoning governs the status copy in §4: the app says what is *true of
the data* ("captures are safe") before it says anything about the network.

### Camera screen states

| State | Screen |
| --- | --- |
| Ready, empty batch | Preview + controls; no batch action, no thumbnail |
| Ready, active batch | Thumbnail with count badge; "Finish batch (n)" visible |
| Focusing | Reticle at tap point |
| Zooming | Slider thumb tracks; active preset highlights |
| Capturing | Brief frame flash; shutter compresses; controls stay live |
| Permission denied | Preview replaced by an explanatory panel + action |
| No camera | Explanatory panel; Pending Uploads still reachable |
| Initialisation failed | Explanatory panel + "Try again" |

The last three matter: the user must still reach their queued uploads when the
camera is unavailable. **The queue is never trapped behind a broken camera.**

---

## 4. Upload Manager (Pending Uploads)

```
┌─────────────────────────────────────────┐
│ ‹  Pending uploads                      │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │ ⚡ Connected · uploading automatically│ │  ← hint, never a promise
│  └───────────────────────────────────┘  │
│                                         │
│  BATCH · 2 min ago            3 of 5 ▓▓░│
│  ┌───────────────────────────────────┐  │
│  │ ▣  IMG_0031    ✓ Synced           │  │
│  │ ▣  IMG_0032    ↑ Uploading        │  │
│  │ ▣  IMG_0033    ↻ Retrying · try 3 │  │
│  │ ▣  IMG_0034    ⏱ In queue         │  │
│  └───────────────────────────────────┘  │
│                                         │
│  BATCH · 1 hr ago             0 of 2 ░░░│
│  ┌───────────────────────────────────┐  │
│  │ ▣  IMG_0028  ☁ Waiting for network│  │
│  └───────────────────────────────────┘  │
│                                         │
│  Saved on this device. Uploads resume   │  ← the reassurance line
│  automatically when you're connected.   │
│                                         │
│        [ + Start new batch ]            │
└─────────────────────────────────────────┘
```

| Element | Rule |
| --- | --- |
| Connectivity chip | Hint wording. Never "STABLE LINK" as a guarantee — the app cannot know (`FR-05`, `FLT-UX-010`). Exact strings in §4.1. |
| Batch header | Relative time + `n of m` uploaded. Progress is **count-based**, honest; no fabricated byte percentage. |
| Density | Professional, not decorative. Filenames at `bodyMedium`, status at `bodySmall`, ~16 dp row padding, and a **noticeably larger gap between batches than between rows** — the grouping is carried by whitespace, not by borders or nested cards. Rows must stay compact enough that several are visible at once; this is a work queue, not a feed. |
| Item row | Thumbnail, name, state with icon + words (`FLT-UX-005`, `FLT-UX-011`). |
| Attempt count | Shown only while retrying. No `/5` denominator unless a cap exists (`SYNC_ENGINE.md` §5). |
| Reassurance line | Persistent while anything is pending. This is the single most important sentence on the screen (`FLT-UX-007`). |
| Manual retry | Overflow only, labelled "Try now". An accelerator, never the mechanism (`FLT-SYNC-014`). |

### 4.1 Status copy — what the app is allowed to claim

Three things must come across, in this order of priority: **captures are safe**,
**syncing is automatic**, **you do not have to do anything**. The network is the
least important of the four facts on screen, so it never leads.

| State | Chip | Reasoning |
| --- | --- | --- |
| Offline, items queued | **"Offline · captures are safe"** | Leads with the reassurance, not the problem. The user's real question is "did I lose them?", and the first three words answer it. |
| Connected, draining | **"Connected · uploading automatically"** | *Uploading*, not *retrying*. Retry is what follows a failure; on the happy path nothing has failed, and saying "retrying" invents a problem. |
| Connected, nothing pending | Chip hidden | Nothing to reassure anyone about. |

Reassurance line, persistent while anything is pending:

> **Saved on this device. Uploads resume automatically when you're connected.**

Camera chip stays compact — just **"Offline"**. There is no room for a sentence
over a viewfinder, and the camera screen is not where the queue is explained.

**What the copy must not claim.** WorkManager scheduling is OS-controlled and can
be deferred by Doze, App Standby and OEM battery managers (`SYNC_ENGINE.md` §9).
So the wording promises *automatic*, never *immediate* or *continuous*:

| Never write | Why | Write |
| --- | --- | --- |
| "Uploading now" / "Syncing now" | Not true while the worker is unscheduled | "Uploading automatically" |
| "Continuously monitoring your connection" | Nothing runs while unscheduled | "Uploads resume automatically when you're connected" |
| "Will upload in a few seconds" | The OS decides, not the app | *(say nothing about timing)* |
| "Connection stable" / "STABLE LINK" | Link presence is not reachability (`FR-05`) | "Connected" |
| "Retrying" on a first attempt | Nothing has failed yet | "Uploading" |

"Automatically" is the honest word: it promises the user has no work to do, which
is true and is `FLT-SYNC-004`, without promising a schedule the app does not
control.

### Empty state (`FLT-UX-006`)

Not an error. Centred icon, "Everything's uploaded", one line — "Photos you
capture will appear here until they're safely uploaded." — and a primary
"Open camera" action.

### Completion

A batch reaching `COMPLETED` does not vanish mid-glance. It shows "Synced" for
~2 s, then collapses out with `standard` motion — so the user sees the success
rather than an item disappearing.

---

## 5. Tone of voice

| Instead of | Write |
| --- | --- |
| "Upload batch (4)" | "Finish batch (4)" |
| "Upload failed" | "Waiting for connection" |
| "No connection · we'll retry automatically" | "Offline · captures are safe" |
| "Error 500" | "Couldn't upload — we'll retry" |
| "0 items" | "Everything's uploaded" |
| "Permission denied" | "PresenceLens needs camera access to take photos" |
| "STABLE LINK" | "Connected · uploading automatically" |

The user's mental question is *"did I lose my photos?"* Every string on the
Upload Manager answers "no".

---

## 6. Accessibility (`FLT-UX-002` … `FLT-UX-005`, `FLT-UX-013`)

| Requirement | Implementation |
| --- | --- |
| Touch targets | ≥ 48×48 dp on every control; shutter 72 dp. |
| Semantics — shutter | `button`, "Take photo". |
| Semantics — presets | `button`, selected state, "Zoom 2 times". |
| Semantics — slider | `Slider` with `semanticFormatterCallback` → "Zoom 3.4 times". |
| Semantics — preview | Labelled "Camera preview. Double tap to focus." |
| Semantics — queue item | One label per row: "IMG_0033, retrying, attempt 3." Not four separate nodes. |
| Live updates | State changes announce via `SemanticsService.announce` — throttled, so a draining queue does not spam the screen reader. |
| Contrast | Camera controls ≥ 4.5:1 against their scrim; verified against a worst-case bright scene. |
| Colour independence | Every state has an icon and a word (§2.1). |
| Gesture alternatives | Zoom is fully operable by slider and presets without pinch (`FLT-UX-013`). Focus has no non-gesture equivalent — noted honestly; the camera auto-focuses without user input. |
| Text scaling | Supported; camera labels capped at 1.3×. |
| Reduced motion | §7. |

---

## 7. Motion (`FLT-UX-004`)

Motion must explain a state change. Nothing here is decorative.

### 7.1 The signature interaction — focus → capture → batch

This is the one sequence worth getting exactly right. It is where the product's
character lives, and it is the only motion in the app that is *composed* rather
than incidental.

The single sentence it must communicate:

> **This image was captured, and it safely joined the batch.**

Nothing in it may read as playful. This is a field-capture tool; a photo joining
a batch is a small act of record-keeping, not a game event. The emerald accent is
the connective thread — it marks the focus point, then the batch badge — so the
eye follows one colour from *where you aimed* to *where it was stored*.

```
  ①  tap preview
      └─ emerald reticle appears AT the tap point         quick, ~120 ms
         scale 1.15 → 1.00, opacity 0 → 1

  ②  acquisition                                          ~150–250 ms, device-led
      └─ single restrained pulse of the ring (scale ≤1.04)
         NOT a spinner, NOT a loop

  ③  confirmation settles                                 quick
      └─ ring thins, holds ~600 ms, fades out             standard

  ④  shutter press                                        instant, ~80 ms
      └─ ring compresses ~4%, mediumImpact haptic
         fires on TOUCH DOWN, before any async work

  ⑤  capture completes
      └─ brief frame flash, white @ ~30%, out over quick

  ⑥  captured image contracts into the thumbnail stack    deliberate, ~320 ms
      └─ a small representation of the frame travels from
         the preview centre to the stack, scaling down,
         easeInOutCubic, arriving slightly ahead of ⑦

  ⑦  batch count increments                               quick
      └─ badge steps 3 → 4 as the representation lands,
         lightImpact haptic
```

**Why this shape.** Steps ④ and ⑦ are separated by ~400 ms of real work
(persisting the file, inserting the row). Without ⑥ the user presses the shutter
and, a moment later, a number changes somewhere else on screen — two unrelated
events. The travelling representation is what makes them one causal story, and it
is also the honest one: the image really is being moved into durable storage
before it counts (`FLT-CAM-015`).

**Timing is a starting point, not a specification.** The durations above are
derived from the motion tokens in §2.5 and are intended to be tuned on a real
device once the capture pipeline's actual latency is known — a slow device may
need ⑥ to stretch to cover a longer write, and a fast one may need it clamped so
it does not lag behind reality. Do not treat these numbers as precise before
device QA (`FQ-04`, gate F7). What is *not* negotiable is the ordering, and that
⑥ resolves before or with ⑦, never after.

**Hard constraints.**

| Rule | Why |
| --- | --- |
| No bounce, spring, or overshoot | Reads as playful; this is a record-keeping tool |
| No rotation or arc path — straight, decelerating travel | Arcs read as decorative |
| ⑥ must never block the shutter | A second capture must be possible immediately; the animation is fire-and-forget |
| If capture **fails**, ⑥ never runs | The motion asserts durability. Playing it on a failed write would be a lie |
| The count increments on the **database write**, not on the animation | The badge reflects committed state, never an in-flight one |

**Reduced motion (`MediaQuery.disableAnimations`).** The semantics survive intact;
only movement is removed. This is the rule the widget test in
[TEST_STRATEGY.md](TEST_STRATEGY.md) §6 pins.

| Step | Reduced-motion behaviour |
| --- | --- |
| ① reticle | Appears instantly at the tap point — **still appears** (`FLT-CAM-009`) |
| ② acquisition | No pulse; static ring |
| ③ settle | Holds ~800 ms, then disappears without a fade |
| ④ shutter | No compression. **Haptic is retained** — it is not motion |
| ⑤ flash | Omitted entirely |
| ⑥ travel | **No travel.** The thumbnail cross-fades in place, or simply updates |
| ⑦ count | Increments directly |

The user who has asked for reduced motion still learns: they aimed, it fired, the
count went up, and the thumbnail changed. They just are not shown anything moving.

### 7.2 All motion

| Interaction | Normal | Reduced motion |
| --- | --- | --- |
| **Focus** | Reticle appears at the tap, scale 1.15→1.0 over `quick`; subtle pulse while acquiring; settle; hold 600 ms; fade `standard` | Reticle appears instantly, holds 800 ms, disappears. **Still appears** — it is required feedback. |
| **Shutter** | Ring compresses 4% on press (`instant`); full-screen white flash at 30% opacity, out over `quick`; new thumbnail scales in from the shutter toward the corner | No flash, no travel. Thumbnail updates directly; count increments. |
| **Zoom (pinch)** | 1:1 with the gesture — no animation, no easing. Easing here would feel like lag. | Identical. |
| **Zoom (preset)** | Zoom animates to target over `quick`; pill background cross-fades | Value and pill change instantly. |
| **Lens switch** | Preview cross-fades through a 120 ms blur-free dip to black — hides the unavoidable reinit gap without pretending it isn't there | Straight cut. |
| **Batch commit** | "Finish batch" collapses; thumbnail stack slides toward the uploads entry over `deliberate`; count badge increments | Controls update in place. |
| **Sync state change** | Row's state area cross-fades over `standard`. **The uploading indicator is a determinate-looking but bounded pulse, not an infinite spinner** | Cross-fade omitted; text swaps. |
| **Batch completion** | Holds "Synced" 2 s, collapses over `standard` | Removed after 2 s, no collapse. |

Explicitly rejected: bouncing/springy overshoot on controls, animated background
blurs behind the camera chrome, continuously animating "syncing" shimmer, and any
looping animation on the Upload Manager. A queue that animates forever reads as a
queue that is stuck.

---

## 8. Responsive and inset behaviour

| Condition | Behaviour |
| --- | --- |
| Notch / cutout | All chrome inside `SafeArea`; **the preview deliberately extends beneath it** — full-bleed is the point. |
| Gesture navigation bar | Bottom bar padded above the inset so the shutter is never under the home indicator. |
| Small screens (< 600 dp) | Preset row scrolls horizontally rather than shrinking below the 48 dp target. |
| Large / tablet | Camera stays full-bleed with controls constrained to a max width so the shutter stays thumb-reachable; Upload Manager content caps at 640 dp. |
| Landscape | Camera supports it: controls migrate to the trailing edge, shutter stays on the natural thumb side. Upload Manager is a standard scroll. |

---

## 9. What the prototypes must let a reviewer judge

The static artefacts in [design/](design/) exist to answer, before any production
code is written:

1. Is the camera chrome restrained enough that the preview is still the content?
2. Does the absence of a close control read as confident, or as missing? (§3.1)
3. Are the zoom controls reachable one-handed, and legible over a bright scene?
4. Does the focus reticle read as feedback rather than decoration?
5. Does "Finish batch" read as completing capture rather than starting a transfer? (§3.2)
6. Is the batch affordance obvious without being permanently present?
7. Does the Upload Manager make "your photos are safe" the dominant message?
8. Is the Upload Manager scannable at a glance without feeling sparse? (§4)
9. Are the five per-item states distinguishable without colour?
10. Does the error state keep the queue reachable?
