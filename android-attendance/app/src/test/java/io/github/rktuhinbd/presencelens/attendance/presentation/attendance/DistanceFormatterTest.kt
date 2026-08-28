package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import org.junit.Assert.assertEquals
import org.junit.Test

class DistanceFormatterTest {

    @Test
    fun `nearby distances are whole metres`() {
        assertEquals("47 m", DistanceFormatter.format(47.4))
        assertEquals("48 m", DistanceFormatter.format(47.6))
        assertEquals("120 m", DistanceFormatter.format(120.0))
    }

    @Test
    fun `the readout splits the value from the unit for the gauge`() {
        val readout = DistanceFormatter.readout(120.0)

        assertEquals("120", readout.value)
        assertEquals("m", readout.unit)
    }

    @Test
    fun `distances of a kilometre or more switch units`() {
        assertEquals("1.0 km", DistanceFormatter.format(1_000.0))
        assertEquals("1.2 km", DistanceFormatter.format(1_240.0))
    }

    @Test
    fun `very large distances drop the decimal place`() {
        assertEquals("12 km", DistanceFormatter.format(12_400.0))
    }

    @Test
    fun `the boundary between metres and kilometres is exact`() {
        assertEquals("999 m", DistanceFormatter.format(999.4))
        assertEquals("1.0 km", DistanceFormatter.format(1_000.0))
    }

    @Test
    fun `impossible readings degrade to zero rather than nonsense`() {
        assertEquals("0 m", DistanceFormatter.format(-5.0))
        assertEquals("0 m", DistanceFormatter.format(Double.NaN))
        assertEquals("0 m", DistanceFormatter.format(Double.POSITIVE_INFINITY))
    }
}
