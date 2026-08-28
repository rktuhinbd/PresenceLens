package io.github.rktuhinbd.presencelens.attendance.domain.location

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The threshold that decides whether a held position may still gate attendance.
 *
 * Small enough to fit on one screen, and worth pinning anyway: the boundary is inclusive by
 * design, and the monotonic clock it reads must never be allowed to produce a negative age.
 */
class LocationFreshnessTest {

    private val limit = LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS

    @Test
    fun `a fix taken now is fresh`() {
        assertTrue(LocationFreshness.isFresh(fixElapsedRealtimeMillis = 5_000, nowElapsedRealtimeMillis = 5_000))
    }

    @Test
    fun `a fix exactly at the limit is still fresh`() {
        assertTrue(
            LocationFreshness.isFresh(
                fixElapsedRealtimeMillis = 5_000,
                nowElapsedRealtimeMillis = 5_000 + limit
            )
        )
    }

    @Test
    fun `a fix one millisecond past the limit is stale`() {
        assertFalse(
            LocationFreshness.isFresh(
                fixElapsedRealtimeMillis = 5_000,
                nowElapsedRealtimeMillis = 5_000 + limit + 1
            )
        )
    }

    @Test
    fun `age is reported in milliseconds`() {
        assertEquals(
            2_500L,
            LocationFreshness.ageMillis(
                fixElapsedRealtimeMillis = 1_000,
                nowElapsedRealtimeMillis = 3_500
            )
        )
    }

    @Test
    fun `a fix stamped after now is treated as brand new rather than as negative age`() {
        // Reordered delivery should never make a position look like it arrives from the future.
        assertEquals(
            0L,
            LocationFreshness.ageMillis(
                fixElapsedRealtimeMillis = 9_000,
                nowElapsedRealtimeMillis = 8_000
            )
        )
        assertTrue(
            LocationFreshness.isFresh(
                fixElapsedRealtimeMillis = 9_000,
                nowElapsedRealtimeMillis = 8_000
            )
        )
    }

    @Test
    fun `the threshold stays well inside the boundary it protects`() {
        // At walking pace a stale-but-trusted fix must not be able to hide a radius crossing.
        val walkingPaceMetersPerSecond = 1.4
        val driftMeters = limit / 1_000.0 * walkingPaceMetersPerSecond

        assertTrue(driftMeters < LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS)
    }
}
