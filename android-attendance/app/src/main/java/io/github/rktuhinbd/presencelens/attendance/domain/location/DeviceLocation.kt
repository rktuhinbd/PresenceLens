package io.github.rktuhinbd.presencelens.attendance.domain.location

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates

/**
 * A single position report from the device.
 *
 * [accuracyMeters] is the platform's estimated horizontal error radius, and is nullable
 * because not every provider reports one (`Location.hasAccuracy()` can be false). It is
 * carried into the domain deliberately: AMB-14 requires that fix quality be modelled
 * rather than silently trusted.
 *
 * [elapsedRealtimeMillis] is when the fix was taken, on the device's monotonic since-boot
 * clock rather than the wall clock, because it is compared against *now* to decide whether the
 * position is still current enough to gate attendance ([LocationFreshness]). A wall-clock
 * timestamp would be wrong across an NTP correction or a manual clock change.
 */
data class DeviceLocation(
    val coordinates: GeoCoordinates,
    val accuracyMeters: Double?,
    val elapsedRealtimeMillis: Long
) {
    val quality: LocationQuality get() = LocationQuality.of(accuracyMeters)
}
