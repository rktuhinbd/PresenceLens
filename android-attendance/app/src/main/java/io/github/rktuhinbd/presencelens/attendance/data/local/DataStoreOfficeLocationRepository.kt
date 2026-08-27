package io.github.rktuhinbd.presencelens.attendance.data.local

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.doublePreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * DataStore Preferences implementation of [OfficeLocationRepository] (ADR-002).
 * Takes a [DataStore] instance rather than a `Context`, so it can be constructed
 * directly in JVM unit tests without Robolectric or production Android state.
 */
class DataStoreOfficeLocationRepository(
    private val dataStore: DataStore<Preferences>
) : OfficeLocationRepository {

    override val officeLocation: Flow<OfficeLocation?> = dataStore.data.map { preferences ->
        val latitude = preferences[LATITUDE_KEY]
        val longitude = preferences[LONGITUDE_KEY]
        val capturedAt = preferences[CAPTURED_AT_KEY]
        if (latitude == null || longitude == null || capturedAt == null) {
            null
        } else {
            OfficeLocation(
                coordinates = GeoCoordinates(latitude = latitude, longitude = longitude),
                capturedAtEpochMillis = capturedAt
            )
        }
    }

    override suspend fun save(officeLocation: OfficeLocation) {
        dataStore.edit { preferences ->
            preferences[LATITUDE_KEY] = officeLocation.coordinates.latitude
            preferences[LONGITUDE_KEY] = officeLocation.coordinates.longitude
            preferences[CAPTURED_AT_KEY] = officeLocation.capturedAtEpochMillis
        }
    }

    override suspend fun clear() {
        dataStore.edit { it.clear() }
    }

    private companion object {
        val LATITUDE_KEY = doublePreferencesKey("office_lat")
        val LONGITUDE_KEY = doublePreferencesKey("office_lon")
        val CAPTURED_AT_KEY = longPreferencesKey("captured_at")
    }
}
