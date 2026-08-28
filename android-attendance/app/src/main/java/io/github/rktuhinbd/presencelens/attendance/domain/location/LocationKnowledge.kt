package io.github.rktuhinbd.presencelens.attendance.domain.location

/**
 * What the app knows about the device's position, accumulated across raw [LocationFix] events
 * (ADR-014).
 *
 * Kept separate from [LocationReading] because knowledge and presentation age differently:
 * this changes only when the platform says something, while the reading derived from it
 * changes with the passage of time as well. Folding a fix in is [after]; reading the result at
 * an instant is [readingAt].
 *
 * This lived privately inside `AttendanceViewModel` until G3.8. It is pure, it is the whole
 * "may this position decide the rule?" decision, and it has nothing to do with Android - so it
 * belongs here, where it can be exercised directly rather than only through a ViewModel and a
 * test dispatcher.
 */
data class LocationKnowledge(
    /** When observation began, used to bound how long "still acquiring" may honestly last. */
    val observingSinceElapsedMillis: Long? = null,
    val lastLocation: DeviceLocation? = null,
    val providerReportsNoLocation: Boolean = false,
    val permissionDenied: Boolean = false,
    val failure: LocationFailureCause? = null
) {

    fun after(fix: LocationFix?, nowElapsedMillis: Long): LocationKnowledge = when (fix) {
        // Not observing at all: the grant went away, so everything known about position goes
        // with it rather than lingering as a position the app cannot justify showing.
        null -> LocationKnowledge()

        is LocationFix.Available -> observingSince(nowElapsedMillis).copy(
            lastLocation = fix.location,
            providerReportsNoLocation = false,
            permissionDenied = false,
            failure = null
        )

        LocationFix.PermissionDenied -> LocationKnowledge(permissionDenied = true)

        // An estimate, recorded and nothing more. It cannot discard a fix already held.
        LocationFix.ProviderReportedUnavailable ->
            observingSince(nowElapsedMillis).copy(providerReportsNoLocation = true)

        is LocationFix.Failed -> LocationKnowledge(failure = fix.cause)
    }

    /**
     * The knowledge above, read at a moment in time.
     *
     * The two quality gates are applied in this order deliberately. **Age first:** a fix that
     * may no longer describe where the user is says nothing useful about the boundary however
     * tight its error radius was when it was taken. **Then accuracy:** a current fix whose own
     * uncertainty is wider than the radius cannot resolve the boundary either, so it produces
     * [LocationReading.Imprecise] and fails closed rather than authorising attendance from a
     * measurement that does not support the answer.
     *
     * The provider's availability estimate is escalated to a failure in exactly one case: the
     * app has never held a position, and the acquisition window has passed with the provider
     * saying it cannot obtain one. That is a genuine inability rather than a mood, and it is
     * the only path from an availability signal to "Location unavailable".
     */
    fun readingAt(nowElapsedMillis: Long): LocationReading = when {
        permissionDenied -> LocationReading.PermissionDenied

        failure != null -> LocationReading.Failed(failure)

        lastLocation != null -> when {
            !LocationFreshness.isFresh(lastLocation.elapsedRealtimeMillis, nowElapsedMillis) ->
                LocationReading.Stale(lastLocation)

            !lastLocation.quality.isUsableForAttendance ->
                LocationReading.Imprecise(lastLocation)

            else -> LocationReading.Fresh(lastLocation)
        }

        providerReportsNoLocation && observingSinceElapsedMillis != null &&
            !LocationFreshness.isFresh(observingSinceElapsedMillis, nowElapsedMillis) ->
            LocationReading.Failed(LocationFailureCause.NO_FIX_AVAILABLE)

        else -> LocationReading.Acquiring
    }

    /** Stamps the start of this observation once, so the acquisition window has an origin. */
    private fun observingSince(nowElapsedMillis: Long): LocationKnowledge =
        if (observingSinceElapsedMillis != null) {
            this
        } else {
            copy(observingSinceElapsedMillis = nowElapsedMillis)
        }
}
