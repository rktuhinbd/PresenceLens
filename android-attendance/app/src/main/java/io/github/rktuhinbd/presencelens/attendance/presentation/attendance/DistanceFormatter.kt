package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import java.util.Locale
import kotlin.math.roundToInt

/**
 * Turns a raw metre distance into the two shapes the screen needs: a split value/unit pair
 * for the gauge (AND-17), and a single joined string for the live readout (AND-09).
 *
 * Pure, so the wording of "You are 47 m away" is unit-testable without a device. [Locale.US]
 * is used deliberately - the app ships English copy only, and a fixed locale keeps the
 * decimal separator (and therefore the tests) deterministic.
 */
object DistanceFormatter {

    private const val METERS_IN_KILOMETER = 1_000.0

    /** Above this, one decimal place on a kilometre value stops carrying information. */
    private const val WHOLE_KILOMETER_THRESHOLD_METERS = 10_000.0

    /** The gauge renders the number and the unit at different type sizes. */
    data class Readout(val value: String, val unit: String)

    fun readout(distanceMeters: Double): Readout {
        val meters = sanitise(distanceMeters)
        return when {
            meters < METERS_IN_KILOMETER ->
                Readout(value = meters.roundToInt().toString(), unit = "m")

            meters < WHOLE_KILOMETER_THRESHOLD_METERS ->
                Readout(
                    value = String.format(Locale.US, "%.1f", meters / METERS_IN_KILOMETER),
                    unit = "km"
                )

            else -> Readout(
                value = (meters / METERS_IN_KILOMETER).roundToInt().toString(),
                unit = "km"
            )
        }
    }

    /** e.g. `"47 m"`, `"1.2 km"`. */
    fun format(distanceMeters: Double): String = with(readout(distanceMeters)) { "$value $unit" }

    /**
     * A negative or non-finite distance is not a real reading. Clamping to zero keeps a
     * corrupt provider value from rendering as nonsense text.
     */
    private fun sanitise(distanceMeters: Double): Double =
        if (distanceMeters.isFinite() && distanceMeters > 0.0) distanceMeters else 0.0
}
