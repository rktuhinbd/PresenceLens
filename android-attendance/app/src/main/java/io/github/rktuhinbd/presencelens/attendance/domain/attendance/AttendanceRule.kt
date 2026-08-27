package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates

/**
 * The mandated 50 m attendance eligibility rule (AND-08), isolated as a pure function.
 * No `GeofencingClient`, no Android imports (ADR-001).
 */
object AttendanceRule {

    const val ELIGIBLE_RADIUS_METERS = 50.0

    /**
     * Geodesic distance math (trig round-trips through radians/degrees) does not land on
     * an exact bit-for-bit value at the radius boundary. A sub-millimetre epsilon absorbs
     * that floating-point noise without weakening the 50 m rule in any real GPS scenario.
     */
    private const val BOUNDARY_EPSILON_METERS = 1e-6

    fun evaluate(current: GeoCoordinates, office: GeoCoordinates): ProximityResult {
        val distanceMeters = DistanceCalculator.distanceMeters(current, office)
        return ProximityResult(
            distanceMeters = distanceMeters,
            isEligible = distanceMeters <= ELIGIBLE_RADIUS_METERS + BOUNDARY_EPSILON_METERS
        )
    }
}
