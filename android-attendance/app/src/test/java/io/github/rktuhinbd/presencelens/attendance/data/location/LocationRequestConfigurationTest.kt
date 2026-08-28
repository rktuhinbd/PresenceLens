package io.github.rktuhinbd.presencelens.attendance.data.location

import com.google.android.gms.location.Granularity
import com.google.android.gms.location.Priority
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The two request configurations, asserted rather than reviewed.
 *
 * `FusedLocationDataSource` itself cannot be unit-tested - it needs a real
 * `FusedLocationProviderClient` - but the requests it builds are plain value objects, and they
 * carry the settings that decide how trustworthy every reading in the app is. Those are worth
 * pinning: `maxUpdateAge = 0` and `waitForAccurateLocation = true` are each one character away
 * from silently reverting to the behaviour they replaced, with no test failing and nothing
 * visible on screen until a bad office anchor has already been written.
 */
class LocationRequestConfigurationTest {

    @Test
    fun `the live stream waits for an accurate first fix`() {
        val request = FusedLocationDataSource.liveUpdateRequest()

        // The setting this test exists for: under high accuracy the platform briefly holds back
        // the first delivery rather than handing over a coarse network fix. The screen has an
        // honest "Finding your location…" state to spend that in; a 200 m first fix against a
        // 50 m rule is the alternative.
        assertTrue(request.isWaitForAccurateLocation)
        assertEquals(Priority.PRIORITY_HIGH_ACCURACY, request.priority)
    }

    @Test
    fun `the live stream keeps its two-second cadence and never batches`() {
        val request = FusedLocationDataSource.liveUpdateRequest()

        assertEquals(FusedLocationDataSource.UPDATE_INTERVAL_MILLIS, request.intervalMillis)
        // Batched delivery would make the 50 m crossing appear late (AND-09). Play Services
        // floors the reported delay at the interval, so "no batching" reads back as "no delay
        // beyond a single interval" rather than as the zero that was set.
        assertEquals(request.intervalMillis, request.maxUpdateDelayMillis)
        assertEquals(0f, request.minUpdateDistanceMeters, 0f)
    }

    @Test
    fun `the office capture refuses cached positions entirely`() {
        val request = FusedLocationDataSource.officeCaptureRequest()

        // Zero, not the 10 s freshness bound the live screen uses. The anchor is written to
        // disk and every later distance is measured from it, so it must be derived now.
        assertEquals(0L, request.maxUpdateAgeMillis)
        assertEquals(
            FusedLocationDataSource.OFFICE_CAPTURE_MAX_UPDATE_AGE_MILLIS,
            request.maxUpdateAgeMillis
        )
    }

    @Test
    fun `the office capture asks for high accuracy at fine granularity`() {
        val request = FusedLocationDataSource.officeCaptureRequest()

        assertEquals(Priority.PRIORITY_HIGH_ACCURACY, request.priority)
        assertEquals(Granularity.GRANULARITY_FINE, request.granularity)
    }

    @Test
    fun `the office capture window is long enough for a cold fix and short enough to watch`() {
        val request = FusedLocationDataSource.officeCaptureRequest()

        assertEquals(FusedLocationDataSource.CURRENT_LOCATION_TIMEOUT_MILLIS, request.durationMillis)
        assertTrue(
            "capture window was ${request.durationMillis} ms",
            request.durationMillis in 28_000L..30_000L
        )
    }
}
