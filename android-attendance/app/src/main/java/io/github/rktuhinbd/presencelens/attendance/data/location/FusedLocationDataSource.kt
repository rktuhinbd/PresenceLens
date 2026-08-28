package io.github.rktuhinbd.presencelens.attendance.data.location

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.Granularity
import com.google.android.gms.location.LocationAvailability
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.google.android.gms.tasks.Task
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * [LocationDataSource] over `FusedLocationProviderClient` (ADR-001).
 *
 * Foreground only, high-accuracy priority, no `GeofencingClient` and no background-location
 * permission: Android's recommended minimum geofence radius (~100-150 m) is two to three
 * times the 50 m boundary this feature must resolve, and geofence callbacks carry no
 * continuous distance for AND-09's live readout.
 *
 * The streaming flow is cold. The platform callback is registered when collection starts
 * and removed in `awaitClose` when it stops, so an unsubscribed screen leaves no listener
 * behind - that is the whole mechanism behind lifecycle-aware observation here.
 *
 * **This class reports; it does not judge.** An availability estimate arrives as
 * [LocationFix.ProviderReportedUnavailable] and never as a failure, and an empty
 * `LocationResult` produces no emission at all rather than an invented one. Whether the app
 * still holds a usable position is decided upstream, where the last fix and its age are both
 * known.
 */
class FusedLocationDataSource(
    private val context: Context,
    private val client: FusedLocationProviderClient
) : LocationDataSource {

    @SuppressLint("MissingPermission") // Guarded by the explicit runtime check below.
    override fun locationUpdates(): Flow<LocationFix> = callbackFlow {
        if (!hasFineLocationPermission()) {
            send(LocationFix.PermissionDenied)
            close()
            return@callbackFlow
        }

        val callback = object : LocationCallback() {
            /**
             * A result with no usable location is not a failure and not news - it is the
             * provider saying nothing. Emitting nothing leaves the last fix and its age as the
             * only things that decide the screen's state.
             */
            override fun onLocationResult(result: LocationResult) {
                val location = result.lastLocation?.toDeviceLocationOrNull() ?: return
                trySend(LocationFix.Available(location))
            }

            /**
             * Play Services documents this as a best-effort estimate, not a verdict, and on a
             * stationary device it flips to `false` routinely between confident reports. It is
             * therefore forwarded as the advisory it is. Mapping it to a failure here is what
             * made the screen oscillate between eligible and "Location unavailable" every few
             * seconds while nothing about the device had changed.
             */
            override fun onLocationAvailability(availability: LocationAvailability) {
                if (!availability.isLocationAvailable) {
                    trySend(LocationFix.ProviderReportedUnavailable)
                }
            }
        }

        try {
            client.requestLocationUpdates(liveUpdateRequest(), callback, Looper.getMainLooper())
        } catch (securityException: SecurityException) {
            // The permission was revoked between the check above and this call.
            send(LocationFix.PermissionDenied)
            close()
            return@callbackFlow
        }

        awaitClose { client.removeLocationUpdates(callback) }
    }.conflate() // Only the newest position matters; never queue stale fixes behind it.

    @SuppressLint("MissingPermission") // Guarded by the explicit runtime check below.
    override suspend fun currentLocation(): LocationFix {
        if (!hasFineLocationPermission()) return LocationFix.PermissionDenied

        val cancellationTokenSource = CancellationTokenSource()
        return try {
            val location = withTimeoutOrNull(CURRENT_LOCATION_TIMEOUT_MILLIS + TIMEOUT_GRACE_MILLIS) {
                client.getCurrentLocation(officeCaptureRequest(), cancellationTokenSource.token)
                    .awaitOrNull()
            }?.toDeviceLocationOrNull()

            if (location == null) {
                LocationFix.Failed(LocationFailureCause.NO_FIX_AVAILABLE)
            } else {
                LocationFix.Available(location)
            }
        } catch (securityException: SecurityException) {
            LocationFix.PermissionDenied
        } catch (error: Exception) {
            LocationFix.Failed(LocationFailureCause.PROVIDER_ERROR)
        } finally {
            cancellationTokenSource.cancel()
        }
    }

    private fun hasFineLocationPermission(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    companion object {
        /**
         * AMB-13 leaves "real-time" unquantified, so it is chosen here rather than inherited.
         * At walking pace (~1.4 m/s) a 2 s cadence moves the reading about 3 m - fine enough
         * that the 50 m boundary is crossed visibly, coarse enough to stay battery-honest for
         * a screen that is only observed while in the foreground.
         */
        const val UPDATE_INTERVAL_MILLIS = 2_000L

        /** Accept faster deliveries when another app has already prompted a fix. */
        private const val FASTEST_UPDATE_INTERVAL_MILLIS = 1_000L

        /**
         * Long enough for a cold high-accuracy fix indoors, now that the request refuses the
         * cache entirely. A 20 s window was sized against a request that could be satisfied by
         * a 10 s-old position; with [OFFICE_CAPTURE_MAX_UPDATE_AGE_MILLIS] at zero the whole
         * window has to cover a genuine acquisition, and GNSS convergence indoors routinely
         * takes past 20 s. Capped below half a minute so the wait stays one the user can watch
         * rather than abandon, which the in-place capture note names while it runs.
         */
        internal const val CURRENT_LOCATION_TIMEOUT_MILLIS = 28_000L

        /**
         * Zero, and deliberately not `LocationFreshness.FRESH_FIX_MAX_AGE_MILLIS`.
         *
         * Setting the office is the one act whose result is written to disk and used to judge
         * every later distance, so it must derive a position now rather than accept the most
         * recent one the fused engine happens to be holding. The freshness bound answers a
         * different question - whether a *live* fix may still decide the rule - and reusing it
         * here let a cached fix, taken up to ten seconds earlier somewhere the user no longer
         * is, define the anchor permanently.
         */
        internal const val OFFICE_CAPTURE_MAX_UPDATE_AGE_MILLIS = 0L

        /** Small margin so the coroutine timeout never fires before the request timeout. */
        private const val TIMEOUT_GRACE_MILLIS = 1_000L

        /**
         * The streaming request (AND-09).
         *
         * `setWaitForAccurateLocation(true)` is the one setting here worth arguing for. Under
         * `PRIORITY_HIGH_ACCURACY` the platform may hold back the *first* delivery briefly
         * while GNSS converges, instead of handing over a coarse network fix it is about to
         * replace. That short wait is exactly what this screen wants: the app already has an
         * honest "Finding your location…" state to spend it in, and the alternative is a
         * first fix accurate to a few hundred metres arriving against a 50 m rule. Only the
         * initial delivery is affected; the cadence below is unchanged.
         */
        internal fun liveUpdateRequest(): LocationRequest = LocationRequest
            .Builder(Priority.PRIORITY_HIGH_ACCURACY, UPDATE_INTERVAL_MILLIS)
            .setMinUpdateIntervalMillis(FASTEST_UPDATE_INTERVAL_MILLIS)
            // Report even while the user stands still: the distance readout (AND-09) should
            // reflect accuracy improvements, and emulator coordinate changes must land at once.
            .setMinUpdateDistanceMeters(0f)
            // Never batch. Batched delivery would make the 50 m crossing appear late.
            .setMaxUpdateDelayMillis(0L)
            .setWaitForAccurateLocation(true)
            .build()

        /**
         * The one-shot office-capture request (AND-06): high accuracy, fine granularity, and
         * no cache at all.
         *
         * `GRANULARITY_FINE` is stated rather than left to the permission level. The call site
         * has already verified `ACCESS_FINE_LOCATION`, and the anchor this produces is the
         * origin of every distance the app will ever report - so the request says which
         * granularity it needs instead of inheriting whatever the grant currently permits.
         */
        internal fun officeCaptureRequest(): CurrentLocationRequest = CurrentLocationRequest
            .Builder()
            .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
            .setGranularity(Granularity.GRANULARITY_FINE)
            .setDurationMillis(CURRENT_LOCATION_TIMEOUT_MILLIS)
            .setMaxUpdateAgeMillis(OFFICE_CAPTURE_MAX_UPDATE_AGE_MILLIS)
            .build()
    }
}

/**
 * Bridges a Play Services [Task] to a coroutine. Written here rather than pulling in
 * `kotlinx-coroutines-play-services` for a single call site: the whole bridge is six lines
 * and keeps the dependency list honest.
 */
private suspend fun <T> Task<T>.awaitOrNull(): T? = suspendCancellableCoroutine { continuation ->
    addOnCompleteListener { task ->
        val exception = task.exception
        when {
            task.isCanceled -> continuation.cancel()
            exception != null -> continuation.resumeWithException(exception)
            else -> continuation.resume(task.result)
        }
    }
}

/**
 * Maps a platform [Location] into the domain, rejecting values that could not be a real
 * position. Without this a malformed provider reading would throw out of a system callback.
 */
private fun Location.toDeviceLocationOrNull(): DeviceLocation? {
    if (latitude.isNaN() || longitude.isNaN()) return null
    if (latitude !in -90.0..90.0 || longitude !in -180.0..180.0) return null
    return DeviceLocation(
        coordinates = GeoCoordinates(latitude = latitude, longitude = longitude),
        accuracyMeters = if (hasAccuracy()) accuracy.toDouble() else null,
        // Monotonic since boot, which is what freshness is measured against.
        // getElapsedRealtimeMillis() would read better but is API 33+; this app supports 24.
        elapsedRealtimeMillis = elapsedRealtimeNanos / NANOS_PER_MILLI
    )
}

private const val NANOS_PER_MILLI = 1_000_000L
