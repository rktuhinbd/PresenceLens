package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
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
        val presentation = AttendanceStatusPresenter.present(
            trackingState(distanceMeters = 220.0, markedAtEpochMillis = 1_756_000_000_000L),
            canRequestPermissionInApp = true
        )

        assertEquals(AttendanceStatusKind.OUT_OF_RANGE, presentation.kind)
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
                timestampEpochMillis = 0L
            ),
            status = AttendanceStatus.Tracking(
                AttendanceRule.evaluate(current = current, office = office)
            ),
            attendanceMarkedAtEpochMillis = markedAtEpochMillis
        )
    }

    private companion object {
        const val EARTH_RADIUS_METERS = 6_371_000.0
    }
}
