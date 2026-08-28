package io.github.rktuhinbd.presencelens.attendance.data.local

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Repository behaviour that needs more than one write, plus read-failure recovery, exercised
 * against an in-memory `DataStore<Preferences>` so the assertions are about the mapping and
 * not about the host filesystem (see [InMemoryPreferenceDataStore] for why).
 */
@OptIn(ExperimentalCoroutinesApi::class)
class InMemoryOfficeLocationRepositoryTest {

    private val first = OfficeLocation(
        coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125),
        capturedAtEpochMillis = 1_000L
    )
    private val second = OfficeLocation(
        coordinates = GeoCoordinates(latitude = 24.0, longitude = 91.0),
        capturedAtEpochMillis = 2_000L
    )

    @Test
    fun `office location is initially absent`() = runTest(UnconfinedTestDispatcher()) {
        val repository = DataStoreOfficeLocationRepository(InMemoryPreferenceDataStore())

        assertNull(repository.officeLocation.first())
    }

    @Test
    fun `a saved office location is read back`() = runTest(UnconfinedTestDispatcher()) {
        val repository = DataStoreOfficeLocationRepository(InMemoryPreferenceDataStore())

        repository.save(first)

        assertEquals(first, repository.officeLocation.first())
    }

    @Test
    fun `saving again overwrites the previous office location`() =
        runTest(UnconfinedTestDispatcher()) {
            val repository = DataStoreOfficeLocationRepository(InMemoryPreferenceDataStore())
            repository.save(first)

            repository.save(second)

            assertEquals(second, repository.officeLocation.first())
        }

    @Test
    fun `clear removes the saved office location`() = runTest(UnconfinedTestDispatcher()) {
        val repository = DataStoreOfficeLocationRepository(InMemoryPreferenceDataStore())
        repository.save(first)

        repository.clear()

        assertNull(repository.officeLocation.first())
    }

    @Test
    fun `an unreadable store degrades to no saved office rather than crashing the screen`() =
        runTest(UnconfinedTestDispatcher()) {
            val repository = DataStoreOfficeLocationRepository(UnreadablePreferenceDataStore())

            // GEN-04: a corrupt preferences file must not take the attendance screen down
            // with it. The user simply sees "no office saved" and can capture it again.
            assertNull(repository.officeLocation.first())
        }
}
