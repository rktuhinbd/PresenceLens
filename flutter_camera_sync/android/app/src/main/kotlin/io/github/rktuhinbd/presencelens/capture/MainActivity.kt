package io.github.rktuhinbd.presencelens.capture

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity, plus the one platform call Flutter does not provide.
 *
 * The camera permission panel offers "Open settings" once refusals repeat
 * (ADR-F22). That is a *recovery route*, not a claim that Android permanently
 * denied anything — `camera_android_camerax` reports no such verdict, so the app
 * never asserts one.
 *
 * Fifteen lines here instead of a second permission library for one intent:
 * `permission_handler` was considered and rejected twice on the evidence
 * (RESEARCH.md §2, ADR-F22).
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == OPEN_APP_SETTINGS) {
                    result.success(openAppSettings())
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Shows this app's own details page, where camera access can be re-enabled.
     *
     * Returns whether the intent was accepted. A device with no settings
     * activity for the action is a disappointment, not a crash: the panel still
     * offers "Try again" beside this.
     */
    private fun openAppSettings(): Boolean = try {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", packageName, null),
        ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        startActivity(intent)
        true
    } catch (error: Exception) {
        false
    }

    private companion object {
        const val CHANNEL = "io.github.rktuhinbd.presencelens.capture/app_settings"
        const val OPEN_APP_SETTINGS = "openAppSettings"
    }
}
