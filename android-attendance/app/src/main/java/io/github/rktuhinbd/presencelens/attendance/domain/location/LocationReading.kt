package io.github.rktuhinbd.presencelens.attendance.domain.location

/**
 * What the app can say about the device's position right now: what it has been told
 * ([LocationKnowledge]), read against the age and the reported accuracy of the last fix.
 *
 * This is a domain type, not a UI type. It answers one question - *may the 50 m rule be
 * decided with what the app currently holds?* - and the presentation layer maps the answer to
 * a screen state. Keeping the question here is what lets both halves of "trustworthy enough"
 * (freshness and accuracy) be tested with plain JUnit, with no device and no Robolectric.
 *
 * Exactly two of these carry a position the rule may be applied to: [Fresh] does, and nothing
 * else does. [Stale] and [Imprecise] still expose a [location] because the screen keeps drawing
 * the last known marker rather than blinking, but neither may produce a distance.
 */
sealed interface LocationReading {

    /** The last usable position, if one is still worth drawing on screen. */
    val location: DeviceLocation? get() = null

    /** Observing, but no position has arrived yet. Not a failure. */
    data object Acquiring : LocationReading

    /**
     * A position recent enough *and* accurate enough to decide the 50 m rule. The only reading
     * from which attendance may be authorised.
     */
    data class Fresh(override val location: DeviceLocation) : LocationReading

    /** A position that is still the best one held, but too old to gate attendance with. */
    data class Stale(override val location: DeviceLocation) : LocationReading

    /**
     * A current position whose own error radius is too wide to resolve the boundary, or which
     * arrived with no accuracy at all ([LocationQuality.isUsableForAttendance]).
     *
     * Deliberately not a failure and deliberately not [Stale]: nothing has gone wrong and
     * nothing is out of date. The provider is still converging, which is a wait, not an error.
     */
    data class Imprecise(override val location: DeviceLocation) : LocationReading

    /** The grant disappeared while updates were running. */
    data object PermissionDenied : LocationReading

    /** A real inability to obtain a position (GEN-04). */
    data class Failed(val cause: LocationFailureCause) : LocationReading
}
