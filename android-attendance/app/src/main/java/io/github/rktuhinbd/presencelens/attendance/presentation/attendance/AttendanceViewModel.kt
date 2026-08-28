package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.SetOfficeLocationResult
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.SetOfficeLocationUseCase
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationKnowledge
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationPermissionStatus
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationReading
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationServiceMonitor
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.retryWhen
import kotlinx.coroutines.flow.scan
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * The single coordinator for `AttendanceScreen` (ADR-006, AND-12, GEN-01).
 *
 * Four inputs - the permission grant, the OS location toggle, the device location stream,
 * and the persisted office location - are folded into one [StateFlow] of
 * [AttendanceUiState]. Events arrive as plain function calls; nothing flows back out.
 *
 * **Lifecycle.** The whole graph hangs off `stateIn(WhileSubscribed)`, so when the screen
 * stops collecting, the upstream `callbackFlow`s are cancelled and both the Fused Location
 * callback and the location-mode broadcast receiver are torn down. Resuming re-subscribes.
 * There is no manual start/stop for the screen to forget to call.
 *
 * **Location is a retained value, not a stream of verdicts** (ADR-014). Each raw [LocationFix]
 * updates what the app knows ([LocationKnowledge]); what the app *may say* is then derived
 * from that knowledge plus the age and the accuracy of the last fix ([LocationReading]). Both
 * of those types are domain code and are tested directly - this class consumes their answer
 * and maps it to a screen state; it does not re-derive it.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModel(
    private val locationDataSource: LocationDataSource,
    private val setOfficeLocation: SetOfficeLocationUseCase,
    officeLocationRepository: OfficeLocationRepository,
    locationServiceMonitor: LocationServiceMonitor,
    private val clock: () -> Long = System::currentTimeMillis,
    private val elapsedRealtime: () -> Long = SystemClock::elapsedRealtime
) : ViewModel() {

    private val permissionStatus = MutableStateFlow(LocationPermissionStatus.DENIED)
    private val transientState = MutableStateFlow(TransientState())

    /**
     * Location is observed only under a precise grant. Anything less cannot decide a 50 m
     * boundary, and emitting `null` on the way down resets what is known so a revoked
     * permission can never leave a stale position on screen.
     */
    private val locationFixes: Flow<LocationFix?> = permissionStatus
        .flatMapLatest { permission ->
            if (permission == LocationPermissionStatus.PRECISE) {
                recoveringLocationUpdates()
            } else {
                flowOf(null)
            }
        }

    /**
     * The device location stream, with the provider's own faults treated as interruptions
     * rather than as the end of tracking.
     *
     * A `callbackFlow` that throws is a *terminated* flow: before this, one Play Services
     * fault ended location observation for as long as the screen stayed on it, and the only
     * recovery was for the user to navigate away and come back - which is not a recovery a
     * user can be expected to discover. The failure is still reported, because the screen must
     * not claim to be tracking when it is not; it is simply no longer permanent.
     *
     * `retryWhen` rather than a hand-rolled collect loop, because it preserves Kotlin's flow
     * exception transparency: only upstream failures are caught, a cancellation still cancels,
     * and `awaitClose` still removes the platform callback before each re-subscription.
     */
    private fun recoveringLocationUpdates(): Flow<LocationFix> = locationDataSource
        .locationUpdates()
        .retryWhen { _, attempt ->
            emit(LocationFix.Failed(LocationFailureCause.PROVIDER_ERROR))
            delay(RETRY_BACKOFF_MILLIS[attempt.coerceAtMost(RETRY_BACKOFF_LAST_INDEX).toInt()])
            true
        }

    /**
     * Re-evaluates freshness while nothing else is happening.
     *
     * A stale fix is the one state change with no event behind it - the provider going quiet
     * produces no emission, so without a tick the screen would keep showing a position that
     * stopped being current. It runs inside the shared flow, so it exists only while the screen
     * is observing, and [distinctUntilChanged] means a tick that changes nothing costs nothing.
     */
    private val freshnessTicks: Flow<Unit> = flow {
        while (true) {
            emit(Unit)
            delay(FRESHNESS_TICK_MILLIS)
        }
    }

    private val locationReadings: Flow<LocationReading> = combine(
        locationFixes.scan(LocationKnowledge()) { knowledge, fix ->
            knowledge.after(fix, elapsedRealtime())
        },
        freshnessTicks
    ) { knowledge, _ -> knowledge.readingAt(elapsedRealtime()) }.distinctUntilChanged()

    val uiState: StateFlow<AttendanceUiState> = combine(
        permissionStatus,
        locationServiceMonitor.locationServicesEnabled,
        locationReadings,
        officeLocationRepository.officeLocation,
        transientState
    ) { permission, locationServicesEnabled, reading, office, transient ->
        buildUiState(permission, locationServicesEnabled, reading, office, transient)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MILLIS),
        initialValue = AttendanceUiState()
    )

    /**
     * Reported by the screen on first composition, after a permission dialog, and on every
     * resume - so a grant made in system settings is picked up when the user returns.
     *
     * Backed by a `StateFlow`, so re-reporting the same grant is not a change and does not
     * restart the location subscription underneath.
     */
    fun onPermissionStatusChanged(status: LocationPermissionStatus) {
        permissionStatus.value = status
    }

    /**
     * AND-06 / AND-07, delegated to [SetOfficeLocationUseCase].
     *
     * The whole of this method is guarding against a second concurrent capture and turning a
     * domain outcome into something to say. Acquiring the position, judging whether it is good
     * enough to anchor the boundary, and persisting it are the use case's job - a decision
     * that permanent should not live in a class whose other responsibility is what colour the
     * status card is.
     */
    fun onSetOfficeLocationClicked() {
        if (transientState.value.isCapturingOfficeLocation) return

        viewModelScope.launch {
            transientState.update { it.copy(isCapturingOfficeLocation = true, message = null) }
            val message = messageFor(setOfficeLocation())
            transientState.update { it.copy(isCapturingOfficeLocation = false, message = message) }
        }
    }

    /**
     * AND-08. The rule is re-evaluated here rather than trusted from the rendered button:
     * a tap can land on a frame whose enabled state is one location emission out of date.
     *
     * There is no attendance API in the assessment (p3 Note), so a successful mark produces
     * local confirmation only. No network call is invented to fill the gap.
     */
    fun onMarkAttendanceClicked() {
        val status = uiState.value.status
        if (status !is AttendanceStatus.Tracking || !status.proximity.isEligible) return

        transientState.update {
            it.copy(
                message = AttendanceMessage.AttendanceMarked(status.proximity.distanceMeters),
                // The distance is recorded here, at the instant the rule was applied, so the
                // confirmation can state what was verified rather than where the user has
                // drifted to since.
                markedAttendance = MarkedAttendance(
                    atEpochMillis = clock(),
                    distanceMeters = status.proximity.distanceMeters
                )
            )
        }
    }

    fun onMessageShown() {
        transientState.update { it.copy(message = null) }
    }

    /**
     * The domain's outcome, translated into something the user can read.
     *
     * The translation lives here and only here: [SetOfficeLocationResult] carries no copy, so
     * the rule about what counts as a good enough anchor is stated once, in the domain, and is
     * not reachable through a string resource.
     *
     * The two refusals collapse to one message deliberately. "The fix was too coarse" and "the
     * fix reported no accuracy" are different facts about the provider and identical advice to
     * the user, and inventing a second sentence would be precision the reader cannot act on.
     */
    private fun messageFor(result: SetOfficeLocationResult): AttendanceMessage = when (result) {
        is SetOfficeLocationResult.Saved ->
            AttendanceMessage.OfficeLocationSaved(result.officeLocation.coordinates)

        is SetOfficeLocationResult.SavedWithLimitedAccuracy ->
            AttendanceMessage.OfficeLocationSavedWithLimitedAccuracy

        SetOfficeLocationResult.AccuracyInsufficient,
        SetOfficeLocationResult.AccuracyUnavailable ->
            AttendanceMessage.OfficeLocationAccuracyInsufficient

        SetOfficeLocationResult.NoFix -> AttendanceMessage.OfficeLocationCaptureFailed
        SetOfficeLocationResult.PermissionDenied -> AttendanceMessage.LocationPermissionMissing
        SetOfficeLocationResult.StorageFailure -> AttendanceMessage.OfficeLocationSaveFailed
    }

    /**
     * The ordering below is the whole failure model. Permission outranks everything because
     * nothing else is knowable without it; the services toggle outranks any fix already in
     * hand, so switching location off cannot leave a stale distance on screen.
     *
     * [LocationReading.Stale] and [LocationReading.Imprecise] both sit between "no fix at all"
     * and "tracking": the position is kept on the location surface so the screen does not
     * blink, but neither produces a distance, so [AttendanceUiState.canMarkAttendance] is false
     * and the user is told the app is still working rather than that something failed. They are
     * separate states because the honest sentence differs - one is waiting for a *newer* fix,
     * the other for a *tighter* one.
     */
    private fun buildUiState(
        permission: LocationPermissionStatus,
        locationServicesEnabled: Boolean,
        reading: LocationReading,
        office: OfficeLocation?,
        transient: TransientState
    ): AttendanceUiState {
        val status = when {
            permission == LocationPermissionStatus.DENIED ->
                AttendanceStatus.PermissionRequired

            permission == LocationPermissionStatus.APPROXIMATE_ONLY ->
                AttendanceStatus.PreciseLocationRequired

            !locationServicesEnabled ->
                AttendanceStatus.LocationServicesDisabled

            reading is LocationReading.PermissionDenied ->
                AttendanceStatus.PermissionRequired

            reading is LocationReading.Failed ->
                AttendanceStatus.LocationUnavailable(reading.cause)

            reading is LocationReading.Acquiring ->
                AttendanceStatus.AcquiringFix

            reading is LocationReading.Stale ->
                AttendanceStatus.RefreshingFix

            reading is LocationReading.Imprecise ->
                AttendanceStatus.ImprovingAccuracy

            office == null ->
                AttendanceStatus.OfficeNotSet

            else -> AttendanceStatus.Tracking(
                AttendanceRule.evaluate(
                    current = (reading as LocationReading.Fresh).location.coordinates,
                    office = office.coordinates
                )
            )
        }

        // A position may only be drawn while the two things that make it meaningful still hold.
        // Checked here rather than inferred from `status`, so a permission change that has not
        // yet propagated through the location stream cannot leave a marker on the surface.
        val canShowPosition =
            permission == LocationPermissionStatus.PRECISE && locationServicesEnabled

        return AttendanceUiState(
            office = office,
            currentLocation = if (canShowPosition) reading.location else null,
            status = status,
            isCapturingOfficeLocation = transient.isCapturingOfficeLocation,
            message = transient.message,
            markedAttendance = transient.markedAttendance
        )
    }

    /** Screen state that is driven by user actions rather than by an observed source. */
    private data class TransientState(
        val isCapturingOfficeLocation: Boolean = false,
        val message: AttendanceMessage? = null,
        val markedAttendance: MarkedAttendance? = null
    )

    private companion object {
        /**
         * Keeps the location subscription alive across a configuration change instead of
         * tearing the GPS callback down and immediately rebuilding it, while still stopping
         * updates promptly when the user actually leaves the screen.
         */
        const val SUBSCRIPTION_TIMEOUT_MILLIS = 5_000L

        /**
         * A second is fine grain against a ten-second threshold, and the tick is free unless it
         * changes the answer: identical readings are dropped before they reach the state.
         */
        const val FRESHNESS_TICK_MILLIS = 1_000L

        /**
         * How long to wait before re-subscribing after a provider fault, capped rather than
         * unbounded.
         *
         * The first retry is quick because most Play Services faults are transient and the
         * user is standing there watching. It then backs off so a genuinely broken provider is
         * not re-attached to five times a second for as long as the screen is open, and stops
         * growing at five seconds so recovery still feels immediate whenever the provider
         * comes back. Retrying never stops while the screen is subscribed; leaving the screen
         * cancels it, because the whole graph is scoped to the subscription.
         */
        val RETRY_BACKOFF_MILLIS = longArrayOf(1_000L, 2_000L, 5_000L)

        val RETRY_BACKOFF_LAST_INDEX = RETRY_BACKOFF_MILLIS.lastIndex.toLong()
    }
}
