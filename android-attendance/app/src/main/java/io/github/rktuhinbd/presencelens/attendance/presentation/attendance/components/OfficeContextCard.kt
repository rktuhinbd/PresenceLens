package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceUiState
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.CoordinateFormatter
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.DistanceFormatter
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.TimestampFormatter
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle

/**
 * The Setup Phase card from the reference (AND-14, AND-15, AND-16, AND-05, AND-06): the
 * "STEP 1: OFFICE CONTEXT" overline with its state dot, the location surface and coordinate
 * pill, the helper copy, and the "Set Office Location" button.
 *
 * Both this and the attendance action live on the same screen, never behind navigation
 * (AND-04). Every value shown is read from [state]; nothing is computed here.
 */
@Composable
fun OfficeContextCard(
    state: AttendanceUiState,
    onSetOfficeLocation: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors
    val office = state.office
    val radiusMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.extraLarge,
        colors = CardDefaults.cardColors(containerColor = colorScheme.surfaceContainerLow)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResource(R.string.office_context_overline),
                    style = OverlineTextStyle,
                    color = colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
                StatusDot(
                    color = if (office != null) statusColors.success else colorScheme.outline,
                    contentDescription = stringResource(
                        if (office != null) {
                            R.string.content_description_office_set
                        } else {
                            R.string.content_description_office_not_set
                        }
                    )
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(
                        if (office != null) {
                            R.string.office_context_set
                        } else {
                            R.string.office_context_not_set
                        }
                    ),
                    style = MaterialTheme.typography.labelMedium,
                    color = colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.size(16.dp))

            LocationSurface(
                officeCoordinates = office?.coordinates,
                currentCoordinates = state.currentLocation?.coordinates,
                proximity = state.proximity,
                radiusMeters = radiusMeters,
                coordinateLabel = coordinateLabel(state),
                coordinateValue = coordinateValue(state),
                legendText = stringResource(
                    R.string.location_surface_legend,
                    radiusMeters.toInt()
                ),
                surfaceContentDescription = surfaceContentDescription(state, radiusMeters),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.size(16.dp))

            Text(
                text = stringResource(R.string.office_context_helper),
                style = MaterialTheme.typography.bodyMedium,
                color = colorScheme.onSurfaceVariant
            )

            AnimatedVisibility(
                visible = office != null,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Text(
                    text = stringResource(
                        R.string.office_context_captured_at,
                        TimestampFormatter.format(office?.capturedAtEpochMillis ?: 0L)
                    ),
                    style = MaterialTheme.typography.bodySmall,
                    color = colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp)
                )
            }

            Spacer(modifier = Modifier.size(18.dp))

            OutlinedButton(
                onClick = onSetOfficeLocation,
                enabled = state.canSetOfficeLocation,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 56.dp),
                shape = MaterialTheme.shapes.medium
            ) {
                if (state.isCapturingOfficeLocation) {
                    // The label below stays fixed at "Set Office Location" (AND-05), so the
                    // in-progress state has to be announced here or it is visual-only.
                    val capturing = stringResource(R.string.set_office_location_capturing)
                    CircularProgressIndicator(
                        modifier = Modifier
                            .size(18.dp)
                            .semantics { contentDescription = capturing },
                        strokeWidth = 2.dp
                    )
                } else {
                    Icon(
                        painter = painterResource(R.drawable.ic_crosshair),
                        // The button label immediately after says what this does.
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                }
                Spacer(modifier = Modifier.width(10.dp))
                // The label is fixed (AND-05). Progress is signalled by the leading indicator
                // and the disabled state, not by rewriting the mandated text.
                Text(
                    text = stringResource(R.string.set_office_location),
                    style = MaterialTheme.typography.labelLarge
                )
            }
        }
    }
}

/** "OFFICE" once captured, otherwise the live position that a capture would record. */
@Composable
private fun coordinateLabel(state: AttendanceUiState): String = when {
    state.office != null -> stringResource(R.string.location_surface_legend_office)
    else -> stringResource(R.string.location_surface_legend_you)
}

@Composable
private fun coordinateValue(state: AttendanceUiState): String {
    val coordinates = state.office?.coordinates ?: state.currentLocation?.coordinates
    return if (coordinates == null) {
        stringResource(R.string.location_surface_no_coordinates)
    } else {
        stringResource(
            R.string.location_surface_coordinates,
            CoordinateFormatter.latitude(coordinates),
            CoordinateFormatter.longitude(coordinates)
        )
    }
}

/**
 * The surface is a drawing, so everything it conveys visually has to be said in words for a
 * screen reader.
 */
@Composable
private fun surfaceContentDescription(state: AttendanceUiState, radiusMeters: Double): String {
    val proximity = state.proximity
    return when {
        proximity != null -> stringResource(
            R.string.content_description_location_surface_tracking,
            radiusMeters.toInt(),
            DistanceFormatter.format(proximity.distanceMeters)
        )

        state.office == null -> stringResource(R.string.content_description_location_surface_no_office)
        else -> stringResource(R.string.content_description_location_surface_no_fix)
    }
}
