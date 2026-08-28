package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationQuality
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import java.io.IOException

/**
 * Capture the current position and make it the office anchor (AND-06, AND-07).
 *
 * This is the one use case in the app, and it exists because this action is the only place
 * where a decision spans two collaborators and a policy: acquire a fresh position, judge
 * whether it is good enough to *define* the boundary, persist it, and report which of those
 * steps decided the outcome. Left in the ViewModel that sequence was presentation code holding
 * the most consequential rule in the product. Everything else the screen does is either a pure
 * function ([AttendanceRule]) or a single repository call, and wrapping those in use cases
 * would be ceremony rather than structure.
 *
 * **Why the accuracy gate is stricter here than for a live fix.** A live reading is transient:
 * a poor one is discarded a second later and the screen simply waits. The office anchor is
 * written to disk and every future distance in the app is measured from it, so a bad capture
 * is a permanent error that silently corrupts a rule the user cannot see. That asymmetry is
 * the reason a fix that is merely *unusable* for a live decision is *refused* here instead.
 *
 * Contains no user-facing copy. It returns [SetOfficeLocationResult]; the ViewModel decides
 * what to say about it.
 */
class SetOfficeLocationUseCase(
    private val locationDataSource: LocationDataSource,
    private val officeLocationRepository: OfficeLocationRepository,
    private val clock: () -> Long
) {

    suspend operator fun invoke(): SetOfficeLocationResult {
        val location = when (val fix = locationDataSource.currentLocation()) {
            is LocationFix.Available -> fix.location

            LocationFix.PermissionDenied -> return SetOfficeLocationResult.PermissionDenied

            // Neither produced a position, and the office cannot be guessed. The one already
            // saved is left exactly as it was - nothing below this line runs.
            LocationFix.ProviderReportedUnavailable,
            is LocationFix.Failed -> return SetOfficeLocationResult.NoFix
        }

        return when (location.quality) {
            // Nothing is persisted on either of these paths. Anchoring the office to a reading
            // this wide - or to one whose error is unknown - would bake the error into every
            // later distance, where it is invisible and unfixable.
            LocationQuality.UNUSABLE -> SetOfficeLocationResult.AccuracyInsufficient
            LocationQuality.UNKNOWN -> SetOfficeLocationResult.AccuracyUnavailable

            LocationQuality.PRECISE -> persist(location.coordinates)?.let(
                SetOfficeLocationResult::Saved
            ) ?: SetOfficeLocationResult.StorageFailure

            // Good enough to anchor, wide enough to mention. Saved, because refusing here
            // would leave a user indoors with no way to finish setup at all.
            LocationQuality.DEGRADED -> persist(location.coordinates)?.let(
                SetOfficeLocationResult::SavedWithLimitedAccuracy
            ) ?: SetOfficeLocationResult.StorageFailure
        }
    }

    /**
     * Writes the anchor, or `null` if local storage refused it.
     *
     * Only the captured coordinates and the capture time are stored - the accuracy that
     * qualified them is not (ADR-015). It has no later consumer: distance is measured from the
     * point, and every live fix carries its own accuracy. Persisting it would add a nullable
     * field and a migration for a number nothing would ever read back.
     */
    private suspend fun persist(coordinates: GeoCoordinates): OfficeLocation? {
        val office = OfficeLocation(coordinates = coordinates, capturedAtEpochMillis = clock())
        return try {
            officeLocationRepository.save(office)
            office
        } catch (error: IOException) {
            // Local storage can fail (full disk, corrupt file). GEN-04 requires this to reach
            // the user rather than surface as a silent no-op.
            null
        }
    }
}

/**
 * What happened when the user asked to set the office, as a closed set of outcomes rather than
 * a boolean plus a nullable error.
 *
 * Four of the seven are distinct *refusals*, which is the point: "no fix", "the fix was too
 * coarse", "the fix reported no accuracy", and "the disk refused it" fail for different
 * reasons and a reviewer should be able to see that the code distinguishes them. Only the two
 * `Saved` outcomes wrote anything.
 */
sealed interface SetOfficeLocationResult {

    /** Captured within [LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS] and persisted. */
    data class Saved(val officeLocation: OfficeLocation) : SetOfficeLocationResult

    /**
     * Persisted, but the fix's error radius was between half the attendance radius and the
     * radius itself. Usable as an anchor; worth telling the user they can do better.
     */
    data class SavedWithLimitedAccuracy(
        val officeLocation: OfficeLocation
    ) : SetOfficeLocationResult

    /** A fix arrived, but its error radius was wider than the radius it would define. */
    data object AccuracyInsufficient : SetOfficeLocationResult

    /** A fix arrived carrying no accuracy at all, so it could not be qualified. */
    data object AccuracyUnavailable : SetOfficeLocationResult

    /** The one-shot request produced no position within its window. */
    data object NoFix : SetOfficeLocationResult

    /** The location permission was missing or was revoked before the request ran. */
    data object PermissionDenied : SetOfficeLocationResult

    /** A position was captured and qualified, but writing it to local storage failed. */
    data object StorageFailure : SetOfficeLocationResult
}
