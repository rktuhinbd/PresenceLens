package io.github.rktuhinbd.presencelens.attendance.data.location

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.LocationManager
import androidx.core.content.ContextCompat
import androidx.core.location.LocationManagerCompat
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationServiceMonitor
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Observes the OS location toggle via `LocationManager.MODE_CHANGED_ACTION`.
 *
 * Polling would be the obvious alternative and is worse here: the user leaves the app to
 * flip this switch, so a broadcast means the screen is already correct when they return
 * rather than correct one poll interval later. The receiver is registered on collection and
 * unregistered in `awaitClose`, so it follows the same lifecycle as the location updates.
 */
class SystemLocationServiceMonitor(
    private val context: Context
) : LocationServiceMonitor {

    override val locationServicesEnabled: Flow<Boolean> = callbackFlow {
        val locationManager = ContextCompat.getSystemService(context, LocationManager::class.java)
        if (locationManager == null) {
            // No LocationManager at all. Reporting "enabled" would strand the user on a
            // screen that can never acquire a fix, so report the honest answer instead.
            send(false)
            close()
            return@callbackFlow
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(receiverContext: Context?, intent: Intent?) {
                trySend(LocationManagerCompat.isLocationEnabled(locationManager))
            }
        }

        ContextCompat.registerReceiver(
            context,
            receiver,
            IntentFilter(LocationManager.MODE_CHANGED_ACTION),
            // Only the system sends this broadcast, so the receiver is not exported.
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
        send(LocationManagerCompat.isLocationEnabled(locationManager))

        awaitClose { context.unregisterReceiver(receiver) }
    }.distinctUntilChanged().conflate()
}
