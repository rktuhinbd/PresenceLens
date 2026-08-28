package io.github.rktuhinbd.presencelens.attendance.domain.location

/**
 * The outcome of asking the platform for a position. Failures are values, not exceptions,
 * so the ViewModel maps them exhaustively and fakes can reproduce them in unit tests.
 */
sealed interface LocationFix {

    /** A usable position report. */
    data class Available(val location: DeviceLocation) : LocationFix

    /** The permission was missing or was revoked while updates were running. */
    data object PermissionDenied : LocationFix

    /** The provider is reachable but produced no position. */
    data class Unavailable(val cause: LocationFailureCause) : LocationFix
}

/** Why a position could not be produced. Drives the user-facing failure copy (GEN-04). */
enum class LocationFailureCause {
    /** The provider reported that no location is currently obtainable (indoors, no signal). */
    NO_FIX_AVAILABLE,

    /** The request itself failed — Play Services error, timeout, or an unexpected fault. */
    PROVIDER_ERROR
}
