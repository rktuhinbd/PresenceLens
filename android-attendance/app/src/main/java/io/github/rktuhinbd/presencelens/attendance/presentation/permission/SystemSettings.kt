package io.github.rktuhinbd.presencelens.attendance.presentation.permission

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings

/**
 * The two escape hatches offered when the screen cannot fix a problem itself: the app's own
 * permission page, and the system location toggle.
 *
 * Both are wrapped in `runCatching` because a stripped-down device or a restricted profile
 * may have no Activity for either intent, and a dead-end screen is preferable to a crash.
 */
internal fun Context.openApplicationSettings() {
    val intent = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.fromParts("package", packageName, null)
    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    runCatching { startActivity(intent) }
}

internal fun Context.openLocationSettings() {
    val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    runCatching { startActivity(intent) }
}
