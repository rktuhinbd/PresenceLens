package io.github.rktuhinbd.presencelens.attendance.domain.attendance

/**
 * Outcome of comparing a current position against the office location: the distance
 * (feeds AND-09's real-time readout) and whether that distance is within the
 * attendance radius (feeds AND-08's button gate).
 */
data class ProximityResult(
    val distanceMeters: Double,
    val isEligible: Boolean
)
