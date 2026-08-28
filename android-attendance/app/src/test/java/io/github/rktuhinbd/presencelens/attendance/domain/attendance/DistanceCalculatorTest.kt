package io.github.rktuhinbd.presencelens.attendance.domain.attendance

import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationQuality
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

class DistanceCalculatorTest {

    @Test
    fun `identical coordinates produce approximately 0 meters`() {
        val point = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)

        val distance = DistanceCalculator.distanceMeters(point, point)

        assertEquals(0.0, distance, 0.0001)
    }

    @Test
    fun `known nearby coordinates produce a sensible distance`() {
        // Two points exactly one degree of latitude apart, ~111.19 km along a meridian.
        val southPoint = GeoCoordinates(latitude = 23.0, longitude = 90.0)
        val northPoint = GeoCoordinates(latitude = 24.0, longitude = 90.0)

        val distance = DistanceCalculator.distanceMeters(southPoint, northPoint)

        assertEquals(111_195.0, distance, 500.0)
    }

    @Test
    fun `distance is symmetric`() {
        val a = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val b = GeoCoordinates(latitude = 23.7104, longitude = 90.4074)

        val forward = DistanceCalculator.distanceMeters(a, b)
        val backward = DistanceCalculator.distanceMeters(b, a)

        assertEquals(forward, backward, 0.0001)
    }

    @Test
    fun `bearing points north east south and west as expected`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val step = 0.01

        assertEquals(
            0.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(latitude = origin.latitude + step)
            ),
            0.1
        )
        assertEquals(
            90.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(longitude = origin.longitude + step)
            ),
            0.1
        )
        assertEquals(
            180.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(latitude = origin.latitude - step)
            ),
            0.1
        )
        assertEquals(
            270.0,
            DistanceCalculator.initialBearingDegrees(
                origin,
                origin.copy(longitude = origin.longitude - step)
            ),
            0.1
        )
    }

    // --- Precision at the scale the product actually decides (AND-08) ----------------------
    //
    // The large-distance case above has a 500 m tolerance, which is fine for "the formula is
    // wired up" and says nothing about a 50 m rule. The three tests below close that gap. They
    // measure the spherical (Haversine) result against an independent WGS-84 ellipsoidal
    // computation, so a real error in the implementation cannot pass by agreeing with itself.

    @Test
    fun `at the attendance radius the spherical model tracks the WGS-84 ellipsoid closely`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val radius = AttendanceRule.ELIGIBLE_RADIUS_METERS

        // Every direction, because the two models disagree by different amounts north-south
        // (meridional radius) and east-west (normal radius); the worst case is not axis-aligned
        // by accident.
        for (bearingDegrees in 0 until 360 step 15) {
            val target = ellipsoidalOffset(origin, radius, bearingDegrees.toDouble())
            val haversine = DistanceCalculator.distanceMeters(origin, target)

            assertEquals(
                "bearing $bearingDegrees",
                radius,
                haversine,
                MAX_GEODESY_ERROR_METERS
            )
        }
    }

    @Test
    fun `the geodesy error at 50 m is negligible against real device positioning error`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val radius = AttendanceRule.ELIGIBLE_RADIUS_METERS

        // Due north is the worst direction at this latitude: the sphere's 6371 km radius is
        // about 0.4% larger than the local meridional radius of curvature.
        val worstCase = DistanceCalculator.distanceMeters(
            origin,
            ellipsoidalOffset(origin, radius, bearingDegrees = 0.0)
        ) - radius

        // The claim this test exists to substantiate: choosing a sphere over an ellipsoid costs
        // about 20 cm at the boundary. The tightest accuracy this app is willing to call
        // "precise" is 25 m - two orders of magnitude larger - so the model choice is not what
        // decides any real attendance outcome. The device's own uncertainty is.
        assertTrue(
            "worst-case geodesy error was $worstCase m",
            abs(worstCase) < MAX_GEODESY_ERROR_METERS
        )
        assertTrue(
            "geodesy error is not negligible against the precise-fix threshold",
            abs(worstCase) < LocationQuality.DEGRADED_ACCURACY_THRESHOLD_METERS / 100.0
        )
    }

    @Test
    fun `sub-metre movement either side of the radius is resolved`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        val radius = AttendanceRule.ELIGIBLE_RADIUS_METERS

        val justInside = DistanceCalculator.distanceMeters(
            origin,
            ellipsoidalOffset(origin, radius - 0.5, bearingDegrees = 45.0)
        )
        val justOutside = DistanceCalculator.distanceMeters(
            origin,
            ellipsoidalOffset(origin, radius + 0.5, bearingDegrees = 45.0)
        )

        // Floating-point resolution is not the limiting factor anywhere near this scale: a
        // metre of movement produces about a metre of measured change, not noise.
        assertEquals(1.0, justOutside - justInside, 0.01)
    }

    /**
     * A point [meters] away from [origin] along [bearingDegrees], computed on the WGS-84
     * ellipsoid rather than on the sphere the implementation uses.
     *
     * Local radii of curvature - meridional (M) north-south, normal (N) east-west - are exact
     * for the ellipsoid at this latitude, and over 50 m the curvature of those radii themselves
     * is far below a millimetre. That makes this an independent reference, not a restatement of
     * the formula under test.
     */
    private fun ellipsoidalOffset(
        origin: GeoCoordinates,
        meters: Double,
        bearingDegrees: Double
    ): GeoCoordinates {
        val latitudeRadians = Math.toRadians(origin.latitude)
        val sinLatitudeSquared = sin(latitudeRadians) * sin(latitudeRadians)
        val w = 1 - WGS84_ECCENTRICITY_SQUARED * sinLatitudeSquared

        val meridionalRadius =
            WGS84_SEMI_MAJOR_AXIS_METERS * (1 - WGS84_ECCENTRICITY_SQUARED) / (w * sqrt(w))
        val normalRadius = WGS84_SEMI_MAJOR_AXIS_METERS / sqrt(w)

        val bearingRadians = Math.toRadians(bearingDegrees)
        val northMeters = meters * cos(bearingRadians)
        val eastMeters = meters * sin(bearingRadians)

        return GeoCoordinates(
            latitude = origin.latitude + Math.toDegrees(northMeters / meridionalRadius),
            longitude = origin.longitude +
                Math.toDegrees(eastMeters / (normalRadius * cos(latitudeRadians)))
        )
    }

    @Test
    fun `bearing is normalised into the 0 to 360 range`() {
        val origin = GeoCoordinates(latitude = 23.8103, longitude = 90.4125)
        // North-west, which the raw atan2 result would express as a negative angle.
        val target = GeoCoordinates(latitude = 23.8203, longitude = 90.4025)

        val bearing = DistanceCalculator.initialBearingDegrees(origin, target)

        assertTrue("bearing was $bearing", bearing in 0.0..360.0)
        assertEquals(317.5, bearing, 1.0)
    }

    private companion object {
        /**
         * The tolerance the product can defend. Half a metre is already an order of magnitude
         * below the best horizontal accuracy consumer GNSS reports in the open, so a bound at
         * a quarter of that is comfortably tighter than anything the rule ever depends on.
         */
        const val MAX_GEODESY_ERROR_METERS = 0.25

        const val WGS84_SEMI_MAJOR_AXIS_METERS = 6_378_137.0

        /** e^2 = 2f - f^2 for the WGS-84 flattening f = 1 / 298.257223563. */
        const val WGS84_ECCENTRICITY_SQUARED = 0.00669437999014
    }
}
