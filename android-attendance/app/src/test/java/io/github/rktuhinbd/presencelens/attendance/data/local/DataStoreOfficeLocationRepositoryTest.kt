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
 * Real file-backed coverage: the coordinates genuinely go to disk and come back, using a
 * DataStore built over a temp file rather than a `Context`, so this stays a plain JVM unit
 * test with no Robolectric and no production Android state.
 *
 * These cases each perform at most one write. Multi-write behaviour (overwrite, clear) lives
 * in [InMemoryOfficeLocationRepositoryTest] because DataStore's commit-by-rename cannot
 * overwrite an existing file on a Windows host - see [InMemoryPreferenceDataStore].
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
    fun `a saved office location survives a round trip through the file`() =
        runTest(UnconfinedTestDispatcher()) {
            val repository = repository(this)
            val location = OfficeLocation(
                coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125),
                capturedAtEpochMillis = 1_000L
            )

            repository.save(location)

            assertEquals(location, repository.officeLocation.first())
        }
}
