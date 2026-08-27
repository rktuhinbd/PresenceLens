package io.github.rktuhinbd.presencelens.attendance.domain.model

/**
 * A validated latitude/longitude pair. Android-independent: no Location or GMS imports.
 */
data class GeoCoordinates(
    val latitude: Double,
    val longitude: Double
) {
    init {
        require(latitude in -90.0..90.0) {
            "Latitude must be between -90 and 90 degrees, was $latitude"
        }
        require(longitude in -180.0..180.0) {
            "Longitude must be between -180 and 180 degrees, was $longitude"
        }
    }
}
