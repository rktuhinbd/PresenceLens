package io.github.rktuhinbd.presencelens.attendance.presentation.permission

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationPermissionStatus

/**
 * What the screen needs to know and do about the location permission.
 *
 * This holds *plumbing*, not policy. Which UI state to show is decided upstream by
 * `AttendanceViewModel` from [LocationPermissionStatus]; this only reports the grant and
 * offers the two actions the platform allows.
 */
@Stable
class LocationPermissionController internal constructor(
    val status: LocationPermissionStatus,
    /**
     * False once the user has denied twice (or ticked "don't ask again"), at which point the
     * system suppresses the dialog silently. Asking again there would produce a button that
     * visibly does nothing, so the screen offers system settings instead.
     */
    val canRequestInApp: Boolean,
    private val requestPermission: () -> Unit,
    private val openSettings: () -> Unit
) {
    fun request() = requestPermission()

    fun openApplicationSettings() = openSettings()
}

/**
 * Wires the permission request into Compose and keeps [onStatusChanged] informed.
 *
 * The grant is re-read on every `ON_RESUME`, so returning from system settings updates the
 * screen immediately rather than on the next location emission.
 *
 * Exactly one request is made automatically, on first composition. Every later request is
 * user-initiated - which is what keeps this from becoming a dialog loop when the user says no.
 */
@Composable
fun rememberLocationPermissionController(
    onStatusChanged: (LocationPermissionStatus) -> Unit
): LocationPermissionController {
    val context = LocalContext.current
    val activity = remember(context) { context.findActivity() }
    val currentOnStatusChanged by rememberUpdatedState(onStatusChanged)

    var status by remember { mutableStateOf(context.locationPermissionStatus()) }
    // Survives configuration change, so a rotation cannot re-trigger the automatic request.
    var hasRequestedOnce by rememberSaveable { mutableStateOf(false) }
    var systemWillShowDialog by remember { mutableStateOf(true) }

    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) {
        hasRequestedOnce = true
        status = context.locationPermissionStatus()
        // After a denial the system still shows the dialog once more; after that it does not.
        systemWillShowDialog = activity?.shouldShowLocationRationale() == true
    }

    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        status = context.locationPermissionStatus()
        if (!hasRequestedOnce || activity?.shouldShowLocationRationale() == true) {
            systemWillShowDialog = true
        }
    }

    LaunchedEffect(status) { currentOnStatusChanged(status) }

    LaunchedEffect(Unit) {
        if (status == LocationPermissionStatus.DENIED && !hasRequestedOnce) {
            hasRequestedOnce = true
            launcher.launch(LOCATION_PERMISSIONS)
        }
    }

    return remember(status, systemWillShowDialog, hasRequestedOnce) {
        LocationPermissionController(
            status = status,
            canRequestInApp = !hasRequestedOnce || systemWillShowDialog,
            requestPermission = { launcher.launch(LOCATION_PERMISSIONS) },
            openSettings = { context.openApplicationSettings() }
        )
    }
}

/**
 * Both are requested together: from Android 12 the dialog offers a Precise/Approximate
 * choice, and asking for fine alone does not present it. Background location is never
 * requested - this feature works only while the screen is open (ADR-001).
 */
private val LOCATION_PERMISSIONS = arrayOf(
    Manifest.permission.ACCESS_FINE_LOCATION,
    Manifest.permission.ACCESS_COARSE_LOCATION
)

private fun Context.locationPermissionStatus(): LocationPermissionStatus = when {
    isGranted(Manifest.permission.ACCESS_FINE_LOCATION) -> LocationPermissionStatus.PRECISE
    isGranted(Manifest.permission.ACCESS_COARSE_LOCATION) -> LocationPermissionStatus.APPROXIMATE_ONLY
    else -> LocationPermissionStatus.DENIED
}

private fun Context.isGranted(permission: String): Boolean =
    ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

private fun Activity.shouldShowLocationRationale(): Boolean =
    ActivityCompat.shouldShowRequestPermissionRationale(this, Manifest.permission.ACCESS_FINE_LOCATION)

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
