package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.ProximityResult
import io.github.rktuhinbd.presencelens.attendance.domain.model.GeoCoordinates
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.ProximityGeometry
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * The location panel (AND-15), drawn entirely from Compose primitives.
 *
 * There is no Google Maps SDK here and no third-party tile of any kind (ADR-003): a Maps key
 * cannot be committed to a public repository, and an uncommitted one would leave this panel
 * blank for anyone cloning the project. What is drawn instead is not a substitute map - it is
 * a plan view of the thing the feature actually cares about, which a map tile cannot show:
 * the 50 m boundary itself, and the user's true bearing and distance across it.
 *
 * It offers no pan or zoom affordance, because it implements neither.
 */
@Composable
fun LocationSurface(
    officeCoordinates: GeoCoordinates?,
    currentCoordinates: GeoCoordinates?,
    proximity: ProximityResult?,
    radiusMeters: Double,
    coordinateLabel: String,
    coordinateValue: String,
    legendText: String,
    surfaceContentDescription: String,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors

    val isEligible = proximity?.isEligible == true
    val boundaryColor = when {
        proximity == null -> colorScheme.outline
        isEligible -> statusColors.success
        else -> colorScheme.error
    }

    // Cartesian rather than polar interpolation: animating the bearing directly would swing
    // the marker the long way round every time it crosses due north.
    val radiusFraction = if (proximity == null) {
        0f
    } else {
        ProximityGeometry.surfaceRadiusFraction(proximity.distanceMeters, radiusMeters)
    }
    val bearingRadians = ((proximity?.bearingFromOfficeDegrees ?: 0.0) * PI / 180.0).toFloat()
    val markerX by animateFloatAsState(
        targetValue = radiusFraction * sin(bearingRadians),
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "markerX"
    )
    val markerY by animateFloatAsState(
        targetValue = -radiusFraction * cos(bearingRadians),
        animationSpec = tween(durationMillis = 600, easing = FastOutSlowInEasing),
        label = "markerY"
    )

    // A slow breath on the "you are here" marker, signalling that the position is live.
    // It delays nothing and blocks nothing; it is the only motion on the panel.
    val pulse = rememberInfiniteTransition(label = "livePositionPulse")
    val pulseProgress by pulse.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2_400, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "livePositionPulseProgress"
    )

    Surface(
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        color = colorScheme.surfaceContainerHigh
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(SURFACE_HEIGHT_DP.dp)
                .background(
                    Brush.verticalGradient(
                        listOf(
                            colorScheme.surfaceContainerHigh,
                            colorScheme.surfaceContainerLow
                        )
                    )
                )
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .semantics { contentDescription = surfaceContentDescription }
            ) {
                drawLocationPlan(
                    hasOffice = officeCoordinates != null,
                    hasCurrentPosition = currentCoordinates != null,
                    markerX = markerX,
                    markerY = markerY,
                    boundaryColor = boundaryColor,
                    guideColor = colorScheme.outlineVariant,
                    officeColor = colorScheme.tertiary,
                    officeRingColor = colorScheme.surfaceContainerLowest,
                    connectorColor = colorScheme.onSurfaceVariant,
                    pulseProgress = pulseProgress
                )
            }

            Text(
                text = legendText,
                style = OverlineTextStyle,
                color = colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(14.dp)
            )

            CoordinatePill(
                label = coordinateLabel,
                value = coordinateValue,
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(12.dp)
            )
        }
    }
}

/** The readout overlay from the reference panel (AND-15). */
@Composable
private fun CoordinatePill(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.surfaceContainerLowest.copy(alpha = 0.92f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(6.dp)
                    .background(MaterialTheme.colorScheme.primary, CircleShape)
                    .clearAndSetSemantics { }
            )
            Column {
                Text(
                    text = label,
                    style = OverlineTextStyle,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = value,
                    style = MaterialTheme.typography.labelLarge,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

/**
 * Draws the plan view: guide rings, the attendance boundary, the office at the centre, and
 * the live position at its true bearing.
 */
private fun DrawScope.drawLocationPlan(
    hasOffice: Boolean,
    hasCurrentPosition: Boolean,
    markerX: Float,
    markerY: Float,
    boundaryColor: Color,
    guideColor: Color,
    officeColor: Color,
    officeRingColor: Color,
    connectorColor: Color,
    pulseProgress: Float
) {
    val center = Offset(size.width / 2f, size.height / 2f)
    val extent = min(size.width, size.height) / 2f * 0.88f
    val boundaryRadius = extent * BOUNDARY_RADIUS_FRACTION

    // Faint concentric guides, so the boundary ring reads as one step in a scale rather than
    // as an arbitrary circle.
    GUIDE_RING_MULTIPLES.forEach { multiple ->
        drawCircle(
            color = guideColor.copy(alpha = 0.34f),
            radius = boundaryRadius * multiple,
            center = center,
            style = Stroke(width = 1.dp.toPx())
        )
    }

    // Bearing reference lines. Kept very light: they orient the diagram without competing
    // with the two markers that carry the actual information.
    val axisColor = guideColor.copy(alpha = 0.28f)
    val axisExtent = boundaryRadius * GUIDE_RING_MULTIPLES.last()
    drawLine(
        color = axisColor,
        start = Offset(center.x, center.y - axisExtent),
        end = Offset(center.x, center.y + axisExtent),
        strokeWidth = 1.dp.toPx()
    )
    drawLine(
        color = axisColor,
        start = Offset(center.x - axisExtent, center.y),
        end = Offset(center.x + axisExtent, center.y),
        strokeWidth = 1.dp.toPx()
    )

    if (!hasOffice) {
        // Nothing is anchored yet, so the boundary would be a claim the app cannot make.
        drawCircle(
            color = guideColor.copy(alpha = 0.55f),
            radius = boundaryRadius,
            center = center,
            style = Stroke(
                width = 2.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 8.dp.toPx()))
            )
        )
        return
    }

    // The attendance boundary itself - the one thing a map tile could never show.
    drawCircle(color = boundaryColor.copy(alpha = 0.10f), radius = boundaryRadius, center = center)
    drawCircle(
        color = boundaryColor.copy(alpha = 0.85f),
        radius = boundaryRadius,
        center = center,
        style = Stroke(
            width = 2.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(10.dp.toPx(), 7.dp.toPx()))
        )
    )

    if (hasCurrentPosition) {
        val marker = Offset(
            x = center.x + markerX * boundaryRadius,
            y = center.y + markerY * boundaryRadius
        )

        drawLine(
            color = connectorColor.copy(alpha = 0.45f),
            start = center,
            end = marker,
            strokeWidth = 1.5.dp.toPx(),
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 5.dp.toPx()))
        )

        drawCircle(
            color = boundaryColor.copy(alpha = 0.10f + 0.12f * pulseProgress),
            radius = (12.dp.toPx()) * (1f + 0.35f * pulseProgress),
            center = marker
        )
        drawCircle(color = officeRingColor, radius = 8.dp.toPx(), center = marker)
        drawCircle(color = boundaryColor, radius = 5.5.dp.toPx(), center = marker)
    }

    // Office last, so it is never overdrawn when the user is standing on it.
    drawCircle(color = officeColor.copy(alpha = 0.16f), radius = 14.dp.toPx(), center = center)
    drawCircle(color = officeRingColor, radius = 9.dp.toPx(), center = center)
    drawCircle(color = officeColor, radius = 6.dp.toPx(), center = center)
}

private const val SURFACE_HEIGHT_DP = 208

/** The boundary ring sits well inside the panel so an out-of-range marker still fits. */
private const val BOUNDARY_RADIUS_FRACTION = 0.44f

private val GUIDE_RING_MULTIPLES = listOf(0.5f, 1.6f, 2.25f)
