package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationServiceMonitor
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.flow.onStart
import java.io.IOException

/**
 * Fakes for the ViewModel tests. Hand-written rather than mocked: the interfaces are three
 * methods wide, and a fake that also *records* what happened (subscription count, save calls)
 * lets the tests assert things a mock verification could not express as clearly.
 */
class FakeLocationDataSource : LocationDataSource {

    private val updates = MutableStateFlow<LocationFix?>(null)

    /** What the next one-shot request returns, i.e. what "Set Office Location" will capture. */
    var currentLocationFix: LocationFix =
        LocationFix.Failed(LocationFailureCause.NO_FIX_AVAILABLE)

    var currentLocationRequests = 0
        private set

    /**
     * How many collectors are attached right now. This is what makes the lifecycle claim
     * testable: when the screen stops observing, this must fall back to zero.
     */
    var activeSubscriptions = 0
        private set

    /**
     * How many times collection has ever begun. Distinct from [activeSubscriptions]: a stream
     * torn down and rebuilt would leave that at one while this rises, which is exactly the
     * shape of an accidental restart.
     */
    var subscriptionsStarted = 0
        private set

    override fun locationUpdates(): Flow<LocationFix> = updates
        .filterNotNull()
        .onStart {
            activeSubscriptions++
            subscriptionsStarted++
        }
        .onCompletion { activeSubscriptions-- }

    override suspend fun currentLocation(): LocationFix {
        currentLocationRequests++
        return currentLocationFix
    }

    /** Note: backed by a StateFlow, so emitting an equal value twice produces one emission. */
    fun emit(fix: LocationFix) {
        updates.value = fix
    }
}

class FakeOfficeLocationRepository(initial: OfficeLocation? = null) : OfficeLocationRepository {

    private val stored = MutableStateFlow(initial)

    /** Set to make [save] fail, standing in for a full disk or an unwritable store. */
    var saveFailure: IOException? = null

    val savedLocations = mutableListOf<OfficeLocation>()

    override val officeLocation: Flow<OfficeLocation?> = stored

    override suspend fun save(officeLocation: OfficeLocation) {
        saveFailure?.let { throw it }
        savedLocations += officeLocation
        stored.value = officeLocation
    }

    override suspend fun clear() {
        stored.value = null
    }
}

class FakeLocationServiceMonitor(enabled: Boolean = true) : LocationServiceMonitor {

    val enabled = MutableStateFlow(enabled)

    override val locationServicesEnabled: Flow<Boolean> = this.enabled
}
