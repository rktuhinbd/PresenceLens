package io.github.rktuhinbd.presencelens.attendance.domain.location

/**
 * The outcome of asking the platform for a position. Failures are values, not exceptions,
 * so the ViewModel maps them exhaustively and fakes can reproduce them in unit tests.
 *
 * The distinction between [ProviderReportedUnavailable] and [Failed] is deliberate and is the
 * whole point of this type. Play Services documents `LocationAvailability` as an *estimate* of
 * whether a location can currently be obtained - a best guess that flips to `false` routinely
 * on a stationary device while the fused engine is between confident reports. Treating that
 * guess as a failure is what made the screen oscillate between "Ready to mark attendance" and
 * "Location unavailable" every couple of seconds. Only [Failed] is a real inability.
 */
sealed interface LocationFix {

    /** A usable position report. */
    data class Available(val location: DeviceLocation) : LocationFix

    /** The permission was missing or was revoked while updates were running. */
    data object PermissionDenied : LocationFix

    /**
     * The provider's own estimate that it cannot currently produce a position - an advisory
     * signal, not an outcome. It never invalidates a fix already in hand, and on its own it
     * never produces a failure state; the freshness of the last fix decides that instead
     * ([LocationFreshness]).
     */
    data object ProviderReportedUnavailable : LocationFix

    /** The request genuinely failed and no position can be produced. */
    data class Failed(val cause: LocationFailureCause) : LocationFix
}

/** Why a position could not be produced. Drives the user-facing failure copy (GEN-04). */
enum class LocationFailureCause {
    /**
     * The normal acquisition path was exhausted without a position: a one-shot capture whose
     * window elapsed, or a stream that has never produced a fix while the provider reports it
     * cannot obtain one.
     */
    NO_FIX_AVAILABLE,

    /** The request itself failed — Play Services error, or an unexpected fault. */
    PROVIDER_ERROR
}
