package io.github.rktuhinbd.presencelens.attendance.domain.location

/**
 * The foreground location permission grant, as three mutually exclusive outcomes rather
 * than two independent booleans.
 *
 * Background location is deliberately absent — this feature is satisfied entirely while
 * `AttendanceScreen` is on screen (ADR-001), so the permission is never requested.
 */
enum class LocationPermissionStatus {
    /** Neither fine nor coarse location was granted. */
    DENIED,

    /**
     * Coarse location only. Android's approximate location is accurate to roughly a city
     * block, which cannot honestly resolve a 50 m boundary, so this is treated as
     * insufficient and surfaced as its own UI state rather than quietly accepted.
     */
    APPROXIMATE_ONLY,

    /** Fine location granted — the only grant that can drive the 50 m decision. */
    PRECISE
}
