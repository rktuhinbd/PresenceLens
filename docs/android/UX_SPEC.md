# Native Android UX Specification

**What this document is for:** it defines the visual direction for the Native Android Compose UI and records the state inventory the shipped `AttendanceStatus` hierarchy produces. Authority order for the presentation layer (Gate B2): the shipped Compose source first, then the verified v1.0.0 runtime screenshot (`docs/assets/android/attendance-ready.png`), then this document, then the generated HTML reference under `docs/android/design/`. Where a paragraph below and the source disagree, the source is right and this document is stale - report it rather than trusting this file.

## Visual Direction

Governed by [ADR-012](../ARCHITECTURE.md#visual-direction-adr-012): **reference-layout fidelity with premium native Material 3 execution.**
The reference screenshot's information architecture, ordering, controls, and overall composition are preserved exactly. The execution quality is elevated via typographic hierarchy, spacing rhythm, shape system, tonal surfaces, meaningful status color, complete button states, and purposeful motion. Stable Material 3 / Compose only; native Android semantics, accessibility, and touch targets take precedence over any stylistic influence.

## Source-State UX Inventory

The following represents every meaningful shipped UI condition based on the `AttendanceStatusKind` closed set (`AttendanceStatusPresenter.kt`), the underlying `AttendanceStatus` sealed hierarchy, and the `AttendanceMessage` session events. Copy quoted here is taken directly from `android-attendance/app/src/main/res/values/strings.xml` - it is not paraphrased, and a future edit to this document must keep it that way.

Two facts are independent of which of the fourteen kinds is showing, and are recorded separately in [Section 3](#3-orthogonal-modifiers) rather than folded into the state table: whether an office is saved (`state.office != null`, which decides the `OfficeContextCard` face and whether `ProximityCard` renders at all) and whether the current fix is `LocationQuality.DEGRADED`.

### 1. OFFICE_NOT_SET
- **Source type**: `AttendanceStatus.OfficeNotSet`
- **Trigger/precondition**: A location fix exists and permission/services are fine, but no office anchor is persisted yet (`office = null`).
- **Title**: "Office setup required"
- **Body**: "Save your office location once to enable attendance."
- **Tone**: `INFO` (primaryContainer / onPrimaryContainer)
- **Mark Attendance**: blocked - "Set your office location to continue."
- **Visual treatment**: `OfficeContextCard` is in its setup face (title, body, filled "Set Office Location" button); `ProximityCard` is entirely absent, because a gauge with no office to measure from would have nothing to draw.
- **Reference page**: `01-setup.html`.

### 2. PERMISSION_REQUIRED
- **Source type**: `AttendanceStatus.PermissionRequired`, `canRequestPermissionInApp = true`
- **Trigger/precondition**: Foreground location permission has not been granted, and the system will still show its own request dialog (`shouldShowRequestPermissionRationale() == true`, or no request has been refused yet).
- **Title**: "Location access needed"
- **Body**: "PresenceLens compares your position with the saved office location. It uses location only while this screen is open."
- **Tone**: `ATTENTION` (warningContainer)
- **Action**: "Grant location access" (`REQUEST_PERMISSION`)
- **Mark Attendance**: blocked - "Grant location access to continue."
- **Reference page**: `05-location-permission.html` (primary frame).

### 3. PERMISSION_BLOCKED
- **Source type**: `AttendanceStatus.PermissionRequired`, `canRequestPermissionInApp = false`
- **Trigger/precondition**: The system has stopped showing its own permission dialog (`shouldShowRequestPermissionRationale() == false` after a prior refusal). Unlike the Flutter camera plugin's Android limitation (`ADR-F22`), Android's location permission API genuinely distinguishes this state via `shouldShowRequestPermissionRationale()`, so "blocked" here is a real, checkable signal rather than an inferred guess.
- **Title**: "Location access needed" (same title as kind 2 - only the body and action change)
- **Body**: "Location access was declined. Enable it for PresenceLens in app settings to continue."
- **Tone**: `ATTENTION`
- **Action**: "Open app settings" (`OPEN_APPLICATION_SETTINGS`, with the external-link glyph)
- **Mark Attendance**: blocked - "Grant location access to continue."
- **Reference page**: `05-location-permission.html` (repeated-denial variant).

### 4. PRECISE_REQUIRED
- **Source type**: `AttendanceStatus.PreciseLocationRequired`, `canRequestPermissionInApp = true`
- **Trigger/precondition**: Only `ACCESS_COARSE_LOCATION` was granted. Coarse resolves to roughly a city block, which cannot decide a 50 m boundary, so it is refused explicitly rather than trusted.
- **Title**: "Precise location required"
- **Body**: "Approximate location is accurate to roughly a city block, which cannot decide a 50 metre boundary. Switch to precise location to continue."
- **Tone**: `ATTENTION`
- **Action**: "Use precise location" (`REQUEST_PERMISSION`) - a distinct label from kind 2's "Grant location access", because the user has already granted *something*.
- **Mark Attendance**: blocked - "Precise location is required."
- **Reference page**: `06-precise-location.html` (primary frame).

### 5. PRECISE_BLOCKED
- **Source type**: `AttendanceStatus.PreciseLocationRequired`, `canRequestPermissionInApp = false`
- **Trigger/precondition**: As kind 4, with the system permission dialog also suppressed.
- **Title**: "Precise location required" (unchanged)
- **Body**: unchanged from kind 4
- **Tone**: `ATTENTION`
- **Action**: "Open app settings" (`OPEN_APPLICATION_SETTINGS`)
- **Mark Attendance**: blocked - "Precise location is required."
- **Evidence**: **no `@Preview` and no runtime screenshot exist for this kind.** It is derived directly from source (kind 4's title/body composed with kind 3's action), and the generated reference labels it as such.
- **Reference page**: `06-precise-location.html` (no-preview variant).

### 6. SERVICES_DISABLED
- **Source type**: `AttendanceStatus.LocationServicesDisabled`
- **Trigger/precondition**: Permission is granted, but the OS location toggle is off.
- **Title**: "Turn on location services"
- **Body**: "Device location is off, so your position cannot be read and attendance stays locked."
- **Tone**: `ATTENTION`
- **Action**: "Open location settings" (`OPEN_LOCATION_SETTINGS`)
- **Mark Attendance**: blocked - "Turn on device location to continue."
- **Visual treatment**: office is **set** in the canonical fixture (the `@Preview` "Location services off" saves an office first), so `OfficeContextCard` is in its configured face and `ProximityCard` renders with an empty gauge (`"—"`) - there is no active `Tracking` state to measure from.
- **Reference page**: `07-location-services-disabled.html`.

### 7. ACQUIRING_FIX
- **Source type**: `AttendanceStatus.AcquiringFix`
- **Trigger/precondition**: Permission and services are both fine; no usable fix has arrived yet.
- **Title**: "Finding your location…"
- **Body**: "Waiting for an accurate fix. This is usually quicker near a window or outdoors."
- **Tone**: `PROGRESS` (secondaryContainer) - the status badge shows a spinner, not an icon.
- **Mark Attendance**: blocked - "Waiting for your location."
- **Reference page**: `08-location-progress.html` (primary frame).

### 8. REFRESHING_FIX
- **Source type**: `AttendanceStatus.RefreshingFix`
- **Trigger/precondition**: A position is held, but it is older than the freshness window. The last known fix stays on the `LocationSurface` so nothing blinks, but no distance is quoted.
- **Title**: "Updating your location…"
- **Body**: "Waiting for a fresh GPS fix."
- **Tone**: `PROGRESS`
- **Mark Attendance**: blocked - "Waiting for a fresh GPS fix."
- **Reference page**: `08-location-progress.html` (variant - geometrically identical to kind 7, distinct banner).

### 9. IMPROVING_ACCURACY
- **Source type**: `AttendanceStatus.ImprovingAccuracy`
- **Trigger/precondition**: A current position is held, but its reported error radius is wider than the 50 m boundary (or the provider reported no accuracy at all). The provider is converging, which is progress, not failure.
- **Title**: "Improving location accuracy…"
- **Body**: "Waiting for a more precise location fix. This is usually quicker near a window or outdoors."
- **Tone**: `PROGRESS`
- **Mark Attendance**: blocked - "Waiting for a more precise location fix."
- **Reference page**: `08-location-progress.html` (variant - geometrically identical to kinds 7-8, distinct banner).

### 10. LOCATION_UNAVAILABLE_NO_FIX
- **Source type**: `AttendanceStatus.LocationUnavailable(LocationFailureCause.NO_FIX_AVAILABLE)`
- **Trigger/precondition**: The app has never held a position and the acquisition window has passed. Reserved for a real inability to obtain a position - never a reaction to a single `LocationAvailability` event.
- **Title**: "Location unavailable"
- **Body**: "No position could be obtained. Move somewhere with a clearer view of the sky and it will retry automatically."
- **Tone**: `BLOCKED` (errorContainer) - distinct from `ATTENTION`; nothing the user can do fixes this directly.
- **Mark Attendance**: blocked - "Waiting for your location."
- **Reference page**: `09-location-unavailable.html` (primary frame).

### 11. LOCATION_UNAVAILABLE_PROVIDER
- **Source type**: `AttendanceStatus.LocationUnavailable(LocationFailureCause.PROVIDER_ERROR)`
- **Trigger/precondition**: The location provider itself reported an error.
- **Title**: "Location unavailable" (same title as kind 10)
- **Body**: "The location provider reported an error. It will retry automatically." - the one line that distinguishes this kind from kind 10.
- **Tone**: `BLOCKED`
- **Mark Attendance**: blocked - "Waiting for your location."
- **Evidence**: **no `@Preview` and no runtime screenshot exist for this kind.** Geometry is identical to kind 10; only the body string differs. Source-derived, labelled as such in the generated reference.
- **Reference page**: `09-location-unavailable.html` (no-preview variant).

### 12. OUT_OF_RANGE
- **Source type**: `AttendanceStatus.Tracking(proximity)`, `proximity.isEligible = false`
- **Trigger/precondition**: A fix and a saved office both exist; distance exceeds 50 m.
- **Title**: "Move closer to the office"
- **Body**: "You're `<distance>` away. Move within 50 m to mark attendance."
- **Tone**: `BLOCKED`
- **Visual treatment**: `RangeStatusChip` reads "OUT OF RANGE" in error tones; the gauge's arc saturates at the full 50 m allowance (`ProximityGeometry.radiusUsageFraction` clamps at 1.0), while the plan-view marker itself is allowed to sit outside the boundary ring, compressing smoothly rather than clamping (`ProximityGeometry.surfaceRadiusFraction`). `AttendanceActionPanel` keeps its dashed outline and disabled button.
- **Mark Attendance**: blocked - "Move within 50 m to mark attendance."
- **Reference page**: `03-tracking-out-of-range.html`.

### 13. READY_TO_MARK
- **Source type**: `AttendanceStatus.Tracking(proximity)`, `proximity.isEligible = true`, `isAttendanceConfirmed = false`
- **Trigger/precondition**: A fix and a saved office both exist; distance is within 50 m; attendance has not yet been marked this session.
- **Title**: "Ready to mark attendance"
- **Body**: "You're `<distance>` from the office, inside the 50 m radius."
- **Tone**: `SUCCESS` (successContainer)
- **Visual treatment**: `RangeStatusChip` reads "IN RANGE"; `AttendanceActionPanel`'s outline turns solid and the Mark Attendance button becomes pressable, filled in `statusColors.success` (**not** the Material `primary` role - a distinct status colour with no Material 3 baseline equivalent).
- **Mark Attendance**: available.
- **Evidence**: **runtime screenshot** (`docs/assets/android/attendance-ready.png`, captured at 2 m) is this kind's primary evidence, alongside the "Ready to mark" `@Preview` (32 m).
- **Reference page**: `02-tracking-ready.html`.

### 14. ATTENDANCE_MARKED
- **Source type**: `AttendanceStatus.Tracking(proximity)` **with** `isAttendanceConfirmed = true` (checked *before* eligibility - `AttendanceStatusPresenter`, `ADR-016`)
- **Trigger/precondition**: The user pressed Mark Attendance while eligible. The confirmation is a **triad** of three independently-sourced facts that must not drift apart, because three different call sites read them from the same `AttendanceUiState.markedAttendance` value:
  1. **`AttendanceStatusKind.ATTENDANCE_MARKED`** - drives the status card's title/body ("Attendance marked" / "Your location was verified at `<time>`.") and stays showing even if the user later walks outside the radius, because a completed action is a fact about the past, not a live condition.
  2. **`MarkAttendanceAction.COMPLETED`** - drives `AttendanceActionPanel` to drop the dashed/solid outline and the button entirely, replacing them with a compact receipt (badge, "Attendance marked", "Location verified · `<distance>` from office", and the time on the trailing edge).
  3. **`AttendanceMessage.AttendanceMarked`** - fires exactly once, produces **no snackbar** (the success is already shown in place), and triggers only a `HapticFeedbackType.LongPress`.
- **Tone**: `SUCCESS`
- **Reference page**: `04-attendance-marked.html`.

## 2. Not modelled as a fifteenth kind: office capture / storage feedback

`OfficeLocationSaved`, `OfficeLocationSavedWithLimitedAccuracy`, `OfficeLocationAccuracyInsufficient`, `OfficeLocationSaveFailed`, `OfficeLocationCaptureFailed`, and `LocationPermissionMissing` are one-shot `AttendanceMessage` values rendered as a Material 3 `Snackbar`, never as a status-card kind. No `@Preview` exercises any of them (Compose previews cannot show a transient `LaunchedEffect`-driven snackbar). The generated reference includes exactly one representative Snackbar (`snackbar_office_saved`) in the component gallery, labelled source-derived - it is not, and must not become, a standalone reference page.

## 3. Orthogonal modifiers

These are not `AttendanceStatusKind` values. Each can, in principle, combine with several of the fourteen kinds above, and none of them is a standalone reference page - they are variants shown in the `docs/android/design/index.html` component gallery.

### 3.1 Capturing office location (`isCapturingOfficeLocation`)
- **Trigger/precondition**: The one-shot high-accuracy capture is in flight, after "Set Office Location" or "Change office location" is pressed.
- **Visual effect**: the pressed button's leading icon becomes an 18 dp spinner (label text is unchanged - AND-05 fixes it at "Set Office Location"); both office controls disable via `canSetOfficeLocation`; a `CapturingNote` expands beneath the button: "Getting a precise fix. This can take a few seconds."
- **Independent of** `AttendanceStatusKind`: capturing can occur from `OFFICE_NOT_SET` (first capture) or from any kind once an office already exists (a re-capture via "Change office location").

### 3.2 Degraded accuracy notice (`DegradedAccuracyNotice`)
- **Trigger/precondition**: `state.currentLocation?.quality == LocationQuality.DEGRADED` - the reported accuracy is wider than `AttendanceRule.ELIGIBLE_RADIUS_METERS / 2` (25 m) but no wider than the full radius (50 m). An accuracy value at or beyond 50 m is `UNUSABLE`, not `DEGRADED`, and never reaches `Tracking` at all (`LocationQuality.kt`); a value beyond 50 m is therefore **not a reachable example for this notice** - **40 m** is the canonical, production-valid example (the `@Preview` "Degraded fix" uses 40 m at a 18 m distance, deliberately inside the radius so the notice and a live `READY_TO_MARK` state can be shown together).
- **Title**: "Location accuracy is low"
- **Body**: "Accuracy is about 40 m. The distance shown may be off by roughly that much." (with the actual accuracy substituted)
- **Visual effect**: a second `StatusBanner`, in warning tones, inserted between the main status card and `OfficeContextCard`. It is a caution, never a refusal (`AMB-14`) - it never disables Mark Attendance on its own, because AND-08 names distance as the only eligibility condition.

## 4. Reference-family mapping (Gate B2)

The fourteen kinds above map to exactly nine standalone HTML pages under `docs/android/design/`, following each kind's own canonical `@Preview` fixture (or, for the two kinds with no preview, the nearest structurally-identical one) rather than a uniform assumption. The office-set/office-null axis is independent of kind and is called out per page because it changes the screen's height and the `OfficeContextCard` face, not just its copy.

| Page | Kinds | Office precondition |
|---|---|---|
| `01-setup.html` | `OFFICE_NOT_SET` | office = null, current location held |
| `02-tracking-ready.html` | `READY_TO_MARK` | office set (runtime: 2 m; preview variant: 32 m) |
| `03-tracking-out-of-range.html` | `OUT_OF_RANGE` | office set, 120 m |
| `04-attendance-marked.html` | `ATTENDANCE_MARKED` | office set, 32 m |
| `05-location-permission.html` | `PERMISSION_REQUIRED`, `PERMISSION_BLOCKED` | office = null, current location = null |
| `06-precise-location.html` | `PRECISE_REQUIRED`, `PRECISE_BLOCKED` | office = null, current location = null |
| `07-location-services-disabled.html` | `SERVICES_DISABLED` | office **set** (ProximityCard present, empty gauge) |
| `08-location-progress.html` | `ACQUIRING_FIX`, `REFRESHING_FIX`, `IMPROVING_ACCURACY` | office **set** in all three |
| `09-location-unavailable.html` | `LOCATION_UNAVAILABLE_NO_FIX`, `LOCATION_UNAVAILABLE_PROVIDER` | office **set** |

No tenth standalone page exists. The two modifiers in Section 3, plus `HowAttendanceWorksSheet`, `ChangeOfficeLocationDialog`, and one representative Snackbar, are rendered as component-gallery variants on `index.html` only.
