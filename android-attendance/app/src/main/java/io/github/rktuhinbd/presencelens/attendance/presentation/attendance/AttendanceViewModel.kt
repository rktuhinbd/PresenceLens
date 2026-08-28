package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationPermissionStatus
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationServiceMonitor
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.flowOf
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
 */
@OptIn(ExperimentalCoroutinesApi::class)
class AttendanceViewModel(
    private val locationDataSource: LocationDataSource,
    private val officeLocationRepository: OfficeLocationRepository,
    locationServiceMonitor: LocationServiceMonitor,
    private val clock: () -> Long = System::currentTimeMillis
) : ViewModel() {

    private val permissionStatus = MutableStateFlow(LocationPermissionStatus.DENIED)
    private val transientState = MutableStateFlow(TransientState())

    /**
     * Location is observed only under a precise grant. Anything less cannot decide a 50 m
     * boundary, and emitting `null` on the way down clears any earlier fix so a revoked
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
        .catch { emit(LocationFix.Unavailable(LocationFailureCause.PROVIDER_ERROR)) }

    val uiState: StateFlow<AttendanceUiState> = combine(
        permissionStatus,
        locationServiceMonitor.locationServicesEnabled,
        locationFixes,
        officeLocationRepository.officeLocation,
        transientState
    ) { permission, locationServicesEnabled, fix, office, transient ->
        buildUiState(permission, locationServicesEnabled, fix, office, transient)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(SUBSCRIPTION_TIMEOUT_MILLIS),
        initialValue = AttendanceUiState()
    )

    /**
     * Reported by the screen on first composition, after a permission dialog, and on every
     * resume - so a grant made in system settings is picked up when the user returns.
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
                is LocationFix.Unavailable -> AttendanceMessage.OfficeLocationCaptureFailed
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
     */
    private fun buildUiState(
        permission: LocationPermissionStatus,
        locationServicesEnabled: Boolean,
        fix: LocationFix?,
        office: OfficeLocation?,
        transient: TransientState
    ): AttendanceUiState {
        val location = (fix as? LocationFix.Available)?.location
        val status = when {
            permission == LocationPermissionStatus.DENIED ->
                AttendanceStatus.PermissionRequired

            permission == LocationPermissionStatus.APPROXIMATE_ONLY ->
                AttendanceStatus.PreciseLocationRequired

            !locationServicesEnabled ->
                AttendanceStatus.LocationServicesDisabled

            fix is LocationFix.PermissionDenied ->
                AttendanceStatus.PermissionRequired

            fix is LocationFix.Unavailable ->
                AttendanceStatus.LocationUnavailable(fix.cause)

            location == null ->
                AttendanceStatus.AcquiringFix

            office == null ->
                AttendanceStatus.OfficeNotSet

            else -> AttendanceStatus.Tracking(
                AttendanceRule.evaluate(
                    current = location.coordinates,
                    office = office.coordinates
                )
            )
        }

        return AttendanceUiState(
            office = office,
            currentLocation = location,
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
    }
}
