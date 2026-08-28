package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * Direct tests for the two-part "may this position decide the 50 m rule?" decision.
 *
 * These used to be reachable only through [io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceViewModel],
 * a test dispatcher and a fake clock, which meant a rule about *geometry and time* was being
 * exercised through a coroutine harness. Since G3.8 the decision is domain code and is tested
 * as what it is: a pure function of a fix, its age, and its reported accuracy.
 */
class LocationKnowledgeTest {

    private val coordinates = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)

    @Test
    fun `nothing observed yet is acquiring, not a failure`() {
        assertEquals(LocationReading.Acquiring, LocationKnowledge().readingAt(NOW))
    }

    // --- Accuracy: the prerequisite for trusting a measurement ------------------------------

    @Test
    fun `a tight recent fix is usable`() {
        val reading = readingFor(accuracyMeters = 8.0, ageMillis = 0L)

        assertEquals(LocationReading.Fresh(fix(accuracyMeters = 8.0, takenAt = NOW)), reading)
    }

    @Test
    fun `accuracy exactly at the degraded threshold is still precise and still usable`() {
        val reading = readingFor(
            accuracyMeters = LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS,
            ageMillis = 0L
        )

        assertEquals(LocationQuality.PRECISE, reading.location?.quality)
        assertReadingIs<LocationReading.Fresh>(reading)
    }

    @Test
    fun `accuracy between the two thresholds is degraded but still decides the rule`() {
        // The whole point of keeping DEGRADED usable: a 30 m error radius is worth cautioning
        // about and is not worth refusing attendance over, or nobody indoors could ever mark.
        val reading = readingFor(accuracyMeters = 30.0, ageMillis = 0L)

        assertEquals(LocationQuality.DEGRADED, reading.location?.quality)
        assertReadingIs<LocationReading.Fresh>(reading)
    }

    @Test
    fun `accuracy exactly at the attendance radius is the last usable value`() {
        val reading = readingFor(
            accuracyMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS,
            ageMillis = 0L
        )

        assertReadingIs<LocationReading.Fresh>(reading)
    }

    @Test
    fun `accuracy wider than the attendance radius cannot decide the boundary`() {
        val reading = readingFor(
            accuracyMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS + 0.1,
            ageMillis = 0L
        )

        // Not Fresh, and deliberately not Failed: the provider is converging, not broken.
        assertReadingIs<LocationReading.Imprecise>(reading)
    }

    @Test
    fun `a fix with no reported accuracy fails closed`() {
        // The app knows nothing about this reading's error. Treating that as "probably fine"
        // is the one interpretation that could authorise attendance from a city-block fix.
        assertReadingIs<LocationReading.Imprecise>(readingFor(accuracyMeters = null, ageMillis = 0L))
        assertReadingIs<LocationReading.Imprecise>(readingFor(accuracyMeters = 0.0, ageMillis = 0L))
    }

    @Test
    fun `an unusable fix is still drawn on screen`() {
        val reading = readingFor(accuracyMeters = 400.0, ageMillis = 0L)

        // The marker stays so the surface does not blink; what it may not do is produce a
        // distance, which is the ViewModel's business and follows from this not being Fresh.
        assertEquals(coordinates, reading.location?.coordinates)
    }

    // --- Freshness, and its precedence over accuracy ----------------------------------------

    @Test
    fun `a fix at the freshness limit is still fresh`() {
        assertReadingIs<LocationReading.Fresh>(
            readingFor(
                accuracyMeters = 8.0,
                ageMillis = LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS
            )
        )
    }

    @Test
    fun `a fix past the freshness limit is stale`() {
        assertReadingIs<LocationReading.Stale>(
            readingFor(
                accuracyMeters = 8.0,
                ageMillis = LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1
            )
        )
    }

    @Test
    fun `age outranks accuracy when both are bad`() {
        // Order matters and is asserted rather than assumed: a tight error radius says nothing
        // useful once the reading may no longer describe where the user is, so "wait for a
        // newer fix" is the honest sentence, not "wait for a better one".
        assertReadingIs<LocationReading.Stale>(
            readingFor(
                accuracyMeters = 400.0,
                ageMillis = LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1
            )
        )
    }

    @Test
    fun `a fresh usable fix replaces a stale one`() {
        val knowledge = LocationKnowledge()
            .after(LocationFix.Available(fix(8.0, takenAt = 0L)), 0L)
            .after(LocationFix.Available(fix(8.0, takenAt = NOW)), NOW)

        assertReadingIs<LocationReading.Fresh>(knowledge.readingAt(NOW))
    }

    // --- The availability estimate is advice, never a verdict (ADR-014) ---------------------

    @Test
    fun `an availability report never discards a fix already held`() {
        val knowledge = LocationKnowledge()
            .after(LocationFix.Available(fix(8.0, takenAt = NOW)), NOW)
            .after(LocationFix.ProviderReportedUnavailable, NOW)

        assertReadingIs<LocationReading.Fresh>(knowledge.readingAt(NOW))
    }

    @Test
    fun `an availability report with no fix ever held is patience, then a failure`() {
        val knowledge = LocationKnowledge()
            .after(LocationFix.ProviderReportedUnavailable, NOW)

        assertEquals(LocationReading.Acquiring, knowledge.readingAt(NOW))
        assertEquals(
            LocationReading.Failed(LocationFailureCause.NO_FIX_AVAILABLE),
            knowledge.readingAt(NOW + LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS + 1)
        )
    }

    // --- Terminal signals -------------------------------------------------------------------

    @Test
    fun `a revoked permission discards everything known about the position`() {
        val knowledge = LocationKnowledge()
            .after(LocationFix.Available(fix(8.0, takenAt = NOW)), NOW)
            .after(LocationFix.PermissionDenied, NOW)

        assertEquals(LocationReading.PermissionDenied, knowledge.readingAt(NOW))
        assertNull(knowledge.readingAt(NOW).location)
    }

    @Test
    fun `a real failure discards the position and names its cause`() {
        val knowledge = LocationKnowledge()
            .after(LocationFix.Available(fix(8.0, takenAt = NOW)), NOW)
            .after(LocationFix.Failed(LocationFailureCause.PROVIDER_ERROR), NOW)

        assertEquals(
            LocationReading.Failed(LocationFailureCause.PROVIDER_ERROR),
            knowledge.readingAt(NOW)
        )
        assertNull(knowledge.readingAt(NOW).location)
    }

    @Test
    fun `no longer observing resets knowledge entirely`() {
        val knowledge = LocationKnowledge()
            .after(LocationFix.Available(fix(8.0, takenAt = NOW)), NOW)
            .after(null, NOW)

        assertEquals(LocationKnowledge(), knowledge)
    }

    private fun fix(accuracyMeters: Double?, takenAt: Long) = DeviceLocation(
        coordinates = coordinates,
        accuracyMeters = accuracyMeters,
        elapsedRealtimeMillis = takenAt
    )

    private fun readingFor(accuracyMeters: Double?, ageMillis: Long): LocationReading {
        val takenAt = NOW - ageMillis
        return LocationKnowledge()
            .after(LocationFix.Available(fix(accuracyMeters, takenAt)), takenAt)
            .readingAt(NOW)
    }

    private inline fun <reified T : LocationReading> assertReadingIs(reading: LocationReading) {
        if (reading !is T) {
            throw AssertionError("expected ${T::class.simpleName} but was $reading")
        }
    }

    private companion object {
        /** Comfortably past the freshness window, so "age zero" is not the origin. */
        const val NOW = 60_000L
    }
}
