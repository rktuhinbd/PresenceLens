package io.github.rktuhinbd.presencelens.attendance

import android.content.Context
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.google.android.gms.location.LocationServices
import io.github.rktuhinbd.presencelens.attendance.data.local.DataStoreOfficeLocationRepository
import io.github.rktuhinbd.presencelens.attendance.data.local.officeLocationDataStore
import io.github.rktuhinbd.presencelens.attendance.data.location.FusedLocationDataSource
import io.github.rktuhinbd.presencelens.attendance.data.location.SystemLocationServiceMonitor
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceViewModel

/**
 * The composition root (ADR-009): the one place that knows about both `data` and
 * `presentation`, so no other file has to.
 *
 * The graph is four objects. A DI framework here would add a plugin, annotation processing,
 * and generated code for a reviewer to read past, and would remove nothing - so the wiring
 * is written out by hand where it can simply be read.
 */
object AttendanceComponent {

    fun viewModelFactory(context: Context): ViewModelProvider.Factory {
        // Application context: these objects outlive any single Activity instance.
        val appContext = context.applicationContext
        return viewModelFactory {
            initializer {
                AttendanceViewModel(
                    locationDataSource = FusedLocationDataSource(
                        context = appContext,
                        client = LocationServices.getFusedLocationProviderClient(appContext)
                    ),
                    officeLocationRepository = DataStoreOfficeLocationRepository(
                        appContext.officeLocationDataStore
                    ),
                    locationServiceMonitor = SystemLocationServiceMonitor(appContext)
                )
            }
        }
    }
}
