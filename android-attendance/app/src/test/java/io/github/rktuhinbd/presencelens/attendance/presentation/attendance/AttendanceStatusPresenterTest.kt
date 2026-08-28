package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The status card and the disabled-button reason are the screen's whole explanation of itself,
 * so the mapping that produces them is tested here rather than left to a visual check.
 *
 * These tests also pin the two rules that are easy to regress by accident: a success
 * confirmation must not outlive the eligibility it confirms, and no blocked path may reach the
 * button without a reason attached.
 */
class AttendanceStatusPresenterTest {

    private val office = GeoCoordinates(latitude = 23.780636, longitude = 90.279372)
    private val radius = AttendanceRule.ELIGIBLE_RADIUS_METERS

    @Test
    fun `permission denied asks in app while the system dialog is still available`() {
        val presentation = present(AttendanceStatus.PermissionRequired, canRequestInApp = true)

        assertEquals(AttendanceStatusKind.PERMISSION_REQUIRED, presentation.kind)
        assertEquals(StatusTone.ATTENTION, presentation.tone)
        assertEquals(StatusAction.REQUEST_PERMISSION, presentation.action)
    }

    @Test
    fun `permission denied routes to settings once the dialog is exhausted`() {
        val presentation = present(AttendanceStatus.PermissionRequired, canRequestInApp = false)

        assertEquals(AttendanceStatusKind.PERMISSION_BLOCKED, presentation.kind)
        assertEquals(StatusAction.OPEN_APPLICATION_SETTINGS, presentation.action)
    }

    @Test
    fun `approximate-only permission is surfaced as its own state, not as a denial`() {
        val inApp = present(AttendanceStatus.PreciseLocationRequired, canRequestInApp = true)
        val viaSettings = present(AttendanceStatus.PreciseLocationRequired, canRequestInApp = false)

        assertEquals(AttendanceStatusKind.PRECISE_REQUIRED, inApp.kind)
        assertEquals(StatusAction.REQUEST_PERMISSION, inApp.action)
        assertEquals(AttendanceStatusKind.PRECISE_BLOCKED, viaSettings.kind)
        assertEquals(StatusAction.OPEN_APPLICATION_SETTINGS, viaSettings.action)
    }

    @Test
    fun `location services off offers the settings route`() {
        val presentation = present(AttendanceStatus.LocationServicesDisabled)

        assertEquals(AttendanceStatusKind.SERVICES_DISABLED, presentation.kind)
        assertEquals(StatusAction.OPEN_LOCATION_SETTINGS, presentation.action)
    }

    @Test
    fun `acquiring a fix is progress with nothing for the user to do`() {
        val presentation = present(AttendanceStatus.AcquiringFix)

        assertEquals(AttendanceStatusKind.ACQUIRING_FIX, presentation.kind)
        assertEquals(StatusTone.PROGRESS, presentation.tone)
        assertNull(presentation.action)
    }

    @Test
    fun `a stale fix reads as progress, never as a failure`() {
        val presentation = present(AttendanceStatus.RefreshingFix)

        // The whole point of the state: the provider is between fixes, so the card must not
        // borrow the wording or the tone of a real failure.
        assertEquals(AttendanceStatusKind.REFRESHING_FIX, presentation.kind)
        assertEquals(StatusTone.PROGRESS, presentation.tone)
        assertNull(presentation.action)
    }

    @Test
    fun `a stale fix names its own reason beside the disabled button`() {
        assertEquals(MarkAttendanceBlocker.STALE_FIX, blocker(AttendanceStatus.RefreshingFix))
    }

    @Test
    fun `each provider failure keeps its own explanation`() {
        val noFix = present(
            AttendanceStatus.LocationUnavailable(LocationFailureCause.NO_FIX_AVAILABLE)
        )
        val providerError = present(
            AttendanceStatus.LocationUnavailable(LocationFailureCause.PROVIDER_ERROR)
        )

        assertEquals(AttendanceStatusKind.LOCATION_UNAVAILABLE_NO_FIX, noFix.kind)
        assertEquals(AttendanceStatusKind.LOCATION_UNAVAILABLE_PROVIDER, providerError.kind)
        assertEquals(StatusTone.BLOCKED, noFix.tone)
    }

    @Test
    fun `first use reads as setup rather than as a failure`() {
        val presentation = present(AttendanceStatus.OfficeNotSet)

        assertEquals(AttendanceStatusKind.OFFICE_NOT_SET, presentation.kind)
        assertEquals(StatusTone.INFO, presentation.tone)
        assertNull(presentation.action)
    }

    @Test
    fun `outside the radius the card guides rather than congratulates`() {
        val presentation = AttendanceStatusPresenter.present(
            trackingState(distanceMeters = 220.0),
            canRequestPermissionInApp = true
        )

        assertEquals(AttendanceStatusKind.OUT_OF_RANGE, presentation.kind)
        assertEquals(StatusTone.BLOCKED, presentation.tone)
    }

    @Test
    fun `inside the radius the card says attendance can be marked`() {
        val presentation = AttendanceStatusPresenter.present(
            trackingState(distanceMeters = 20.0),
            canRequestPermissionInApp = true
        )

        assertEquals(AttendanceStatusKind.READY_TO_MARK, presentation.kind)
        assertEquals(StatusTone.SUCCESS, presentation.tone)
    }

    @Test
    fun `marking attendance replaces ready with the confirmation`() {
        val presentation = AttendanceStatusPresenter.present(
            trackingState(distanceMeters = 20.0, markedAtEpochMillis = 1_756_000_000_000L),
            canRequestPermissionInApp = true
        )

        assertEquals(AttendanceStatusKind.ATTENDANCE_MARKED, presentation.kind)
        assertEquals(StatusTone.SUCCESS, presentation.tone)
    }

    @Test
    fun `the confirmation does not outlive the eligibility it confirms`() {
        val state = trackingState(distanceMeters = 220.0, markedAtEpochMillis = MARKED_AT)
        val presentation = AttendanceStatusPresenter.present(state, canRequestPermissionInApp = true)

        assertEquals(AttendanceStatusKind.OUT_OF_RANGE, presentation.kind)
        assertFalse(state.isAttendanceConfirmed)
        // The action comes back with it: the screen is guiding again, not confirming.
        assertEquals(
            MarkAttendanceAction.BLOCKED,
            AttendanceStatusPresenter.markAttendanceAction(state)
        )
    }

    @Test
    fun `eligible and unmarked offers the action and reads as ready`() {
        val state = trackingState(distanceMeters = 20.0)

        assertEquals(
            AttendanceStatusKind.READY_TO_MARK,
            AttendanceStatusPresenter.present(state, canRequestPermissionInApp = true).kind
        )
        assertEquals(
            MarkAttendanceAction.AVAILABLE,
            AttendanceStatusPresenter.markAttendanceAction(state)
        )
        assertFalse(state.isAttendanceConfirmed)
    }

    @Test
    fun `a marked state offers no actionable Mark Attendance control`() {
        val state = trackingState(distanceMeters = 20.0, markedAtEpochMillis = MARKED_AT)

        // Not "available", and not "blocked" either - a completed action stops being rendered
        // as a control at all, so nothing button-shaped is left for a screen reader to find.
        assertEquals(
            MarkAttendanceAction.COMPLETED,
            AttendanceStatusPresenter.markAttendanceAction(state)
        )
        assertNull(AttendanceStatusPresenter.markAttendanceBlocker(state))
        assertTrue(state.isAttendanceConfirmed)
    }

    @Test
    fun `the status card stops inviting an action that is already done`() {
        val ready = trackingState(distanceMeters = 20.0)
        val marked = trackingState(distanceMeters = 20.0, markedAtEpochMillis = MARKED_AT)

        val readyKind = AttendanceStatusPresenter.present(ready, true).kind
        val markedKind = AttendanceStatusPresenter.present(marked, true).kind

        assertEquals(AttendanceStatusKind.READY_TO_MARK, readyKind)
        assertEquals(AttendanceStatusKind.ATTENDANCE_MARKED, markedKind)
        // The regression this pins: the same tone either side, but never the same sentence.
        assertEquals(StatusTone.SUCCESS, AttendanceStatusPresenter.present(marked, true).tone)
    }

    @Test
    fun `the confirmation carries the recorded time and the verified distance`() {
        val state = trackingState(distanceMeters = 20.0, markedAtEpochMillis = MARKED_AT)
        val marked = requireNotNull(state.markedAttendance)

        assertEquals(MARKED_AT, marked.atEpochMillis)
        // The distance the rule was applied to, not whatever the gauge reads later.
        assertEquals(20.0, marked.distanceMeters, 0.5)
    }

    @Test
    fun `every blocked path names a reason for the disabled button`() {
        assertEquals(
            MarkAttendanceBlocker.PERMISSION,
            blocker(AttendanceStatus.PermissionRequired)
        )
        assertEquals(
            MarkAttendanceBlocker.PRECISE_LOCATION,
            blocker(AttendanceStatus.PreciseLocationRequired)
        )
        assertEquals(
            MarkAttendanceBlocker.SERVICES_OFF,
            blocker(AttendanceStatus.LocationServicesDisabled)
        )
        assertEquals(MarkAttendanceBlocker.NO_FIX, blocker(AttendanceStatus.AcquiringFix))
        assertEquals(
            MarkAttendanceBlocker.NO_FIX,
            blocker(AttendanceStatus.LocationUnavailable(LocationFailureCause.PROVIDER_ERROR))
        )
        assertEquals(
            MarkAttendanceBlocker.OFFICE_NOT_SET,
            blocker(AttendanceStatus.OfficeNotSet)
        )
        assertEquals(
            MarkAttendanceBlocker.OUT_OF_RANGE,
            AttendanceStatusPresenter.markAttendanceBlocker(trackingState(distanceMeters = 220.0))
        )
    }

    @Test
    fun `an enabled button carries no reason`() {
        assertNull(
            AttendanceStatusPresenter.markAttendanceBlocker(trackingState(distanceMeters = 12.0))
        )
    }

    @Test
    fun `the blocker flips with the rule either side of the radius`() {
        assertNull(
            AttendanceStatusPresenter.markAttendanceBlocker(
                trackingState(distanceMeters = radius - 1.0)
            )
        )
        assertEquals(
            MarkAttendanceBlocker.OUT_OF_RANGE,
            AttendanceStatusPresenter.markAttendanceBlocker(
                trackingState(distanceMeters = radius + 1.0)
            )
        )
    }

    private fun present(
        status: AttendanceStatus,
        canRequestInApp: Boolean = true
    ): AttendanceStatusPresentation = AttendanceStatusPresenter.present(
        AttendanceUiState(status = status),
        canRequestPermissionInApp = canRequestInApp
    )

    private fun blocker(status: AttendanceStatus): MarkAttendanceBlocker? =
        AttendanceStatusPresenter.markAttendanceBlocker(AttendanceUiState(status = status))

    /** Displacement due north, so a case can name an exact distance. */
    private fun trackingState(
        distanceMeters: Double,
        markedAtEpochMillis: Long? = null
    ): AttendanceUiState {
        val current = GeoCoordinates(
            latitude = office.latitude + Math.toDegrees(distanceMeters / EARTH_RADIUS_METERS),
            longitude = office.longitude
        )
        return AttendanceUiState(
            office = OfficeLocation(coordinates = office, capturedAtEpochMillis = 0L),
            currentLocation = DeviceLocation(
                coordinates = current,
                accuracyMeters = 5.0,
                elapsedRealtimeMillis = 0L
            ),
            status = AttendanceStatus.Tracking(
                AttendanceRule.evaluate(current = current, office = office)
            ),
            markedAttendance = markedAtEpochMillis?.let {
                MarkedAttendance(atEpochMillis = it, distanceMeters = distanceMeters)
            }
        )
    }

    private companion object {
        const val EARTH_RADIUS_METERS = 6_371_000.0
        const val MARKED_AT = 1_756_000_000_000L
    }
}
