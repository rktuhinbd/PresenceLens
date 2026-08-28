package io.github.rktuhinbd.presencelens.attendance.domain.location

/**
 * How old a position may be before the app stops deciding the 50 m rule with it.
 *
 * One threshold, deliberately. A location fix does not become wrong the moment it stops being
 * the newest one, so the screen keeps using the last usable fix while the provider works on the
 * next - that is what stops a momentary gap in delivery from flashing a failure. But attendance
 * must not stay enabled indefinitely from a position that may no longer describe where the user
 * is, so the same threshold also ends that grace.
 *
 * Age is measured against the device's monotonic elapsed-realtime clock, not the wall clock: a
 * time-zone change, an NTP correction, or a user editing the system clock would otherwise make a
 * fresh fix look hours old, or an old one look current.
 */
object LocationFreshness {

    /**
     * Ten seconds, chosen against this feature rather than inherited.
     *
     * The stream requests updates every two seconds, so this tolerates five consecutive missed
     * deliveries before the screen stops trusting the position - comfortably more than the
     * one-or-two-sample gaps a stationary device produces, which is the condition that must not
     * disturb the UI. It is also short enough to stay honest about the 50 m rule: at walking
     * pace (~1.4 m/s) ten seconds is about 14 m of possible movement, well inside the boundary
     * being tested and inside the accuracy the app already tolerates
     * ([LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS]).
     */
    const val FRESH_FIX_MAX_AGE_MILLIS = 10_000L

    /** Age of a fix in milliseconds, floored at zero so a clock skew cannot report negative. */
    fun ageMillis(fixElapsedRealtimeMillis: Long, nowElapsedRealtimeMillis: Long): Long =
        (nowElapsedRealtimeMillis - fixElapsedRealtimeMillis).coerceAtLeast(0L)

    /** Whether a fix taken at [fixElapsedRealtimeMillis] may still decide the 50 m rule. */
    fun isFresh(fixElapsedRealtimeMillis: Long, nowElapsedRealtimeMillis: Long): Boolean =
        ageMillis(fixElapsedRealtimeMillis, nowElapsedRealtimeMillis) <= FRESH_FIX_MAX_AGE_MILLIS
}
