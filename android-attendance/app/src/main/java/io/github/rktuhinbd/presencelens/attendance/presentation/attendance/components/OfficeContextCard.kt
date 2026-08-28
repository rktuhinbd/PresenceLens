package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
 * pill, the helper copy, and the office-location control.
 *
 * The card has two faces, because the user has two entirely different jobs here.
 *
 * **Before an office is saved** this is the screen's centre of gravity: a heading, a sentence
 * explaining why the coordinates are needed, and one prominent filled action reading exactly
 * "Set Office Location" (AND-05). Nothing else on the screen competes with it.
 *
 * **After an office is saved** the setup job is finished, so the control steps back to a quiet
 * secondary "Change office location" that routes through a confirmation - overwriting a saved
 * office silently would be the one destructive thing this screen can do.
 *
 * Both faces live on the same screen as the attendance action, never behind navigation
 * (AND-04). Every value shown is read from [state]; nothing is computed here.
 */
@Composable
fun OfficeContextCard(
    state: AttendanceUiState,
    onSetOfficeLocation: () -> Unit,
    onChangeOfficeLocation: () -> Unit,
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
        Column(modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp)) {
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

            Spacer(modifier = Modifier.size(12.dp))

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
                officeLegendLabel = stringResource(R.string.location_surface_legend_office),
                currentLegendLabel = stringResource(R.string.location_surface_legend_you),
                surfaceContentDescription = surfaceContentDescription(state, radiusMeters),
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.size(14.dp))

            // Setup and configured are the same card changing face, not two cards - a cross
            // fade keeps that legible when the office is captured.
            AnimatedContent(
                targetState = office != null,
                transitionSpec = { fadeIn(tween(240)) togetherWith fadeOut(tween(160)) },
                label = "officeContextFace"
            ) { isConfigured ->
                if (isConfigured) {
                    ConfiguredOffice(
                        capturedAtEpochMillis = office?.capturedAtEpochMillis,
                        enabled = state.canSetOfficeLocation,
                        isCapturing = state.isCapturingOfficeLocation,
                        onChangeOfficeLocation = onChangeOfficeLocation
                    )
                } else {
                    OfficeSetup(
                        enabled = state.canSetOfficeLocation,
                        isCapturing = state.isCapturingOfficeLocation,
                        onSetOfficeLocation = onSetOfficeLocation
                    )
                }
            }
        }
    }
}

/** First use: the screen's primary job, stated plainly and given the only filled button. */
@Composable
private fun OfficeSetup(
    enabled: Boolean,
    isCapturing: Boolean,
    onSetOfficeLocation: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Text(
            text = stringResource(R.string.office_context_setup_title),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = stringResource(R.string.office_context_setup_body),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.size(4.dp))

        Button(
            onClick = onSetOfficeLocation,
            enabled = enabled,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = PRIMARY_BUTTON_HEIGHT_DP.dp),
            shape = MaterialTheme.shapes.medium
        ) {
            if (isCapturing) {
                // The label stays fixed at "Set Office Location" (AND-05), so the in-progress
                // state has to be announced here or it is visual-only.
                val capturing = stringResource(R.string.set_office_location_capturing)
                CircularProgressIndicator(
                    modifier = Modifier
                        .size(18.dp)
                        .semantics { contentDescription = capturing },
                    strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.onPrimary
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
            // AND-05 mandates this exact label for the Setup Phase. Progress is signalled by
            // the leading indicator and the disabled state, not by rewriting the text.
            Text(
                text = stringResource(R.string.set_office_location),
                style = MaterialTheme.typography.labelLarge
            )
        }

        CapturingNote(visible = isCapturing)
    }
}

/** Setup is done: the helper copy, when it was captured, and a quiet way to redo it. */
@Composable
private fun ConfiguredOffice(
    capturedAtEpochMillis: Long?,
    enabled: Boolean,
    isCapturing: Boolean,
    onChangeOfficeLocation: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(
            text = stringResource(R.string.office_context_helper),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = stringResource(
                R.string.office_context_captured_at,
                TimestampFormatter.format(capturedAtEpochMillis ?: 0L)
            ),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        TextButton(
            onClick = onChangeOfficeLocation,
            enabled = enabled,
            modifier = Modifier.defaultMinSize(minHeight = MIN_TOUCH_TARGET_DP.dp)
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_swap),
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
            Text(
                text = stringResource(R.string.change_office_location),
                modifier = Modifier.padding(start = 8.dp),
                style = MaterialTheme.typography.labelLarge
            )
        }

        CapturingNote(visible = isCapturing)
    }
}

/**
 * What the app is doing while a one-shot capture runs.
 *
 * A high-accuracy fix can take several seconds, and a spinner alone does not say whether that
 * is expected. Without this line the obvious next move is to press the button again - which is
 * exactly what a capture in progress must not invite.
 */
@Composable
private fun CapturingNote(visible: Boolean, modifier: Modifier = Modifier) {
    AnimatedVisibility(
        visible = visible,
        enter = fadeIn() + expandVertically(),
        exit = fadeOut() + shrinkVertically(),
        modifier = modifier
    ) {
        Text(
            text = stringResource(R.string.set_office_location_capturing_note),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 6.dp)
        )
    }
}

/** "Office" once captured, otherwise the live position that a capture would record. */
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

private const val PRIMARY_BUTTON_HEIGHT_DP = 56

/** Android's minimum accessible touch target. */
private const val MIN_TOUCH_TARGET_DP = 48
