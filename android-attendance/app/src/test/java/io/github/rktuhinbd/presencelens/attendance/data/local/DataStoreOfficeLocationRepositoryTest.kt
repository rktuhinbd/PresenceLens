package io.github.rktuhinbd.presencelens.attendance.data.local

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

/**
 * Constructs the DataStore directly from a temp file rather than a `Context`, so this
 * runs as a plain JVM unit test with no Robolectric and no production Android state.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class DataStoreOfficeLocationRepositoryTest {

    @get:Rule
    val temporaryFolder = TemporaryFolder()

    private fun repository(scope: TestScope): DataStoreOfficeLocationRepository {
        val file = File(temporaryFolder.root, "office_location_${System.nanoTime()}.preferences_pb")
        val dataStore = PreferenceDataStoreFactory.create(scope = scope) { file }
        return DataStoreOfficeLocationRepository(dataStore)
    }

    @Test
    fun `office location is initially absent`() = runTest(UnconfinedTestDispatcher()) {
        val repository = repository(this)

        assertNull(repository.officeLocation.first())
    }

    @Test
    fun `saved office location is read back`() = runTest(UnconfinedTestDispatcher()) {
        val repository = repository(this)
        val location = OfficeLocation(
            coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125),
            capturedAtEpochMillis = 1_000L
        )

        repository.save(location)

        assertEquals(location, repository.officeLocation.first())
    }

    @Test
    fun `saving again overwrites the previous office location`() = runTest(UnconfinedTestDispatcher()) {
        val repository = repository(this)
        repository.save(
            OfficeLocation(
                coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125),
                capturedAtEpochMillis = 1_000L
            )
        )

        val updated = OfficeLocation(
            coordinates = GeoCoordinates(latitude = 24.0, longitude = 91.0),
            capturedAtEpochMillis = 2_000L
        )
        repository.save(updated)

        assertEquals(updated, repository.officeLocation.first())
    }

    @Test
    fun `clear removes the saved office location`() = runTest(UnconfinedTestDispatcher()) {
        val repository = repository(this)
        repository.save(
            OfficeLocation(
                coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125),
                capturedAtEpochMillis = 1_000L
            )
        )

        repository.clear()

        assertNull(repository.officeLocation.first())
    }
}
