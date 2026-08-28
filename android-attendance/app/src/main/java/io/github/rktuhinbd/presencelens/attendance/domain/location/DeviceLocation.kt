package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates

/**
 * A single position report from the device.
 *
 * [accuracyMeters] is the platform's estimated horizontal error radius, and is nullable
 * because not every provider reports one (`Location.hasAccuracy()` can be false). It is
 * carried into the domain deliberately: AMB-14 requires that fix quality be modelled
 * rather than silently trusted.
 */
data class DeviceLocation(
    val coordinates: GeoCoordinates,
    val accuracyMeters: Double?,
    val timestampEpochMillis: Long
) {
    val quality: LocationQuality get() = LocationQuality.of(accuracyMeters)
}
