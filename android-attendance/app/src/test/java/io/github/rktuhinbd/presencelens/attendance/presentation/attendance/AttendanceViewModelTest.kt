package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.DistanceCalculator
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFreshness
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationPermissionStatus
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
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
 *
 * Time is a first-class input to these tests, because freshness is a first-class input to the
 * ViewModel. [elapsedMillis] stands in for the device's monotonic clock, and [advanceClock]
 * moves it and the coroutine scheduler together so the freshness tick actually fires.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModelTest {

    private val dispatcher = UnconfinedTestDispatcher()

    /** The fake monotonic clock the ViewModel measures fix age against. */
    private var elapsedMillis = 0L

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
        // No stale distance and no stale marker may survive the toggle going off.
        assertNull(fixture.state().proximity)
        assertNull(fixture.state().currentLocation)
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

    // --- The oscillation regression ------------------------------------------------------
    //
    // Play Services documents LocationAvailability as an estimate, and on a stationary device
    // it flips to false routinely. The four tests below are the ones that would have caught the
    // Ready -> Location unavailable -> Ready flicker before it reached a screen recording.

    @Test
    fun `a provider availability report never disturbs a recent fix`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 10.0)

        // Exactly the event that used to blank the screen.
        fixture.locationDataSource.emit(LocationFix.ProviderReportedUnavailable)

        assertTrue(fixture.state().status is AttendanceStatus.Tracking)
        assertTrue(fixture.state().canMarkAttendance)
        assertNotNull(fixture.state().currentLocation)
    }

    @Test
    fun `an availability report produces no failure state at any point in the stream`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 10.0)

            // A stationary device: fixes keep arriving, availability keeps flapping.
            repeat(4) {
                fixture.locationDataSource.emit(LocationFix.ProviderReportedUnavailable)
                advanceClock(1_000)
                fixture.emitFixAt(metersFromOffice = 10.0)
            }

            // Not merely "ends up fine" - it must never have flashed, which is what the user saw.
            assertTrue(
                fixture.states.none { it.status is AttendanceStatus.LocationUnavailable }
            )
            assertTrue(fixture.states.none { it.status is AttendanceStatus.RefreshingFix })
            assertTrue(fixture.state().canMarkAttendance)
        }

    @Test
    fun `an availability report before any fix is patience, then eventually a failure`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()

            fixture.locationDataSource.emit(LocationFix.ProviderReportedUnavailable)

            // Still acquiring: the provider guessing badly is not the same as having failed.
            assertEquals(AttendanceStatus.AcquiringFix, fixture.state().status)

            advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1_000)

            // Never held a position, and the acquisition window has passed with the provider
            // saying it cannot obtain one. That is a real inability, and the only route here.
            assertEquals(
                AttendanceStatus.LocationUnavailable(LocationFailureCause.NO_FIX_AVAILABLE),
                fixture.state().status
            )
        }

    @Test
    fun `a stale fix stays neutral even while the provider reports no location`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 10.0)

            advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1_000)
            fixture.locationDataSource.emit(LocationFix.ProviderReportedUnavailable)

            assertEquals(AttendanceStatus.RefreshingFix, fixture.state().status)
        }

    // --- Freshness -----------------------------------------------------------------------

    @Test
    fun `a fix at the freshness limit still decides the rule`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 10.0)

        advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS)

        assertTrue(fixture.state().status is AttendanceStatus.Tracking)
        assertTrue(fixture.state().canMarkAttendance)
    }

    @Test
    fun `past the freshness limit attendance is disabled and the app says it is updating`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 10.0)
            assertTrue(fixture.state().canMarkAttendance)

            advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1)

            assertEquals(AttendanceStatus.RefreshingFix, fixture.state().status)
            assertFalse(fixture.state().canMarkAttendance)
            // No distance may be quoted from a position that is no longer trusted...
            assertNull(fixture.state().proximity)
            // ...but the last known position stays on the surface, so nothing blinks.
            assertNotNull(fixture.state().currentLocation)
            // And the one job the user may still need to do stays available.
            assertTrue(fixture.state().canSetOfficeLocation)
        }

    @Test
    fun `a fresh fix after a stale one resumes normal eligibility`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 10.0)
        advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1)
        assertEquals(AttendanceStatus.RefreshingFix, fixture.state().status)

        fixture.emitFixAt(metersFromOffice = 30.0)

        assertTrue(fixture.state().status is AttendanceStatus.Tracking)
        assertTrue(fixture.state().canMarkAttendance)
        assertEquals(30.0, fixture.state().proximity!!.distanceMeters, 0.5)
    }

    @Test
    fun `a stale fix recovers into the out-of-range state when that is the truth`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 10.0)
            advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1)

            fixture.emitFixAt(metersFromOffice = 255.0)

            assertTrue(fixture.state().status is AttendanceStatus.Tracking)
            assertFalse(fixture.state().canMarkAttendance)
            assertEquals(255.0, fixture.state().proximity!!.distanceMeters, 0.5)
        }

    // --- Everything else -------------------------------------------------------------------

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
                elapsedRealtimeMillis = elapsedMillis
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
                LocationFix.Failed(LocationFailureCause.NO_FIX_AVAILABLE)

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
                DeviceLocation(office, accuracyMeters = 5.0, elapsedRealtimeMillis = elapsedMillis)
            )

            fixture.viewModel.onSetOfficeLocationClicked()

            assertEquals(AttendanceMessage.OfficeLocationSaveFailed, fixture.state().message)
            assertFalse(fixture.state().isCapturingOfficeLocation)
        }

    @Test
    fun `a real provider failure clears the distance and disables the attendance action`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 5.0)
            assertTrue(fixture.state().canMarkAttendance)

            fixture.locationDataSource.emit(
                LocationFix.Failed(LocationFailureCause.PROVIDER_ERROR)
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
            assertNull(fixture.state().currentLocation)
        }

    @Test
    fun `revoking the grant reported by the screen also clears the position`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 5.0)

            fixture.viewModel.onPermissionStatusChanged(LocationPermissionStatus.DENIED)

            assertEquals(AttendanceStatus.PermissionRequired, fixture.state().status)
            assertNull(fixture.state().currentLocation)
            assertNull(fixture.state().proximity)
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
    fun `marking attendance on a stale fix does nothing`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 12.0)
        advanceClock(LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1)

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

    @Test
    fun `re-reporting the same grant does not restart the location subscription`() =
        runTest(dispatcher) {
            val fixture = Fixture(office = savedOffice)
            fixture.observe(backgroundScope)
            fixture.grantPreciseLocation()
            fixture.emitFixAt(metersFromOffice = 10.0)

            // What a resume, a permission-result callback, and a recomposition all do: report
            // the grant again. None of them is a change, and none may tear down the callback
            // and register a new one.
            repeat(5) { fixture.grantPreciseLocation() }

            assertEquals(1, fixture.locationDataSource.subscriptionsStarted)
            assertEquals(1, fixture.locationDataSource.activeSubscriptions)
        }

    @Test
    fun `the freshness tick alone never produces a new state value`() = runTest(dispatcher) {
        val fixture = Fixture(office = savedOffice)
        fixture.observe(backgroundScope)
        fixture.grantPreciseLocation()
        fixture.emitFixAt(metersFromOffice = 10.0)
        val statesBefore = fixture.states.size

        // Five ticks inside the freshness window. Nothing about the situation changed, so the
        // screen must not be handed a single new value to recompose against.
        advanceClock(5_000)

        assertEquals(statesBefore, fixture.states.size)
    }

    private inner class Fixture(office: OfficeLocation? = null) {
        val locationDataSource = FakeLocationDataSource()
        val repository = FakeOfficeLocationRepository(office)
        val serviceMonitor = FakeLocationServiceMonitor(enabled = true)
        val viewModel = AttendanceViewModel(
            locationDataSource = locationDataSource,
            officeLocationRepository = repository,
            locationServiceMonitor = serviceMonitor,
            clock = { FIXED_NOW },
            elapsedRealtime = { elapsedMillis }
        )

        /** Every value the screen would have been handed, in order. */
        val states = mutableListOf<AttendanceUiState>()

        /**
         * `WhileSubscribed` only produces state while something collects, as it does on
         * screen. Collectors go on `runTest`'s `backgroundScope` so the test body is not
         * waiting on a flow that never completes.
         */
        fun observe(scope: CoroutineScope): Job =
            scope.launch { viewModel.uiState.collect { states += it } }

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
                        elapsedRealtimeMillis = elapsedMillis
                    )
                )
            )
        }
    }

    /** Moves the device clock and the scheduler together, so the freshness tick fires. */
    private fun TestScope.advanceClock(millis: Long) {
        elapsedMillis += millis
        advanceTimeBy(millis)
        runCurrent()
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
