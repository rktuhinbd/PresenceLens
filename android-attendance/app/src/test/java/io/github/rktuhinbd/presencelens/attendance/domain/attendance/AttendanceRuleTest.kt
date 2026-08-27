package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AttendanceRuleTest {

    private val office = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)

    /**
     * Due-north displacement, where Haversine reduces exactly to `R * deltaLatRadians`
     * (deltaLon = 0), using the same Earth radius as [DistanceCalculator]. This lets the
     * boundary tests target an exact distance instead of an approximation.
     */
    private fun coordinateAtDistanceNorth(meters: Double): GeoCoordinates {
        val deltaLatRadians = meters / DistanceCalculator.EARTH_RADIUS_METERS
        val deltaLatDegrees = Math.toDegrees(deltaLatRadians)
        return GeoCoordinates(latitude = office.latitude + deltaLatDegrees, longitude = office.longitude)
    }

    @Test
    fun `0 meters is eligible`() {
        val result = AttendanceRule.evaluate(coordinateAtDistanceNorth(0.0), office)

        assertEquals(0.0, result.distanceMeters, 0.01)
        assertTrue(result.isEligible)
    }

    @Test
    fun `49_9 meters is eligible`() {
        val result = AttendanceRule.evaluate(coordinateAtDistanceNorth(49.9), office)

        assertEquals(49.9, result.distanceMeters, 0.01)
        assertTrue(result.isEligible)
    }

    @Test
    fun `50_0 meters is eligible`() {
        val result = AttendanceRule.evaluate(coordinateAtDistanceNorth(50.0), office)

        assertEquals(50.0, result.distanceMeters, 0.01)
        assertTrue(result.isEligible)
    }

    @Test
    fun `50_1 meters is not eligible`() {
        val result = AttendanceRule.evaluate(coordinateAtDistanceNorth(50.1), office)

        assertEquals(50.1, result.distanceMeters, 0.01)
        assertFalse(result.isEligible)
    }

    @Test
    fun `120 meters is not eligible`() {
        val result = AttendanceRule.evaluate(coordinateAtDistanceNorth(120.0), office)

        assertEquals(120.0, result.distanceMeters, 0.01)
        assertFalse(result.isEligible)
    }
}
