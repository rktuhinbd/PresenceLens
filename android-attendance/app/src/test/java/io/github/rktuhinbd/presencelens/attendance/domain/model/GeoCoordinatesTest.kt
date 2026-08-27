package io.github.rktuhinbd.presencelens.attendance.domain.model

import org.junit.Assert.assertEquals
import org.junit.Test

class GeoCoordinatesTest {

    @Test
    fun `accepts extreme valid boundary values`() {
        val coordinates = GeoCoordinates(latitude = -90.0, longitude = -180.0)
        assertEquals(-90.0, coordinates.latitude, 0.0)
        assertEquals(-180.0, coordinates.longitude, 0.0)

        val opposite = GeoCoordinates(latitude = 90.0, longitude = 180.0)
        assertEquals(90.0, opposite.latitude, 0.0)
        assertEquals(180.0, opposite.longitude, 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects latitude above 90`() {
        GeoCoordinates(latitude = 90.1, longitude = 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects latitude below negative 90`() {
        GeoCoordinates(latitude = -90.1, longitude = 0.0)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects longitude above 180`() {
        GeoCoordinates(latitude = 0.0, longitude = 180.1)
    }

    @Test(expected = IllegalArgumentException::class)
    fun `rejects longitude below negative 180`() {
        GeoCoordinates(latitude = 0.0, longitude = -180.1)
    }
}
