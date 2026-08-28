package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.ProximityResult
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFreshness
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation

/**
 * Everything `AttendanceScreen` renders, in one value (ADR-006).
 *
 * The screen is a single surface whose office panel and attendance panel are both always
 * visible (AND-04), so the always-present facts live at the top level and the mutually
 * exclusive conditions live in [status]. Nothing here is a decision the UI has to make: the
 * Composables read these fields and emit events, and never compute distance, eligibility,
 * or persistence outcomes for themselves.
 */
data class AttendanceUiState(
    val office: OfficeLocation? = null,
    val currentLocation: DeviceLocation? = null,
    val status: AttendanceStatus = AttendanceStatus.AcquiringFix,
    val isCapturingOfficeLocation: Boolean = false,
    val message: AttendanceMessage? = null,
    val markedAttendance: MarkedAttendance? = null
) {

    /** Non-null only while both a fix and a saved office exist. */
    val proximity: ProximityResult?
        get() = (status as? AttendanceStatus.Tracking)?.proximity

    /**
     * AND-08, and the single source of the Mark Attendance button's enabled state.
     *
     * Distance against the 50 m radius is the only condition, and this is a **live** value:
     * it describes where the user is now, not what they have already done. The availability
     * caption ("Office hours") is presentation-only and is deliberately absent from this
     * computation and from every path that reaches it (ADR-011).
     *
     * Fix accuracy does not appear here either. It cannot: a reading the app has refused to
     * trust never becomes [AttendanceStatus.Tracking] in the first place, so by the time this
     * property has anything to evaluate, whether the measurement is sound has already been
     * settled upstream in the domain (ADR-015). Distance remains the only rule.
     */
    val canMarkAttendance: Boolean
        get() = (status as? AttendanceStatus.Tracking)?.proximity?.isEligible == true

    /**
     * Whether attendance has been marked in this session.
     *
     * One value, read by the status card, by the action area, and by the presenter, so a
     * completed action cannot end up confirmed in one place and still offered in another.
     *
     * **A mark is an event; eligibility is a live condition** (ADR-016). Until G3.8 this read
     * `markedAttendance != null && canMarkAttendance`, which conflated the two: one stale fix,
     * or the user stepping outside the radius a minute after marking, erased a confirmation
     * that had genuinely happened. Nothing about the past had changed in either case. The
     * receipt now stands for the rest of the session, and [canMarkAttendance] goes on
     * describing the present independently - which is why the two may be true, false, or mixed
     * without contradicting each other.
     *
     * Session-scoped and nothing more: no history, no persistence, no backend (p3 Note).
     */
    val isAttendanceConfirmed: Boolean
        get() = markedAttendance != null

    /**
     * Whether "Set Office Location" may be pressed.
     *
     * Stated as the three conditions the capture actually depends on - a precise grant, the OS
     * location toggle on, and no capture already running - rather than as a list of streaming
     * states that happen to be acceptable. That inversion is the point: the capture issues its
     * **own** one-shot high-accuracy request and owns its own success and failure, so nothing
     * about the live stream's current state is a reason to refuse it. Whether the stream is
     * acquiring its first fix, refreshing a stale one, converging on a tighter one, or has
     * failed outright is not this button's business.
     *
     * Before G3.8 it was coupled to the stream, which produced the worst case of all: a user
     * whose provider was still warming up saw the one control they needed greyed out, and the
     * request that would have succeeded was never issued.
     *
     * The three states below are refusals because the one-shot request cannot succeed in them
     * either - it would return `PermissionDenied` or no fix - so offering the button would be
     * offering a guaranteed failure.
     */
    val canSetOfficeLocation: Boolean
        get() = !isCapturingOfficeLocation && when (status) {
            AttendanceStatus.PermissionRequired,
            AttendanceStatus.PreciseLocationRequired,
            AttendanceStatus.LocationServicesDisabled -> false

            else -> true
        }
}

/**
 * A mark taken in this session, with the two facts the confirmation states: when it happened,
 * and the distance that was verified at that moment.
 *
 * The pair travels together so the screen cannot show a time without the distance that earned
 * it, and the distance is captured rather than read live - "location verified" describes the
 * reading the rule was applied to, not wherever the user has drifted since.
 *
 * The assessment provides no attendance API (p3 Note), so this is session-scoped local state
 * and nothing more: no record, no history, no backend.
 */
data class MarkedAttendance(
    val atEpochMillis: Long,
    val distanceMeters: Double
)

/**
 * The screen's conditions as a closed set rather than as independent booleans, so a
 * contradictory combination cannot be constructed. In particular, a distance readout only
 * exists inside [Tracking], which makes "120 m away with no location fix" unrepresentable.
 */
sealed interface AttendanceStatus {

    /** Foreground location permission has not been granted (GEN-04). */
    data object PermissionRequired : AttendanceStatus

    /**
     * Only approximate location was granted. Android's coarse location resolves to roughly a
     * city block, which cannot decide a 50 m boundary, so it is refused explicitly rather
     * than used and quietly trusted.
     */
    data object PreciseLocationRequired : AttendanceStatus

    /** Permission is fine, but the OS location toggle is off (GEN-04). */
    data object LocationServicesDisabled : AttendanceStatus

    /** Permission and services are both fine; no usable fix has arrived yet. */
    data object AcquiringFix : AttendanceStatus

    /**
     * A current position is held, but its reported error radius is wider than the 50 m
     * boundary it would be measured against - or the provider reported no accuracy at all, in
     * which case the app fails closed rather than assuming the best (ADR-015).
     *
     * Progress, not failure, and distinct from [RefreshingFix]: nothing here is out of date.
     * The provider is converging, which for a cold GNSS fix is normal and usually brief. The
     * last position stays on the location surface, no distance is quoted from a reading that
     * cannot support one, and Mark Attendance waits for a tighter fix.
     */
    data object ImprovingAccuracy : AttendanceStatus

    /**
     * A position is held, but it is older than [LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS] and
     * so may no longer describe where the user is.
     *
     * This is not a failure and must not read as one. The provider is simply between fixes; the
     * last one stays on the location surface so nothing blinks, but it produces no distance and
     * cannot gate attendance, so Mark Attendance is unavailable until a fresh reading arrives.
     */
    data object RefreshingFix : AttendanceStatus

    /**
     * A real inability to obtain a position (GEN-04).
     *
     * Reserved for that. The provider's `LocationAvailability` estimate is documented as a best
     * guess and reaches this state only when the app has never held a position and the
     * acquisition window has passed - never as a reaction to a single availability event.
     */
    data class LocationUnavailable(val cause: LocationFailureCause) : AttendanceStatus

    /** A fix exists, but no office location has been captured yet (the Setup Phase). */
    data object OfficeNotSet : AttendanceStatus

    /**
     * Both a fix and a saved office exist, so the 50 m rule is meaningful. This is the only
     * state in which attendance can be marked, and the only one carrying a distance.
     */
    data class Tracking(val proximity: ProximityResult) : AttendanceStatus
}

/**
 * One-shot user feedback. Held in state and cleared through `onMessageShown()` rather than
 * pushed through a side channel, which keeps the whole screen describable by a single value.
 */
sealed interface AttendanceMessage {

    /** The office coordinates were captured and persisted (AND-06, AND-07). */
    data class OfficeLocationSaved(val coordinates: GeoCoordinates) : AttendanceMessage

    /**
     * The office was saved, but from a fix whose error radius sits between half the attendance
     * radius and the radius itself. Good enough to anchor from; worth one sentence saying it
     * can be improved.
     */
    data object OfficeLocationSavedWithLimitedAccuracy : AttendanceMessage

    /**
     * A position arrived but was refused as an anchor: its error radius was wider than the
     * radius it would define, or it carried no accuracy at all. **Nothing was written** - an
     * office already saved is left exactly as it was (ADR-015).
     */
    data object OfficeLocationAccuracyInsufficient : AttendanceMessage

    /** A fix was obtained but writing it to local storage failed (GEN-04). */
    data object OfficeLocationSaveFailed : AttendanceMessage

    /** No usable fix could be obtained for the capture (GEN-04). */
    data object OfficeLocationCaptureFailed : AttendanceMessage

    /** The permission disappeared between rendering the button and acting on it. */
    data object LocationPermissionMissing : AttendanceMessage

    /**
     * Attendance was marked. The assessment provides no attendance API (p3 Note), so this is
     * a local confirmation of the action and nothing more - no backend is implied or invented.
     */
    data class AttendanceMarked(val distanceMeters: Double) : AttendanceMessage
}
