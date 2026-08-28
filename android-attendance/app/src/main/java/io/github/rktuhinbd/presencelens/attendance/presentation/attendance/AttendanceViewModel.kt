package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFreshness
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationPermissionStatus
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationServiceMonitor
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.scan
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.io.IOException

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
 * **Location is a retained value, not a stream of verdicts** ([LocationReading]). Each raw
 * [LocationFix] updates what the app knows; what the app *shows* is then decided from that
 * knowledge plus the age of the last fix ([LocationFreshness]). This is the difference between
 * a screen that reports the provider's mood and one that reports the user's situation - and it
 * is why a momentary availability estimate can no longer flash a failure over a position the
 * app is still holding.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModel(
    private val locationDataSource: LocationDataSource,
    private val officeLocationRepository: OfficeLocationRepository,
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
                locationDataSource.locationUpdates()
            } else {
                flowOf(null)
            }
        }
        .catch { emit(LocationFix.Failed(LocationFailureCause.PROVIDER_ERROR)) }

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
     * AND-06: capture the current GPS coordinates and persist them (AND-07).
     *
     * Deliberately a fresh one-shot request rather than a reuse of the streamed position:
     * setting the office is an explicit act, and it should not silently record a cached fix
     * from some earlier moment.
     */
    fun onSetOfficeLocationClicked() {
        if (transientState.value.isCapturingOfficeLocation) return

        viewModelScope.launch {
            transientState.update { it.copy(isCapturingOfficeLocation = true, message = null) }
            val message = when (val fix = locationDataSource.currentLocation()) {
                is LocationFix.Available -> persistOfficeLocation(fix.location)
                LocationFix.PermissionDenied -> AttendanceMessage.LocationPermissionMissing
                LocationFix.ProviderReportedUnavailable,
                is LocationFix.Failed -> AttendanceMessage.OfficeLocationCaptureFailed
            }
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
                attendanceMarkedAtEpochMillis = clock()
            )
        }
    }

    fun onMessageShown() {
        transientState.update { it.copy(message = null) }
    }

    private suspend fun persistOfficeLocation(location: DeviceLocation): AttendanceMessage =
        try {
            officeLocationRepository.save(
                OfficeLocation(
                    coordinates = location.coordinates,
                    capturedAtEpochMillis = clock()
                )
            )
            AttendanceMessage.OfficeLocationSaved(location.coordinates)
        } catch (error: IOException) {
            // Local storage can fail (full disk, corrupt file). GEN-04 requires this to reach
            // the user rather than surface as a silent no-op.
            AttendanceMessage.OfficeLocationSaveFailed
        }

    /**
     * The ordering below is the whole failure model. Permission outranks everything because
     * nothing else is knowable without it; the services toggle outranks any fix already in
     * hand, so switching location off cannot leave a stale distance on screen.
     *
     * A stale fix sits between "no fix at all" and "tracking": the position is kept on the
     * location surface so the screen does not blink, but it no longer produces a distance, so
     * [AttendanceUiState.canMarkAttendance] is false and the user is told the app is waiting
     * for a fresh reading rather than that something failed.
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
            attendanceMarkedAtEpochMillis = transient.attendanceMarkedAtEpochMillis
        )
    }

    /** Screen state that is driven by user actions rather than by an observed source. */
    private data class TransientState(
        val isCapturingOfficeLocation: Boolean = false,
        val message: AttendanceMessage? = null,
        val attendanceMarkedAtEpochMillis: Long? = null
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
    }
}

/**
 * What the app knows about the device's position, accumulated across raw [LocationFix] events.
 *
 * Kept separate from [LocationReading] because knowledge and presentation age differently: this
 * changes only when the platform says something, while the reading derived from it changes with
 * the passage of time as well.
 */
private data class LocationKnowledge(
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
     * The provider's availability estimate is escalated to a failure in exactly one case: the
     * app has never held a position, and the acquisition window has passed with the provider
     * saying it cannot obtain one. That is a genuine inability rather than a mood, and it is
     * the only path from an availability signal to "Location unavailable".
     */
    fun readingAt(nowElapsedMillis: Long): LocationReading = when {
        permissionDenied -> LocationReading.PermissionDenied

        failure != null -> LocationReading.Failed(failure)

        lastLocation != null -> if (
            LocationFreshness.isFresh(lastLocation.elapsedRealtimeMillis, nowElapsedMillis)
        ) {
            LocationReading.Fresh(lastLocation)
        } else {
            LocationReading.Stale(lastLocation)
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

/**
 * What the app can say about the device's position right now: the knowledge above, with the
 * age of the last fix already taken into account.
 */
private sealed interface LocationReading {

    /** The last usable position, if one is still worth drawing on screen. */
    val location: DeviceLocation? get() = null

    /** Observing, but no position has arrived yet. Not a failure. */
    data object Acquiring : LocationReading

    /** A position recent enough to decide the 50 m rule. */
    data class Fresh(override val location: DeviceLocation) : LocationReading

    /** A position that is still the best one held, but too old to gate attendance with. */
    data class Stale(override val location: DeviceLocation) : LocationReading

    /** The grant disappeared while updates were running. */
    data object PermissionDenied : LocationReading

    /** A real inability to obtain a position (GEN-04). */
    data class Failed(val cause: LocationFailureCause) : LocationReading
}
