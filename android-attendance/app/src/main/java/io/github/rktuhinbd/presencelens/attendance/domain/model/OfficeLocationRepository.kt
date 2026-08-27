package io.github.rktuhinbd.presencelens.attendance.domain.model

import kotlinx.coroutines.flow.Flow

/**
 * Persists the single saved office location. Implemented in `data.local` on DataStore
 * (ADR-002) so the domain layer stays free of DataStore/Android imports.
 */
interface OfficeLocationRepository {

    val officeLocation: Flow<OfficeLocation?>

    suspend fun save(officeLocation: OfficeLocation)

    suspend fun clear()
}
