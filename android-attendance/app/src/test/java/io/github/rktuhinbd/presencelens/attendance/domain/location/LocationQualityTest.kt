package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
    fun `the unusable threshold is the attendance radius itself and is inclusive`() {
        assertEquals(
            AttendanceRule.ELIGIBLE_RADIUS_METERS,
            LocationQuality.UNUSABLE_ACCURACY_THRESHOLD_METERS,
            0.0
        )
        assertEquals(
            LocationQuality.DEGRADED,
            LocationQuality.of(AttendanceRule.ELIGIBLE_RADIUS_METERS)
        )
        assertEquals(
            LocationQuality.UNUSABLE,
            LocationQuality.of(AttendanceRule.ELIGIBLE_RADIUS_METERS + 0.1)
        )
    }

    @Test
    fun `an error radius wider than the whole area being tested is unusable`() {
        // 180 m of uncertainty around a 50 m circle is not a coarse measurement of the
        // boundary - it is not a measurement of it at all.
        assertEquals(LocationQuality.UNUSABLE, LocationQuality.of(180.0))
    }

    @Test
    fun `an unreported accuracy is unknown rather than assumed bad`() {
        // Some providers report no accuracy at all. Calling that "degraded" would show a
        // warning the app cannot actually justify.
        assertEquals(LocationQuality.UNKNOWN, LocationQuality.of(null))
        assertEquals(LocationQuality.UNKNOWN, LocationQuality.of(0.0))
        assertEquals(LocationQuality.UNKNOWN, LocationQuality.of(Double.NaN))
    }

    @Test
    fun `only precise and degraded fixes may decide the rule`() {
        // The fail-closed half: UNKNOWN is grouped with UNUSABLE, so a reading the app knows
        // nothing about can never authorise attendance.
        assertTrue(LocationQuality.PRECISE.isUsableForAttendance)
        assertTrue(LocationQuality.DEGRADED.isUsableForAttendance)
        assertFalse(LocationQuality.UNUSABLE.isUsableForAttendance)
        assertFalse(LocationQuality.UNKNOWN.isUsableForAttendance)
    }
}
