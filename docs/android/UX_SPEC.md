# Native Android UX Specification

**What this document is for:** it defines the visual direction and acts as a post-implementation UX contract for the Native Android Compose UI. It serves as the authoritative basis for creating the implementation-faithful HTML references in Gate B.

## Visual Direction

Governed by [ADR-012](../DECISIONS.md#adr-012): **reference-layout fidelity with premium native Material 3 execution.**
The reference screenshot's information architecture, ordering, controls, and overall composition are preserved exactly. The execution quality is elevated via typographic hierarchy, spacing rhythm, shape system, tonal surfaces, meaningful status color, complete button states, and purposeful motion. Stable Material 3 / Compose only; native Android semantics, accessibility, and touch targets take precedence over any stylistic influence.

## Source-State UX Inventory

The following represents every meaningful shipped UI condition based on the `AttendanceStatus` sealed hierarchy and associated `AttendanceMessage` session states. This explicitly maps the underlying Compose source to the presentation.

### 1. OfficeNotSet (Setup Mode)
- **Source type**: `AttendanceStatus.OfficeNotSet` (or `office = null`)
- **Trigger/precondition**: The user has granted permissions and services are on, but no office anchor is persisted.
- **Visible primary copy**: "Office Location Not Set"
- **Secondary copy**: Explains that an office location is required.
- **Primary CTA**: "Set Office Location" (initiates one-shot capture).
- **Secondary CTA**: Help/How it works.
- **Visual treatment**: The `OfficeContextCard` is in setup mode; the distance gauge is entirely hidden.
- **Gate-B HTML reference?**: YES.
- **Reason**: Distinct structural state of the screen before the primary tracking loop engages.

### 2. PermissionRequired
- **Source type**: `AttendanceStatus.PermissionRequired` / `MarkAttendanceBlocker.PERMISSION`
- **Trigger/precondition**: Location permission has not been granted or has been permanently denied.
- **Visible primary copy**: "Location permission required"
- **Secondary copy**: Explains why location is needed for attendance.
- **Primary CTA**: "Grant Location" or "Open Settings" (if permanently denied).
- **Secondary CTA**: None.
- **Visual treatment**: Surfaced within `AttendanceStatusCard` with an error/warning color scheme. Main action button is disabled.
- **Gate-B HTML reference?**: YES.
- **Reason**: Standard failure state required by GEN-04.

### 3. PreciseLocationRequired
- **Source type**: `AttendanceStatus.PreciseLocationRequired` / `MarkAttendanceBlocker.PRECISE_LOCATION`
- **Trigger/precondition**: User granted coarse-only location.
- **Visible primary copy**: "Precise location required"
- **Secondary copy**: "A precise fix is needed for a 50m radius."
- **Primary CTA**: "Enable Precise" / "Open Settings".
- **Secondary CTA**: None.
- **Visual treatment**: Similar to `PermissionRequired` but specific copy for precision.
- **Gate-B HTML reference?**: YES.
- **Reason**: Differentiates between partial grants and total denials (AMB-14).

### 4. LocationServicesDisabled
- **Source type**: `AttendanceStatus.LocationServicesDisabled` / `MarkAttendanceBlocker.SERVICES_OFF`
- **Trigger/precondition**: Global device location services are toggled off.
- **Visible primary copy**: "Location services disabled"
- **Secondary copy**: Prompt to turn on device location.
- **Primary CTA**: "Enable Location".
- **Secondary CTA**: None.
- **Visual treatment**: Surfaced within `AttendanceStatusCard`. Main action button disabled.
- **Gate-B HTML reference?**: YES.
- **Reason**: Graceful handling of hardware/OS failure (GEN-04).

### 5. AcquiringFix / RefreshingFix / ImprovingAccuracy
- **Source type**: `AttendanceStatus.AcquiringFix`, `RefreshingFix`, `ImprovingAccuracy` / `MarkAttendanceBlocker.NO_FIX`
- **Trigger/precondition**: Location services are engaged but either no fix has arrived, the fix is stale (>10s), or the error radius exceeds the acceptable bound.
- **Visible primary copy**: "Acquiring location..." or specific blocking reason in `AttendanceActionPanel`.
- **Secondary copy**: Dynamic based on progress.
- **Primary CTA**: Main action button is disabled.
- **Secondary CTA**: None.
- **Visual treatment**: Loading indicators or disabled main CTA with inline blocking reason.
- **Gate-B HTML reference?**: NO.
- **Reason**: These are transient states. Reference representations are better handled by the stable "Ready" and "Warning" states.

### 6. Tracking: Out of Range
- **Source type**: `AttendanceStatus.Tracking(proximity)` with `canMarkAttendance = false` / `MarkAttendanceBlocker.OUT_OF_RANGE`
- **Trigger/precondition**: Active precise fix, but distance to office > 50 m.
- **Visible primary copy**: Live distance readout (e.g. "120 m away").
- **Secondary copy**: Range guidance out.
- **Primary CTA**: "Mark Attendance" (Disabled).
- **Secondary CTA**: None.
- **Visual treatment**: `ProximityCard` with `RangeStatusChip` marked "OUT OF RANGE" (Error/Warning colors). Distance gauge dial filled proportionally.
- **Gate-B HTML reference?**: YES.
- **Reason**: The primary negative business logic state.

### 7. Tracking: In Range (Ready)
- **Source type**: `AttendanceStatus.Tracking(proximity)` with `canMarkAttendance = true`
- **Trigger/precondition**: Active precise fix, distance to office <= 50 m.
- **Visible primary copy**: Live distance readout (e.g. "32 m away").
- **Secondary copy**: Range guidance in.
- **Primary CTA**: "Mark Attendance" (Enabled).
- **Secondary CTA**: None.
- **Visual treatment**: `ProximityCard` with `RangeStatusChip` marked "IN RANGE" (Success colors).
- **Gate-B HTML reference?**: YES.
- **Reason**: The primary positive business logic state.

### 8. Degraded Accuracy (Modifier)
- **Source type**: `LocationQuality.DEGRADED`
- **Trigger/precondition**: Tracking is active, but the fix error radius is wide (cautionary but not immediately disqualifying).
- **Visible primary copy**: "Degraded Accuracy"
- **Secondary copy**: Mentions the specific error radius (e.g. "±60m").
- **Primary CTA**: None.
- **Secondary CTA**: None.
- **Visual treatment**: Injects a `DegradedAccuracyNotice` warning banner below the status card. Does not disable the main button on its own.
- **Gate-B HTML reference?**: YES.
- **Reason**: Explicit handling of edge-case GPS hardware behavior.

### 9. AttendanceMarked (Session State)
- **Source type**: `AttendanceMessage.AttendanceMarked` (event)
- **Trigger/precondition**: The user successfully clicked "Mark Attendance" while in range.
- **Visible primary copy**: "Attendance confirmed"
- **Secondary copy**: Time and verified distance.
- **Primary CTA**: Button converts to success state / disappears or locks.
- **Secondary CTA**: None.
- **Visual treatment**: Haptic feedback pulse; `AttendanceActionPanel` locks into a success layout.
- **Gate-B HTML reference?**: YES.
- **Reason**: The terminal success state of the application.

### 10. Office Capture / Storage Failures
- **Source type**: `AttendanceMessage.OfficeLocationCaptureFailed` or `OfficeLocationSaveFailed`
- **Trigger/precondition**: Provider timeout during setup or DataStore write exception.
- **Visible primary copy**: Snackbar message detailing the failure.
- **Secondary copy**: None.
- **Primary CTA**: Snackbar dismissal.
- **Secondary CTA**: None.
- **Visual treatment**: Material 3 Snackbar overlay.
- **Gate-B HTML reference?**: NO.
- **Reason**: A standard transient Material snackbar; does not require a dedicated full-screen HTML reference.
