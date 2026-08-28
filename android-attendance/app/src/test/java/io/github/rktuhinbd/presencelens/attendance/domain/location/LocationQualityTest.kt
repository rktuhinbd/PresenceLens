package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import org.junit.Assert.assertEquals
import org.junit.Test

class LocationQualityTest {

    @Test
    fun `a tight error radius is precise`() {
        assertEquals(LocationQuality.PRECISE, LocationQuality.of(5.0))
        assertEquals(LocationQuality.PRECISE, LocationQuality.of(24.9))
    }

    @Test
    fun `the threshold is half the attendance radius and is inclusive`() {
        assertEquals(
            AttendanceRule.ELIGIBLE_RADIUS_METERS / 2,
            LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS,
            0.0
        )
        assertEquals(LocationQuality.PRECISE, LocationQuality.of(25.0))
        assertEquals(LocationQuality.DEGRADED, LocationQuality.of(25.1))
    }

    @Test
    fun `an error radius wider than the rule is degraded`() {
        assertEquals(LocationQuality.DEGRADED, LocationQuality.of(180.0))
    }

    @Test
    fun `an unreported accuracy is unknown rather than assumed bad`() {
        // Some providers report no accuracy at all. Calling that "degraded" would show a
        // warning the app cannot actually justify.
        assertEquals(LocationQuality.UNKNOWN, LocationQuality.of(null))
        assertEquals(LocationQuality.UNKNOWN, LocationQuality.of(0.0))
    }
}
