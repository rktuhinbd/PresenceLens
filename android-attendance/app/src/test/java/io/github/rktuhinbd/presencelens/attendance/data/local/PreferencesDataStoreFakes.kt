package io.github.rktuhinbd.presencelens.attendance.data.local

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flow
import java.io.IOException

/**
 * In-memory stand-ins for `DataStore<Preferences>`.
 *
 * **Why these exist.** DataStore commits a write by renaming a temp file over the target.
 * On Windows `File.renameTo` refuses to overwrite an existing file, so any JVM test that
 * writes to the same DataStore *twice* fails there - deterministically, regardless of the
 * code under test. That is a host-filesystem limitation, not Android behaviour, and it is
 * not what these tests are trying to prove.
 *
 * The split is deliberate: multi-write behaviour (overwrite, clear) and read-failure
 * recovery are exercised here against a fake, while
 * [DataStoreOfficeLocationRepositoryTest] keeps real file-backed coverage for the round trip
 * that actually needs to touch a disk.
 */
class InMemoryPreferenceDataStore(
    initial: Preferences = emptyPreferences()
) : DataStore<Preferences> {

    private val state = MutableStateFlow(initial)

    override val data: Flow<Preferences> = state

    override suspend fun updateData(
        transform: suspend (t: Preferences) -> Preferences
    ): Preferences {
        val updated = transform(state.value)
        state.value = updated
        return updated
    }
}

/** A store whose reads always fail, standing in for a corrupt or unreadable preferences file. */
class UnreadablePreferenceDataStore : DataStore<Preferences> {

    override val data: Flow<Preferences> = flow { throw IOException("preferences file unreadable") }

    override suspend fun updateData(
        transform: suspend (t: Preferences) -> Preferences
    ): Preferences = throw IOException("preferences file unwritable")
}
