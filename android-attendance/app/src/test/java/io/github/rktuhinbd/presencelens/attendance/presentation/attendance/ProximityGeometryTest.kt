package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ProximityGeometryTest {

    private val radius = AttendanceRule.ELIGIBLE_RADIUS_METERS

    @Test
    fun `the gauge is empty at the office and full at the boundary`() {
        assertEquals(0f, ProximityGeometry.radiusUsageFraction(0.0, radius), TOLERANCE)
        assertEquals(0.5f, ProximityGeometry.radiusUsageFraction(25.0, radius), TOLERANCE)
        assertEquals(1f, ProximityGeometry.radiusUsageFraction(50.0, radius), TOLERANCE)
    }

    @Test
    fun `the gauge saturates rather than overflowing beyond the boundary`() {
        assertEquals(1f, ProximityGeometry.radiusUsageFraction(500.0, radius), TOLERANCE)
    }

    @Test
    fun `inside the radius the marker position is literally true`() {
        assertEquals(0.4f, ProximityGeometry.surfaceRadiusFraction(20.0, radius), TOLERANCE)
        assertEquals(1f, ProximityGeometry.surfaceRadiusFraction(50.0, radius), TOLERANCE)
    }

    @Test
    fun `outside the radius the marker keeps moving but stays on the panel`() {
        val near = ProximityGeometry.surfaceRadiusFraction(120.0, radius)
        val far = ProximityGeometry.surfaceRadiusFraction(3_000.0, radius)

        assertTrue("120 m must sit outside the boundary ring", near > 1f)
        assertTrue("further away must draw further out", far > near)
        assertTrue("the marker must never leave the panel", far <= MAX_DRAWN_MULTIPLE)
    }

    @Test
    fun `impossible readings collapse to the centre instead of drawing garbage`() {
        assertEquals(0f, ProximityGeometry.surfaceRadiusFraction(Double.NaN, radius), TOLERANCE)
        assertEquals(0f, ProximityGeometry.surfaceRadiusFraction(-10.0, radius), TOLERANCE)
        assertEquals(0f, ProximityGeometry.radiusUsageFraction(10.0, 0.0), TOLERANCE)
    }

    private companion object {
        const val TOLERANCE = 0.0001f

        /** Mirrors the drawing cap in [ProximityGeometry]; nothing may be plotted past it. */
        const val MAX_DRAWN_MULTIPLE = 2.25f
    }
}
