package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Great-circle geometry between two coordinates, via the Haversine formula.
 * Pure and Android-independent: no `android.location.Location`.
 */
object DistanceCalculator {

    internal const val EARTH_RADIUS_METERS = 6_371_000.0

    fun distanceMeters(from: GeoCoordinates, to: GeoCoordinates): Double {
        val lat1 = Math.toRadians(from.latitude)
        val lat2 = Math.toRadians(to.latitude)
        val deltaLat = Math.toRadians(to.latitude - from.latitude)
        val deltaLon = Math.toRadians(to.longitude - from.longitude)

        val a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        val c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return EARTH_RADIUS_METERS * c
    }

    /**
     * Initial great-circle bearing from [from] to [to], in degrees clockwise from true
     * north, normalised to `[0, 360)`.
     *
     * This exists so the location surface can place the user's marker at the real
     * direction from the office rather than at an arbitrary angle. Keeping the trigonometry
     * here — not in a Composable — is what keeps the drawing code free of geodesy.
     */
    fun initialBearingDegrees(from: GeoCoordinates, to: GeoCoordinates): Double {
        val lat1 = Math.toRadians(from.latitude)
        val lat2 = Math.toRadians(to.latitude)
        val deltaLon = Math.toRadians(to.longitude - from.longitude)

        val y = sin(deltaLon) * cos(lat2)
        val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        val bearing = Math.toDegrees(atan2(y, x))
        return (bearing + 360.0) % 360.0
    }
}
