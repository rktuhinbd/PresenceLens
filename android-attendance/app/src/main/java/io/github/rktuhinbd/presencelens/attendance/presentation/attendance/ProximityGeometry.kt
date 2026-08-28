package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import kotlin.math.exp

/**
 * The two numbers the drawn surfaces need, kept out of the Composables so they can be
 * unit-tested (AND-15, AND-17) and so the drawing code stays drawing code.
 *
 * Neither function decides anything: eligibility comes from `AttendanceRule` alone.
 */
object ProximityGeometry {

    /** Beyond the radius the marker keeps moving outward but never leaves the panel. */
    private const val MAX_OUTSIDE_RADIUS_MULTIPLE = 2.25f

    /** Controls how quickly the outside-the-radius compression flattens. */
    private const val COMPRESSION_FALLOFF = 1.5f

    /**
     * How much of the attendance radius the current distance consumes, clamped to `0..1`.
     *
     * Drives the gauge arc: empty standing on the office, full at the boundary and beyond.
     * Saturating rather than overflowing is the point - once outside, *how far* outside is
     * the readout's job, and the arc only has to say "spent".
     */
    fun radiusUsageFraction(distanceMeters: Double, radiusMeters: Double): Float {
        if (radiusMeters <= 0.0 || !distanceMeters.isFinite() || distanceMeters <= 0.0) return 0f
        return (distanceMeters / radiusMeters).coerceIn(0.0, 1.0).toFloat()
    }

    /**
     * Where to place the user marker, as a multiple of the drawn radius ring.
     *
     * Inside the radius the mapping is linear, so the marker's position against the ring is
     * literally true. Outside it compresses along an exponential curve that approaches
     * [MAX_OUTSIDE_RADIUS_MULTIPLE] without reaching it, so a user 3 km away is still drawn
     * on the panel and still visibly further out than one at 200 m.
     */
    fun surfaceRadiusFraction(distanceMeters: Double, radiusMeters: Double): Float {
        if (radiusMeters <= 0.0 || !distanceMeters.isFinite() || distanceMeters <= 0.0) return 0f
        val ratio = distanceMeters / radiusMeters
        if (ratio <= 1.0) return ratio.toFloat()

        val overshoot = ((ratio - 1.0) / COMPRESSION_FALLOFF).toFloat()
        val compressed = 1f - exp(-overshoot)
        return 1f + compressed * (MAX_OUTSIDE_RADIUS_MULTIPLE - 1f)
    }
}
