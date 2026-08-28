package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.DistanceFormatter
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle
import kotlin.math.min

/**
 * The circular distance readout from the reference (AND-17): the live distance at the centre,
 * an "AWAY" caption, and an arc that fills as the attendance radius is consumed.
 *
 * The arc says how much of the 50 m allowance is spent and saturates at the boundary; how far
 * *beyond* the boundary the user is stays the number's job. Its colour is the same decision
 * the button uses - green inside, error outside - so the two can never disagree.
 */
@Composable
fun DistanceGauge(
    distanceMeters: Double?,
    usageFraction: Float,
    gaugeContentDescription: String,
    awayCaption: String,
    modifier: Modifier = Modifier,
    accentColor: Color = MaterialTheme.colorScheme.primary
) {
    val trackColor = MaterialTheme.colorScheme.surfaceContainerHighest
    val animatedFraction by animateFloatAsState(
        targetValue = usageFraction.coerceIn(0f, 1f),
        animationSpec = tween(durationMillis = 650, easing = FastOutSlowInEasing),
        label = "gaugeFraction"
    )
    val animatedColor by animateColorAsState(
        targetValue = accentColor,
        animationSpec = tween(durationMillis = 400),
        label = "gaugeColor"
    )

    val readout = distanceMeters?.let { DistanceFormatter.readout(it) }

    Box(
        modifier = modifier
            .size(GAUGE_SIZE_DP.dp)
            .semantics { contentDescription = gaugeContentDescription },
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val strokeWidth = GAUGE_STROKE_DP.dp.toPx()
            val diameter = min(size.width, size.height) - strokeWidth
            val topLeft = Offset(
                x = (size.width - diameter) / 2f,
                y = (size.height - diameter) / 2f
            )
            val arcSize = Size(diameter, diameter)

            drawArc(
                color = trackColor,
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = topLeft,
                size = arcSize,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
            )

            if (animatedFraction > 0f) {
                drawArc(
                    color = animatedColor,
                    // Twelve o'clock, so a partly filled gauge reads the way a dial does.
                    startAngle = -90f,
                    sweepAngle = 360f * animatedFraction,
                    useCenter = false,
                    topLeft = topLeft,
                    size = arcSize,
                    style = Stroke(width = strokeWidth, cap = StrokeCap.Round)
                )
            }
        }

        // The gauge announces itself through the Box above; repeating each fragment of text
        // would make a screen reader read the distance three times.
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .padding(GAUGE_STROKE_DP.dp * 2)
                .clearAndSetSemantics { }
        ) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = readout?.value ?: EMPTY_READOUT,
                    style = MaterialTheme.typography.displaySmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    textAlign = TextAlign.Center
                )
                if (readout != null) {
                    Text(
                        text = readout.unit,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 2.dp, bottom = 5.dp)
                    )
                }
            }
            Text(
                text = awayCaption,
                style = OverlineTextStyle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp)
            )
        }
    }
}

private const val GAUGE_SIZE_DP = 168
private const val GAUGE_STROKE_DP = 12

/** An em dash, so the gauge holds its shape before the first fix arrives. */
private const val EMPTY_READOUT = "—"
