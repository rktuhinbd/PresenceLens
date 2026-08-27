package io.github.rktuhinbd.presencelens.attendance.domain.model

/**
 * The saved office coordinates, with the epoch-millis timestamp of when they were captured.
 */
data class OfficeLocation(
    val coordinates: GeoCoordinates,
    val capturedAtEpochMillis: Long
)
