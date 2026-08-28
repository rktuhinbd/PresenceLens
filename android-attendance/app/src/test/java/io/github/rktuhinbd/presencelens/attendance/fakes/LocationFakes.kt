package io.github.rktuhinbd.presencelens.attendance.fakes

import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationDataSource
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFix
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationServiceMonitor
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocationRepository
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.flow.onStart
import java.io.IOException

/**
 * Fakes for the domain and ViewModel tests. Hand-written rather than mocked: the interfaces
 * are three methods wide, and a fake that also *records* what happened (subscription count,
 * save calls) lets the tests assert things a mock verification could not express as clearly.
 *
 * They live in their own package rather than beside the ViewModel tests because the domain
 * tests use them too, and a domain test reaching into a `presentation.*` package to find a
 * fake would quietly contradict the layering those tests exist to demonstrate.
 */
class FakeLocationDataSource : LocationDataSource {

    private val updates = MutableStateFlow<LocationFix?>(null)

    /**
     * Faults raised by the stream itself, as opposed to fixes it delivers.
     *
     * Separate from [updates] because a provider crash is not a value in the stream - it is
     * the stream ending. Modelled with a shared flow so it reaches only the collector that is
     * attached at the time, which is what makes a retry observable: the *next* subscription
     * sees a working source again.
     */
    private val faults = MutableSharedFlow<Throwable>(extraBufferCapacity = 1)

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
     * shape of an accidental restart - and, after a provider fault, exactly the shape of a
     * successful recovery.
     */
    var subscriptionsStarted = 0
        private set

    override fun locationUpdates(): Flow<LocationFix> = merge(
        updates.filterNotNull(),
        faults.map<Throwable, LocationFix> { throw it }
    )
        .onStart {
            activeSubscriptions++
            subscriptionsStarted++
        }
        .onCompletion { activeSubscriptions-- }

    /**
     * Set to hold a one-shot capture open, so a test can observe the app *while* a request is
     * in flight rather than only after it resolved.
     */
    var currentLocationGate: CompletableDeferred<Unit>? = null

    override suspend fun currentLocation(): LocationFix {
        currentLocationRequests++
        currentLocationGate?.await()
        return currentLocationFix
    }

    /** Note: backed by a StateFlow, so emitting an equal value twice produces one emission. */
    fun emit(fix: LocationFix) {
        updates.value = fix
    }

    /**
     * Makes the currently attached collector fail, the way a Play Services fault would.
     *
     * The held fix is dropped at the same time, so a re-subscription does not immediately
     * replay the position that existed before the fault - which would hide whether recovery
     * actually happened behind a `StateFlow` replay.
     */
    fun failStream(cause: Throwable = IllegalStateException("provider crashed")) {
        updates.value = null
        check(faults.tryEmit(cause)) { "no collector was attached to receive the fault" }
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

    /** What a reader would see right now, without collecting. */
    fun current(): OfficeLocation? = stored.value
}

class FakeLocationServiceMonitor(enabled: Boolean = true) : LocationServiceMonitor {

    val enabled = MutableStateFlow(enabled)

    override val locationServicesEnabled: Flow<Boolean> = this.enabled
}
