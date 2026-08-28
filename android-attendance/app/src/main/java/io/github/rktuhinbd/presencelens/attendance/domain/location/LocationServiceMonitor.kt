package io.github.rktuhinbd.presencelens.attendance.domain.location

import kotlinx.coroutines.flow.Flow

/**
 * Whether the OS location toggle is on. Separate from permission: a granted permission with
 * location services switched off produces no fixes at all, and the user needs to be told
 * which of the two to fix (GEN-04).
 */
interface LocationServiceMonitor {

    /** Emits the current state immediately, then again on every change. */
    val locationServicesEnabled: Flow<Boolean>
}
