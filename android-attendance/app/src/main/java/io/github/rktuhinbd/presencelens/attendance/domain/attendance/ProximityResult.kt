package io.github.rktuhinbd.presencelens.attendance.domain.attendance

/**
 * Outcome of comparing a current position against the office location: the distance
 * (feeds AND-09's real-time readout), whether that distance is within the attendance
 * radius (feeds AND-08's button gate), and the direction from the office to the user
 * (feeds the location surface, AND-15).
 */
data class ProximityResult(
    val distanceMeters: Double,
    val isEligible: Boolean,
    val bearingFromOfficeDegrees: Double
)
