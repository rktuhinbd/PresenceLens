package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.DistanceCalculator
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationPermissionStatus
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.IOException

/**
 * State-behaviour tests for [AttendanceViewModel], driven entirely by fakes.
 *
 * No Play Services, no emulator, no Robolectric: the point of putting the rule in `domain`
 * and the platform behind interfaces is that the whole decision path can be exercised here.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    private val office = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
    private val savedOffice = OfficeLocation(coordinates = office, capturedAtEpochMillis = 1_000L)

    @Before
    fun setUp() {
        // viewModelScope runs on Dispatchers.Main.
        Dispatchers.setMain(dispatcher)
    }

    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun `starts by requiring permission`() = runTest(dispatcher) {
        val fixture = Fixture()
        fixture.observe(backgroundScope)

        assertEquals(AttendanceStatus.PermissionRequired, fixture.state().status)
        assertFalse(fixture.state().canMarkAttendance)
    }

    @Test
    fun `approximate location only is refused as insufficient for the 50 m rule`() =
        runTest(dispatcher) {
            val fixture = Fixture()
            fixture.observe(backgroundScope)

            fixture.viewModel.onPermissionStatusChanged(LocationPermissionStatus.APPROXIMATE_ONLY)

            assertEquals(AttendanceStatus.PreciseLocationRequired, fixture.state().status)
            assertFalse(fixture.state().canMarkAttendance)
        }

    @Test
    fun `location services being off outranks an existing fix`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 10.0)
        assertTrue(fixture.state().status is AttendanceStatus.Tracking)

        fixture.serviceMonitor.enabled.value = false

        assertEquals(AttendanceStatus.LocationServicesDisabled, fixture.state().status)
        assertFalse(fixture.state().canMarkAttendance)
        // No stale distance may survive the toggle going off.
        assertNull(fixture.state().proximity)
    }

    @Test
    fun `a fix without a saved office reports office not set`() = runTest(dispatcher) {
        val fixture = Fixture()
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        fixture.emitFixAt(metersFromOffice = 0.0)

        assertEquals(AttendanceStatus.OfficeNotSet, fixture.state().status)
        assertNull(fixture.state().proximity)
        assertFalse(fixture.state().canMarkAttendance)
        // The office can still be captured - that is the whole point of this state.
        assertTrue(fixture.state().canSetOfficeLocation)
    }

    @Test
    fun `a restored office location is applied without any user action`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        fixture.emitFixAt(metersFromOffice = 30.0)

        assertEquals(savedOffice, fixture.state().office)
        assertTrue(fixture.state().status is AttendanceStatus.Tracking)
    }

    @Test
    fun `each location update recomputes the distance`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        fixture.emitFixAt(metersFromOffice = 120.0)
        assertEquals(120.0, fixture.state().proximity!!.distanceMeters, 0.5)

        fixture.emitFixAt(metersFromOffice = 20.0)
        assertEquals(20.0, fixture.state().proximity!!.distanceMeters, 0.5)
    }

    @Test
    fun `inside the radius the attendance action is enabled`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        fixture.emitFixAt(metersFromOffice = 49.9)

        assertTrue(fixture.state().canMarkAttendance)
    }

    @Test
    fun `exactly at the radius the attendance action is still enabled`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        fixture.emitFixAt(metersFromOffice = AttendanceRule.ELIGIBLE_RADIUS_METERS)

        assertTrue(fixture.state().canMarkAttendance)
    }

    @Test
    fun `outside the radius the attendance action is disabled`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        fixture.emitFixAt(metersFromOffice = 50.1)

        assertFalse(fixture.state().canMarkAttendance)
        assertTrue(fixture.state().proximity!!.distanceMeters > AttendanceRule.ELIGIBLE_RADIUS_METERS)
    }

    @Test
    fun `a degraded fix warns but never disables the attendance action`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()

        // Error radius far wider than the rule being tested.
        fixture.emitFixAt(metersFromOffice = 10.0, accuracyMeters = 180.0)

        // AND-08 names distance as the only condition; accuracy is surfaced, not enforced.
        assertTrue(fixture.state().canMarkAttendance)
        assertEquals(180.0, fixture.state().currentLocation!!.accuracyMeters!!, 0.001)
    }

    @Test
    fun `setting the office persists the freshly captured coordinate`() = runTest(dispatcher) {
        val fixture = Fixture()
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 0.0)

        val captured = GeoCoordinates(latitude = 23.7808, longitude = 90.2793)
        fixture.locationDataSource.currentLocationFix = LocationFix.Available(
            DeviceLocation(
                coordinates = captured,
                accuracyMeters = 8.0,
                timestampEpochMillis = 5L
            )
        )

        fixture.viewModel.onSetOfficeLocationClicked()

        assertEquals(1, fixture.locationDataSource.currentLocationRequests)
        assertEquals(
            listOf(OfficeLocation(coordinates = captured, capturedAtEpochMillis = FIXED_NOW)),
            fixture.repository.savedLocations
        )
        assertEquals(captured, fixture.state().office?.coordinates)
        assertEquals(
            AttendanceMessage.OfficeLocationSaved(captured),
            fixture.state().message
        )
        assertFalse(fixture.state().isCapturingOfficeLocation)
    }

    @Test
    fun `a failed capture leaves the stored office untouched and reports the failure`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 10.0)
            fixture.locationDataSource.currentLocationFix =
                LocationFix.Unavailable(LocationFailureCause.NO_FIX_AVAILABLE)

            fixture.viewModel.onSetOfficeLocationClicked()

            assertTrue(fixture.repository.savedLocations.isEmpty())
            assertEquals(savedOffice, fixture.state().office)
            assertEquals(AttendanceMessage.OfficeLocationCaptureFailed, fixture.state().message)
        }

    @Test
    fun `a storage failure while saving the office is reported to the user`() =
        runTest(dispatcher) {
            val fixture = Fixture()
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 0.0)
            fixture.repository.saveFailure = IOException("disk full")
            fixture.locationDataSource.currentLocationFix = LocationFix.Available(
                DeviceLocation(office, accuracyMeters = 5.0, timestampEpochMillis = 1L)
            )

            fixture.viewModel.onSetOfficeLocationClicked()

            assertEquals(AttendanceMessage.OfficeLocationSaveFailed, fixture.state().message)
            assertFalse(fixture.state().isCapturingOfficeLocation)
        }

    @Test
    fun `an unavailable location clears the distance and disables the attendance action`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 5.0)
            assertTrue(fixture.state().canMarkAttendance)

            fixture.locationDataSource.emit(
                LocationFix.Unavailable(LocationFailureCause.PROVIDER_ERROR)
            )

            assertEquals(
                AttendanceStatus.LocationUnavailable(LocationFailureCause.PROVIDER_ERROR),
                fixture.state().status
            )
            assertFalse(fixture.state().canMarkAttendance)
            assertNull(fixture.state().proximity)
            assertNull(fixture.state().currentLocation)
        }

    @Test
    fun `a permission revoked mid-stream falls back to requiring permission`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 5.0)

            fixture.locationDataSource.emit(LocationFix.PermissionDenied)

            assertEquals(AttendanceStatus.PermissionRequired, fixture.state().status)
            assertFalse(fixture.state().canMarkAttendance)
        }

    @Test
    fun `marking attendance out of range does nothing`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 75.0)

        fixture.viewModel.onMarkAttendanceClicked()

        assertNull(fixture.state().message)
        assertNull(fixture.state().attendanceMarkedAtEpochMillis)
    }

    @Test
    fun `marking attendance in range confirms locally`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 12.0)

        fixture.viewModel.onMarkAttendanceClicked()

        val message = fixture.state().message
        assertTrue(message is AttendanceMessage.AttendanceMarked)
        assertEquals(12.0, (message as AttendanceMessage.AttendanceMarked).distanceMeters, 0.5)
        assertEquals(FIXED_NOW, fixture.state().attendanceMarkedAtEpochMillis)
    }

    @Test
    fun `a shown message is cleared so it cannot repeat`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 12.0)
        fixture.viewModel.onMarkAttendanceClicked()

        fixture.viewModel.onMessageShown()

        assertNull(fixture.state().message)
    }

    @Test
    fun `location updates stop once the screen stops observing`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        val job = fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 10.0)
        assertEquals(1, fixture.locationDataSource.activeSubscriptions)

        job.cancel()
        // WhileSubscribed holds the subscription briefly across configuration changes; past
        // that window the platform callback must be gone.
        advanceTimeBy(6_000)
        runCurrent()

        assertEquals(0, fixture.locationDataSource.activeSubscriptions)
    }

    private inner class Fixture(office: OfficeLocation? = null) {
        val locationDataSource = FakeLocationDataSource()
        val repository = FakeOfficeLocationRepository(office)
        val serviceMonitor = FakeLocationServiceMonitor(enabled = true)
        val viewModel = AttendanceViewModel(
            locationDataSource = locationDataSource,
            officeLocationRepository = repository,
            locationServiceMonitor = serviceMonitor,
            clock = { FIXED_NOW }
        )

        /**
         * `WhileSubscribed` only produces state while something collects, as it does on
         * screen. Collectors go on `runTest`'s `backgroundScope` so the test body is not
         * waiting on a flow that never completes.
         */
        fun observe(scope: CoroutineScope): Job = scope.launch { viewModel.uiState.collect() }

        fun state(): AttendanceUiState = viewModel.uiState.value

        fun grantPreciseLocation() {
            viewModel.onPermissionStatusChanged(LocationPermissionStatus.PRECISE)
        }

        fun emitFixAt(metersFromOffice: Double, accuracyMeters: Double? = 6.0) {
            locationDataSource.emit(
                LocationFix.Available(
                    DeviceLocation(
                        coordinates = coordinatesNorthOfOffice(metersFromOffice),
                        accuracyMeters = accuracyMeters,
                        timestampEpochMillis = FIXED_NOW
                    )
                )
            )
        }
    }

    /**
     * Displacement due north, where Haversine reduces to `R * deltaLatRadians`, so a test can
     * name an exact distance instead of an approximation.
     */
    private fun coordinatesNorthOfOffice(meters: Double): GeoCoordinates {
        val deltaLatDegrees = Math.toDegrees(meters / DistanceCalculator.EARTH_RADIUS_METERS)
        return GeoCoordinates(
            latitude = office.latitude + deltaLatDegrees,
            longitude = office.longitude
        )
    }

    private companion object {
        const val FIXED_NOW = 1_700_000_000_000L
    }
}
