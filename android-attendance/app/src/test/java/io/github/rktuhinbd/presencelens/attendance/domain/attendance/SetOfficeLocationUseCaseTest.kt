package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationQuality
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.fakes.FakeLocationDataSource
import io.github.rktuhinbd.presencelens.attendance.fakes.FakeOfficeLocationRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

/**
 * The office-capture policy, tested where it lives - with no ViewModel, no dispatcher, and no
 * Android.
 *
 * The rule these pin is the one with permanent consequences: a bad anchor is written once and
 * then silently distorts every distance the app reports afterwards, in a way the user has no
 * way to see. So the assertion made repeatedly here is not just which result came back, but
 * whether **anything was written at all**.
 */
class SetOfficeLocationUseCaseTest {

    private val captured = GeoCoordinates(latitude = 23.780636, longitude = 90.279372)
    private val existingOffice = OfficeLocation(
        coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125),
        capturedAtEpochMillis = 1_000L
    )

    @Test
    fun `a tight fix is saved`() = runTest {
        val fixture = Fixture(available(accuracyMeters = 9.0))

        val result = fixture.useCase()

        assertEquals(
            SetOfficeLocationResult.Saved(
                OfficeLocation(coordinates = captured, capturedAtEpochMillis = NOW)
            ),
            result
        )
        assertEquals(listOf(captured), fixture.repository.savedLocations.map { it.coordinates })
        assertEquals(1, fixture.locationDataSource.currentLocationRequests)
    }

    @Test
    fun `a fix at the precise boundary is saved without a caution`() = runTest {
        val fixture = Fixture(
            available(accuracyMeters = LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS)
        )

        assertTrue(fixture.useCase() is SetOfficeLocationResult.Saved)
    }

    @Test
    fun `a degraded fix is saved, and says so`() = runTest {
        val fixture = Fixture(available(accuracyMeters = 40.0))

        val result = fixture.useCase()

        // Saved, because refusing here would strand a user indoors with no way to finish
        // setup - but reported distinctly, so the screen can offer the one thing that helps.
        assertEquals(
            SetOfficeLocationResult.SavedWithLimitedAccuracy(
                OfficeLocation(coordinates = captured, capturedAtEpochMillis = NOW)
            ),
            result
        )
        assertEquals(1, fixture.repository.savedLocations.size)
    }

    @Test
    fun `a fix at the attendance radius is the last one still accepted`() = runTest {
        val fixture = Fixture(
            available(accuracyMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS)
        )

        assertTrue(fixture.useCase() is SetOfficeLocationResult.SavedWithLimitedAccuracy)
        assertEquals(1, fixture.repository.savedLocations.size)
    }

    @Test
    fun `a fix wider than the attendance radius is refused and nothing is written`() = runTest {
        val fixture = Fixture(
            available(accuracyMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS + 0.1),
            office = existingOffice
        )

        val result = fixture.useCase()

        assertEquals(SetOfficeLocationResult.AccuracyInsufficient, result)
        assertTrue(fixture.repository.savedLocations.isEmpty())
        assertEquals(existingOffice, fixture.repository.current())
    }

    @Test
    fun `a fix carrying no accuracy is refused and nothing is written`() = runTest {
        val fixture = Fixture(available(accuracyMeters = null), office = existingOffice)

        val result = fixture.useCase()

        assertEquals(SetOfficeLocationResult.AccuracyUnavailable, result)
        assertTrue(fixture.repository.savedLocations.isEmpty())
        assertEquals(existingOffice, fixture.repository.current())
    }

    @Test
    fun `no fix within the window leaves the saved office untouched`() = runTest {
        val fixture = Fixture(
            LocationFix.Failed(LocationFailureCause.NO_FIX_AVAILABLE),
            office = existingOffice
        )

        assertEquals(SetOfficeLocationResult.NoFix, fixture.useCase())
        assertEquals(existingOffice, fixture.repository.current())
    }

    @Test
    fun `an availability estimate is not a capture and writes nothing`() = runTest {
        val fixture = Fixture(LocationFix.ProviderReportedUnavailable, office = existingOffice)

        assertEquals(SetOfficeLocationResult.NoFix, fixture.useCase())
        assertEquals(existingOffice, fixture.repository.current())
    }

    @Test
    fun `a missing permission is reported as itself, not as a failed capture`() = runTest {
        val fixture = Fixture(LocationFix.PermissionDenied)

        assertEquals(SetOfficeLocationResult.PermissionDenied, fixture.useCase())
        assertTrue(fixture.repository.savedLocations.isEmpty())
    }

    @Test
    fun `a storage failure is reported rather than swallowed`() = runTest {
        val fixture = Fixture(available(accuracyMeters = 9.0), office = existingOffice)
        fixture.repository.saveFailure = IOException("disk full")

        assertEquals(SetOfficeLocationResult.StorageFailure, fixture.useCase())
        assertEquals(existingOffice, fixture.repository.current())
    }

    @Test
    fun `a degraded fix that cannot be written reports the storage failure, not the caution`() =
        runTest {
            val fixture = Fixture(available(accuracyMeters = 40.0))
            fixture.repository.saveFailure = IOException("disk full")

            // The interesting half: the accuracy caution must not shadow the fact that nothing
            // was actually saved.
            assertEquals(SetOfficeLocationResult.StorageFailure, fixture.useCase())
        }

    @Test
    fun `the capture time comes from the clock, not from the fix`() = runTest {
        val fixture = Fixture(available(accuracyMeters = 9.0))

        val result = fixture.useCase() as SetOfficeLocationResult.Saved

        assertEquals(NOW, result.officeLocation.capturedAtEpochMillis)
    }

    private fun available(accuracyMeters: Double?) = LocationFix.Available(
        DeviceLocation(
            coordinates = captured,
            accuracyMeters = accuracyMeters,
            elapsedRealtimeMillis = 5_000L
        )
    )

    private class Fixture(fix: LocationFix, office: OfficeLocation? = null) {
        val locationDataSource = FakeLocationDataSource().apply { currentLocationFix = fix }
        val repository = FakeOfficeLocationRepository(office)
        val useCase = SetOfficeLocationUseCase(
            locationDataSource = locationDataSource,
            officeLocationRepository = repository,
            clock = { NOW }
        )
    }

    private companion object {
        const val NOW = 1_700_000_000_000L
    }
}
