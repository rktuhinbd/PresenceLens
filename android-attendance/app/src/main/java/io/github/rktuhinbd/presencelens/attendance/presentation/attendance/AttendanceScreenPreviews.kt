package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.DeviceLocation
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.domain.model.OfficeLocation
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.ChangeOfficeLocationDialog
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.HowAttendanceWorksContent
import io.github.rktuhinbd.presencelens.attendance.ui.theme.PresenceLensAttendanceTheme

/**
 * Every branch of [AttendanceStatus], rendered without a device.
 *
 * This is the practical payoff of keeping [AttendanceScreen] stateless: the failure states -
 * the ones that are awkward to reach on a running device - can be reviewed side by side in
 * the IDE, and a reviewer can confirm each one is designed rather than left to chance.
 */
private val OFFICE = GeoCoordinates(latitude = 23.780636, longitude = 90.279372)

private fun deviceLocation(
    coordinates: GeoCoordinates = OFFICE,
    accuracyMeters: Double? = 6.0
) = DeviceLocation(
    coordinates = coordinates,
    accuracyMeters = accuracyMeters,
    elapsedRealtimeMillis = 120_000L
)

private fun savedOffice() = OfficeLocation(
    coordinates = OFFICE,
    capturedAtEpochMillis = 1_756_000_000_000L
)

/** Displacement due north, so a preview can name an exact distance. */
private fun coordinatesAt(metersNorth: Double): GeoCoordinates {
    val deltaLatDegrees = Math.toDegrees(metersNorth / 6_371_000.0)
    return GeoCoordinates(
        latitude = OFFICE.latitude + deltaLatDegrees,
        longitude = OFFICE.longitude
    )
}

private fun trackingState(
    distanceMeters: Double,
    accuracyMeters: Double? = 6.0,
    markedAtEpochMillis: Long? = null
): AttendanceUiState {
    val current = coordinatesAt(distanceMeters)
    return AttendanceUiState(
        office = savedOffice(),
        currentLocation = deviceLocation(current, accuracyMeters),
        status = AttendanceStatus.Tracking(
            AttendanceRule.evaluate(current = current, office = OFFICE)
        ),
        attendanceMarkedAtEpochMillis = markedAtEpochMillis
    )
}

@Composable
private fun PreviewScreen(state: AttendanceUiState, canRequestPermissionInApp: Boolean = true) {
    PresenceLensAttendanceTheme {
        AttendanceScreen(
            state = state,
            canRequestPermissionInApp = canRequestPermissionInApp,
            onRequestPermission = {},
            onOpenApplicationSettings = {},
            onOpenLocationSettings = {},
            onSetOfficeLocation = {},
            onMarkAttendance = {},
            onMessageShown = {}
        )
    }
}

@Preview(name = "Out of range", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenOutOfRangePreview() {
    PreviewScreen(trackingState(distanceMeters = 120.0))
}

@Preview(name = "In range", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenInRangePreview() {
    PreviewScreen(trackingState(distanceMeters = 32.0))
}

@Preview(name = "In range (dark)", showBackground = true, heightDp = 1_100, uiMode = 0x21)
@Composable
private fun AttendanceScreenInRangeDarkPreview() {
    PreviewScreen(trackingState(distanceMeters = 32.0))
}

@Preview(name = "Degraded fix", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenDegradedFixPreview() {
    PreviewScreen(trackingState(distanceMeters = 18.0, accuracyMeters = 180.0))
}

@Preview(name = "Attendance marked", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenMarkedPreview() {
    PreviewScreen(
        trackingState(distanceMeters = 32.0, markedAtEpochMillis = 1_756_000_000_000L)
    )
}

@Preview(name = "Attendance marked (dark)", showBackground = true, heightDp = 1_100, uiMode = 0x21)
@Composable
private fun AttendanceScreenMarkedDarkPreview() {
    PreviewScreen(
        trackingState(distanceMeters = 32.0, markedAtEpochMillis = 1_756_000_000_000L)
    )
}

@Preview(name = "First use - setup", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenOfficeNotSetPreview() {
    PreviewScreen(
        AttendanceUiState(
            currentLocation = deviceLocation(),
            status = AttendanceStatus.OfficeNotSet
        )
    )
}

@Preview(name = "Capturing office", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenCapturingPreview() {
    PreviewScreen(
        AttendanceUiState(
            currentLocation = deviceLocation(),
            status = AttendanceStatus.OfficeNotSet,
            isCapturingOfficeLocation = true
        )
    )
}

@Preview(name = "Permission required", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenPermissionRequiredPreview() {
    PreviewScreen(AttendanceUiState(status = AttendanceStatus.PermissionRequired))
}

@Preview(name = "Permission permanently denied", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenPermissionDeniedForeverPreview() {
    PreviewScreen(
        state = AttendanceUiState(status = AttendanceStatus.PermissionRequired),
        canRequestPermissionInApp = false
    )
}

@Preview(name = "Approximate location only", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenPreciseRequiredPreview() {
    PreviewScreen(AttendanceUiState(status = AttendanceStatus.PreciseLocationRequired))
}

@Preview(name = "Location services off", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenServicesDisabledPreview() {
    PreviewScreen(
        AttendanceUiState(
            office = savedOffice(),
            status = AttendanceStatus.LocationServicesDisabled
        )
    )
}

@Preview(name = "Acquiring fix", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenAcquiringPreview() {
    PreviewScreen(
        AttendanceUiState(
            office = savedOffice(),
            status = AttendanceStatus.AcquiringFix
        )
    )
}

@Preview(name = "Refreshing a stale fix", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenRefreshingPreview() {
    PreviewScreen(
        AttendanceUiState(
            office = savedOffice(),
            currentLocation = deviceLocation(coordinatesAt(30.0)),
            status = AttendanceStatus.RefreshingFix
        )
    )
}

@Preview(name = "Location unavailable", showBackground = true, heightDp = 1_100)
@Composable
private fun AttendanceScreenUnavailablePreview() {
    PreviewScreen(
        AttendanceUiState(
            office = savedOffice(),
            status = AttendanceStatus.LocationUnavailable(LocationFailureCause.NO_FIX_AVAILABLE)
        )
    )
}

@Preview(name = "First use - setup (dark)", showBackground = true, heightDp = 1_100, uiMode = 0x21)
@Composable
private fun AttendanceScreenOfficeNotSetDarkPreview() {
    PreviewScreen(
        AttendanceUiState(
            currentLocation = deviceLocation(),
            status = AttendanceStatus.OfficeNotSet
        )
    )
}

@Preview(name = "How attendance works", showBackground = true, heightDp = 620)
@Composable
private fun HowAttendanceWorksPreview() {
    PresenceLensAttendanceTheme {
        Surface(color = MaterialTheme.colorScheme.surfaceContainerLow) {
            HowAttendanceWorksContent(
                radiusMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS.toInt(),
                onDismiss = {},
                modifier = Modifier.padding(vertical = 24.dp)
            )
        }
    }
}

@Preview(name = "Change office confirmation", showBackground = true, heightDp = 420)
@Composable
private fun ChangeOfficeLocationDialogPreview() {
    PresenceLensAttendanceTheme {
        ChangeOfficeLocationDialog(
            currentOfficeCoordinates = "Lat: 23.780636, Lon: 90.279372",
            onConfirm = {},
            onDismiss = {}
        )
    }
}
