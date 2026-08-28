package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import java.util.Locale

/**
 * Formats coordinates for the readout pill on the location surface (AND-15).
 *
 * Six decimal places is roughly 0.1 m of resolution - enough precision that the reviewer can
 * see the value change as the emulator moves, without printing digits the fix cannot support.
 */
object CoordinateFormatter {

    private const val DECIMAL_PLACES = 6

    fun latitude(coordinates: GeoCoordinates): String = format(coordinates.latitude)

    fun longitude(coordinates: GeoCoordinates): String = format(coordinates.longitude)

    private fun format(value: Double): String =
        String.format(Locale.US, "%.${DECIMAL_PLACES}f", value)
}
