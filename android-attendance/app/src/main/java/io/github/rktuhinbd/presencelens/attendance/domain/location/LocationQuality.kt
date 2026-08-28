package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule

/**
 * How much a fix's reported accuracy can be trusted against the 50 m rule (AMB-14, GEN-04).
 *
 * **This is not a second geographic rule.** AND-08 names distance as the only condition, and
 * that is unchanged: the app never asks "is distance + accuracy inside 50 m?". What this type
 * decides is the question that comes *before* the rule - whether the fix in hand is a
 * trustworthy enough measurement to evaluate the rule with at all. A reading whose own error
 * radius exceeds the boundary being tested cannot answer "inside or outside 50 m" in either
 * direction, so authorising attendance from it would be false confidence, not compliance.
 *
 * Both thresholds are derived from [AttendanceRule.ELIGIBLE_RADIUS_METERS] so the 50 m value
 * exists in exactly one place:
 *
 * | Reported accuracy | Quality    | Usable for the rule |
 * | ----------------- | ---------- | ------------------- |
 * | `<= 25 m`         | [PRECISE]  | yes                 |
 * | `25 m .. 50 m`    | [DEGRADED] | yes, with a caution |
 * | `> 50 m`          | [UNUSABLE] | no                  |
 * | not reported      | [UNKNOWN]  | no (fails closed)   |
 */
enum class LocationQuality {
    /** Error radius is small enough to resolve the 50 m boundary confidently. */
    PRECISE,

    /**
     * Error radius is wide enough that the reading and the truth can sit on opposite sides of
     * the boundary, but still smaller than the boundary itself. The fix is used and the user
     * is cautioned; it is never converted into a refusal.
     */
    DEGRADED,

    /**
     * Error radius is at least as large as the whole area being tested. A reading like this
     * places the device somewhere inside a circle wider than the office radius, which is not a
     * measurement of the 50 m rule in any useful sense.
     */
    UNUSABLE,

    /**
     * The provider reported no usable accuracy value, so quality cannot be judged.
     *
     * Treated as not usable rather than as "probably fine": the app would otherwise be
     * authorising attendance on a reading it knows nothing about.
     */
    UNKNOWN;

    /**
     * Whether a fix of this quality may be used to decide the 50 m rule.
     *
     * Fails closed. [UNKNOWN] is deliberately grouped with [UNUSABLE] here and nowhere else -
     * the UI still distinguishes them nowhere, because to the user both mean the same thing:
     * wait a moment for a better fix.
     */
    val isUsableForAttendance: Boolean
        get() = this == PRECISE || this == DEGRADED

    companion object {
        /**
         * Half the attendance radius. An error radius above this means the reported position
         * and the true position can fall on opposite sides of the 50 m boundary, which is
         * exactly the condition worth warning about.
         */
        const val DEGRADED_ACCURACY_THRESHOLD_METERS = AttendanceRule.ELIGIBLE_RADIUS_METERS / 2

        /**
         * The attendance radius itself. Past this, the fix's own uncertainty is wider than the
         * circle being tested, so no answer it produces about the boundary means anything.
         */
        const val UNUSABLE_ACCURACY_THRESHOLD_METERS = AttendanceRule.ELIGIBLE_RADIUS_METERS

        fun of(accuracyMeters: Double?): LocationQuality = when {
            // A missing, non-finite, or non-positive value is an absent measurement, not a
            // good one. `Location.hasAccuracy()` can be false, and a zero radius is not a
            // perfect fix - it is a provider that did not fill the field in.
            accuracyMeters == null || !accuracyMeters.isFinite() || accuracyMeters <= 0.0 -> UNKNOWN

            accuracyMeters <= DEGRADED_ACCURACY_THRESHOLD_METERS -> PRECISE
            accuracyMeters <= UNUSABLE_ACCURACY_THRESHOLD_METERS -> DEGRADED
            else -> UNUSABLE
        }
    }
}
