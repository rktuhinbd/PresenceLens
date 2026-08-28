package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DistanceCalculatorTest {

    @Test
    fun `identical coordinates produce approximately 0 meters`() {
        val point = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)

        val distance = DistanceCalculator.distanceMeters(point, point)

        assertEquals(0.0, distance, 0.0001)
    }

    @Test
    fun `known nearby coordinates produce a sensible distance`() {
        // Two points exactly one degree of latitude apart, ~111.19 km along a meridian.
        val southPoint = GeoCoordinates(latitude = 23.0, longitude = 90.0)
        val northPoint = GeoCoordinates(latitude = 24.0, longitude = 90.0)

        val distance = DistanceCalculator.distanceMeters(southPoint, northPoint)

        assertEquals(111_195.0, distance, 500.0)
    }

    @Test
    fun `distance is symmetric`() {
        val a = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val b = GeoCoordinates(latitude = 23.7104, longitude = 90.4074)

        val forward = DistanceCalculator.distanceMeters(a, b)
        val backward = DistanceCalculator.distanceMeters(b, a)

        assertEquals(forward, backward, 0.0001)
    }

    @Test
    fun `bearing points north east south and west as expected`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val step = 0.01

        assertEquals(
            0.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(latitude = origin.latitude + step)
            ),
            0.1
        )
        assertEquals(
            90.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(longitude = origin.longitude + step)
            ),
            0.1
        )
        assertEquals(
            180.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(latitude = origin.latitude - step)
            ),
            0.1
        )
        assertEquals(
            270.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(longitude = origin.longitude - step)
            ),
            0.1
        )
    }

    @Test
    fun `bearing is normalised into the 0 to 360 range`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        // North-west, which the raw atan2 result would express as a negative angle.
        val target = GeoCoordinates(latitude = 23.8203, longitude = 90.4025)

        val bearing = DistanceCalculator.initialBearingDegrees(origin, target)

        assertTrue("bearing was $bearing", bearing in 0.0..360.0)
        assertEquals(317.5, bearing, 1.0)
    }
}
