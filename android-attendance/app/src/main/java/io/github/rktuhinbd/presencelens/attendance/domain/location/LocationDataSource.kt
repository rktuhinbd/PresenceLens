package io.github.rktuhinbd.presencelens.attendance.domain.location

import kotlinx.coroutines.flow.Flow

/**
 * Device positioning, as seen by the domain. Implemented in `data.location` over
 * `FusedLocationProviderClient` (ADR-001); no `GeofencingClient` anywhere.
 *
 * Declared here so [io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceViewModel]
 * can be unit-tested against fakes with no Play Services, no emulator and no Robolectric.
 */
interface LocationDataSource {

    /**
     * Continuous high-accuracy updates. Cold: the underlying platform callback is registered
     * on collection and removed when collection stops, which is what makes observation
     * lifecycle-aware rather than leaking for the process lifetime.
     */
    fun locationUpdates(): Flow<LocationFix>

    /**
     * A single fresh high-accuracy fix, used by "Set Office Location" (AND-06). Deliberately
     * distinct from [locationUpdates]: capturing the office is a one-shot user action, not a
     * subscription, and it must not silently reuse a stale cached position.
     */
    suspend fun currentLocation(): LocationFix
}
