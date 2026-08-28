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
    val attendanceMarkedAtEpochMillis: Long? = null
) {

    /** Non-null only while both a fix and a saved office exist. */
    val proximity: ProximityResult?
        get() = (status as? AttendanceStatus.Tracking)?.proximity

    /**
     * AND-08, and the single source of the Mark Attendance button's enabled state.
     *
     * Distance against the 50 m radius is the only condition. The availability caption
     * ("AVAILABLE 09:00 AM - 10:30 AM") is presentation-only and is deliberately absent from
     * this computation and from every path that reaches it (ADR-011). Fix quality is not
     * consulted either - it is surfaced as a caution, never converted into a refusal.
     */
    val canMarkAttendance: Boolean
        get() = (status as? AttendanceStatus.Tracking)?.proximity?.isEligible == true

    /**
     * "Set Office Location" needs the app to be receiving positions at all. It stays disabled
     * while a capture is already running so a double tap cannot start two requests.
     *
     * A stale streamed fix does **not** disable it: capturing the office issues its own
     * one-shot high-accuracy request, so the age of the streamed position is irrelevant to it,
     * and greying the button out there would leave the user with nothing to press for the one
     * job the screen exists to let them finish.
     */
    val canSetOfficeLocation: Boolean
        get() = !isCapturingOfficeLocation && when (status) {
            is AttendanceStatus.OfficeNotSet,
            is AttendanceStatus.RefreshingFix,
            is AttendanceStatus.Tracking -> true

            else -> false
        }
}

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
