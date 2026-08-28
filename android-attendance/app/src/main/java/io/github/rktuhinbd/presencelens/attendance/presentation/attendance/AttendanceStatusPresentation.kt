package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause

/**
 * What the status card says, and why the primary action is unavailable — decided once, as a
 * pure function, rather than inside a Composable.
 *
 * `android-attendance/AGENTS.md` forbids a Composable from making a decision. Choosing which
 * of a dozen sentences the screen shows is exactly such a decision, so it is resolved here
 * where it can be unit-tested without a device, and the Composables are left to render the
 * answer.
 *
 * Nothing here participates in eligibility. [MarkAttendanceBlocker] *describes* why
 * `AttendanceUiState.canMarkAttendance` is false; it never contributes to that value, and the
 * office-hours caption (ADR-011) is absent from this file entirely.
 */

/** The visual weight of a status, resolved to colour roles by the status card. */
enum class StatusTone {
    /** Neutral information the user is expected to act on next. */
    INFO,

    /** Something is in flight; the user waits rather than acts. */
    PROGRESS,

    /** A device or permission setting is blocking progress, and the user can fix it. */
    ATTENTION,

    /** Attendance is not possible right now. Matches the "OUT OF RANGE" chip's family. */
    BLOCKED,

    /** Attendance is possible, or has just been recorded. */
    SUCCESS
}

/** The one action a status card may offer. Resolved to a callback by the screen. */
enum class StatusAction {
    REQUEST_PERMISSION,
    OPEN_APPLICATION_SETTINGS,
    OPEN_LOCATION_SETTINGS
}

/**
 * Which sentence the status card shows. A closed set, so a state the ViewModel can produce
 * cannot end up with no explanation on screen.
 */
enum class AttendanceStatusKind {
    PERMISSION_REQUIRED,
    PERMISSION_BLOCKED,
    PRECISE_REQUIRED,
    PRECISE_BLOCKED,
    SERVICES_DISABLED,
    ACQUIRING_FIX,
    LOCATION_UNAVAILABLE_NO_FIX,
    LOCATION_UNAVAILABLE_PROVIDER,
    OFFICE_NOT_SET,
    OUT_OF_RANGE,
    READY_TO_MARK,
    ATTENDANCE_MARKED
}

data class AttendanceStatusPresentation(
    val kind: AttendanceStatusKind,
    val tone: StatusTone,
    val action: StatusAction? = null
)

/**
 * Why Mark Attendance is disabled. A disabled control with no stated reason is a dead end, so
 * every blocked path names itself next to the button.
 */
enum class MarkAttendanceBlocker {
    OFFICE_NOT_SET,
    PERMISSION,
    PRECISE_LOCATION,
    SERVICES_OFF,
    NO_FIX,
    OUT_OF_RANGE
}

object AttendanceStatusPresenter {

    /**
     * [canRequestPermissionInApp] is the one input that is not in the state value: whether the
     * system will still show a permission dialog, or whether the user has to be sent to
     * settings. It changes the wording and the action, never the outcome.
     */
    fun present(
        state: AttendanceUiState,
        canRequestPermissionInApp: Boolean
    ): AttendanceStatusPresentation = when (val status = state.status) {
        AttendanceStatus.PermissionRequired -> if (canRequestPermissionInApp) {
            AttendanceStatusPresentation(
                kind = AttendanceStatusKind.PERMISSION_REQUIRED,
                tone = StatusTone.ATTENTION,
                action = StatusAction.REQUEST_PERMISSION
            )
        } else {
            AttendanceStatusPresentation(
                kind = AttendanceStatusKind.PERMISSION_BLOCKED,
                tone = StatusTone.ATTENTION,
                action = StatusAction.OPEN_APPLICATION_SETTINGS
            )
        }

        AttendanceStatus.PreciseLocationRequired -> AttendanceStatusPresentation(
            kind = if (canRequestPermissionInApp) {
                AttendanceStatusKind.PRECISE_REQUIRED
            } else {
                AttendanceStatusKind.PRECISE_BLOCKED
            },
            tone = StatusTone.ATTENTION,
            action = if (canRequestPermissionInApp) {
                StatusAction.REQUEST_PERMISSION
            } else {
                StatusAction.OPEN_APPLICATION_SETTINGS
            }
        )

        AttendanceStatus.LocationServicesDisabled -> AttendanceStatusPresentation(
            kind = AttendanceStatusKind.SERVICES_DISABLED,
            tone = StatusTone.ATTENTION,
            action = StatusAction.OPEN_LOCATION_SETTINGS
        )

        AttendanceStatus.AcquiringFix -> AttendanceStatusPresentation(
            kind = AttendanceStatusKind.ACQUIRING_FIX,
            tone = StatusTone.PROGRESS
        )

        is AttendanceStatus.LocationUnavailable -> AttendanceStatusPresentation(
            kind = when (status.cause) {
                LocationFailureCause.NO_FIX_AVAILABLE ->
                    AttendanceStatusKind.LOCATION_UNAVAILABLE_NO_FIX

                LocationFailureCause.PROVIDER_ERROR ->
                    AttendanceStatusKind.LOCATION_UNAVAILABLE_PROVIDER
            },
            tone = StatusTone.BLOCKED
        )

        AttendanceStatus.OfficeNotSet -> AttendanceStatusPresentation(
            kind = AttendanceStatusKind.OFFICE_NOT_SET,
            tone = StatusTone.INFO
        )

        is AttendanceStatus.Tracking -> when {
            // The confirmation stands only while the check-in it confirms is still true. Walk
            // out of range and the screen goes back to guiding the user, rather than leaving a
            // success message on a screen where attendance is no longer possible.
            !status.proximity.isEligible -> AttendanceStatusPresentation(
                kind = AttendanceStatusKind.OUT_OF_RANGE,
                tone = StatusTone.BLOCKED
            )

            state.attendanceMarkedAtEpochMillis != null -> AttendanceStatusPresentation(
                kind = AttendanceStatusKind.ATTENDANCE_MARKED,
                tone = StatusTone.SUCCESS
            )

            else -> AttendanceStatusPresentation(
                kind = AttendanceStatusKind.READY_TO_MARK,
                tone = StatusTone.SUCCESS
            )
        }
    }

    /**
     * `null` when attendance can be marked. Derived from the same state value the button reads,
     * so the reason and the enabled state cannot drift apart.
     */
    fun markAttendanceBlocker(state: AttendanceUiState): MarkAttendanceBlocker? {
        if (state.canMarkAttendance) return null
        return when (state.status) {
            AttendanceStatus.PermissionRequired -> MarkAttendanceBlocker.PERMISSION
            AttendanceStatus.PreciseLocationRequired -> MarkAttendanceBlocker.PRECISE_LOCATION
            AttendanceStatus.LocationServicesDisabled -> MarkAttendanceBlocker.SERVICES_OFF
            AttendanceStatus.AcquiringFix -> MarkAttendanceBlocker.NO_FIX
            is AttendanceStatus.LocationUnavailable -> MarkAttendanceBlocker.NO_FIX
            AttendanceStatus.OfficeNotSet -> MarkAttendanceBlocker.OFFICE_NOT_SET
            is AttendanceStatus.Tracking -> MarkAttendanceBlocker.OUT_OF_RANGE
        }
    }
}
