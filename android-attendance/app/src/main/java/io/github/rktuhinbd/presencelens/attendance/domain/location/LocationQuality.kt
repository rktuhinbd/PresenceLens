package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule

/**
 * How much a fix's reported accuracy can be trusted against the 50 m rule (AMB-14, GEN-04).
 *
 * This classification is **advisory to the UI only**. It never gates Mark Attendance:
 * AND-08 names distance as the sole functional condition, and silently adding an accuracy
 * condition would change the mandated behaviour. A [DEGRADED] fix is surfaced to the user
 * as a caution, not converted into a refusal.
 */
enum class LocationQuality {
    /** Error radius is small enough to resolve the 50 m boundary confidently. */
    PRECISE,

    /** Error radius is comparable to (or larger than) the radius being tested. */
    DEGRADED,

    /** The provider reported no usable accuracy value, so quality cannot be judged. */
    UNKNOWN;

    companion object {
        /**
         * Half the attendance radius. An error radius above this means the reported position
         * and the true position can fall on opposite sides of the 50 m boundary, which is
         * exactly the condition worth warning about. Derived from
         * [AttendanceRule.ELIGIBLE_RADIUS_METERS] so the 50 m value is never duplicated.
         */
        const val DEGRADED_ACCURACY_THRESHOLD_METERS = AttendanceRule.ELIGIBLE_RADIUS_METERS / 2

        fun of(accuracyMeters: Double?): LocationQuality = when {
            accuracyMeters == null || accuracyMeters <= 0.0 -> UNKNOWN
            accuracyMeters <= DEGRADED_ACCURACY_THRESHOLD_METERS -> PRECISE
            else -> DEGRADED
        }
    }
}
