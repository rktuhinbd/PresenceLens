package io.github.rktuhinbd.presencelens.attendance.data.local

import android.content.Context
import androidx.datastore.preferences.preferencesDataStore

/**
 * Production construction seam for the office-location DataStore. Kept separate from
 * [DataStoreOfficeLocationRepository] so that class can be unit-tested without a
 * `Context` (see the JVM unit tests, which build their own file-backed DataStore).
 */
val Context.officeLocationDataStore by preferencesDataStore(name = "office_location")
